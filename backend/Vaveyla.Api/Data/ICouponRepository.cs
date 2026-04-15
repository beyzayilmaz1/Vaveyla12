using Vaveyla.Api.Models;

namespace Vaveyla.Api.Data;

public interface ICouponRepository
{
    Task<Coupon?> GetByCodeAsync(string code, CancellationToken ct = default);
    Task<Coupon?> GetByIdAsync(Guid couponId, CancellationToken ct = default);
    Task<UserCoupon?> GetUserCouponAsync(Guid userCouponId, CancellationToken ct = default);
    Task<UserCoupon?> GetUserCouponAsync(Guid userId, Guid couponId, CancellationToken ct = default);
    Task<bool> HasActiveUserCouponAsync(Guid userId, Guid couponId, CancellationToken ct = default);
    Task<List<UserCoupon>> GetUserCouponsAsync(Guid userId, CancellationToken ct = default);
    Task<List<UserCoupon>> GetPendingUserCouponsAsync(CancellationToken ct = default);
    Task<UserCoupon> CreateUserCouponAsync(UserCoupon userCoupon, CancellationToken ct = default);
    Task UpdateUserCouponAsync(UserCoupon userCoupon, CancellationToken ct = default);
    Task<Coupon> CreateCouponAsync(Coupon coupon, CancellationToken ct = default);
}
