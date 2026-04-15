using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Vaveyla.Api.Data;
using Vaveyla.Api.Models;

namespace Vaveyla.Api.Controllers;

[ApiController]
[Route("api/restaurant")]
public sealed class RestaurantTopProductsController : ControllerBase
{
    private static readonly Regex QuantityProductRegex = new(
        @"^\s*(\d+)\s*[xX]\s*(.+?)\s*$",
        RegexOptions.Compiled);

    // Trailing "(...)" is removed since order items store weight like "(0.45 kg)".
    private static readonly Regex TrailingParenthesesRegex = new(
        @"\s*\([^)]*\)\s*$",
        RegexOptions.Compiled);

    private readonly VaveylaDbContext _dbContext;
    private readonly IRestaurantOwnerRepository _restaurantRepo;

    public RestaurantTopProductsController(
        VaveylaDbContext dbContext,
        IRestaurantOwnerRepository restaurantRepo)
    {
        _dbContext = dbContext;
        _restaurantRepo = restaurantRepo;
    }

    [HttpGet("{restaurantId:guid}/top-products")]
    [HttpGet("/restaurant/{restaurantId:guid}/top-products")]
    public async Task<ActionResult<object>> GetTopProducts(
        [FromRoute] Guid restaurantId,
        [FromQuery] string? period,
        CancellationToken cancellationToken)
    {
        if (restaurantId == Guid.Empty)
        {
            return BadRequest(new { message = "RestaurantId is required." });
        }

        var normalizedPeriod = (period ?? "all").Trim().ToLowerInvariant();
        DateTime? startUtc = null;

        if (normalizedPeriod == "all")
        {
            startUtc = null;
        }
        else if (normalizedPeriod == "weekly")
        {
            startUtc = DateTime.UtcNow.AddDays(-7);
        }
        else if (normalizedPeriod == "monthly")
        {
            startUtc = DateTime.UtcNow.AddDays(-30);
        }
        else
        {
            return BadRequest(new
            {
                message = "Invalid period. Use 'all', 'weekly', or 'monthly'."
            });
        }

        var menuItems = await _restaurantRepo.GetMenuItemsAsync(restaurantId, cancellationToken);
        if (menuItems.Count == 0)
        {
            return Ok(new { bestSeller = (object?)null, topProducts = Array.Empty<object>() });
        }

        var normalizedNameToMenuItem = menuItems
            .Where(mi => !string.IsNullOrWhiteSpace(mi.Name))
            .GroupBy(mi => NormalizeName(mi.Name))
            .ToDictionary(g => g.Key, g => g.First());

        var ordersQuery = _dbContext.CustomerOrders
            .Where(o =>
                o.RestaurantId == restaurantId &&
                o.Status == CustomerOrderStatus.Delivered)
            .AsNoTracking();

        if (startUtc.HasValue)
        {
            ordersQuery = ordersQuery.Where(o => o.CreatedAtUtc >= startUtc.Value);
        }

        // We only need Items strings to calculate top products.
        var orders = await ordersQuery
            .Select(o => o.Items)
            .ToListAsync(cancellationToken);

        var totalsByMenuItemId = new Dictionary<Guid, int>();
        var menuItemsList = menuItems;

        foreach (var itemsText in orders)
        {
            if (string.IsNullOrWhiteSpace(itemsText))
            {
                continue;
            }

            foreach (var (qty, productName) in ParseItems(itemsText))
            {
                if (qty <= 0 || string.IsNullOrWhiteSpace(productName))
                {
                    continue;
                }

                var matched = MatchMenuItem(
                    productName,
                    normalizedNameToMenuItem,
                    menuItemsList);

                if (matched is null)
                {
                    continue;
                }

                totalsByMenuItemId.TryGetValue(matched.MenuItemId, out var current);
                totalsByMenuItemId[matched.MenuItemId] = current + qty;
            }
        }

        if (totalsByMenuItemId.Count == 0)
        {
            return Ok(new { bestSeller = (object?)null, topProducts = Array.Empty<object>() });
        }

        var menuItemById = menuItems.ToDictionary(mi => mi.MenuItemId, mi => mi);

        var sortedTop = totalsByMenuItemId
            .OrderByDescending(kvp => kvp.Value)
            .ThenBy(kvp => menuItemById.TryGetValue(kvp.Key, out var mi) ? mi.Name : string.Empty)
            .Take(10)
            .ToList();

        var bestSellerId = sortedTop[0].Key;
        var bestSellerItem = menuItemById[bestSellerId];
        var bestSellerTotal = totalsByMenuItemId[bestSellerId];

        var topProducts = sortedTop.Select(kvp =>
        {
            var productId = kvp.Key;
            var productName = menuItemById[productId].Name;
            return new
            {
                productId,
                productName,
                totalSold = kvp.Value
            };
        }).ToList();

        return Ok(new
        {
            bestSeller = new
            {
                productId = bestSellerId,
                productName = bestSellerItem.Name,
                totalSold = bestSellerTotal
            },
            topProducts = topProducts
        });
    }

    private static IEnumerable<(int Quantity, string ProductName)> ParseItems(string itemsText)
    {
        var parts = itemsText.Split(
            ',',
            StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        foreach (var part in parts)
        {
            if (string.IsNullOrWhiteSpace(part))
            {
                continue;
            }

            var match = QuantityProductRegex.Match(part);
            if (!match.Success)
            {
                // If the format is unexpected, treat it as 1 quantity.
                var fallbackName = CleanProductName(part);
                if (!string.IsNullOrWhiteSpace(fallbackName))
                {
                    yield return (1, fallbackName);
                }

                continue;
            }

            var qtyText = match.Groups[1].Value;
            var nameText = match.Groups[2].Value;

            if (!int.TryParse(qtyText, out var qty) || qty <= 0)
            {
                continue;
            }

            var productName = CleanProductName(nameText);
            if (string.IsNullOrWhiteSpace(productName))
            {
                continue;
            }

            yield return (qty, productName);
        }
    }

    private static string CleanProductName(string productName)
    {
        var trimmed = productName.Trim();
        trimmed = TrailingParenthesesRegex.Replace(trimmed, string.Empty);
        return trimmed.Trim();
    }

    private static MenuItem? MatchMenuItem(
        string orderedProductName,
        IReadOnlyDictionary<string, MenuItem> normalizedNameToMenuItem,
        IReadOnlyList<MenuItem> menuItems)
    {
        var normalizedOrdered = NormalizeName(orderedProductName);
        if (normalizedNameToMenuItem.TryGetValue(normalizedOrdered, out var exact))
        {
            return exact;
        }

        // Fuzzy match: allow partial overlap, similar to existing order review logic.
        var candidates = new List<MenuItem>();
        foreach (var menuItem in menuItems)
        {
            if (string.IsNullOrWhiteSpace(menuItem.Name))
            {
                continue;
            }

            var normalizedMenuName = NormalizeName(menuItem.Name);
            if (normalizedOrdered.Contains(normalizedMenuName) ||
                normalizedMenuName.Contains(normalizedOrdered))
            {
                candidates.Add(menuItem);
            }
        }

        if (candidates.Count == 0)
        {
            return null;
        }

        // Prefer the "longest" menu name match to reduce ambiguity.
        return candidates
            .OrderByDescending(mi => mi.Name?.Length ?? 0)
            .First();
    }

    private static string NormalizeName(string value) =>
        value.Trim().ToLowerInvariant();
}

