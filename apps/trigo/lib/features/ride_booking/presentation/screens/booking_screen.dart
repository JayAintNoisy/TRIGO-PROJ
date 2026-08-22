import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../data/rides_repository.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _repository = RidesRepository();
  bool _isLoading = false;
  String? _error;

  Future<void> _requestRide() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _repository.requestRide(
        municipalityId: '934d7d07-2e3b-440d-8fd4-26a9340143bb',
        pickupLat: 10.3157,
        pickupLng: 123.8854,
        pickupAddress: 'Mactan-Cebu International Airport (T1)',
        dropoffLat: 10.2520,
        dropoffLng: 123.9501,
        dropoffAddress: 'Cordova Public Market',
      );
      if (mounted) {
        context.go('/ride/${result['id']}/tracking');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppTopBar(title: 'Book Tricycle Ride'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.my_location, color: Colors.blue),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Mactan-Cebu International Airport (T1)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Cordova Public Market',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppCard(
                backgroundColor:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Fare (Cash)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '1.5 km',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    Text(
                      '\u20B145.00',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
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
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
              ],
              const Spacer(),
              AppButton(
                label: 'Confirm & Request Tricycle',
                icon: Icons.check_circle,
                isLoading: _isLoading,
                onPressed: _requestRide,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
