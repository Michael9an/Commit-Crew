import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../models/club.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_event/create_event_flow.dart';
import 'dart:io';

class ClubEventDetailsScreen extends StatefulWidget {
  final EventModel event;
  final Club club;

  const ClubEventDetailsScreen({super.key, required this.event, required this.club});

  @override
  _ClubEventDetailsScreenState createState() => _ClubEventDetailsScreenState();
}

class _ClubEventDetailsScreenState extends State<ClubEventDetailsScreen> {
  bool _isLoading = false;

  bool get _isPastEvent {
    if (widget.event.date == null) return false;
    final timestamp = int.tryParse(widget.event.date!) ?? 0;
    if (timestamp == 0) return false;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return date.isBefore(DateTime.now().subtract(Duration(days: 1)));
  }

  bool get _isPublished => widget.event.status == 'published';
  bool get _isArchived => widget.event.status == 'archived';

  void _showManagementOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Event', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),

                if (!_isPastEvent && !_isArchived)
                  _buildOptionTile(Icons.edit, Colors.blue, 'Edit Event', 'Update details', 
                    () => _navigateToEdit(isDuplicate: false)),
                
                _buildOptionTile(
                  _isPublished ? Icons.archive : Icons.unarchive,
                  _isPublished ? Colors.orange : Colors.green,
                  _isPublished ? 'Archive Event' : 'Publish Event',
                  _isPublished ? 'Move to archive list' : 'Make visible to everyone',
                  _toggleArchiveStatus,
                ),

                _buildOptionTile(Icons.copy, Colors.purple, 'Duplicate Event', 'Create copy of this event', 
                  () => _navigateToEdit(isDuplicate: true)),

                Divider(height: 32),
                _buildOptionTile(Icons.delete_forever, Colors.red, 'Delete Event', 'Permanently remove', _confirmDelete),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile(IconData icon, Color color, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _toggleArchiveStatus() async {
    final newStatus = _isPublished ? 'archived' : 'published';
    setState(() => _isLoading = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update({'status': newStatus});
      
      if (mounted) {
        String msg = newStatus == 'archived' ? 'Event Archived' : 'Event Published';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _navigateToEdit({required bool isDuplicate}) {
    EventModel eventPass;

    if (isDuplicate) {
      eventPass = widget.event.copyWith(
        id: '', 
        name: 'Copy of ${widget.event.name}',
        date: DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch.toString(),
        status: 'draft',
        attendees: [],
        waitlist: [],
        views: 0,
        shares: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else {
      eventPass = widget.event;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventFlow(
          club: widget.club,
          eventToEdit: eventPass,
          isDuplicate: isDuplicate,
        ),
      ),
    ).then((_) {
      if (mounted && !isDuplicate) Navigator.pop(context);
    });
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Event?'),
        content: Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance.collection('events').doc(widget.event.id).delete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Event deleted')));
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;

    if (_isPublished) {
      color = Colors.green;
      text = 'PUBLISHED';
    } else if (_isArchived) {
      color = Colors.grey;
      text = 'ARCHIVED';
    } else {
      color = Colors.orange;
      text = 'DRAFT';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Event Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showManagementOptions,
          ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Logic (Fixed syntax)
                Builder(
                  builder: (context) {
                    final rawUrl = widget.event.bannerUrl;
                    if (rawUrl == null || rawUrl.isEmpty || rawUrl == 'file:///') {
                      return Container(
                        height: 200, width: double.infinity, color: Colors.grey[200], 
                        child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey))
                      );
                    }
                    if (rawUrl.startsWith('http')) {
                      return FutureBuilder<String?>(
                        future: StorageService().resolveImageUrl(rawUrl),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(height: 200, color: Colors.grey[200]);
                          }
                          // FIX: Used specific names instead of underscores
                          return Image.network(
                            snapshot.data ?? rawUrl, 
                            height: 200, 
                            width: double.infinity, 
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(height: 200, color: Colors.grey[200]),
                          );
                        },
                      );
                    }
                    return Container(height: 200, color: Colors.grey[200]);
                  },
                ),

                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.event.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      // Status Badge (Updated)
                      _buildStatusBadge(),
                      SizedBox(height: 16),
                      Text(widget.event.description ?? ''),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}