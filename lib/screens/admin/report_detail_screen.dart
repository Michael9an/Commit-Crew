import 'package:flutter/material.dart';
import '../../models/report.dart';
import '../../services/report_service.dart';

class ReportDetailScreen extends StatefulWidget {
  final ReportModel report;
  const ReportDetailScreen({Key? key, required this.report}) : super(key: key);

  @override
  _ReportDetailScreenState createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final ReportService _service = ReportService();
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.report.reviewerNotes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String status) async {
    setState(() {
      _isSaving = true;
    });
    try {
      await _service.updateReportStatus(
        reportId: widget.report.id,
        status: status,
        reviewerNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report marked as $status')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Detail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.eventName.isNotEmpty ? r.eventName : 'Event ${r.eventId}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Reported by: ${r.userId}'),
            const SizedBox(height: 8),
            Text('Reason: ${r.reason}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (r.details != null && r.details!.isNotEmpty) ...[
              const Text('Details:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(r.details!),
              const SizedBox(height: 12),
            ],

            const Divider(),
            const SizedBox(height: 8),
            const Text('Reviewer notes', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Add notes for this review (optional)',
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _updateStatus('reviewed'),
                    child: _isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2,)) : const Text('Mark Reviewed'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _updateStatus('resolved'),
                    child: _isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2,)) : const Text('Mark Resolved'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
