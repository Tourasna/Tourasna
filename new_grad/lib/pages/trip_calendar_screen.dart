import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_colors.dart';
import '../models/trip.dart';
import '../models/place_map.dart';

class TripCalendarScreen extends StatefulWidget {
  final Trip trip;
  final Function(int dayIndex) onDaySelected;

  const TripCalendarScreen({
    Key? key,
    required this.trip,
    required this.onDaySelected,
  }) : super(key: key);

  @override
  State<TripCalendarScreen> createState() => _TripCalendarScreenState();
}

class _TripCalendarScreenState extends State<TripCalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  Map<DateTime, TripDay> _tripDays = {};

  @override
  void initState() {
    super.initState();
    _initializeTripDays();
    _focusedDay = _tripDays.keys.first;
    _selectedDay = _focusedDay;
  }

  // تحويل الأيام لـ Map
  void _initializeTripDays() {
    for (var day in widget.trip.days) {
      if (day.date != null) {
        try {
          final date = DateTime.parse(day.date!);
          // حذف الوقت (عشان نقارن بالتاريخ بس)
          final dateOnly = DateTime(date.year, date.month, date.day);
          _tripDays[dateOnly] = day;
        } catch (e) {
          print('Error parsing date: ${day.date}');
        }
      }
    }
  }

  // التحقق إذا كان اليوم فيه رحلة
  bool _hasTripOnDay(DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    return _tripDays.containsKey(dateOnly);
  }

  // جلب بيانات اليوم
  TripDay? _getTripDay(DateTime day) {
    final dateOnly = DateTime(day.year, day.month, day.day);
    return _tripDays[dateOnly];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.tealDark,
        title: Text('${widget.trip.destination} Trip Calendar'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 📅 الـ Calendar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              
              // عند اختيار يوم
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              
              // شكل الـ Calendar
              calendarStyle: CalendarStyle(
                // اليوم الحالي
                todayDecoration: BoxDecoration(
                  color: AppColors.blueGray.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                
                // اليوم المختار
                selectedDecoration: const BoxDecoration(
                  color: AppColors.pyramid,
                  shape: BoxShape.circle,
                ),
                
                // علامة على الأيام اللي فيها رحلة
                markerDecoration: const BoxDecoration(
                  color: AppColors.tealDark,
                  shape: BoxShape.circle,
                ),
              ),
              
              // Header style
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tealDark,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.pyramid,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.pyramid,
                ),
              ),
              
              // إضافة markers للأيام اللي فيها رحلة
              eventLoader: (day) {
                return _hasTripOnDay(day) ? ['trip'] : [];
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 📋 تفاصيل اليوم المختار
          Expanded(
            child: _selectedDay != null && _hasTripOnDay(_selectedDay!)
                ? _buildTripDayDetails(_getTripDay(_selectedDay!)!)
                : _buildNoTripMessage(),
          ),
        ],
      ),
    );
  }

  // 📋 عرض تفاصيل اليوم
  Widget _buildTripDayDetails(TripDay tripDay) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.pyramid,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Day ${tripDay.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                tripDay.date ?? '',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // عدد الأماكن
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.tealDark, size: 20),
              const SizedBox(width: 8),
              Text(
                '${tripDay.places.length} Places to Visit',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealDark,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // قائمة الأماكن
          Expanded(
            child: ListView.builder(
              itemCount: tripDay.places.length,
              itemBuilder: (context, index) {
                final place = tripDay.places[index];
                if (place.id == 'user') return const SizedBox.shrink();
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.pyramid.withOpacity(0.2),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.pyramid,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      place.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (place.category != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            place.category!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        if (place.estimatedVisitTime != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: AppColors.pyramid),
                              const SizedBox(width: 4),
                              Text(
                                place.estimatedVisitTime!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.tealDark,
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // زر View on Map
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // الرجوع للخريطة وعرض هذا اليوم
                final dayIndex = widget.trip.days.indexOf(tripDay);
                widget.onDaySelected(dayIndex);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.map),
              label: const Text(
                'View on Map',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pyramid,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // رسالة لما مافيش رحلة في اليوم
  Widget _buildNoTripMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No trip planned for this day',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}