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
  final StorageService _storageService = StorageService();
  bool _isLoading = false;

  // Map Variables
  LatLng? _eventLatLng;
  Set<Marker> _markers = {};
  bool _isMapLoading = true;
  final Completer<GoogleMapController> _mapController = Completer();
  final String _mapStyle = '[{"featureType": "poi","elementType": "labels.icon","stylers": [{"visibility": "off"}]}]';

  // --- LOCAL STATE FOR EVENT ---
  // We use this to update the UI immediately after editing the PIN locally
  late EventModel _displayEvent;

  @override
  void initState() {
    super.initState();
    _displayEvent = widget.event; // Initialize with widget data
    _loadEventLocation();
  }

  void _loadEventLocation() {
    if (_displayEvent.latitude != null && _displayEvent.longitude != null) {
      final position = LatLng(_displayEvent.latitude!, _displayEvent.longitude!);
      if (mounted) {
        setState(() {
          _eventLatLng = position;
          _markers.add(Marker(markerId: const MarkerId('event_location'), position: position));
          _isMapLoading = false;
        });
      }
    } else if (_displayEvent.location.isNotEmpty) {
      _resolveAddressFallback();
    } else {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  Future<void> _resolveAddressFallback() async {
    try {
      List<Location> locations = await locationFromAddress(_displayEvent.location);
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
          stream: _reviewService.getEventReviews(_displayEvent.id),
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
          
          // --- NEW: DISPLAY REVIEW PHOTOS ---
          if (review.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoUrls.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FutureBuilder<String?>(
                      // Use resolveImageUrl to handle Google Drive links
                      future: _storageService.resolveImageUrl(review.photoUrls[index]),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(width: 80, height: 80, color: Colors.grey[200]);
                        }
                        return GestureDetector(
                          onTap: () => _showFullImage(context, snapshot.data!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              snapshot.data!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_,__,___) => Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
          // ----------------------------------

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

  // Add this helper method to the class for viewing images full screen
  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.network(imageUrl)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportOptions() {
    ParticipantExportService.showExportOptions(context, _displayEvent);
  }
  
  // --- MANAGEMENT LOGIC ---
  bool get _isPastEvent {
    if (_displayEvent.date.isEmpty) return false;
    final timestamp = int.tryParse(_displayEvent.date) ?? 0;
    if (timestamp == 0) return false;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return date.isBefore(DateTime.now().subtract(const Duration(days: 1)));
  }

  bool get _isPublished => _displayEvent.status == 'published';
  bool get _isArchived => _displayEvent.status == 'archived';

  void _showManagementOptions() {
    final bool isEditable = _displayEvent.canEdit; 

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
                
                // --- DYNAMIC SCANNER OPTIONS ---
                if (!_isPastEvent && !_isArchived)
                  if (_displayEvent.checkInMethod == 'self_scan')
                    _buildOptionTile(
                      Icons.qr_code_2,
                      Colors.deepPurple,
                      'Attendance QR',
                      'Display code for students to scan',
                      () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceQRPage(event: _displayEvent)));
                      },
                    )
                  else
                    // --- NEW: SCANNER SETTINGS ---
                    _buildOptionTile(
                      Icons.password,
                      Colors.indigo,
                      'Scanner Pass PIN',
                      'View or change the volunteer PIN',
                      _showEditPinDialog,
                    ),
                // --------------------------------

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

  // --- NEW: QUICK PIN EDIT DIALOG ---
  void _showEditPinDialog() {
    // Close the bottom sheet first
    Navigator.pop(context); 

    final pinController = TextEditingController(text: _displayEvent.scannerPin);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Scanner Settings"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Volunteers need this PIN to log in as scanners for this event."),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: "Scanner PIN",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPin = pinController.text.trim();
              if (newPin.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN must be 4 digits")));
                return;
              }
              
              // Update Firebase
              try {
                await FirebaseFirestore.instance
                    .collection('events')
                    .doc(_displayEvent.id)
                    .update({'scannerPin': newPin});
                
                // Update Local State
                setState(() {
                  _displayEvent = _displayEvent.copyWith(scannerPin: newPin);
                });
                
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN Updated Successfully!")));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            }, 
            child: const Text("Save PIN"),
          ),
        ],
      ),
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
        // Only pop if it's not the scanner settings (we handle pop manually there)
        if (onTap != _showEditPinDialog) {
           Navigator.pop(context);
        }
        onTap();
      },
    );
  }

  void _navigateToEdit({required bool isDuplicate}) {
    EventModel eventPass;
    if (isDuplicate) {
      eventPass = _displayEvent.copyWith(
        id: '', 
        name: 'Copy of ${_displayEvent.name}',
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
      eventPass = _displayEvent;
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
      // Reload logic could go here if needed, but we rely on stream updates usually
      // However, if we edited locally, we might want to refresh?
      // For now, assume CreateEventFlow updates DB and Stream updates UI elsewhere.
      if (mounted && !isDuplicate) Navigator.pop(context);
    });
  }

  Future<void> _toggleArchiveStatus() async {
    final newStatus = _isPublished ? 'archived' : 'published';
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('events').doc(_displayEvent.id).update({'status': newStatus});
      
      // Update local state immediately
      setState(() {
        _displayEvent = _displayEvent.copyWith(status: newStatus);
        _isLoading = false;
      });

      if (mounted) {
        String msg = newStatus == 'archived' ? 'Event Archived' : 'Event Published';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        await FirebaseFirestore.instance.collection('events').doc(_displayEvent.id).delete();
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

  Widget _buildEventBanner() {
    final url = _displayEvent.bannerUrl;
    if (url == null || url.isEmpty) {
      return Container(
        height: 200, 
        width: double.infinity, 
        color: Colors.grey[200], 
        child: const Icon(Icons.image, size: 50, color: Colors.grey)
      );
    }

    if (url.startsWith('/')) {
      return Image.file(File(url), height: 200, width: double.infinity, fit: BoxFit.cover);
    }

    return FutureBuilder<String?>(
      future: _storageService.resolveImageUrl(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(height: 200, color: Colors.grey[200], child: const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return Image.network(
            snapshot.data!, 
            height: 200, 
            width: double.infinity, 
            fit: BoxFit.cover,
            errorBuilder: (_,__,___) => Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
          );
        }
        return Container(height: 200, color: Colors.grey[200], child: const Icon(Icons.broken_image));
      },
    );
  }

  Widget _buildMapSection() {
    if (_displayEvent.location.isEmpty) return const SizedBox.shrink();
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 14))),
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
             _buildEventBanner(),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TITLE + PIN DISPLAY ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(_displayEvent.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                      
                      // Show small key icon if PIN exists
                      if (_displayEvent.checkInMethod == 'organizer_scan' && _displayEvent.scannerPin != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.vpn_key, size: 14, color: Colors.indigo),
                              const SizedBox(width: 4),
                              Text("PIN: ${_displayEvent.scannerPin}", style: TextStyle(color: Colors.indigo[900], fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // ----------------------------

                  const SizedBox(height: 16),

                  _buildInfoRow(Icons.calendar_today, _displayEvent.formattedDate),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.access_time, _displayEvent.formattedTime),
                  
                  const SizedBox(height: 24),

                  const Text("About Event", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    _displayEvent.description, 
                    style: TextStyle(color: Colors.grey[800], height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  
                  const Text("Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.location_on, _displayEvent.location),
                  
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
// ADMIN REPLY BOTTOM SHEET (UNCHANGED)
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
  final StorageService _storageService = StorageService();
  
  String? _editingReplyId;

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    
    if (_editingReplyId != null) {
      await _service.updateReply(widget.reviewId, _editingReplyId!, _ctrl.text.trim());
      setState(() { _editingReplyId = null; _ctrl.clear(); });
      FocusScope.of(context).unfocus();
      return;
    }

    if (widget.actingAsClub != null) {
      String? clubAvatarUrl = widget.actingAsClub!.imageUrl;
      if (clubAvatarUrl != null && !clubAvatarUrl.startsWith('http')) {
         try {
           clubAvatarUrl = await _storageService.resolveImageUrl(clubAvatarUrl);
         } catch (e) {
           print("Error resolving club image: $e");
         }
      }
      _service.addReply(widget.reviewId, _ctrl.text.trim(), isClubRep: true, overrideName: widget.actingAsClub!.name, overrideAvatarUrl: clubAvatarUrl);
    } else {
      _service.addReply(widget.reviewId, _ctrl.text.trim());
    }
    _ctrl.clear();
    FocusScope.of(context).unfocus();
  }

  void _deleteReply(String replyId) {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text("Delete Reply"), content: Text("Are you sure?"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")), TextButton(onPressed: () { _service.deleteReply(widget.reviewId, replyId); Navigator.pop(context); }, child: Text("Delete", style: TextStyle(color: Colors.red)))]));
  }

  void _startEditing(String replyId, String content) {
    setState(() { _editingReplyId = replyId; _ctrl.text = content; });
  }

  void _cancelEditing() {
    setState(() { _editingReplyId = null; _ctrl.clear(); });
    FocusScope.of(context).unfocus();
  }

  Widget _buildAvatar(String? url, String name) {
    if (url == null || url.isEmpty) return CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?'));
    return FutureBuilder<String?>(
      future: url.startsWith('http') ? Future.value(url) : _storageService.resolveImageUrl(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const CircleAvatar(backgroundColor: Colors.grey);
        if (snapshot.data == null) return CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?'));
        return CircleAvatar(backgroundImage: NetworkImage(snapshot.data!), onBackgroundImageError: (_,__) {});
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
                  itemBuilder: (_, i) {
                    final reply = replies[i];
                    return ListTile(
                      title: Text(reply.userName, style: TextStyle(fontWeight: FontWeight.bold, color: reply.isClubRep ? Colors.blue : Colors.black)),
                      subtitle: Text(reply.content),
                      leading: _buildAvatar(reply.userAvatarUrl, reply.userName),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          if (reply.isClubRep) PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                        onSelected: (value) {
                          if (value == 'edit') _startEditing(reply.id, reply.content);
                          else if (value == 'delete') _deleteReply(reply.id);
                        },
                      ),
                    );
                  }
                );
              }
            )),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]),
              child: Column(
                children: [
                  if (_editingReplyId != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                      child: Row(children: [Icon(Icons.edit, size: 14, color: Colors.blue), SizedBox(width: 8), Expanded(child: Text("Editing your reply", style: TextStyle(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold))), GestureDetector(onTap: _cancelEditing, child: Icon(Icons.close, size: 16, color: Colors.blue))]),
                    ),
                  Row(children: [Expanded(child: TextField(controller: _ctrl, decoration: InputDecoration(hintText: _editingReplyId != null ? "Update reply..." : "Write a reply as Club...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), filled: true, fillColor: Colors.grey[100], contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)))), SizedBox(width: 8), IconButton(onPressed: _send, icon: Icon(_editingReplyId != null ? Icons.check_circle : Icons.send, color: Colors.blue))]),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}