import 'package:flutter/material.dart';

import '../../../../core/constants/payment_methods.dart';
import '../../../../shared/widgets/authenticated_image.dart';
import '../../data/payment_methods_repository.dart';

/// Asks the passenger how they will pay the driver.
///
/// Only methods the driver actually accepts are listed (cash always is), and a
/// selected e-wallet shows the driver's QR code so it can be scanned straight
/// away. Returns the chosen method id, or null when dismissed.
Future<String?> showPassengerPaymentMethodSheet(
  BuildContext context, {
  required List<EnabledPaymentMethod> methods,
  required String? selectedMethod,
  required String fareText,
  required String driverName,
}) {
  final available = methods.isEmpty
      ? const [EnabledPaymentMethod(method: 'cash')]
      : methods;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _PassengerPaymentMethodSheet(
      methods: available,
      selectedMethod: selectedMethod,
      fareText: fareText,
      driverName: driverName,
    ),
  );
}

class _PassengerPaymentMethodSheet extends StatefulWidget {
  const _PassengerPaymentMethodSheet({
    required this.methods,
    required this.selectedMethod,
    required this.fareText,
    required this.driverName,
  });

  final List<EnabledPaymentMethod> methods;
  final String? selectedMethod;
  final String fareText;
  final String driverName;

  @override
  State<_PassengerPaymentMethodSheet> createState() =>
      _PassengerPaymentMethodSheetState();
}

class _PassengerPaymentMethodSheetState
    extends State<_PassengerPaymentMethodSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    // Cash is the default when the passenger has not chosen yet.
    _selected = widget.selectedMethod ?? PaymentMethods.cash;
  }

  String? get _selectedQrUrl {
    for (final method in widget.methods) {
      if (method.method == _selected) return method.qrCodeUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'How will you pay?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pay ${widget.driverName} ${widget.fareText} with one of the '
                  'methods they accept',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              shrinkWrap: true,
              children: [
                for (final method in widget.methods)
                  _buildOption(context, method),
                if (_selected != PaymentMethods.cash && _selectedQrUrl != null) ...[
                  const SizedBox(height: 8),
                  _buildQrPreview(context, _selectedQrUrl!),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              media.padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Confirm ${PaymentMethods.labelFor(_selected)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, EnabledPaymentMethod method) {
    final meta = PaymentMethods.byId(method.method);
    final isSelected = method.method == _selected;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _selected = method.method),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade200,
              width: isSelected ? 1.6 : 1,
            ),
          ),
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
                      meta.blurb,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrPreview(BuildContext context, String qrCodeUrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 190,
              height: 190,
              child: AuthenticatedImage(
                url: absoluteUploadUrl(qrCodeUrl),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Scan this QR code with your ${PaymentMethods.labelFor(_selected)} app",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
