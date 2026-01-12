import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/review.dart';
import '../models/report.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- 1. CHECK STATUS (For hiding the button) ---
  Stream<ReviewModel?> streamUserReview(String eventId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _firestore
        .collection('reviews')
        .doc('${eventId}_$userId')
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return ReviewModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    });
  }

  Future<void> submitReview({
    required String eventId,
    required double rating,
    required String comment,
    List<String> photoUrls = const [], // CHANGED: Now accepts List<String>
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("User must be logged in.");

    final String reviewId = '${eventId}_${currentUser.uid}';
    final DocumentReference reviewRef = _firestore.collection('reviews').doc(reviewId);

    final docSnapshot = await reviewRef.get();
    if (docSnapshot.exists) throw Exception('ALREADY_REVIEWED');

    try {
      // 1. Get User Display Name (Same logic as before)
      String displayName = '';
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          displayName = data['username'] ?? data['fullName'] ?? data['name'] ?? '';
        }
      } catch (e) { print(e); }
      
      if (displayName.isEmpty) displayName = currentUser.displayName ?? currentUser.email!.split('@')[0];

      // 2. Create Review Object
      final newReview = ReviewModel(
        id: reviewId,
        eventId: eventId,
        userId: currentUser.uid,
        userName: displayName,
        rating: rating,
        comment: comment,
        photoUrls: photoUrls, // Pass the URLs directly
        createdAt: DateTime.now(),
      );

      // 3. Save to Firestore
      await reviewRef.set(newReview.toFirestore());
    } catch (e) {
      throw Exception('Failed to submit review: $e');
    }
  }

  // --- 3. UPDATE REVIEW (Main Review) ---
  Future<void> updateReview({
    required String reviewId,
    required double newRating,
    required String newComment,
  }) async {
    await _firestore.collection('reviews').doc(reviewId).update({
      'rating': newRating, 
      'comment': newComment,
      'isEdited': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // --- 4. REPLIES ---
  Stream<List<ReplyModel>> getReplies(String reviewId) {
    return _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ReplyModel.fromFirestore(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addReply(String reviewId, String content, {
    bool isClubRep = false,
    String? overrideName,
    String? overrideAvatarUrl,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    String displayName = overrideName ?? '';

    if (!isClubRep && displayName.isEmpty) {
        try {
          final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
             final data = userDoc.data();
             displayName = data?['username'] ?? data?['fullName'] ?? data?['name'] ?? '';
          }
        } catch (e) { print(e); }
        
        if (displayName.isEmpty) {
           displayName = currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'User';
        }
    }

    final reply = ReplyModel(
      id: '',
      userId: currentUser.uid,
      userName: displayName,
      userAvatarUrl: overrideAvatarUrl, 
      isClubRep: isClubRep,             
      content: content,
    );

    await _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .add(reply.toFirestore());
  }

  // --- NEW: UPDATE REPLY (For editing specific comments) ---
  Future<void> updateReply(String reviewId, String replyId, String newContent) async {
    await _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .doc(replyId)
        .update({
          'content': newContent,
          // You could also add 'isEdited': true here if ReplyModel supports it
        });
  }

  Future<void> deleteReply(String reviewId, String replyId) async {
    await _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .doc(replyId)
        .delete();
  }

  // --- 5. HELPERS ---
  Future<List<String>> _uploadPhotos(String eventId, List<File>? photos) async {
    if (photos == null || photos.isEmpty) return [];
    
    List<String> urls = [];
    final uuid = Uuid();

    for (var imageFile in photos) {
      final String fileName = '${uuid.v4()}.jpg';
      final Reference ref = _storage.ref().child('reviews').child(eventId).child(fileName);
      await ref.putFile(imageFile);
      urls.add(await ref.getDownloadURL());
    }
    return urls;
  }

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

  Future<void> deleteReview(String reviewId) async {
    await _firestore.collection('reviews').doc(reviewId).delete();
  }

  Future<void> toggleLikeReview(String reviewId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final docRef = _firestore.collection('reviews').doc(reviewId);
    final doc = await docRef.get();
    
    if (doc.exists) {
      List<dynamic> likedBy = doc.data()?['likedBy'] ?? [];
      if (likedBy.contains(userId)) {
        await docRef.update({'likedBy': FieldValue.arrayRemove([userId])});
      } else {
        await docRef.update({'likedBy': FieldValue.arrayUnion([userId])});
      }
    }
  }

  Future<void> reportReview(String reviewId, String reason) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // 1. Get Review Data to find Event ID
      final reviewDoc = await _firestore.collection('reviews').doc(reviewId).get();
      if (!reviewDoc.exists) return; // Or throw
      
      final String eventId = reviewDoc.data()?['eventId'] ?? '';
      
      // 2. Get Event Data to find Event Name
      String eventName = 'Unknown Event';
      if (eventId.isNotEmpty) {
        final eventDoc = await _firestore.collection('events').doc(eventId).get();
        if (eventDoc.exists) {
          eventName = eventDoc.data()?['name'] ?? 'Unknown Event';
        }
      }

      // 3. Create Report
      final String reportId = _firestore.collection('reports').doc().id;
      
      final report = ReportModel(
        id: reportId,
        eventId: eventId,
        eventName: eventName,
        userId: currentUser.uid,
        reason: reason,
        status: 'pending',
        type: 'review',
        targetId: reviewId,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('reports').doc(reportId).set(report.toFirestore());
    } catch (e) {
      print('Error reporting review: $e');
      rethrow;
    }
  }
}