import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Ensure you added this package
import '../../models/club.dart';
import '../../services/firestore_service.dart';
import '../../models/event.dart';
import '../../widgets/participant_list_sheet.dart';

class EventAnalyticsScreen extends StatefulWidget {
  final Club club;

  const EventAnalyticsScreen({super.key, required this.club});

  @override
  _EventAnalyticsScreenState createState() => _EventAnalyticsScreenState();
}

class _EventAnalyticsScreenState extends State<EventAnalyticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.last30Days;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics'),
        actions: [
          // Time Period Filter
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<AnalyticsPeriod>(
              value: _selectedPeriod,
              underline: SizedBox(),
              icon: Icon(Icons.calendar_today, color: Colors.blue),
              items: [
                DropdownMenuItem(
                  value: AnalyticsPeriod.last7Days,
                  child: Text('Last 7 Days'),
                ),
                DropdownMenuItem(
                  value: AnalyticsPeriod.last30Days,
                  child: Text('Last 30 Days'),
                ),
                DropdownMenuItem(
                  value: AnalyticsPeriod.thisYear,
                  child: Text('This Year'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPeriod = value);
                }
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<ClubAnalytics>(
        stream: _firestoreService.getClubAnalytics(widget.club.id, _selectedPeriod),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error loading analytics"));
          }

          final data = snapshot.data ?? ClubAnalytics.empty();

          if (data.totalEvents == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
                  SizedBox(height: 16),
                  Text("No data available for this period"),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Summary Cards
                Row(
                  children: [
                    _buildSummaryCard(
                      'Total Attendees',
                      '${data.totalAttendance}',
                      Icons.people,
                      Colors.blue,
                    ),
                    SizedBox(width: 12),
                    _buildSummaryCard(
                      'Revenue',
                      '\$${data.totalRevenue.toStringAsFixed(0)}',
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // 2. Attendance Chart
                Text("Attendance Trend", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Container(
                  height: 250,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: _buildLineChart(data.attendanceTrend),
                ),

                SizedBox(height: 24),

                // 3. Top Events List
                Text("Top Performing Events", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                ...data.topEvents.map((event) => _buildTopEventTile(event)),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopEventTile(EventModel event) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: Colors.grey[200]!)
      ),
      child: ListTile(
        // Add functionality to open the list
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true, // Needed for full height sheet
            backgroundColor: Colors.transparent,
            builder: (context) => ParticipantListSheet(event: event),
          );
        },
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            '${event.attendees.length}', 
            style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold)
          ),
        ),
        title: Text(
          event.name, 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis, 
          style: TextStyle(fontWeight: FontWeight.bold)
        ),
        subtitle: Text('Tap to view participants'), // Updated subtitle
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }

  Widget _buildLineChart(List<AttendanceData> trendData) {
    if (trendData.isEmpty) return Center(child: Text("No trend data"));

    // Convert data to FlSpots
    List<FlSpot> spots = [];
    for (int i = 0; i < trendData.length; i++) {
      spots.add(FlSpot(i.toDouble(), trendData[i].attendance.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < trendData.length) {
                  // Show only first, middle, last labels to prevent clutter
                  if (index == 0 || index == trendData.length - 1 || index == (trendData.length / 2).round()) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(trendData[index].date, style: TextStyle(fontSize: 10, color: Colors.grey)),
                    );
                  }
                }
                return SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}