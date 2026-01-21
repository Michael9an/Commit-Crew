import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/report_service.dart';
import '../../models/report.dart';
import 'report_detail_screen.dart';

class ContentModerationScreen extends StatefulWidget {
  const ContentModerationScreen({Key? key}) : super(key: key);

  @override
  State<ContentModerationScreen> createState() => _ContentModerationScreenState();
}

class _ContentModerationScreenState extends State<ContentModerationScreen> {
  final ReportService _reportService = ReportService();
  
  String _selectedStatus = 'pending';
  String _selectedReason = 'All';
  String _sortOrder = 'Newest'; // Newest, Oldest
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final List<String> _reasons = ['All', 'Inappropriate Content', 'Spam', 'Fraud', 'Misleading Information', 'Other'];

  late Stream<List<ReportModel>> _reportsStream;

  @override
  void initState() {
    super.initState();
    _reportsStream = _reportService.getReports(status: null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ReportModel>>(
        stream: _reportsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allReports = snapshot.data ?? [];
          
          final pendingCount = allReports.where((r) => r.status == 'pending').length;
          // final reviewingCount = allReports.where((r) => r.status == 'reviewing').length;
          final resolvedCount = allReports.where((r) => r.status == 'resolved').length;
          final dismissedCount = allReports.where((r) => r.status == 'dismissed').length;

          var reports = allReports.where((r) => r.status == _selectedStatus).toList();

          // Client-side filtering for Reason
          if (_selectedReason != 'All') {
            reports = reports.where((r) => r.reason == _selectedReason).toList();
          }

          // Client-side filtering for Search
          if (_searchController.text.isNotEmpty) {
            final search = _searchController.text.toLowerCase();
            reports = reports.where((r) => 
              r.eventName.toLowerCase().contains(search) || 
              r.reason.toLowerCase().contains(search)
            ).toList();
          }

          // Client-side sorting (Stream is already sorted by Newest/descending)
          if (_sortOrder == 'Oldest') {
            reports = reports.reversed.toList();
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!_isSearching)
                      const Text('Content Moderation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
                    else
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search by event or reason...',
                            border: InputBorder.none,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () => setState(() {}),
                            ),
                          ),
                          onSubmitted: (value) => setState(() {}),
                        ),
                      ),
                    IconButton(
                      icon: Icon(_isSearching ? Icons.close : Icons.search),
                      onPressed: () {
                        setState(() {
                          if (_isSearching) {
                            _searchController.clear();
                          }
                          _isSearching = !_isSearching;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Review and moderate reported content, events, and posts.'),
                const SizedBox(height: 18),
                
                // Filters
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusTab('pending', 'Pending', pendingCount),
                        // _buildStatusTab('reviewing', 'Reviewing', reviewingCount), // Removed as per request
                        _buildStatusTab('resolved', 'Resolved', resolvedCount),
                        _buildStatusTab('dismissed', 'Dismissed', dismissedCount),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    // Reason Filter
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 50,
                        child: DropdownButtonFormField<String>(
                          value: _selectedReason,
                          decoration: const InputDecoration(
                            labelText: 'Reason',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          ),
                          isExpanded: true,
                          items: _reasons.map((r) => DropdownMenuItem(
                            value: r, 
                            child: Text(
                              r, 
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            )
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedReason = val!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sort Filter
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 50,
                        child: DropdownButtonFormField<String>(
                          value: _sortOrder,
                          decoration: const InputDecoration(
                            labelText: 'Sort By',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          ),
                          isExpanded: true,
                          items: ['Newest', 'Oldest'].map((s) => DropdownMenuItem(
                            value: s, 
                            child: Text(
                              s,
                              style: const TextStyle(fontSize: 13),
                            )
                          )).toList(),
                          onChanged: (val) => setState(() => _sortOrder = val!),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Expanded(
                  child: reports.isEmpty
                      ? Center(child: Text('No $_selectedStatus reports found'))
                      : ListView.separated(
                          itemCount: reports.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final r = reports[index];
                            return _buildReportItem(r);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusTab(String status, String label, int count) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              )
            : null,
        child: Text(
          '$label ($count)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildReportItem(ReportModel r) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ReportDetailScreen(report: r),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Removed danger icon
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.eventName.isNotEmpty ? r.eventName : 'Event ${r.eventId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text('Reason: ${r.reason}', style: TextStyle(color: Colors.grey[800])),
                    const SizedBox(height: 4),
                    // User Name FutureBuilder
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(r.userId).get(),
                      builder: (context, snapshot) {
                        String userName = 'Loading...';
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          userName = data['name'] ?? 'Unknown User';
                        }
                        return Text(
                          'Reported by: $userName',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        );
                      },
                    ),
                    Text(
                      _formatDate(r.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  Future<void> _confirmDelete(ReportModel report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('reports').doc(report.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }
}