import 'package:equatable/equatable.dart';

/// Règlages métier globaux (lus depuis app_settings, clé 'limits').
class BusinessLimits extends Equatable {
  const BusinessLimits({
    required this.maxDevices,
    required this.maxTvDevices,
    required this.monthlyPriceEur,
  });

  factory BusinessLimits.fromJson(Map<String, dynamic> json) => BusinessLimits(
        maxDevices: (json['max_devices_per_account'] as int?) ?? 1,
        maxTvDevices: (json['max_tv_devices_per_account'] as int?) ?? 0,
        monthlyPriceEur: (json['monthly_price_eur'] as num?)?.toInt() ?? 0,
      );

  final int maxDevices;
  final int maxTvDevices;
  final int monthlyPriceEur;

  String get priceLabel =>
      monthlyPriceEur > 0 ? '$monthlyPriceEur € / mois' : 'Gratuit';

  @override
  List<Object?> get props => <Object?>[maxDevices, maxTvDevices, monthlyPriceEur];
}
