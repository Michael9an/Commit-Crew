import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:async';

// --- MODELS ---
import '../../models/event.dart';
import '../../models/review.dart';

// --- SERVICES ---
import '../../services/storage_service.dart';
import '../../services/registration_service.dart';
import '../../services/auth_service.dart';
import '../../services/review_service.dart';

// --- SCREENS ---
import 'report_screen.dart';
import 'event_registration_screen.dart';
import 'event_review_screen.dart';

// --- MAP IMPORTS ---
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
  // --- SERVICES ---
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();
  final ReviewService _reviewService = ReviewService();
  final StorageService _storageService = StorageService(); // NEW

  // --- STATE VARIABLES ---
  bool _isRegistered = false;
  bool _isCheckingRegistration = true;

  // --- MAP STATE VARIABLES ---
  LatLng? _eventLatLng;
  Set<Marker> _markers = {};
  bool _isMapLoading = true;
  final Completer<GoogleMapController> _mapController = Completer();

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
    _loadEventLocation();
  }

  // =========================================================
  // MAP LOGIC
  // =========================================================
  void _loadEventLocation() {
    if (widget.event.latitude != null && widget.event.longitude != null) {
      final position = LatLng(widget.event.latitude!, widget.event.longitude!);
      
      if (mounted) {
        setState(() {
          _eventLatLng = position;
          _markers.add(
            Marker(
              markerId: const MarkerId('event_location'),
              position: position,
              infoWindow: InfoWindow(title: widget.event.location),
            ),
          );
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
        final loc = locations.first;
        final position = LatLng(loc.latitude, loc.longitude);
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
          const SnackBar(content: Text("Could not open maps application.")),
        );
      }
    }
  }

  // =========================================================
  // REGISTRATION LOGIC
  // =========================================================
  Future<void> _checkRegistrationStatus() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        if (mounted) {
          setState(() {
            _isRegistered = false;
            _isCheckingRegistration = false;
          });
        }
        return;
      }

      final isRegistered = await _registrationService.isUserRegistered(
        widget.event.id,
        userId: user.id,
        email: user.email,
      );

      if (mounted) {
        setState(() {
          _isRegistered = isRegistered;
          _isCheckingRegistration = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRegistered = false;
          _isCheckingRegistration = false;
        });
      }
    }
  }

  // =========================================================
  // REVIEW ACTIONS
  // =========================================================
  void _deleteReview(String reviewId) async {
    try {
      await _reviewService.deleteReview(reviewId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Review deleted")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete: $e")));
      }
    }
  }

  void _reportReview(String reviewId) {
    showDialog(
      context: context,
      builder: (ctx) {
        final reasons = ["Inappropriate Content", "Spam", "Harassment", "Other"];
        return SimpleDialog(
          title: const Text("Report Review"),
          children: reasons.map((r) => SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _reviewService.reportReview(reviewId, r);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report submitted.")));
            },
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(r)),
          )).toList(),
        );
      },
    );
  }

  // =========================================================
  // WIDGET BUILDER
  // =========================================================
  
  Widget _buildMapSection() {
    if (widget.event.location.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Location Map", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (_eventLatLng != null)
              TextButton.icon(
                onPressed: _launchMapsApp,
                icon: const Icon(Icons.directions, size: 18),
                label: const Text("Get Directions"),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, 
                  visualDensity: VisualDensity.compact
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 180, 
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _isMapLoading
              ? const Center(child: CircularProgressIndicator())
              : _eventLatLng == null
                ? const Center(child: Text("Could not load map for this address.", style: TextStyle(color: Colors.grey)))
                : GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(
                      target: _eventLatLng!,
                      zoom: 15,
                    ),
                    markers: _markers,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false, 
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
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildEventImage(widget.event.bannerUrl),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.event.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('by ${widget.event.clubName}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.favorite_border, color: Colors.red),
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to favorites!'))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Price Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.event.isFree ? Colors.green[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: widget.event.isFree ? Colors.green : Colors.blue),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Price', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600])),
                        Text(
                          widget.event.isFree ? 'FREE' : '\$${widget.event.price.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.event.isFree ? Colors.green : Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Date & Location
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(widget.event.formattedDate, style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(widget.event.formattedTime, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.event.location, style: TextStyle(color: Colors.grey[600]))),
                    ],
                  ),

                  _buildMapSection(),
                  const SizedBox(height: 24),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    child: _isCheckingRegistration
                        ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
                        : _buildBottomButton(widget.event.isPast),
                  ),
                  const SizedBox(height: 24),

                  const Text('About Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(widget.event.description, style: TextStyle(color: Colors.grey[600], height: 1.5)),
                  const SizedBox(height: 16),
                  
                  // Club Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
                    child: Row(
                      children: [
                        const Icon(Icons.business, size: 20, color: Colors.blue),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Organized by', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            Text(widget.event.clubName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 12),

                  StreamBuilder<List<ReviewModel>>(
                    stream: _reviewService.getEventReviews(widget.event.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      final reviews = snapshot.data ?? [];
                      bool hasUserReviewed = false;
                      if (currentUser != null) {
                        hasUserReviewed = reviews.any((r) => r.userId == currentUser.uid);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.event.isPast) ...[
                            if (hasUserReviewed)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(color: Colors.green[50], border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(8)),
                                child: Row(children: [const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text("You have submitted your review.", style: TextStyle(color: Colors.green[800])))]),
                              )
                            else
                              Column(children: [
                                Text('Did you attend? Share your experience.', style: TextStyle(color: Colors.grey[600])),
                                const SizedBox(height: 12),
                                SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WriteReviewScreen(event: widget.event))), icon: const Icon(Icons.rate_review_outlined), label: const Text('Write a Review'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)))),
                                const SizedBox(height: 16),
                              ]),
                          ],
                          if (reviews.isEmpty)
                            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text("No reviews yet.", style: TextStyle(color: Colors.grey))))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: reviews.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) => _buildReviewItem(reviews[index], currentUser),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Report Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ParticipantReportEventScreen(event: widget.event))),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Report Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BUTTON LOGIC ---
  Widget _buildBottomButton(bool isPastEvent) {
    if (_isRegistered) {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text("You are Registered", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (isPastEvent) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
        child: const Center(child: Text("Event has ended", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey))),
      );
    }

    return ElevatedButton(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => EventRegistrationScreen(event: widget.event)))
            .then((_) => _checkRegistrationStatus());
      },
      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Text(widget.event.isFree ? "Register for Free" : "Register - RM${widget.event.price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  void _navigateToReview() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => WriteReviewScreen(event: widget.event)));
  }

  // --- SAFE AVATAR BUILDER (Fix for Crash) ---
  Widget _buildAvatar(String? url, String name, bool isClub) {
    // Default widget to show if loading fails or no URL
    Widget defaultWidget = CircleAvatar(
        radius: 16,
        backgroundColor: isClub ? Colors.blue : Colors.orange[100],
        child: isClub 
          ? const Icon(Icons.verified, size: 16, color: Colors.white)
          : Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
    );

    if (url == null || url.isEmpty) return defaultWidget;

    return FutureBuilder<String?>(
      future: _storageService.resolveImageUrl(url), // Resolve local paths
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const CircleAvatar(radius: 16, backgroundColor: Colors.grey);
        if (snapshot.hasError || snapshot.data == null) return defaultWidget;
        
        return CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(snapshot.data!),
          onBackgroundImageError: (_,__) {}, // Catch network errors
        );
      },
    );
  }

  // --- REVIEW ITEM with AUTHOR BADGE ---
  Widget _buildReviewItem(ReviewModel review, User? currentUser) {
    bool isMe = currentUser != null && review.userId == currentUser.uid;
    bool isLiked = currentUser != null && review.likedBy.contains(currentUser.uid);
    int likeCount = review.likedBy.length;
    
    // Fix username display
    String displayName = review.userName.isNotEmpty ? review.userName : 'Participant';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   CircleAvatar(
                     radius: 16, 
                     backgroundColor: Colors.orange[100], 
                     child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')
                   ),
                   const SizedBox(width: 8),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                       Text(review.createdAt != null ? "${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}" : "Just now", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                     ],
                   ),
                ],
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => WriteReviewScreen(event: widget.event, existingReview: review)));
                  else if (value == 'delete') _deleteReview(review.id!);
                  else if (value == 'report') _reportReview(review.id!);
                },
                itemBuilder: (context) => [
                  if (isMe) ...[
                    const PopupMenuItem(value: 'edit', child: Text('Edit Review')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Review', style: TextStyle(color: Colors.red))),
                  ] else ...[
                    const PopupMenuItem(value: 'report', child: Text('Report Review', style: TextStyle(color: Colors.red))),
                  ]
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(children: List.generate(5, (index) => Icon(index < review.rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 16))),
          const SizedBox(height: 8),
          Text(review.comment),
          if (review.isEdited) const Text("(edited)", style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
          if (review.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoUrls.length,
                itemBuilder: (context, index) => Padding(padding: const EdgeInsets.only(right: 8.0), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(review.photoUrls[index], width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(width: 80, height: 80, color: Colors.grey)))),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
               InkWell(onTap: () => _reviewService.toggleLikeReview(review.id!), child: Row(children: [Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey, size: 20), const SizedBox(width: 4), Text("$likeCount", style: const TextStyle(color: Colors.grey, fontSize: 12))])),
               const SizedBox(width: 20),
               InkWell(
                  onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => ReplyBottomSheet(reviewId: review.id!)),
                  child: StreamBuilder<List<ReplyModel>>(
                    stream: _reviewService.getReplies(review.id!),
                    builder: (context, snapshot) {
                      String label = "Reply";
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) label = snapshot.data!.length.toString();
                      return Row(children: [const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20), const SizedBox(width: 4), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))]);
                    }
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.event, size: 40, color: Colors.grey)));
    if (imageUrl.startsWith('/')) return Image.file(File(imageUrl), fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildErrorImage());
    return Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildErrorImage());
  }
  Widget _buildErrorImage() => Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)));
}

