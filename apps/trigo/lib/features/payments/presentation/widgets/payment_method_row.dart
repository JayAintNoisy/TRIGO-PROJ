import 'package:flutter/material.dart';

import '../../../../core/constants/payment_methods.dart';
import '../../../../shared/widgets/authenticated_image.dart';
import '../../data/payment_methods_repository.dart';

/// One row on the driver's payment methods screen.
///
/// Cash is always available, so its switch is locked on and its only action is
/// informational; every other method is switched on by uploading a QR code.
class PaymentMethodRow extends StatelessWidget {
  const PaymentMethodRow({
    super.key,
    required this.meta,
    required this.isEnabled,
    required this.isBusy,
    required this.onToggle,
    required this.onEditQr,
    this.qrCodeUrl,
  });

  final PaymentMethodMeta meta;
  final bool isEnabled;
  final bool isBusy;
  final String? qrCodeUrl;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditQr;

  String get _subtitle {
    if (meta.isCash) return 'Always available — pay the driver directly';
    if (qrCodeUrl == null || qrCodeUrl!.isEmpty) {
      return 'Add a QR code to enable';
    }
    return isEnabled ? 'Enabled — tap to update the QR code' : 'QR code saved';
  }

  @override
  Widget build(BuildContext context) {
    final hasQr = qrCodeUrl != null && qrCodeUrl!.isNotEmpty;

    return InkWell(
      onTap: (meta.isCash || isBusy) ? null : onEditQr,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: meta.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(meta.icon, color: meta.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (hasQr) ...[
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: AuthenticatedImage(
                    url: absoluteUploadUrl(qrCodeUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            if (isBusy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Switch(
                value: isEnabled,
                onChanged: meta.isCash ? null : onToggle,
              ),
          ],
        ),
      ),
    );
  }
}
