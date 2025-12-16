import 'package:flutter/material.dart';
import '../../models/event.dart';
import 'dart:io';
import 'dart:async'; // Required for Completer
import '../../services/storage_service.dart';
import 'report_screen.dart';
import 'event_registration_screen.dart';
import '../../services/registration_service.dart';
import '../../services/auth_service.dart';

// --- NEW MAP IMPORTS ---
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class ParticipantEventDetailScreen extends StatefulWidget {
  final EventModel event;

  const ParticipantEventDetailScreen({
    super.key,
    required this.event,
  });

  @override
  State<ParticipantEventDetailScreen> createState() => _ParticipantEventDetailScreenState();
}

class _ParticipantEventDetailScreenState extends State<ParticipantEventDetailScreen> {
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();
  bool _isRegistered = false;
  bool _isCheckingRegistration = true;

  // --- MAP STATE VARIABLES ---
  LatLng? _eventLatLng;
  Set<Marker> _markers = {};
  bool _isMapLoading = true;
  final Completer<GoogleMapController> _mapController = Completer();

  // Simple map style to hide clutter (Same as club screen)
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
    _checkRegistrationStatus();
    _loadEventLocation(); // Initialize map location logic
  }

  // --- MAP LOGIC START ---
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
    // 2. Fallback: Try to find address by text if no GPS provided
    else if (widget.event.location.isNotEmpty) {
      _resolveAddressFallback();
    } else {
      if (mounted) setState(() => _isMapLoading = false);
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

  Future<void> _launchMapsApp() async {
    if (_eventLatLng == null) return;
    
    final double lat = _eventLatLng!.latitude;
    final double lng = _eventLatLng!.longitude;
    
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
  // --- MAP LOGIC END ---

  Future<void> _checkRegistrationStatus() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        setState(() {
          _isRegistered = false;
          _isCheckingRegistration = false;
        });
        return;
      }

      final isRegistered = await _registrationService.isUserRegistered(
        widget.event.id,
        userId: user.id,
        email: user.email,
      );

      setState(() {
        _isRegistered = isRegistered;
        _isCheckingRegistration = false;
      });
    } catch (e) {
      print('Error checking registration status: $e');
      setState(() {
        _isRegistered = false;
        _isCheckingRegistration = false;
      });
    }
  }

  // --- MAP WIDGET BUILDER ---
  Widget _buildMapSection() {
    if (widget.event.location.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Location Map", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (_eventLatLng != null)
              TextButton.icon(
                onPressed: _launchMapsApp,
                icon: Icon(Icons.directions, size: 18),
                label: Text("Get Directions"),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, 
                  visualDensity: VisualDensity.compact
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          height: 180, // Slightly smaller height for participant view
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _isMapLoading
              ? Center(child: CircularProgressIndicator())
              : _eventLatLng == null
                ? Center(child: Text("Could not load map for this address.", style: TextStyle(color: Colors.grey)))
                : GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(
                      target: _eventLatLng!,
                      zoom: 15,
                    ),
                    markers: _markers,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false, // Keep static to allow scrolling the page
                    zoomGesturesEnabled: true,
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildEventImage(widget.event.bannerUrl),
            ),

            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Name and Favorite Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.event.name,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'by ${widget.event.clubName}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.favorite_border, color: Colors.red),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Added to favorites!')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Price Section
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.event.isFree ? Colors.green[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.event.isFree ? Colors.green : Colors.blue,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          widget.event.isFree
                              ? 'FREE'
                              : '\$${widget.event.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.event.isFree ? Colors.green : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Date and Time
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        widget.event.formattedDate,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(width: 16),
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        widget.event.formattedTime,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  // Location Text
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.event.location,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),

                  // --- INSERTED MAP SECTION HERE ---
                  _buildMapSection(),
                  // ---------------------------------

                  SizedBox(height: 24),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                     child: _isCheckingRegistration
                        ? Container(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                          child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              ),
                          )
                        : ElevatedButton(
                            onPressed: _isRegistered
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EventRegistrationScreen(
                                          event: widget.event,
                                          ticketQuantity: 1,
                                        ),
                                      ),
                                    ).then((success) {
                                      if (success == true) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Successfully registered for ${widget.event.name}!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        _checkRegistrationStatus();
                                      }
                                    });
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isRegistered ? Colors.grey : Colors.red,
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              _isRegistered
                                  ? 'Already Registered'
                                  : widget.event.isFree
                                      ? 'Register for Event'
                                      : 'Register Now - RM${widget.event.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),

                  SizedBox(height: 24),

                  // About Event Section
                  Text(
                    'About Event',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 12),

                  Text(
                    widget.event.description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 16),
                  // ... Rest of the file remains the same ...
                  
                  // Club Information
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business, size: 20, color: Colors.blue),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Organized by',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              widget.event.clubName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Event Info Cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoCard(
                        icon: Icons.people,
                        label: 'Attendees',
                        value: '${widget.event.attendees.length}/${widget.event.maxAttendees > 0 ? widget.event.maxAttendees : 'Unlimited'}',
                        color: Colors.red,
                      ),
                      _buildInfoCard(
                        icon: Icons.location_on,
                        label: 'Venue',
                        value: widget.event.location.split(',').first,
                        color: Colors.orange,
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // Post a Review Section
                  Text(
                    'Post a Review',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),

                  SizedBox(height: 12),

                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Share your experience...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 3,
                  ),

                  SizedBox(height: 16),

                  // Report Section
                  Row(
                    children: [
                      Icon(Icons.flag, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ParticipantReportEventScreen(event: widget.event),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Report Event',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.event, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No image',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // If the URL is a local file path
    if (imageUrl.startsWith('/')) {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorImage();
        },
      );
    }

    // For network or storage images
    final storageService = StorageService();
    return FutureBuilder<String?>(
      future: storageService.resolveImageUrl(imageUrl),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[200],
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final resolved = snap.data;
        if (resolved == null || resolved.isEmpty) {
          return _buildErrorImage();
        }

        if (resolved.startsWith('/')) {
          return Image.file(
            File(resolved),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorImage();
            },
          );
        }

        return Image.network(
          resolved,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorImage();
          },
        );
      },
    );
  }

  Widget _buildErrorImage() {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.broken_image, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'Image not available',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}