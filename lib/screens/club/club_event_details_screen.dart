import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../models/club.dart';
import '../../services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_event/create_event_flow.dart';
import 'dart:async';
import '../../services/participant_export_service.dart';

// --- MAP & LOCATION IMPORTS ---
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'attendance_qr_page.dart';

class ClubEventDetailsScreen extends StatefulWidget {
  final EventModel event;
  final Club club;

  const ClubEventDetailsScreen({super.key, required this.event, required this.club});

  @override
  _ClubEventDetailsScreenState createState() => _ClubEventDetailsScreenState();
}

class _ClubEventDetailsScreenState extends State<ClubEventDetailsScreen> {
  bool _isLoading = false;

  // --- MAP STATE VARIABLES ---
  LatLng? _eventLatLng;
  Set<Marker> _markers = {};
  bool _isMapLoading = true;
  final Completer<GoogleMapController> _mapController = Completer();

  // Simple map style to hide clutter
  final String _mapStyle = '''
  [
    {
      "featureType": "poi",
      "elementType": "labels.icon",
      "stylers": [{"visibility": "off"}]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadEventLocation();
  }

  // Convert the address string to coordinates
  void _loadEventLocation() {
    // 1. Check if we have exact GPS coordinates saved
    if (widget.event.latitude != null && widget.event.longitude != null) {
      final position = LatLng(widget.event.latitude!, widget.event.longitude!);
      
      if (mounted) {
        setState(() {
          _eventLatLng = position;
          _markers.add(
            Marker(
              markerId: MarkerId('event_location'),
              position: position,
              infoWindow: InfoWindow(title: widget.event.location),
            ),
          );
          _isMapLoading = false;
        });
      }
    } 
    // 2. Fallback: If old event (no GPS), try to find address by text
    else if (widget.event.location.isNotEmpty) {
      _resolveAddressFallback();
    } else {
      setState(() => _isMapLoading = false);
    }
  }

  Future<void> _resolveAddressFallback() async {
    try {
      List<Location> locations = await locationFromAddress(widget.event.location);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final position = LatLng(loc.latitude, loc.longitude);
        if (mounted) {
          setState(() {
            _eventLatLng = position;
            _markers.add(Marker(markerId: MarkerId('event'), position: position));
            _isMapLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  // Open external map app for navigation
  Future<void> _launchMapsApp() async {
    if (_eventLatLng == null) return;
    
    final double lat = _eventLatLng!.latitude;
    final double lng = _eventLatLng!.longitude;
    
    // Create URLs for Google Maps (Android/iOS) and Apple Maps (iOS fallback)
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    final Uri appleMapsUrl = Uri.parse("https://maps.apple.com/?q=$lat,$lng");

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open maps application.")),
        );
      }
    }
  }

  // --- GETTERS ---
  bool get _isPastEvent {
    if (widget.event.date == null) return false;
    final timestamp = int.tryParse(widget.event.date!) ?? 0;
    if (timestamp == 0) return false;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return date.isBefore(DateTime.now().subtract(Duration(days: 1)));
  }

  bool get _isPublished => widget.event.status == 'published';
  bool get _isArchived => widget.event.status == 'archived';

  void _showExportOptions() {
    ParticipantExportService.showExportOptions(context, widget.event);
  }
  // --- MANAGEMENT OPTIONS ---
  void _showManagementOptions() {
    // Check our new logic
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

                // 1. EDIT BUTTON (With Lock Logic)
                if (!_isPastEvent && !_isArchived)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isEditable ? Colors.blue.withOpacity(0.1) : Colors.grey[200], 
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Icon(
                        isEditable ? Icons.edit : Icons.lock, 
                        color: isEditable ? Colors.blue : Colors.grey
                      ),
                    ),
                    title: Text(
                      isEditable ? 'Edit Event' : 'Editing Locked',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isEditable ? Colors.black : Colors.grey
                      )
                    ),
                    subtitle: Text(
                      isEditable ? 'Update details' : 'Locked 3 days before start',
                      style: TextStyle(color: isEditable ? Colors.grey[600] : Colors.red[300])
                    ),
                    onTap: () {
                      if (isEditable) {
                        Navigator.pop(context);
                        _navigateToEdit(isDuplicate: false);
                      } else {
                        // Show warning if they click it anyway
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Cannot edit event less than 3 days before start!"))
                        );
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AttendanceQRPage(event: widget.event)),
                      );
                    },
                  ),
                _buildOptionTile(
                  _isPublished ? Icons.archive : Icons.unarchive,
                  _isPublished ? Colors.orange : Colors.green,
                  _isPublished ? 'Archive Event' : 'Publish Event',
                  _isPublished ? 'Move to archive list' : 'Make visible to everyone',
                  _toggleArchiveStatus,
                ),
                
                // 4. DUPLICATE EVENT (Restored)
                _buildOptionTile(
                  Icons.copy,
                  Colors.teal,
                  'Duplicate Event',
                  'Create a copy of this event',
                  () => _navigateToEdit(isDuplicate: true),
                ),

                const Divider(height: 32),

                // 5. DELETE EVENT (Restored)
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
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
              ],
            ),
            SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // --- MAP WIDGET BUILDER ---
  Widget _buildMapSection() {
    if (widget.event.location.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Location Map", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_eventLatLng != null)
              TextButton.icon(
                onPressed: _launchMapsApp,
                icon: Icon(Icons.directions, size: 18),
                label: Text("Get Directions"),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _isMapLoading
              ? Center(child: CircularProgressIndicator())
              : _eventLatLng == null
                ? Center(child: Text("Could not load map for this address."))
                : GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(
                      target: _eventLatLng!,
                      zoom: 15,
                    ),
                    markers: _markers,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false, // Static map
                    zoomGesturesEnabled: true,    // Allow zooming
                    onMapCreated: (GoogleMapController controller) {
                      _mapController.complete(controller);
                      controller.setMapStyle(_mapStyle);
                    },
                  ),
          ),
        ),
      ],
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
                // Event Banner
                Builder(
                  builder: (context) {
                    final rawUrl = widget.event.bannerUrl;
                    if (rawUrl == null || rawUrl.isEmpty || rawUrl == 'file:///') {
                      return Container(height: 200, width: double.infinity, color: Colors.grey[200], child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey)));
                    }
                    if (rawUrl.startsWith('http')) {
                      return FutureBuilder<String?>(
                        future: StorageService().resolveImageUrl(rawUrl),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return Container(height: 200, color: Colors.grey[200]);
                          return Image.network(
                            snapshot.data ?? rawUrl, height: 200, width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(height: 200, color: Colors.grey[200]),
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
                      _buildStatusBadge(),
                      
                      SizedBox(height: 24),
                      Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(widget.event.description ?? 'No description provided.', style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800])),

                      SizedBox(height: 24),
                      Text("Event Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 12),
                      
                      Row(
                        children: [
                          _buildDetailItem(Icons.people, "Attendance", "${widget.event.attendees.length} / ${widget.event.maxAttendees > 0 ? widget.event.maxAttendees : 'Unlimited'}", Colors.blue),
                          SizedBox(width: 12),
                          _buildDetailItem(Icons.attach_money, "Fee", widget.event.isFree ? "Free" : "\$${widget.event.price.toStringAsFixed(2)}", Colors.green),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          _buildDetailItem(Icons.category, "Category", widget.event.category, Colors.purple),
                          SizedBox(width: 12),
                          _buildDetailItem(Icons.location_on, "Location", widget.event.location, Colors.orange),
                        ],
                      ),

                      // --- NEW: Map Section ---
                      SizedBox(height: 24),
                      _buildMapSection(),
                      // -------------------------

                      SizedBox(height: 32),
                      Text("Participant Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 12),
                      
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showExportOptions,
                          icon: Icon(Icons.file_download),
                          label: Text("Export Participant Report"),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}