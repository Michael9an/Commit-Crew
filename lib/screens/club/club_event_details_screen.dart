import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../models/club.dart';
import '../../models/review.dart';
import '../../services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_event/create_event_flow.dart';
import 'dart:async';
import '../../services/participant_export_service.dart';
import '../../services/review_service.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'attendance_qr_page.dart';
import 'dart:io';

class ClubEventDetailsScreen extends StatefulWidget {
  final EventModel event;
  final Club club;

  const ClubEventDetailsScreen({super.key, required this.event, required this.club});

  @override
  _ClubEventDetailsScreenState createState() => _ClubEventDetailsScreenState();
}

class _ClubEventDetailsScreenState extends State<ClubEventDetailsScreen> {
  final ReviewService _reviewService = ReviewService();
  bool _isLoading = false;

  // Map Variables
  LatLng? _eventLatLng;
  Set<Marker> _markers = {};
  bool _isMapLoading = true;
  final Completer<GoogleMapController> _mapController = Completer();
  final String _mapStyle = '[{"featureType": "poi","elementType": "labels.icon","stylers": [{"visibility": "off"}]}]';

  @override
  void initState() {
    super.initState();
    _loadEventLocation();
  }

  void _loadEventLocation() {
    if (widget.event.latitude != null && widget.event.longitude != null) {
      final position = LatLng(widget.event.latitude!, widget.event.longitude!);
      if (mounted) {
        setState(() {
          _eventLatLng = position;
          _markers.add(Marker(markerId: const MarkerId('event_location'), position: position));
          _isMapLoading = false;
        });
      }
    } else if (widget.event.location.isNotEmpty) {
      _resolveAddressFallback();
    } else {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  Future<void> _resolveAddressFallback() async {
    try {
      List<Location> locations = await locationFromAddress(widget.event.location);
      if (locations.isNotEmpty) {
        final position = LatLng(locations.first.latitude, locations.first.longitude);
        if (mounted) {
          setState(() {
            _eventLatLng = position;
            _markers.add(Marker(markerId: const MarkerId('event'), position: position));
            _isMapLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  // --- REVIEWS SECTION ---
  void _openReplySheet(String reviewId) {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      builder: (_) => AdminReplyBottomSheet(
        reviewId: reviewId, 
        actingAsClub: widget.club 
      )
    );
  }

  void _deleteReview(String reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Review"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _reviewService.deleteReview(reviewId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Review deleted")));
    }
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Reviews & Feedback", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<List<ReviewModel>>(
          stream: _reviewService.getEventReviews(widget.event.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final reviews = snapshot.data ?? [];
            if (reviews.isEmpty) return Container(padding: const EdgeInsets.all(16), width: double.infinity, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Center(child: Text("No reviews yet.", style: TextStyle(color: Colors.grey[600]))));

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              separatorBuilder: (c, i) => const Divider(),
              itemBuilder: (context, index) => _buildAdminReviewItem(reviews[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdminReviewItem(ReviewModel review) {
    // Determine avatar display
    Widget avatarChild;
    if (review.userName.isNotEmpty) {
      avatarChild = Text(review.userName[0].toUpperCase());
    } else {
      avatarChild = const Icon(Icons.person, size: 16);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16, 
                backgroundColor: Colors.blue[100], 
                child: avatarChild
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName.isNotEmpty ? review.userName : 'Participant', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                    ),
                    Text(review.createdAt != null ? "${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}" : "Unknown date", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(4)),
                child: Row(children: [const Icon(Icons.star, size: 14, color: Colors.amber), const SizedBox(width: 4), Text(review.rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(review.comment),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                onTap: () => _openReplySheet(review.id!),
                child: StreamBuilder<List<ReplyModel>>(
                  stream: _reviewService.getReplies(review.id!),
                  builder: (context, snapshot) {
                    int count = snapshot.data?.length ?? 0;
                    return Row(children: [const Icon(Icons.reply, size: 18, color: Colors.blue), const SizedBox(width: 4), Text(count > 0 ? "Replies ($count)" : "Reply", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13))]);
                  }
                ),
              ),
              const Spacer(),
              InkWell(onTap: () => _deleteReview(review.id!), child: Row(children: [const Icon(Icons.delete_outline, size: 18, color: Colors.red), const SizedBox(width: 4), const Text("Delete", style: TextStyle(color: Colors.red, fontSize: 13))])),
            ],
          ),
        ],
      ),
    );
  }

  void _showExportOptions() {
    ParticipantExportService.showExportOptions(context, widget.event);
  }
  
  // --- MANAGEMENT LOGIC ---
  bool get _isPastEvent {
    if (widget.event.date == null) return false;
    final timestamp = int.tryParse(widget.event.date!) ?? 0;
    if (timestamp == 0) return false;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
  }

  bool get _isPublished => widget.event.status == 'published';
  bool get _isArchived => widget.event.status == 'archived';

  void _showManagementOptions() {
    final bool isEditable = widget.event.canEdit; 

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Manage Event', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                if (!_isPastEvent && !_isArchived)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: isEditable ? Colors.blue.withOpacity(0.1) : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                      child: Icon(isEditable ? Icons.edit : Icons.lock, color: isEditable ? Colors.blue : Colors.grey),
                    ),
                    title: Text(isEditable ? 'Edit Event' : 'Editing Locked', style: TextStyle(fontWeight: FontWeight.bold, color: isEditable ? Colors.black : Colors.grey)),
                    subtitle: Text(isEditable ? 'Update details' : 'Locked 3 days before start', style: TextStyle(color: isEditable ? Colors.grey[600] : Colors.red[300])),
                    onTap: () {
                      if (isEditable) {
                        Navigator.pop(context);
                        _navigateToEdit(isDuplicate: false);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot edit event less than 3 days before start!")));
                      }
                    },
                  ),
                
                if (!_isPastEvent && !_isArchived)
                  _buildOptionTile(
                    Icons.qr_code_2,
                    Colors.deepPurple,
                    'Attendance QR',
                    'Display code for students to scan',
                    () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceQRPage(event: widget.event)));
                    },
                  ),
                
                _buildOptionTile(
                  _isPublished ? Icons.archive : Icons.unarchive,
                  _isPublished ? Colors.orange : Colors.green,
                  _isPublished ? 'Archive Event' : 'Publish Event',
                  _isPublished ? 'Move to archive list' : 'Make visible to everyone',
                  _toggleArchiveStatus,
                ),
                
                _buildOptionTile(
                  Icons.copy,
                  Colors.teal,
                  'Duplicate Event',
                  'Create a copy of this event',
                  () => _navigateToEdit(isDuplicate: true),
                ),

                const Divider(height: 32),

                _buildOptionTile(
                  Icons.delete_forever,
                  Colors.red,
                  'Delete Event',
                  'Permanently remove event',
                  _confirmDelete,
                ),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _navigateToEdit({required bool isDuplicate}) {
    EventModel eventPass;
    if (isDuplicate) {
      eventPass = widget.event.copyWith(
        id: '', 
        name: 'Copy of ${widget.event.name}',
        date: DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch.toString(),
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

  Future<void> _toggleArchiveStatus() async {
    final newStatus = _isPublished ? 'archived' : 'published';
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('events').doc(widget.event.id).update({'status': newStatus});
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

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance.collection('events').doc(widget.event.id).delete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted')));
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildMapSection() {
    if (widget.event.location.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          height: 200, width: double.infinity,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[300]!)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _isMapLoading
              ? const Center(child: CircularProgressIndicator())
              : _eventLatLng == null
                ? const Center(child: Text("Map not available"))
                : GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(target: _eventLatLng!, zoom: 15),
                    markers: _markers,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    onMapCreated: (c) { _mapController.complete(c); c.setMapStyle(_mapStyle); },
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event Details'), actions: [IconButton(icon: const Icon(Icons.settings), onPressed: _showManagementOptions)]),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Container(height: 200, width: double.infinity, color: Colors.grey[200], child: widget.event.bannerUrl != null ? Image.network(widget.event.bannerUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image)) : const Icon(Icons.image)),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.event.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  const Text("Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildMapSection(),

                  const SizedBox(height: 32),
                  const Text("Participant Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _showExportOptions, icon: const Icon(Icons.file_download), label: const Text("Export Participant Report"))),
                  
                  const SizedBox(height: 32),
                  _buildReviewsSection(), 
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ADMIN REPLY BOTTOM SHEET
// ==========================================
class AdminReplyBottomSheet extends StatefulWidget {
  final String reviewId;
  final Club? actingAsClub; 

  const AdminReplyBottomSheet({super.key, required this.reviewId, this.actingAsClub});

  @override
  State<AdminReplyBottomSheet> createState() => _AdminReplyBottomSheetState();
}

class _AdminReplyBottomSheetState extends State<AdminReplyBottomSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final ReviewService _service = ReviewService();
  final StorageService _storageService = StorageService(); // NEW

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    
    // SEND AS CLUB
    if (widget.actingAsClub != null) {
      String? clubAvatarUrl = widget.actingAsClub!.imageUrl;
      
      // Resolve path before saving
      if (clubAvatarUrl != null && !clubAvatarUrl.startsWith('http')) {
         try {
           clubAvatarUrl = await _storageService.resolveImageUrl(clubAvatarUrl);
         } catch (e) {
           print("Error resolving club image: $e");
         }
      }
      
      _service.addReply(
        widget.reviewId, 
        _ctrl.text.trim(),
        isClubRep: true,
        overrideName: widget.actingAsClub!.name,
        overrideAvatarUrl: clubAvatarUrl,
      );
    } else {
      _service.addReply(widget.reviewId, _ctrl.text.trim());
    }
    _ctrl.clear();
    FocusScope.of(context).unfocus();
  }

  // --- SAFE AVATAR BUILDER (Fix for Crash) ---
  Widget _buildAvatar(String? url, String name) {
    if (url == null || url.isEmpty) {
      return CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?'));
    }
    
    return FutureBuilder<String?>(
      future: url.startsWith('http') ? Future.value(url) : _storageService.resolveImageUrl(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const CircleAvatar(backgroundColor: Colors.grey);
        if (snapshot.data == null) return CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?'));
        
        return CircleAvatar(
          backgroundImage: NetworkImage(snapshot.data!),
          onBackgroundImageError: (_,__) {},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: 400,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text("Reply to Review", style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: StreamBuilder<List<ReplyModel>>(
              stream: _service.getReplies(widget.reviewId),
              builder: (context, snap) {
                final replies = snap.data ?? [];
                return ListView.builder(
                  itemCount: replies.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(replies[i].userName, style: TextStyle(fontWeight: FontWeight.bold, color: replies[i].isClubRep ? Colors.blue : Colors.black)),
                    subtitle: Text(replies[i].content),
                    leading: _buildAvatar(replies[i].userAvatarUrl, replies[i].userName),
                  ),
                );
              }
            )),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [Expanded(child: TextField(controller: _ctrl, decoration: const InputDecoration(hintText: "Write a reply as Club..."))), IconButton(onPressed: _send, icon: const Icon(Icons.send, color: Colors.blue))]),
            )
          ],
        ),
      ),
    );
  }
}