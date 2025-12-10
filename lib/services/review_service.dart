import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/review.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submits a review. 
  /// Enforces One Review per User per Event by using a composite ID (eventId_userId).
  Future<void> submitReview({
    required String eventId,
    required double rating,
    required String comment,
    List<File>? photos,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception("User must be logged in to submit a review.");
    }

    // 1. Create Unique Review ID (EventID + UserID)
    final String reviewId = '${eventId}_${currentUser.uid}';
    final DocumentReference reviewRef = _firestore.collection('reviews').doc(reviewId);

    // 2. CHECK if review already exists
    final docSnapshot = await reviewRef.get();
    if (docSnapshot.exists) {
      throw Exception('ALREADY_REVIEWED'); 
    }

    try {
      List<String> downloadUrls = [];

      // 3. Image Upload Logic
      if (photos != null && photos.isNotEmpty) {
        final uuid = Uuid();

        for (var imageFile in photos) {
          final String fileName = '${uuid.v4()}.jpg';
          // Save under: reviews / eventId / uniqueFile.jpg
          final Reference ref = _storage
              .ref()
              .child('reviews')
              .child(eventId)
              .child(fileName);

          final UploadTask uploadTask = ref.putFile(imageFile);
          final TaskSnapshot snapshot = await uploadTask;
          final String url = await snapshot.ref.getDownloadURL();
          downloadUrls.add(url);
        }
      }

      // 4. Create Review Model
      final String displayName = currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'User';
      
      final newReview = ReviewModel(
        id: reviewId, // Use our composite ID
        eventId: eventId,
        userId: currentUser.uid,
        userName: displayName, 
        rating: rating,
        comment: comment,
        photoUrls: downloadUrls,
      );

      // 5. Save to Firestore using SET (not add)
      await reviewRef.set(newReview.toFirestore());
      
    } catch (e) {
      print('Error submitting review: $e');
      // Re-throw so the UI can catch specific errors like 'ALREADY_REVIEWED'
      rethrow;
    }
  }

  /// Get reviews for a specific event as a Stream
  Stream<List<ReviewModel>> getEventReviews(String eventId) {
    return _firestore
        .collection('reviews')
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ReviewModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Optional: Get a specific review to check if it exists (useful for initial loading states)
  Future<ReviewModel?> getUserReviewForEvent(String eventId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    final String reviewId = '${eventId}_${currentUser.uid}';
    final docSnapshot = await _firestore.collection('reviews').doc(reviewId).get();

    if (docSnapshot.exists) {
      return ReviewModel.fromFirestore(docSnapshot.data()!, docSnapshot.id);
    }
    return null;
  }
}