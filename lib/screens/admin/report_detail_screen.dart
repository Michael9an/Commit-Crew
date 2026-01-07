import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/report.dart';
import '../../services/storage_service.dart';

class ReportDetailScreen extends StatefulWidget {
  final ReportModel report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  bool _isAddingNote = false;
  late Future<String?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _resolveImageUrl();
    _notesController.text = widget.report.reviewerNotes ?? '';
  }
  
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
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
      setState(() { _isSaving = true; });
      try {
        await FirebaseFirestore.instance.collection('reports').doc(widget.report.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report deleted')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
          setState(() { _isSaving = false; });
        }
      }
    }
  }

  Future<String?> _resolveImageUrl() async {
    if (widget.report.imageUrl != null && widget.report.imageUrl!.isNotEmpty) {
      return StorageService().resolveImageUrl(widget.report.imageUrl);
    }
    return null;
  }

  Future<void> _saveNotes() async {
    setState(() { _isSaving = true; });
    try {
      final Map<String, dynamic> updates = {
        'reviewerNotes': _notesController.text.trim(),
      };
      
      if (widget.report.status == 'pending') {
        updates['status'] = 'reviewing';
      }

      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.id)
          .update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes saved successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save notes: $e')));
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() { _isSaving = true; });
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.report.id)
          .update({
            'status': status,
            'reviewerNotes': _notesController.text.trim(),
            'resolvedAt': status == 'resolved' ? FieldValue.serverTimestamp() : null,
          });

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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section with Image/Avatar and Info
            FutureBuilder<DocumentSnapshot>(
              future: r.eventId.isNotEmpty 
                  ? FirebaseFirestore.instance.collection('events').doc(r.eventId).get()
                  : Future.value(null),
              builder: (context, eventSnapshot) {
                return FutureBuilder<DocumentSnapshot>(
                  future: r.userId.isNotEmpty
                      ? FirebaseFirestore.instance.collection('users').doc(r.userId).get()
                      : Future.value(null),
                  builder: (context, userSnapshot) {
                    String clubName = 'Unknown Club';
                    String userName = 'Loading...';
                    
                    if (eventSnapshot.hasData && eventSnapshot.data != null && eventSnapshot.data!.exists) {
                      final eventData = eventSnapshot.data!.data() as Map<String, dynamic>;
                      clubName = eventData['clubName'] ?? 'Unknown Club';
                    }
                    
                    if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      userName = userData['name'] ?? 'Unknown User';
                    }
                    
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event Image or First Letter Avatar
                          FutureBuilder<String?>(
                            future: _imageFuture,
                            builder: (context, imgSnapshot) {
                              if (imgSnapshot.hasData && imgSnapshot.data != null && imgSnapshot.data!.isNotEmpty) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(imgSnapshot.data!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              } else {
                                // Show first letter of event name
                                String firstLetter = r.eventName.isNotEmpty ? r.eventName[0].toUpperCase() : 'E';
                                return Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      firstLetter,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 12),
                          // Event Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.eventName.isNotEmpty ? r.eventName : 'Event ${r.eventId}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'by $clubName',
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      r.reason,
                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${_formatDate(r.createdAt)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(r.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              r.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(r.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const Divider(height: 1),
            
            // Report Description Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REPORT DESCRIPTION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Report Details
                  (r.details != null && r.details!.isNotEmpty)
                      ? Text(
                          r.details!,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        )
                      : const Text(
                          'No additional details provided.',
                          style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                  const SizedBox(height: 16),
                  
                  // Reporter Info
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(r.userId).get(),
                    builder: (context, snapshot) {
                      String userName = 'Loading...';
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        userName = data['name'] ?? 'Unknown User';
                      }
                      return Text(
                        '— Reported by $userName',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            if (r.imageUrl != null && r.imageUrl!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ATTACHMENT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<String?>(
                      future: _imageFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const Text('Failed to load image');
                        }
                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                child: Image.network(snapshot.data!),
                              ),
                            );
                          },
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Admin Review Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_outlined, size: 18, color: Colors.black87),
                          SizedBox(width: 8),
                          Text('ADMIN REVIEW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      if (!_isAddingNote)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isAddingNote = true;
                            });
                          },
                          child: Text(_notesController.text.isNotEmpty ? 'Edit Note' : '+ Add Note'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Note Input Area
                  if (_isAddingNote) ...[
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Enter internal notes here...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isAddingNote = false;
                            });
                          },
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSaving ? null : () async {
                            await _saveNotes();
                            setState(() {
                              _isAddingNote = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSaving 
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                              : const Text('Save Note'),
                        ),
                      ],
                    ),
                  ] else if (_notesController.text.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(_notesController.text),
                    ),
                  ],
                  
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (r.status != 'resolved' && r.status != 'dismissed') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : () => _updateStatus('resolved'),
                            icon: const Icon(Icons.check, color: Colors.green),
                            label: const Text('Resolve', style: TextStyle(color: Colors.green)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Colors.green),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : () => _updateStatus('dismissed'),
                            icon: const Icon(Icons.close, color: Colors.black87),
                            label: const Text('Dismiss', style: TextStyle(color: Colors.black87)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: r.status == 'resolved' ? Colors.green[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: r.status == 'resolved' ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            r.status == 'resolved' ? Icons.check_circle : Icons.cancel,
                            color: r.status == 'resolved' ? Colors.green : Colors.grey,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            r.status == 'resolved' ? 'This report has been resolved' : 'This report has been dismissed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: r.status == 'resolved' ? Colors.green[800] : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isSaving ? null : () => _updateStatus('pending'),
                              icon: const Icon(Icons.refresh, color: Colors.orange),
                              label: const Text('Reopen Issue', style: TextStyle(color: Colors.orange)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Colors.orange),
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatDate(DateTime dt) {
    return '${dt.month.toString().padLeft(2,'0')}/${dt.day.toString().padLeft(2,'0')}/${dt.year}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'reviewing': return Colors.blue;
      case 'resolved': return Colors.green;
      case 'dismissed': return Colors.grey;
      default: return Colors.black;
    }
  }
}
