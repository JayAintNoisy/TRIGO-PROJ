import 'package:flutter/material.dart';
import '../../../../shared/services/geocoding_service.dart';
import '../../../../shared/utils/input_validators.dart';
import 'address_search_input.dart';

/// Draggable booking sheet content for the customer home screen with adaptive,
/// compact sizing, debounced address search, and "Select on Map" support.
class CustomerBookingSheet extends StatelessWidget {
  const CustomerBookingSheet({
    super.key,
    required this.userName,
    required this.pickupController,
    required this.dropoffController,
    required this.bookingFormKey,
    required this.passengerCount,
    required this.isRequesting,
    required this.onIncrementPassenger,
    required this.onDecrementPassenger,
    required this.onFindTrike,
    required this.scrollController,
    this.bottomInset = 0,
    this.proximityLat,
    this.proximityLng,
    this.onPickupSelected,
    this.onDropoffSelected,
    this.onToggleExpand,
    this.onPickPickupOnMap,
    this.onPickDropoffOnMap,
  });

  final String? userName;
  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final GlobalKey<FormState> bookingFormKey;
  final int passengerCount;
  final bool isRequesting;
  final VoidCallback onIncrementPassenger;
  final VoidCallback onDecrementPassenger;
  final VoidCallback onFindTrike;
  final ScrollController scrollController;
  final double bottomInset;
  final double? proximityLat;
  final double? proximityLng;
  final ValueChanged<LocationSearchResult>? onPickupSelected;
  final ValueChanged<LocationSearchResult>? onDropoffSelected;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onPickPickupOnMap;
  final VoidCallback? onPickDropoffOnMap;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 720;
    final sectionGap = isSmallScreen ? 10.0 : 14.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.only(
          left: isSmallScreen ? 16 : 20,
          right: isSmallScreen ? 16 : 20,
          top: 6,
          bottom: bottomInset + (isSmallScreen ? 62 : 72),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Full top header interactive area for open/close toggle
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleExpand,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Welcome, ${userName ?? 'Rider'}!',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 18 : 21,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Icon(
                              Icons.unfold_more_rounded,
                              size: 22,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 4 : 8),
                Form(
                  key: bookingFormKey,
                  child: Column(
                    children: [
                      AddressSearchInput(
                        hint: 'Current Location',
                        controller: pickupController,
                        prefixIcon: const Icon(Icons.my_location,
                            color: Color(0xFF10B981), size: 20),
                        accentColor: const Color(0xFF10B981),
                        proximityLat: proximityLat,
                        proximityLng: proximityLng,
                        onLocationSelected: onPickupSelected,
                        onSelectFromMap: onPickPickupOnMap,
                        validator: (value) => InputValidators.required(
                            value, 'Enter your pickup location'),
                      ),
                      const SizedBox(height: 8),
                      AddressSearchInput(
                        hint: 'Drop-off Destination',
                        controller: dropoffController,
                        prefixIcon: const Icon(Icons.location_on,
                            color: Color(0xFFEF4444), size: 20),
                        accentColor: const Color(0xFFEF4444),
                        proximityLat: proximityLat,
                        proximityLng: proximityLng,
                        onLocationSelected: onDropoffSelected,
                        onSelectFromMap: onPickDropoffOnMap,
                        validator: (value) => InputValidators.required(
                            value, 'Enter your drop-off destination'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 14,
                    vertical: isSmallScreen ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Number of Passengers',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 13 : 14,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fare will be split among passengers',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10.5 : 11,
                              color: const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: onDecrementPassenger,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                child: const Text(
                                  '-',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$passengerCount',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 15 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: onIncrementPassenger,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                child: const Text(
                                  '+',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isRequesting ? null : onFindTrike,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 12 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor:
                          const Color(0xFF2563EB).withValues(alpha: 0.2),
                    ),
                    child: isRequesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Find a Trike',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
