import 'package:url_launcher/url_launcher.dart';

/// Simple URL helper for common external links used in the app.
/// Keeps taps testable and centralizes URL constants.
class Links {
  static const String termsOfService = 'https://example.com/terms';
  static const String privacyPolicy = 'https://example.com/privacy';
  static const String helpCenter = 'https://example.com/help';
  static const String barbershopRegister =
      'https://example.com/register-barbershop';

  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}
