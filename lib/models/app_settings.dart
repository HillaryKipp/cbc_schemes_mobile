class AppSettings {
  final bool paymentsEnabled;
  final bool adsEnabled;
  final double pricePerScheme;
  final String currency;
  final String? mpesaPaybill;
  final String? supportPhone;
  final String? supportEmail;

  AppSettings({
    this.paymentsEnabled = false,
    this.adsEnabled = false,
    this.pricePerScheme = 100.0,
    this.currency = 'KES',
    this.mpesaPaybill,
    this.supportPhone = '+254700000000',
    this.supportEmail = 'ruttohkip4@gmail.com',
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      paymentsEnabled: json['payments_enabled'] as bool? ?? false,
      adsEnabled: json['ads_enabled'] as bool? ?? false,
      pricePerScheme: (json['price_per_scheme'] as num?)?.toDouble() ?? 100.0,
      currency: json['currency'] as String? ?? 'KES',
      mpesaPaybill: json['mpesa_paybill'] as String?,
      supportPhone: json['support_phone'] as String?,
      supportEmail: json['support_email'] as String? ?? 'ruttohkip4@gmail.com',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payments_enabled': paymentsEnabled,
      'ads_enabled': adsEnabled,
      'price_per_scheme': pricePerScheme,
      'currency': currency,
      'mpesa_paybill': mpesaPaybill,
      'support_phone': supportPhone,
      'support_email': supportEmail,
    };
  }
}
