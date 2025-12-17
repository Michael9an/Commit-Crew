import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../models/event.dart';
import '../../models/review.dart'; 
import '../../services/storage_service.dart';
import '../../services/registration_service.dart'; 
import '../../services/auth_service.dart'; 
import '../../services/review_service.dart'; 
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
  final ReviewService _reviewService = ReviewService(); 

  // State variables for Registration
  bool _isRegistered = false;
  bool _isCheckingRegistration = true;

  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
  }

  // Logic to check if the current user is already registered
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

  // --- ACTIONS FOR REVIEWS ---
  
  void _deleteReview(String reviewId) async {
    try {
      await _reviewService.deleteReview(reviewId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Review deleted")));
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
          title: Text("Report Review"),
          children: reasons.map((r) => SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _reviewService.reportReview(reviewId, r);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Report submitted.")));
            },
            child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text(r)),
          )).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current firebase user for Review logic
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
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'by ${widget.event.clubName}',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(Icons.favorite_border, color: Colors.red),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to favorites!')));
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

                  SizedBox(height: 16),

                  // Date and Time
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(widget.event.formattedDate, style: TextStyle(color: Colors.grey[600])),
                      SizedBox(width: 16),
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(widget.event.formattedTime, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),

                  SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Expanded(child: Text(widget.event.location, style: TextStyle(color: Colors.grey[600]))),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    child: _isCheckingRegistration
                        ? Container(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
                            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                          )
                        : ElevatedButton(
                            onPressed: _isRegistered ? null : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EventRegistrationScreen(event: widget.event, ticketQuantity: 1),
                                      ),
                                    ).then((success) {
                                      if (success == true) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Successfully registered for ${widget.event.name}!'), backgroundColor: Colors.green),
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
                                  : widget.event.isFree ? 'Register for Event' : 'Register Now - RM${widget.event.price.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                  ),

                  SizedBox(height: 24),

                  // About Event Section
                  Text('About Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Text(widget.event.description, style: TextStyle(color: Colors.grey[600], height: 1.5)),
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
                            Text('Organized by', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            Text(widget.event.clubName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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

                  // ===============================================
                  // REVIEWS SECTION
                  // ===============================================
                  Text('Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                  SizedBox(height: 12),

                  StreamBuilder<List<ReviewModel>>(
                    stream: _reviewService.getEventReviews(widget.event.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Container(
                          padding: EdgeInsets.all(16),
                          color: Colors.red[50],
                          child: Text("Error loading reviews.", style: TextStyle(color: Colors.red, fontSize: 12)),
                        );
                      }

                      final reviews = snapshot.data ?? [];
                      bool hasUserReviewed = false;
                      if (currentUser != null) {
                        hasUserReviewed = reviews.any((r) => r.userId == currentUser.uid);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- SECTION A: Button / Status Message ---
                          if (widget.event.isPast) ...[
                            if (hasUserReviewed)
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
                                    Expanded(child: Text("You have submitted your review.", style: TextStyle(color: Colors.green[800]))),
                                  ],
                                ),
                              )
                            else
                              Column(
                                children: [
                                  Text('Did you attend? Share your experience.', style: TextStyle(color: Colors.grey[600])),
                                  SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WriteReviewScreen(event: widget.event))),
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red), padding: EdgeInsets.symmetric(vertical: 12)),
                                      icon: Icon(Icons.rate_review_outlined),
                                      label: Text('Write a Review'),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                ],
                              ),
                          ] else ...[
                             Container(
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.grey),
                                  SizedBox(width: 12),
                                  Expanded(child: Text('Reviews will open once the event has concluded.', style: TextStyle(color: Colors.grey[600]))),
                                ],
                              ),
                            ),
                          ],

                          // --- SECTION B: List of Reviews ---
                          if (reviews.isEmpty)
                            Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text("No reviews yet.", style: TextStyle(color: Colors.grey))))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: reviews.length,
                              separatorBuilder: (context, index) => Divider(),
                              itemBuilder: (context, index) {
                                return _buildReviewItem(reviews[index], currentUser);
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
                      Text('Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ParticipantReportEventScreen(event: widget.event))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Report Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildReviewItem(ReviewModel review, User? currentUser) {
    bool isMe = currentUser != null && review.userId == currentUser.uid;
    bool isLiked = currentUser != null && review.likedBy.contains(currentUser.uid);
    int likeCount = review.likedBy.length;

    // Safety checks for display
    String avatarLetter = (review.userName.isNotEmpty) 
        ? review.userName[0].toUpperCase() 
        : '?';

    String displayName = (review.userName.isNotEmpty) 
        ? review.userName 
        : 'Anonymous';

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Name, Date, Menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   CircleAvatar(
                     radius: 16, 
                     backgroundColor: Colors.orange[100],
                     child: Text(avatarLetter),
                   ),
                   SizedBox(width: 8),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                       Text(
                         review.createdAt != null 
                           ? "${review.createdAt!.day}/${review.createdAt!.month}/${review.createdAt!.year}" 
                           : "Just now",
                         style: TextStyle(fontSize: 12, color: Colors.grey),
                       ),
                     ],
                   ),
                ],
              ),
              // Menu Logic
              PopupMenuButton(
                icon: Icon(Icons.more_horiz, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => WriteReviewScreen(event: widget.event, existingReview: review)));
                  } else if (value == 'delete') {
                    _deleteReview(review.id!);
                  } else if (value == 'report') {
                    _reportReview(review.id!);
                  }
                },
                itemBuilder: (context) => [
                  if (isMe) ...[
                    PopupMenuItem(value: 'edit', child: Text('Edit Review')),
                    PopupMenuItem(value: 'delete', child: Text('Delete Review', style: TextStyle(color: Colors.red))),
                  ] else ...[
                    PopupMenuItem(value: 'report', child: Text('Report Review', style: TextStyle(color: Colors.red))),
                  ]
                ],
              ),
            ],
          ),

          SizedBox(height: 4),

          // 2. Rating
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

          // 3. Comment + Edited status
          Text(review.comment),
          if (review.isEdited) 
            Text("(edited)", style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),

          // 4. Photos
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

          SizedBox(height: 12),

          // 5. Action Row: Like & Reply
          Row(
            children: [
               // LIKE
               InkWell(
                  onTap: () => _reviewService.toggleLikeReview(review.id!),
                  child: Row(
                    children: [
                      Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey, size: 20),
                      SizedBox(width: 4),
                      Text("$likeCount", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(width: 20),
                
                // REPLY (UPDATED)
                InkWell(
                  onTap: () => showModalBottomSheet(
                    context: context, 
                    isScrollControlled: true,
                    builder: (_) => ReplyBottomSheet(reviewId: review.id!)
                  ),
                  child: StreamBuilder<List<ReplyModel>>(
                    stream: _reviewService.getReplies(review.id!),
                    builder: (context, snapshot) {
                      // Determine label: "Reply" if 0, or "5" if > 0
                      String label = "Reply";
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        label = snapshot.data!.length.toString();
                      }
                      
                      return Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 20),
                          SizedBox(width: 4),
                          Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      );
                    }
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Original Helpers ---

  Widget _buildEventImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.event, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('No image', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    if (imageUrl.startsWith('/')) {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorImage();
        },
      );
    }
    final storageService = StorageService();
    return FutureBuilder<String?>(
      future: storageService.resolveImageUrl(imageUrl),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(color: Colors.grey[200], child: Center(child: CircularProgressIndicator()));
        }
        final resolved = snap.data;
        if (resolved == null || resolved.isEmpty) {
          return _buildErrorImage();
        }
        if (resolved.startsWith('/')) {
          return Image.file(
            File(resolved),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
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
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildErrorImage(),
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
          Text('Image not available', style: TextStyle(color: Colors.grey)),
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
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// IMPROVED REPLY BOTTOM SHEET
// ==========================================
class ReplyBottomSheet extends StatefulWidget {
  final String reviewId;
  const ReplyBottomSheet({super.key, required this.reviewId});

  @override
  State<ReplyBottomSheet> createState() => _ReplyBottomSheetState();
}

class _ReplyBottomSheetState extends State<ReplyBottomSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // Added for auto-focus
  final ReviewService _service = ReviewService();
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  String? _replyingToUser; // Track who we are replying to

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    if (_ctrl.text.trim().isEmpty) return;
    
    // The service handles the database logic
    _service.addReply(widget.reviewId, _ctrl.text.trim());
    
    _ctrl.clear();
    setState(() {
      _replyingToUser = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _delete(String replyId) => _service.deleteReply(widget.reviewId, replyId);

  // Triggered when user clicks "Reply" on someone's comment
  void _startReplyToUser(String userName) {
    setState(() {
      _replyingToUser = userName;
    });
    
    // Pre-fill text with mention
    String mention = "@$userName ";
    _ctrl.text = mention;
    
    // Move cursor to end
    _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
    
    // Open keyboard
    FocusScope.of(context).requestFocus(_focusNode);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate height to avoid keyboard covering input
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75, // Slightly taller
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // --- Header ---
            Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300], 
                    borderRadius: BorderRadius.circular(2)
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text("Replies", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),

            // --- List of Replies ---
            Expanded(
              child: StreamBuilder<List<ReplyModel>>(
                stream: _service.getReplies(widget.reviewId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  
                  final replies = snap.data ?? [];
                  
                  if (replies.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                          SizedBox(height: 12),
                          Text("No replies yet.", style: TextStyle(color: Colors.grey)),
                          Text("Start the conversation!", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: replies.length,
                    itemBuilder: (_, i) {
                      final r = replies[i];
                      bool isMe = r.userId == _myUid;

                      // Safety Check for Name/Avatar
                      String replyName = r.userName.isNotEmpty ? r.userName : 'Anonymous';
                      String replyAvatar = replyName.isNotEmpty ? replyName[0].toUpperCase() : '?';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue[50],
                              child: Text(replyAvatar, style: TextStyle(fontSize: 14, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ),
                            SizedBox(width: 12),
                            
                            // Content Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(replyName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[800])),
                                      if (isMe) 
                                        Text(" (You)", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    r.content, 
                                    style: TextStyle(fontSize: 14, color: Colors.black87),
                                  ),
                                  SizedBox(height: 6),
                                  
                                  // Interaction Row (Reply button)
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _startReplyToUser(replyName),
                                        child: Text("Reply", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                                      ),
                                      if (isMe) ...[
                                        SizedBox(width: 16),
                                        GestureDetector(
                                          onTap: () => _delete(r.id),
                                          child: Text("Delete", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red[300])),
                                        ),
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

            // --- Input Area ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, -5))
                ],
              ),
              padding: EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 12),
              child: Column(
                children: [
                  // Banner showing who we are replying to
                  if (_replyingToUser != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Text("Replying to ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text("@$_replyingToUser", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Spacer(),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _replyingToUser = null;
                                _ctrl.clear();
                              });
                            },
                            child: Icon(Icons.close, size: 16, color: Colors.grey),
                          )
                        ],
                      ),
                    ),
                  
                  // Text Field
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _ctrl,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: _replyingToUser != null ? "Reply to $_replyingToUser..." : "Add a reply...",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              isDense: true,
                            ),
                            maxLines: null, // Allow expanding
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      GestureDetector(
                        onTap: _send,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}