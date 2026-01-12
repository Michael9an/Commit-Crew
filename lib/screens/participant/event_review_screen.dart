import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/event.dart';
import '../../models/review.dart';
import '../../services/review_service.dart';
import '../../services/storage_service.dart'; // Import StorageService

class WriteReviewScreen extends StatefulWidget {
  final EventModel event;
  final ReviewModel? existingReview;

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
  final StorageService _storageService = StorageService(); // Init Storage Service
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  double _rating = 0;
  List<File> _selectedImages = [];
  bool _isSubmitting = false;
  String _statusMessage = ''; // To show "Uploading 1/3..."

  @override
  void initState() {
    super.initState();
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
    if (widget.existingReview != null) return;
    
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

  // --- NEW: Handle Image Uploads via StorageService ---
  Future<List<String>> _processImageUploads() async {
    List<String> uploadedUrls = [];
    
    for (int i = 0; i < _selectedImages.length; i++) {
      setState(() {
        _statusMessage = 'Uploading photo ${i + 1} of ${_selectedImages.length}...';
      });

      // Generate a unique ID for this specific image to avoid overwrites
      // Format: eventId_timestamp_index
      String uniqueImageId = '${widget.event.id}_${DateTime.now().millisecondsSinceEpoch}_$i';

      try {
        String? url = await _storageService.uploadReviewImage(
          _selectedImages[i], 
          uniqueImageId
        );
        
        if (url != null) {
          uploadedUrls.add(url);
        }
      } catch (e) {
        print("Failed to upload image $i: $e");
        // Optional: decide if you want to stop or continue if one fails
      }
    }
    return uploadedUrls;
  }

  Future<void> _handleSubmit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a star rating.')));
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a review comment.')));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Preparing...';
    });

    try {
      if (widget.existingReview != null) {
        // UPDATE Existing Review
        await _reviewService.updateReview(
          reviewId: widget.existingReview!.id!,
          newComment: _commentController.text.trim(),
          newRating: _rating,
        );
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review updated!'), backgroundColor: Colors.green),
          );
        }
      } else {
        // CREATE New Review
        
        // 1. Upload Images
        List<String> photoUrls = [];
        if (_selectedImages.isNotEmpty) {
          photoUrls = await _processImageUploads();
        }

        setState(() => _statusMessage = 'Submitting review...');

        // 2. Submit Data
        await _reviewService.submitReview(
          eventId: widget.event.id,
          rating: _rating,
          comment: _commentController.text.trim(),
          photoUrls: photoUrls, // Pass the cloud URLs
        );

         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Review submitted!'), backgroundColor: Colors.green),
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
          // Main Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEditing ? 'Update Rating' : 'How was the event?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Center(
                  child: RatingBar.builder(
                    initialRating: _rating,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
                    onRatingUpdate: (rating) => setState(() => _rating = rating),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Share your experience', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'What did you like or dislike?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  maxLines: 5,
                  maxLength: 500,
                ),
                const SizedBox(height: 16),
                
                // Photo Picker Section
                if (!isEditing) ...[
                  const Text('Add Photos (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
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
                               child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
                             ),
                          )
                        ],
                      )),
                    ],
                  ),
                ],
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(isEditing ? 'Update Review' : 'Submit Review', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          
          // Loading Overlay
          if (_isSubmitting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage, 
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}