import 'package:url_launcher/url_launcher.dart';

/// Phone actions for the Call and Text buttons on an active ride.
///
/// These supplement the in-app chat: calling and texting hand off to the
/// platform dialer and messaging app, so a driver on a motorcycle can reach a
/// passenger without opening TriGo again.
class PhoneActions {
  const PhoneActions._();

  /// Strips formatting and normalises a Philippine local number to E.164 so
  /// the dialer and SMS app receive something they can act on.
  static String sanitize(String rawPhone) {
    final trimmed = rawPhone.trim();
    if (trimmed.isEmpty) return '';

    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    if (hasPlus) return '+$digits';
    if (digits.startsWith('63')) return '+$digits';
    if (digits.startsWith('0')) return '+63${digits.substring(1)}';
    if (digits.length == 10) return '+63$digits';
    return digits;
  }

  /// Opens the dialer with [phone]. Returns false when it cannot be launched
  /// (no dialer, or the number is unusable) so callers can explain why.
  static Future<bool> placeCall(String phone) async {
    final number = sanitize(phone);
    if (number.isEmpty) return false;

    try {
      return await launchUrl(
        Uri(scheme: 'tel', path: number),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  /// Opens the messaging app addressed to [phone].
  static Future<bool> sendSms(String phone) async {
    final number = sanitize(phone);
    if (number.isEmpty) return false;

    try {
      return await launchUrl(
        Uri(scheme: 'smsto', path: number),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
