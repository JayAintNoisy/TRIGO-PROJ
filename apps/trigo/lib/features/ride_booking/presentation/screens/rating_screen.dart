import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/utils/rating_window.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../data/rides_repository.dart';

/// Rates a finished ride, or changes an existing rating.
///
/// Both modes end on the trip receipt (`/ride/:id/details`), which is where the
/// rating is then displayed — so a passenger who already rated is taken to the
/// receipt with the rating shown, never asked to rate again.
class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({
    super.key,
    required this.rideId,
    this.isEditing = false,
    this.rideLoader,
  });

  final String rideId;

  /// True when changing a rating that already exists; the existing stars and
  /// feedback are loaded and submitted through the update endpoint.
  final bool isEditing;

  /// Test seam: supplies the current rating in edit mode without a network
  /// call. Defaults to the real repository.
  final Future<dynamic> Function(String rideId)? rideLoader;

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  late final RidesRepository _repository = RidesRepository();
  int _rating = 0;
  bool _isSubmitting = false;
  bool _isLoadingExisting = false;
  String? _loadError;
  final Set<String> _selectedFeedback = {};

  final List<String> _feedbackOptions = [
    'Polite',
    'Safe',
    'Clean',
    'On Time',
    'Friendly'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _isLoadingExisting = true;
      _loadExistingRating();
    }
  }

  Future<void> _loadExistingRating() async {
    try {
      final ride = await (widget.rideLoader?.call(widget.rideId) ??
          _repository.getRideById(widget.rideId));
      if (!mounted) return;
      final comment = ride is Map ? ride['ratingComment']?.toString() : null;
      setState(() {
        _rating = (ride is Map ? RidesRepository.ratingOf(ride) : null) ?? 0;
        _selectedFeedback
          ..clear()
          ..addAll(
            (comment ?? '')
                .split(',')
                .map((part) => part.trim())
                .where((part) => part.isNotEmpty),
          );
        _isLoadingExisting = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingExisting = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submitRating() async {
    if (_rating == 0 || widget.rideId.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final comment = _selectedFeedback.join(', ');
      if (widget.isEditing) {
        await _repository.updateRating(widget.rideId, _rating, comment: comment);
      } else {
        await _repository.rateRide(widget.rideId, _rating, comment: comment);
      }
      if (mounted) context.go('/ride/${widget.rideId}/details');
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _toggleFeedback(String feedback) {
    setState(() {
      if (_selectedFeedback.contains(feedback)) {
        _selectedFeedback.remove(feedback);
      } else {
        _selectedFeedback.add(feedback);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppTopBar(
        title: widget.isEditing ? 'Edit Your Rating' : 'Rate Your Ride',
        fallbackLocation: '/ride/${widget.rideId}/details',
      ),
      body: _isLoadingExisting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 40),
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.check, color: Colors.white, size: 48),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.isEditing ? 'Change your rating' : 'Ride Complete!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isEditing
                        ? 'You can change this within '
                            '${ratingEditWindowLabel()} of the trip.'
                        : 'How was your experience?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Could not load your current rating: $_loadError',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFDC2626)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Rate Your Driver',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Scales down rather than overflowing: five 40px stars
                        // plus their padding are wider than the card on a
                        // 320px screen.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return IconButton(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                constraints: const BoxConstraints(
                                    minWidth: 44, minHeight: 44),
                                icon: Icon(
                                  index < _rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 40,
                                  color: index < _rating
                                      ? const Color(0xFFF59E0B)
                                      : Colors.grey.shade300,
                                ),
                                onPressed: () {
                                  setState(() => _rating = index + 1);
                                },
                              );
                            }),
                          ),
                        ),
                        Text(
                          _rating == 0
                              ? 'Tap a star to rate'
                              : '$_rating out of 5',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'What went well?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: _feedbackOptions.map((option) {
                            final isSelected = _selectedFeedback.contains(option);
                            return GestureDetector(
                              onTap: () => _toggleFeedback(option),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFEFF6FF)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF3B82F6)
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              widget.isEditing
                                  ? 'Update Rating'
                                  : 'Submit & View Receipt',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
