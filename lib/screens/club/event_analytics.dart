import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; 
import '../../models/club.dart';
import '../../services/firestore_service.dart';
import '../../models/event.dart';
// import '../../widgets/participant_list_sheet.dart'; // Removed: Replaced with full details screen
import 'club_event_details_screen.dart'; // Ensure this matches your file structure

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
        title: const Text('Analytics'),
        actions: [
          // Time Period Filter
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<AnalyticsPeriod>(
              value: _selectedPeriod,
              underline: const SizedBox(),
              icon: const Icon(Icons.calendar_today, color: Colors.blue),
              items: const [
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
      // Wrapped in RefreshIndicator for better UX
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {}); // Triggers StreamBuilder to reload
        },
        child: StreamBuilder<ClubAnalytics>(
          stream: _firestoreService.getClubAnalytics(widget.club.id, _selectedPeriod),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text("Error loading analytics"));
            }

            final data = snapshot.data ?? ClubAnalytics.empty();

            if (data.totalEvents == 0) {
              return ListView( // Use ListView to allow RefreshIndicator to work on empty state
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text("No data available for this period"),
                      ],
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh always works
              padding: const EdgeInsets.all(16),
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
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'Revenue',
                        '\$${data.totalRevenue.toStringAsFixed(2)}', // Updated to 2 decimal places for accuracy
                        Icons.attach_money,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. Attendance Chart
                  const Text("Attendance Trend", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    height: 250,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: _buildLineChart(data.attendanceTrend),
                  ),

                  const SizedBox(height: 24),

                  // 3. Top Events List
                  const Text("Top Performing Events", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...data.topEvents.map((event) => _buildTopEventTile(event)),
                  
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
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
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: Colors.grey[200]!)
      ),
      child: ListTile(
        // UPDATED: Navigate to Full Details Screen instead of simple list
        // This allows Access to Export, Scanner, and Management tools
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClubEventDetailsScreen(
                event: event,
                club: widget.club,
              ),
            ),
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
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        subtitle: const Text('Tap to manage & export'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }

  Widget _buildLineChart(List<AttendanceData> trendData) {
    if (trendData.isEmpty) return const Center(child: Text("No trend data"));

    // Convert data to FlSpots
    List<FlSpot> spots = [];
    for (int i = 0; i < trendData.length; i++) {
      spots.add(FlSpot(i.toDouble(), trendData[i].attendance.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                      child: Text(trendData[index].date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    );
                  }
                }
                return const SizedBox();
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
            dotData: const FlDotData(show: false),
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