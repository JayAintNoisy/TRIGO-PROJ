import 'package:flutter/material.dart';

/// Display metadata for one payment method.
///
/// Every value here mirrors the backend catalog in
/// `trigo-backend/src/shared/constants/payment-status.ts`: cash is always
/// available and is never configured per driver, while the e-wallets are off
/// until the driver uploads a QR code for them.
@immutable
class PaymentMethodMeta {
  const PaymentMethodMeta({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.blurb,
    this.isCash = false,
  });

  /// Wire value shared with the API (`cash`, `gcash`, `maya`, …).
  final String id;

  /// Human-readable name shown in the app.
  final String label;

  final IconData icon;

  /// Brand colour used for the icon and accents.
  final Color color;

  /// Soft tile background behind [icon].
  final Color background;

  /// One-line explanation shown under the label.
  final String blurb;

  /// Cash needs no configuration, so it can never be switched off.
  final bool isCash;
}

/// The built-in payment methods, in display order.
class PaymentMethods {
  const PaymentMethods._();

  static const String cash = 'cash';
  static const String gcash = 'gcash';
  static const String maya = 'maya';
  static const String gotyme = 'gotyme';
  static const String maribank = 'maribank';

  static const List<PaymentMethodMeta> all = [
    PaymentMethodMeta(
      id: cash,
      label: 'Cash',
      icon: Icons.payments_outlined,
      color: Color(0xFF059669),
      background: Color(0xFFECFDF5),
      blurb: 'Pay the driver directly',
      isCash: true,
    ),
    PaymentMethodMeta(
      id: gcash,
      label: 'GCash',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFF2563EB),
      background: Color(0xFFEFF6FF),
      blurb: 'Scan the driver\'s GCash QR code',
    ),
    PaymentMethodMeta(
      id: maya,
      label: 'Maya',
      icon: Icons.credit_card_outlined,
      color: Color(0xFF7C3AED),
      background: Color(0xFFF5F3FF),
      blurb: 'Scan the driver\'s Maya QR code',
    ),
    PaymentMethodMeta(
      id: gotyme,
      label: 'GoTyme',
      icon: Icons.savings_outlined,
      color: Color(0xFF0891B2),
      background: Color(0xFFECFEFF),
      blurb: 'Scan the driver\'s GoTyme QR code',
    ),
    PaymentMethodMeta(
      id: maribank,
      label: 'Maribank',
      icon: Icons.account_balance_outlined,
      color: Color(0xFFDB2777),
      background: Color(0xFFFDF2F8),
      blurb: 'Scan the driver\'s Maribank QR code',
    ),
  ];

  /// The always-available cash method.
  static PaymentMethodMeta get cashMethod => all.first;

  /// Looks a method up by id; unknown or missing ids fall back to cash, which
  /// is the method a ride is paid with when the passenger never chose one.
  static PaymentMethodMeta byId(String? id) {
    if (id == null) return cashMethod;
    for (final method in all) {
      if (method.id == id) return method;
    }
    return cashMethod;
  }

  /// Label for a stored method id, defensive against unknown values.
  static String labelFor(String? id) => byId(id).label;
}
