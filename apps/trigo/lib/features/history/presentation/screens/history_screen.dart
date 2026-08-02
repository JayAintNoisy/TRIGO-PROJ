import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Widget _buildRideCard({
    required BuildContext context,
    required String date,
    required String status,
    required Color statusColor,
    required Color statusBgColor,
    required String pickup,
    required String dropoff,
    required String driverName,
    required String fare,
    required bool isCancelled,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Timeline
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCancelled ? Colors.grey.shade100 : const Color(0xFFD1FAE5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isCancelled ? Colors.grey.shade400 : const Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                    Text(
                      pickup,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCancelled ? Colors.grey.shade100 : const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isCancelled ? Colors.grey.shade400 : const Color(0xFFF87171),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Drop-off',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                    ),
                    Text(
                      dropoff,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade100),
          const SizedBox(height: 12),
          
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Driver',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                  Text(
                    driverName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Fare',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                  Text(
                    fare,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isCancelled ? Colors.grey.shade400 : const Color(0xFF059669),
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Ride History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.grey.shade400),
            onPressed: () {},
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey.shade100,
            height: 1,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRideCard(
            context: context,
            date: 'Today, 2:45 PM',
            status: 'Completed',
            statusColor: const Color(0xFF047857),
            statusBgColor: const Color(0xFFD1FAE5),
            pickup: 'Barangay Center',
            dropoff: 'SM Mall',
            driverName: 'Mang Jose',
            fare: '₱50',
            isCancelled: false,
          ),
          _buildRideCard(
            context: context,
            date: 'Yesterday, 4:30 PM',
            status: 'Completed',
            statusColor: const Color(0xFF047857),
            statusBgColor: const Color(0xFFD1FAE5),
            pickup: 'Home',
            dropoff: 'Market',
            driverName: 'Kuya Mario',
            fare: '₱35',
            isCancelled: false,
          ),
          _buildRideCard(
            context: context,
            date: 'Apr 28, 10:15 AM',
            status: 'Completed',
            statusColor: const Color(0xFF047857),
            statusBgColor: const Color(0xFFD1FAE5),
            pickup: 'Church',
            dropoff: 'Hospital',
            driverName: 'Tatay Ben',
            fare: '₱65',
            isCancelled: false,
          ),
          _buildRideCard(
            context: context,
            date: 'Apr 27, 3:20 PM',
            status: 'Cancelled',
            statusColor: Colors.grey.shade600,
            statusBgColor: Colors.grey.shade200,
            pickup: 'School',
            dropoff: 'Home',
            driverName: 'Mang Carlos',
            fare: '₱40',
            isCancelled: true,
          ),
        ],
      ),
    );
  }
}
