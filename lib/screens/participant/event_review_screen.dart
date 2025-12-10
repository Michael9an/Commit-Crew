import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/event.dart';
// import '../../services/firestore_service.dart'; // Replaced by ReviewService
import '../../services/review_service.dart'; 

class WriteReviewScreen extends StatefulWidget {
  final EventModel event;

  const WriteReviewScreen({super.key, required this.event});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  // UPDATED: Use ReviewService
  final ReviewService _reviewService = ReviewService();
  
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  double _rating = 0;
  List<File> _selectedImages = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Function to pick images from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800, // Limit size for faster uploads
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Function to handle submission
  Future<void> _handleSubmit() async {
    // 1. Validation
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a star rating.')),
      );
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please write a review comment.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 2. Submit to Firebase using ReviewService
      await _reviewService.submitReview(
        eventId: widget.event.id,
        rating: _rating,
        comment: _commentController.text.trim(),
        photos: _selectedImages,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to details screen
      }
    } catch (e) {
      // --- UPDATED ERROR HANDLING ---
      // This will now show the REAL error from Firebase in the app
      String errorMessage = 'Error: $e'; 
      
      if (e.toString().contains('ALREADY_REVIEWED')) {
        errorMessage = 'You have already reviewed this event.';
      } else if (e.toString().contains('permission-denied')) {
        errorMessage = 'Permission denied. Please check Firestore Database Rules.';
      }

      print("DEBUG: Real Review Error: $e"); // View this in your Debug Console

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage), // Shows the specific error now
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Review ${widget.event.name}'),
      ),
      // Show loading overlay if submitting
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How was the event?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                
                // 1. Star Rating Widget
                Center(
                  child: RatingBar.builder(
                    initialRating: 0,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder: (context, _) => Icon(
                      Icons.star,
                      color: Colors.amber,
                    ),
                    onRatingUpdate: (rating) {
                      setState(() {
                        _rating = rating;
                      });
                    },
                  ),
                ),
                SizedBox(height: 24),

                Text(
                  'Share your experience',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                
                // 2. Comment TextField
                TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'What did you like or dislike?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 5,
                  maxLength: 500,
                ),
                SizedBox(height: 16),

                Text(
                  'Add Photos (Optional)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),

                // 3. Image Picker Section
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Button to add images
                    InkWell(
                      onTap: () {
                        // Show bottom sheet to choose camera or gallery
                        showModalBottomSheet(
                            context: context,
                            builder: (context) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: Icon(Icons.photo_library),
                                        title: Text('Photo Library'),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          _pickImage(ImageSource.gallery);
                                        },
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.camera_alt),
                                        title: Text('Camera'),
                                        onTap: () {
                                          Navigator.of(context).pop();
                                          _pickImage(ImageSource.camera);
                                        },
                                      ),
                                    ],
                                  ),
                                ));
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Icon(Icons.add_a_photo, color: Colors.grey[600]),
                      ),
                    ),
                    // Display selected images
                    ..._selectedImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              file,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          // Delete button on top right of image
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImages.removeAt(index);
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),

                SizedBox(height: 32),

                // 4. Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Submit Review',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          // Loading overlay
          if (_isSubmitting)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}