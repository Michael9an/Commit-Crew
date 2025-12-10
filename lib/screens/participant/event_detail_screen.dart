import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../models/event.dart';
import '../../models/review.dart'; 
import '../../services/storage_service.dart';
import '../../services/registration_service.dart'; 
import '../../services/auth_service.dart'; 
import '../../services/review_service.dart'; 
// import '../../services/firestore_service.dart'; // No longer needed here if only used for reviews
import 'report_screen.dart';
import 'event_registration_screen.dart';
import 'event_review_screen.dart'; 

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
  // Services
  final RegistrationService _registrationService = RegistrationService();
  final AuthService _authService = AuthService();
  // UPDATED: Use ReviewService instead of FirestoreService for review data
  final ReviewService _reviewService = ReviewService(); 

  // State variables for Registration
  bool _isRegistered = false;
  bool _isCheckingRegistration = true;

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
  }

  // Logic to check if the current user is already registered (From File 1)
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
      print('Error checking registration status: $e');
      if (mounted) {
        setState(() {
          _isRegistered = false;
          _isCheckingRegistration = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current firebase user for Review logic (From File 2)
    final currentUser = FirebaseAuth.instance.currentUser;

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
                      // Favorite Button
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

                  // Location
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

                  SizedBox(height: 16),

                  // Register Button (Logic from File 1)
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
                                ? null // Disable button if already registered
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
                                        // Registration was successful
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Successfully registered for ${widget.event.name}!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        // Refresh registration status
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
                      // Used the safer logic from File 1 that checks for unlimited
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

                  // ===============================================
                  // REVIEWS SECTION
                  // ===============================================
                  Text(
                    'Reviews',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),

                  SizedBox(height: 12),

                  // StreamBuilder wraps BOTH the Button and the List
                  StreamBuilder<List<ReviewModel>>(
                    // UPDATED: Using _reviewService
                    stream: _reviewService.getEventReviews(widget.event.id),
                    builder: (context, snapshot) {
                      // 1. Loading State
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      // 2. Error State (Likely Index Error)
                      if (snapshot.hasError) {
                        return Container(
                          padding: EdgeInsets.all(16),
                          color: Colors.red[50],
                          child: Text(
                            "To enable reviews, please check your Run Console and click the 'Create Index' link from Firebase.",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        );
                      }

                      final reviews = snapshot.data ?? [];
                      
                      // 3. Logic: Has current user reviewed?
                      bool hasUserReviewed = false;
                      if (currentUser != null) {
                        // Check if ANY review in the list belongs to the current user
                        hasUserReviewed = reviews.any((r) => r.userId == currentUser.uid);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- SECTION A: Button / Status Message ---
                          if (widget.event.isPast) ...[
                            if (hasUserReviewed)
                              // Case 1: Event Passed + User Reviewed -> Hide Button, Show Success
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12),
                                margin: EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  border: Border.all(color: Colors.green),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "You have submitted your review.",
                                        style: TextStyle(color: Colors.green[800]),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              // Case 2: Event Passed + User NOT Reviewed -> Show Button
                              Column(
                                children: [
                                  Text(
                                    'Did you attend? Share your experience.',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                WriteReviewScreen(event: widget.event),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: BorderSide(color: Colors.red),
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      icon: Icon(Icons.rate_review_outlined),
                                      label: Text('Write a Review'),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                ],
                              ),
                          ] else ...[
                            // Case 3: Event NOT Passed -> Show Info
                             Container(
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.grey),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Reviews will open once the event has concluded.',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // --- SECTION B: List of Reviews ---
                          if (reviews.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Text("No reviews yet.", style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: reviews.length,
                              separatorBuilder: (context, index) => Divider(),
                              itemBuilder: (context, index) {
                                return _buildReviewItem(reviews[index]);
                              },
                            ),
                        ],
                      );
                    },
                  ),

                  SizedBox(height: 24),

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

  // --- Helper Widgets ---

  Widget _buildReviewItem(ReviewModel review) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.userName,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                review.createdAt != null 
                  ? "${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}" 
                  : "Just now",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < review.rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 16,
              );
            }),
          ),
          SizedBox(height: 8),
          Text(review.comment),
          if (review.photoUrls.isNotEmpty) ...[
            SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoUrls.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        review.photoUrls[index],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(width: 80, height: 80, color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
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