import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/event.dart';
import '../../models/review.dart'; // Ensure this matches path
import '../../services/review_service.dart';

class WriteReviewScreen extends StatefulWidget {
  final EventModel event;
  final ReviewModel? existingReview; // Added for Edit Mode

  const WriteReviewScreen({
    super.key, 
    required this.event, 
    this.existingReview
  });

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  double _rating = 0;
  List<File> _selectedImages = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill if editing
    if (widget.existingReview != null) {
      _rating = widget.existingReview!.rating;
      _commentController.text = widget.existingReview!.comment;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (widget.existingReview != null) return; // Disable photo edit for simplicity
    
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleSubmit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a star rating.')));
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please write a review comment.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.existingReview != null) {
        // UPDATE Existing
        await _reviewService.updateReview(
          reviewId: widget.existingReview!.id!,
          newComment: _commentController.text.trim(),
          newRating: _rating,
        );
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review updated!'), backgroundColor: Colors.green),
        );
      } else {
        // CREATE New
        await _reviewService.submitReview(
          eventId: widget.event.id,
          rating: _rating,
          comment: _commentController.text.trim(),
          photos: _selectedImages,
        );
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Review submitted!'), backgroundColor: Colors.green),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingReview != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Review' : 'Review ${widget.event.name}')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEditing ? 'Update Rating' : 'How was the event?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Center(
                  child: RatingBar.builder(
                    initialRating: _rating,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
                    onRatingUpdate: (rating) => setState(() => _rating = rating),
                  ),
                ),
                SizedBox(height: 24),
                Text('Share your experience', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'What did you like or dislike?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  maxLines: 5,
                  maxLength: 500,
                ),
                SizedBox(height: 16),
                
                // Hide photo picker if editing to simplify
                if (!isEditing) ...[
                  Text('Add Photos (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InkWell(
                        onTap: () => _pickImage(ImageSource.gallery),
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
                          child: Icon(Icons.add_a_photo, color: Colors.grey[600]),
                        ),
                      ),
                      ..._selectedImages.map((file) => Stack(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover)),
                          Positioned(
                             top: 0, right: 0,
                             child: GestureDetector(
                               onTap: () => setState(() => _selectedImages.remove(file)),
                               child: CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
                             ),
                          )
                        ],
                      )),
                    ],
                  ),
                ],
                
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: EdgeInsets.symmetric(vertical: 14)),
                    child: Text(isEditing ? 'Update Review' : 'Submit Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          if (_isSubmitting) Container(color: Colors.black54, child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}