import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/trip_history.dart';
import '../services/trip_history_service.dart';


class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final TripHistoryService _historyService = TripHistoryService();
  List<TripHistoryItem> _history = [];
  Map<String, dynamic> _statistics = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    
    final history = await _historyService.getTripHistory();
    final stats = await _historyService.getStatistics();
    
    setState(() {
      _history = history..sort((a, b) => b.startDate.compareTo(a.startDate));
      _statistics = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.tealDark,
        title: const Text('Trip History'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showClearConfirmation(),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildStatistics(),
                    Expanded(child: _buildHistoryList()),
                  ],
                ),
    );
  }

  // 📊 الإحصائيات
  Widget _buildStatistics() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.cream,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.trip_origin,
            '${_statistics['totalTrips']}',
            'Trips',
          ),
          _buildStatItem(
            Icons.check_circle,
            '${_statistics['completedTrips']}',
            'Completed',
          ),
          _buildStatItem(
            Icons.place,
            '${_statistics['totalPlaces']}',
            'Places',
          ),
          _buildStatItem(
            Icons.route,
            '${_statistics['totalDistance']?.toStringAsFixed(0)} km',
            'Distance',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.pyramid, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.tealDark,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // 📜 قائمة الرحلات
  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final trip = _history[index];
        return _buildTripCard(trip);
      },
    );
  }

  Widget _buildTripCard(TripHistoryItem trip) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: فتح تفاصيل الرحلة
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // أيقونة الحالة
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: trip.isCompleted
                          ? Colors.green.withOpacity(0.1)
                          : AppColors.pyramid.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      trip.isCompleted ? Icons.check_circle : Icons.pending,
                      color: trip.isCompleted ? Colors.green : AppColors.pyramid,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // العنوان
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.destination,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.tealDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(trip.startDate),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // زر الحذف
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteTrip(trip),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              // المعلومات
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoChip(
                    Icons.place,
                    '${trip.placesVisited} places',
                  ),
                  _buildInfoChip(
                    Icons.route,
                    '${trip.totalDistance.toStringAsFixed(1)} km',
                  ),
                  if (trip.endDate != null)
                    _buildInfoChip(
                      Icons.timer,
                      '${trip.endDate!.difference(trip.startDate).inHours}h',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.pyramid),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  // رسالة فارغة
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No trip history yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start your first trip to see it here!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // حذف رحلة
  Future<void> _deleteTrip(TripHistoryItem trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trip?'),
        content: Text('Delete trip to ${trip.destination}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _historyService.deleteTripHistory(trip.id);
      _loadHistory();
    }
  }

  // مسح الكل
  Future<void> _showClearConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text('This will delete all your trip history permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _historyService.clearAllHistory();
      _loadHistory();
    }
  }
}