import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/club.dart';
import '../../services/firestore_service.dart';

class EventAnalyticsScreen extends StatefulWidget {
  final Club? club;

  const EventAnalyticsScreen({super.key, this.club});

  @override
  _EventAnalyticsScreenState createState() => _EventAnalyticsScreenState();
}

class _EventAnalyticsScreenState extends State<EventAnalyticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.last30Days;

  late Stream<ClubAnalytics> _analyticsStream;

  @override
  void initState() {
    super.initState();
    if (widget.club != null) {
      _analyticsStream = _firestoreService.getClubAnalytics(widget.club!.id, _selectedPeriod);
    } else {
      _analyticsStream = Stream.value(ClubAnalytics.empty());
    }
  }

  void _changePeriod(AnalyticsPeriod period) {
    setState(() {
      _selectedPeriod = period;
      if (widget.club != null) {
        _analyticsStream = _firestoreService.getClubAnalytics(widget.club!.id, period);
      } else {
        _analyticsStream = Stream.value(ClubAnalytics.empty());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: Text('${widget.club?.name ?? 'Club'} Analytics'),
        actions: [
          PopupMenuButton<AnalyticsPeriod>(
            onSelected: _changePeriod,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: AnalyticsPeriod.last7Days,
                child: Text('Last 7 Days'),
              ),
              PopupMenuItem(
                value: AnalyticsPeriod.last30Days,
                child: Text('Last 30 Days'),
              ),
              PopupMenuItem(
                value: AnalyticsPeriod.last90Days,
                child: Text('Last 90 Days'),
              ),
              PopupMenuItem(
                value: AnalyticsPeriod.thisYear,
                child: Text('This Year'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<ClubAnalytics>(
        stream: _analyticsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error loading analytics'),
                  SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final analytics = snapshot.data ?? ClubAnalytics.empty();

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              // Summary Cards
              _buildSummaryCards(analytics),
              SizedBox(height: 24),

              // Attendance Chart
              _buildAttendanceChart(analytics),
              SizedBox(height: 24),

              // Revenue Chart (if applicable)
              if (analytics.totalRevenue > 0) ...[
                _buildRevenueChart(analytics),
                SizedBox(height: 24),
              ],

              // Event Performance
              _buildEventPerformance(analytics),
              SizedBox(height: 24),

              // Popular Events
              _buildPopularEvents(analytics),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(ClubAnalytics analytics) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildSummaryCard(
          title: 'Total Events',
          value: analytics.totalEvents.toString(),
          icon: Icons.event,
          color: Colors.blue,
        ),
        _buildSummaryCard(
          title: 'Total Attendance',
          value: analytics.totalAttendance.toString(),
          icon: Icons.people,
          color: Colors.green,
        ),
        _buildSummaryCard(
          title: 'Avg. Attendance',
          value: analytics.averageAttendance.toStringAsFixed(1),
          icon: Icons.trending_up,
          color: Colors.orange,
        ),
        _buildSummaryCard(
          title: 'Total Revenue',
          value: '\$${analytics.totalRevenue.toStringAsFixed(2)}',
          icon: Icons.attach_money,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceChart(ClubAnalytics analytics) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: analytics.attendanceTrend.map((e) => e.attendance.toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
                  barGroups: analytics.attendanceTrend.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.attendance.toDouble(),
                          color: Colors.blue,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Transform.rotate(
                              angle: -0.785398, // 45 degrees in radians
                              child: Text(
                                analytics.attendanceTrend[value.toInt()].date,
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(ClubAnalytics analytics) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: analytics.revenueTrend.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.revenue);
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= analytics.revenueTrend.length) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Transform.rotate(
                              angle: -0.785398, // 45 degrees in radians
                              child: Text(
                                analytics.revenueTrend[value.toInt()].date,
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('\$${value.toInt()}',
                              style: TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventPerformance(ClubAnalytics analytics) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPerformanceMetric(
                    'Completion Rate',
                    '${analytics.completionRate.toStringAsFixed(1)}%',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildPerformanceMetric(
                    'Cancellation Rate',
                    '${analytics.cancellationRate.toStringAsFixed(1)}%',
                    Icons.cancel,
                    Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildCapacityUtilization(analytics),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetric(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCapacityUtilization(ClubAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Average Capacity Utilization',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        LinearProgressIndicator(
          value: analytics.averageCapacityUtilization / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            analytics.averageCapacityUtilization >= 80
                ? Colors.green
                : analytics.averageCapacityUtilization >= 50
                    ? Colors.orange
                    : Colors.red,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${analytics.averageCapacityUtilization.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPopularEvents(ClubAnalytics analytics) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Events',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            if (analytics.topEvents.isEmpty)
              Center(
                child: Text(
                  'No events in this period',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Column(
                children: analytics.topEvents.map((event) {
                  final utilization = event.maxAttendees > 0
                      ? (event.attendees.length / event.maxAttendees * 100)
                      : 0;

                  return ListTile(
                    leading: event.bannerUrl != null
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(event.bannerUrl!),
                          )
                        : CircleAvatar(
                            child: Icon(Icons.event),
                          ),
                    title: Text(event.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${event.formattedDate} • ${event.location}'),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.people, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text('${event.attendees.length} attendees'),
                            if (event.maxAttendees > 0) ...[
                              SizedBox(width: 8),
                              Text(
                                '(${utilization.toStringAsFixed(1)}% full)',
                                style: TextStyle(
                                  color: utilization >= 80
                                      ? Colors.green
                                      : utilization >= 50
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(
                        event.isFree ? 'Free' : '\$${event.price}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: event.isFree ? Colors.green : Colors.blue,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}