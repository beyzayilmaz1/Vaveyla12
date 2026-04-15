import 'package:flutter/material.dart';
import 'package:flutter_sweet_shop_app_ui/core/services/app_session.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/dimens.dart';
import 'package:flutter_sweet_shop_app_ui/core/theme/theme.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_button.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/app_scaffold.dart';
import 'package:flutter_sweet_shop_app_ui/core/widgets/general_app_bar.dart';
import 'package:flutter_sweet_shop_app_ui/features/coupon_feature/data/models/user_coupon_model.dart';
import 'package:flutter_sweet_shop_app_ui/features/coupon_feature/data/services/coupon_service.dart';

class CouponSelectScreen extends StatefulWidget {
  const CouponSelectScreen({
    super.key,
    this.selectedUserCouponId,
  });

  final String? selectedUserCouponId;

  @override
  State<CouponSelectScreen> createState() => _CouponSelectScreenState();
}

class _CouponSelectScreenState extends State<CouponSelectScreen> {
  final CouponService _couponService = CouponService();

  List<UserCouponModel> _coupons = [];
  bool _loading = true;
  String? _error;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedUserCouponId;
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    final userId = AppSession.userId;
    if (userId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Giriş yapın';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _couponService.getMyCoupons(customerUserId: userId);
      setState(() {
        _coupons = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _onSelect(UserCouponModel coupon) {
    if (!coupon.isUsable) return;
    setState(() {
      _selectedId = _selectedId == coupon.userCouponId ? null : coupon.userCouponId;
    });
  }

  void _confirm() {
    Navigator.of(context).pop(_selectedId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;

    return AppScaffold(
      appBar: GeneralAppBar(
        title: 'Kupon Seç',
        showBackIcon: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(Dimens.largePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: Dimens.padding),
                      child: Text(
                        _error!,
                        style: appTypography.bodySmall.copyWith(color: appColors.error),
                      ),
                    ),
                  Text(
                    'Kuponlarım',
                    style: appTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: Dimens.padding),
                  Builder(
                    builder: (context) {
                      final usableCoupons =
                          _coupons.where((c) => c.isUsable).toList();
                      if (usableCoupons.isEmpty)
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: Dimens.extraLargePadding),
                          child: Text(
                            'Henüz kullanılabilir kuponunuz yok. Admin tarafından size atanmış kuponlar burada görünecektir.',
                            style: appTypography.bodyMedium
                                .copyWith(color: appColors.gray4),
                            textAlign: TextAlign.center,
                          ),
                        );
                      return Column(
                        children: usableCoupons
                            .map((c) => _CouponTile(
                                  coupon: c,
                                  selected: _selectedId == c.userCouponId,
                                  onTap: () => _onSelect(c),
                                ))
                            .toList(),
                      );
                    },
                  ),
                  SizedBox(height: Dimens.extraLargePadding),
                  Builder(
                    builder: (context) {
                      final usableCoupons =
                          _coupons.where((c) => c.isUsable).toList();
                      return AppButton(
                        title: 'Uygula',
                        onPressed: usableCoupons.isEmpty ? null : _confirm,
                        textStyle: appTypography.bodyLarge,
                        borderRadius: Dimens.corners,
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({
    required this.coupon,
    required this.selected,
    required this.onTap,
  });

  final UserCouponModel coupon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = context.theme.appColors;
    final appTypography = context.theme.appTypography;
    final isDisabled = !coupon.isUsable;

    return Padding(
      padding: EdgeInsets.only(bottom: Dimens.padding),
      child: Material(
        color: isDisabled ? appColors.gray2.withValues(alpha: 0.3) : null,
        borderRadius: BorderRadius.circular(Dimens.corners),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(Dimens.corners),
          child: Container(
            padding: EdgeInsets.all(Dimens.largePadding),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? appColors.primary : appColors.gray2,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(Dimens.corners),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.discountText,
                        style: appTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDisabled ? appColors.gray4 : appColors.primary,
                        ),
                      ),
                      SizedBox(height: Dimens.smallPadding),
                      Text(
                        coupon.conditionsText,
                        style: appTypography.bodySmall.copyWith(
                          color: appColors.gray4,
                        ),
                      ),
                      if (coupon.isPending)
                        Text(
                          'Onay bekliyor',
                          style: appTypography.bodySmall.copyWith(
                            color: appColors.warning,
                          ),
                        )
                      else if (coupon.isUsed)
                        Text(
                          'Kullanıldı',
                          style: appTypography.bodySmall.copyWith(
                            color: appColors.gray4,
                          ),
                        )
                      else if (coupon.isExpired)
                        Text(
                          'Süresi doldu',
                          style: appTypography.bodySmall.copyWith(
                            color: appColors.error,
                          ),
                        ),
                    ],
                  ),
                ),
                if (coupon.isUsable)
                  Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected ? appColors.primary : appColors.gray4,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