// ==========================================
// PARTICIPANT REPLY BOTTOM SHEET (Read-Only Badges)
// ==========================================
class ReplyBottomSheet extends StatefulWidget {
  final String reviewId;
  const ReplyBottomSheet({super.key, required this.reviewId});

  @override
  State<ReplyBottomSheet> createState() => _ReplyBottomSheetState();
}

class _ReplyBottomSheetState extends State<ReplyBottomSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ReviewService _service = ReviewService();
  final StorageService _storageService = StorageService(); // NEW
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _replyingToUser;

  void _send() {
    if (_ctrl.text.trim().isEmpty) return;
    _service.addReply(widget.reviewId, _ctrl.text.trim());
    _ctrl.clear();
    setState(() => _replyingToUser = null);
    FocusScope.of(context).unfocus();
  }

  void _delete(String replyId) => _service.deleteReply(widget.reviewId, replyId);

  // --- SAFE AVATAR BUILDER (FIXED) ---
  Widget _buildAvatar(String? url, String name, bool isClub) {
    // Default
    Widget defaultWidget = CircleAvatar(
        radius: 16,
        backgroundColor: isClub ? Colors.blue : Colors.grey[200],
        child: isClub 
          ? const Icon(Icons.verified, size: 16, color: Colors.white)
          : Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
    );

    if (url == null || url.isEmpty) return defaultWidget;

    return FutureBuilder<String?>(
      future: _storageService.resolveImageUrl(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const CircleAvatar(radius: 16, backgroundColor: Colors.grey);
        if (snapshot.hasError || snapshot.data == null) return defaultWidget;
        
        return CircleAvatar(
          radius: 16,
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
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(padding: EdgeInsets.all(12), child: Text("Replies", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Expanded(
              child: StreamBuilder<List<ReplyModel>>(
                stream: _service.getReplies(widget.reviewId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final replies = snap.data ?? [];
                  if (replies.isEmpty) return const Center(child: Text("No replies yet."));

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: replies.length,
                    itemBuilder: (_, i) {
                      final r = replies[i];
                      bool isMe = r.userId == _myUid;
                      bool isClub = r.isClubRep;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             // AVATAR LOGIC (Fixed for Crash)
                             _buildAvatar(r.userAvatarUrl, r.userName, isClub),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(r.userName.isNotEmpty ? r.userName : 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (isClub) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                                          child: const Text("Author", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                      if (isMe) const Text(" (You)", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(r.content),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                            setState(() => _replyingToUser = r.userName);
                                            _ctrl.text = "@${r.userName} ";
                                            _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
                                            FocusScope.of(context).requestFocus(_focusNode);
                                        },
                                        child: Text("Reply", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 16),
                                        GestureDetector(onTap: () => _delete(r.id), child: Text("Delete", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red[300]))),
                                      ]
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
              child: Row(children: [
                Expanded(child: Container(decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(24)), child: TextField(controller: _ctrl, focusNode: _focusNode, decoration: InputDecoration(hintText: _replyingToUser != null ? "Reply to $_replyingToUser..." : "Add a reply...", border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), isDense: true)))), 
                const SizedBox(width: 12), 
                GestureDetector(onTap: _send, child: const CircleAvatar(radius: 20, backgroundColor: Colors.red, child: Icon(Icons.arrow_upward, color: Colors.white, size: 20)))
              ]),
            ),
          ],
        ),
      ),
    );
  }
}