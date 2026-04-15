import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/special_offers_service.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_navigator.dart';
import 'package:flutter_sweet_shop_app_ui/core/utils/app_feedback.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/home_feature/presentation/screens/restaurants_with_discount_screen.dart';

import '../../data/data_source/local/sample_data.dart';

class SpecialOffers extends StatefulWidget {
  const SpecialOffers({super.key});

  @override
  State<SpecialOffers> createState() => _SpecialOffersState();
}

class _SpecialOffersState extends State<SpecialOffers> {
  final SpecialOffersService _specialOffersService = SpecialOffersService();
  List<SpecialOfferItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = AppSession.userId;
      final items = await _specialOffersService.getSpecialOffers(
        customerUserId: userId.isNotEmpty ? userId : null,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _items = [];
          _loading = false;
        });
      }
    }
  }

  void _onCouponTap() {
    context.showInfoMessage(
      'Kuponlar admin tarafından müşterilere atanır. Atanmış kuponlarınızı Kuponlarım sayfasında görebilirsiniz.',
    );
  }

  void _onRestaurantDiscountTap(SpecialOfferItem item) {
    appPush(
      context,
      RestaurantsWithDiscountScreen(
        discountPercent: item.discountValue,
        discountTitle: item.discountLabel,
      ),
    );
  }

  void _onItemTap(SpecialOfferItem item) {
    if (item.isCoupon) {
      _onCouponTap();
    } else if (item.isRestaurantDiscount) {
      _onRestaurantDiscountTap(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTypography = context.theme.appTypography;
    final appColors = context.theme.appColors;

    return AppScaffold(
      appBar: GeneralAppBar(title: 'Özel Teklifler'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildFallbackBanners(context)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(Dimens.largePadding),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return InkWell(
                        onTap: () => _onItemTap(item),
                        borderRadius:
                            BorderRadius.circular(Dimens.largePadding),
                        child: Container(
                          padding: const EdgeInsets.all(Dimens.largePadding),
                          decoration: BoxDecoration(
                            color: appColors.primary.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(Dimens.largePadding),
                            border: Border.all(
                              color: appColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Dimens.padding,
                                      vertical: Dimens.smallPadding,
                                    ),
                                    decoration: BoxDecoration(
                                      color: appColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item.discountLabel,
                                      style: appTypography.labelMedium
                                          .copyWith(color: Colors.white),
                                    ),
                                  ),
                                  if (item.minCartAmount != null &&
                                      item.minCartAmount! > 0) ...[
                                    const SizedBox(width: Dimens.padding),
                                    Text(
                                      '${item.minCartAmount!.round()} ₺ üzeri',
                                      style: appTypography.bodySmall
                                          .copyWith(color: appColors.gray4),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: Dimens.padding),
                              Text(
                                item.title,
                                style: appTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (item.description != null &&
                                  item.description!.isNotEmpty) ...[
                                const SizedBox(height: Dimens.smallPadding),
                                Text(
                                  item.description!,
                                  style: appTypography.bodySmall
                                      .copyWith(color: appColors.gray4),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              Padding(
                                padding: const EdgeInsets.only(top: Dimens.padding),
                                child: Row(
                                  children: [
                                    Text(
                                      item.isRestaurantDiscount
                                          ? 'Pastanelere git'
                                          : 'Bilgi',
                                      style: appTypography.labelMedium
                                          .copyWith(color: appColors.primary),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                      color: appColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Dimens.largePadding),
                  ),
                ),
    );
  }

  Widget _buildFallbackBanners(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(Dimens.largePadding),
      itemCount: banners.length,
      itemBuilder: (context, index) {
        return InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(Dimens.largePadding),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.largePadding),
            child: Image.asset(banners[index]),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: Dimens.largePadding),
    );
  }
}
