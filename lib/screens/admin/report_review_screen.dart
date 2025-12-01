import 'package:flutter/material.dart';
import '../../services/report_service.dart';
import '../../models/report.dart';
import 'report_detail_screen.dart';

class ReportReviewScreen extends StatelessWidget {
  const ReportReviewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ReportService reportService = ReportService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Review'),
      ),
      body: StreamBuilder<List<ReportModel>>(
        stream: reportService.getPendingReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return const Center(child: Text('No pending reports'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final r = reports[index];
              return ListTile(
                title: Text(r.eventName.isNotEmpty ? r.eventName : 'Event ${r.eventId}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reason: ${r.reason}'),
                    const SizedBox(height: 4),
                    Text('By: ${r.userId} • ${_formatDate(r.createdAt)}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                isThreeLine: true,
                trailing: ElevatedButton(
                  child: const Text('Review'),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ReportDetailScreen(report: r),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}
