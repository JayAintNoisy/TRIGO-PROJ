import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/rides_repository.dart';

class RideCompleteScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideCompleteScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideCompleteScreen> createState() =>
      _RideCompleteScreenState();
}

class _RideCompleteScreenState extends ConsumerState<RideCompleteScreen> {
  final _repository = RidesRepository();
  dynamic _ride;
  bool _isLoading = true;
  int rating = 5;

  @override
  void initState() {
    super.initState();
    _loadRide();
  }

  Future<void> _loadRide() async {
    try {
      final ride = await _repository.getRideById(widget.rideId);
      if (mounted) setState(() { _ride = ride; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRating() async {
    try {
      await _repository.rateRide(widget.rideId, rating);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fare =
        _ride?['fareEstimate']?.toString() ?? '45';
    final driverName =
        _ride?['driverName'] ?? 'Driver';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFFD1FAE5),
                      child: Icon(Icons.check_circle,
                          size: 48, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ride Completed!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thank you for riding with $driverName.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    AppCard(
                      child: Column(
                        children: [
                          const Text('Total Fare Paid (Cash)'),
                          const SizedBox(height: 6),
                          Text(
                            '\u20B1${double.parse(fare).toStringAsFixed(2)}',
                            style: theme.textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                ),
                          ),
                          const Divider(height: 32),
                          const Text('Rate your driver:'),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return IconButton(
                                icon: Icon(
                                  index < rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 36,
                                ),
                                onPressed: () {
                                  setState(() => rating = index + 1);
                                },
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      label: 'Submit & Back to Home',
                      onPressed: () {
                        _submitRating();
                        context.go('/home');
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
