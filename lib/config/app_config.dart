class AppConfig {
  static const String stripeMerchantIdentifier = String.fromEnvironment(
    'STRIPE_MERCHANT_IDENTIFIER',
    defaultValue: 'merchant.pt.megacachorro.megadelivery',
  );

  static const String stripeReturnUrl = String.fromEnvironment(
    'STRIPE_RETURN_URL',
    defaultValue: 'flutterstripe://redirect',
  );

  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String googleGeocodingApiKey = String.fromEnvironment(
    'GOOGLE_GEOCODING_API_KEY',
    defaultValue: 'AIzaSyDIT0QuNYL0fMrVYDxMw70dI9STwysbT34',
  );

  static const String googleSignInServerClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
    defaultValue:
        '158452862906-1t5eo38n9tmgr3nilcbbu5rsm0mki3fj.apps.googleusercontent.com',
  );

  static const String adminEmailsCsv = String.fromEnvironment(
    'ADMIN_EMAILS',
    defaultValue: 'juka77@outlook.pt',
  );

  static List<String> get adminEmails => adminEmailsCsv
      .split(',')
      .map((email) => email.trim().toLowerCase())
      .where((email) => email.isNotEmpty)
      .toList(growable: false);

  static bool isAdminEmail(String? email) {
    final normalized = email?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return false;
    return adminEmails.contains(normalized);
  }
}
