import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/payment_methods.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../data/payment_methods_repository.dart';
import '../widgets/payment_method_row.dart';

/// Lets a driver decide which payment methods passengers can pick.
///
/// Cash is built in and always on. GCash, Maya, GoTyme and Maribank are built
/// in but off until the driver uploads a QR code for them; switching one off
/// keeps its QR code so it can be turned back on without re-uploading.
class DriverPaymentMethodsScreen extends StatefulWidget {
  const DriverPaymentMethodsScreen({super.key});

  @override
  State<DriverPaymentMethodsScreen> createState() =>
      _DriverPaymentMethodsScreenState();
}

class _DriverPaymentMethodsScreenState
    extends State<DriverPaymentMethodsScreen> {
  final _repository = PaymentMethodsRepository();

  List<DriverPaymentMethod> _methods = const [];
  final Set<String> _busyMethods = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final methods = await _repository.getDriverPaymentMethods();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// The stored state for a method, defensively defaulted to the built-in
  /// behaviour (cash on, everything else off) when the API omits it.
  DriverPaymentMethod _stateFor(PaymentMethodMeta meta) {
    for (final method in _methods) {
      if (method.method == meta.id) return method;
    }
    return DriverPaymentMethod(
      method: meta.id,
      isEnabled: meta.isCash,
    );
  }

  Future<void> _openQrFlow(PaymentMethodMeta meta) async {
    final saved = await context.push<bool>(
      '/driver/payment-methods/qr?method=${meta.id}',
    );
    if (saved == true) await _load();
  }

  Future<void> _toggle(PaymentMethodMeta meta, bool value) async {
    if (meta.isCash) return;

    final state = _stateFor(meta);
    // Enabling requires a QR code, so the upload flow drives the switch.
    if (value && (state.qrCodeUrl == null || state.qrCodeUrl!.isEmpty)) {
      await _openQrFlow(meta);
      return;
    }

    setState(() => _busyMethods.add(meta.id));
    try {
      final updated = await _repository.setDriverPaymentMethod(
        meta.id,
        isEnabled: value,
      );
      if (!mounted) return;
      setState(() {
        _methods = [
          for (final method in _methods)
            if (method.method == meta.id) updated else method,
        ];
        _busyMethods.remove(meta.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyMethods.remove(meta.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const AppTopBar(
        title: 'Payment Methods',
        fallbackLocation: '/profile',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Passengers see the methods you accept before they '
                            'choose you. Upload a QR code for an e-wallet to '
                            'turn it on.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _error = null;
                              });
                              _load();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < PaymentMethods.all.length; i++) ...[
                          if (i > 0)
                            Divider(color: Colors.grey.shade100, height: 1),
                          Builder(
                            builder: (context) {
                              final meta = PaymentMethods.all[i];
                              final state = _stateFor(meta);
                              return PaymentMethodRow(
                                meta: meta,
                                isEnabled: state.isEnabled,
                                qrCodeUrl: state.qrCodeUrl,
                                isBusy: _busyMethods.contains(meta.id),
                                onToggle: (value) => _toggle(meta, value),
                                onEditQr: () => _openQrFlow(meta),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
