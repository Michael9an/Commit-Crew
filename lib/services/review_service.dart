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

  // --- 1. CORE REVIEW ACTIONS ---

  Future<void> submitReview({
    required String eventId,
    required double rating,
    required String comment,
    List<File>? photos,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("User must be logged in.");

    final String reviewId = '${eventId}_${currentUser.uid}';
    final DocumentReference reviewRef = _firestore.collection('reviews').doc(reviewId);

    final docSnapshot = await reviewRef.get();
    if (docSnapshot.exists) throw Exception('ALREADY_REVIEWED');

    try {
      List<String> downloadUrls = await _uploadPhotos(eventId, photos);
      final String displayName = currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'User';
      
      final newReview = ReviewModel(
        id: reviewId,
        eventId: eventId,
        userId: currentUser.uid,
        userName: displayName,
        rating: rating,
        comment: comment,
        photoUrls: downloadUrls,
      );

      await reviewRef.set(newReview.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  // UPDATE (Edit) Review
  Future<void> updateReview({
    required String reviewId,
    required String newComment,
    required double newRating,
  }) async {
    await _firestore.collection('reviews').doc(reviewId).update({
      'comment': newComment,
      'rating': newRating,
      'isEdited': true,
    });
  }

  // DELETE Review
  Future<void> deleteReview(String reviewId) async {
    await _firestore.collection('reviews').doc(reviewId).delete();
  }

  // LIKE / UNLIKE Review
  Future<void> toggleLikeReview(String reviewId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final docRef = _firestore.collection('reviews').doc(reviewId);
    final doc = await docRef.get();

    if (doc.exists) {
      final List<dynamic> likedBy = doc.data()?['likedBy'] ?? [];
      if (likedBy.contains(currentUser.uid)) {
        // Unlike
        await docRef.update({
          'likedBy': FieldValue.arrayRemove([currentUser.uid])
        });
      } else {
        // Like
        await docRef.update({
          'likedBy': FieldValue.arrayUnion([currentUser.uid])
        });
      }
    }
  }

  // REPORT Review
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

  // --- 2. REPLY ACTIONS (Sub-collection) ---

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

  Future<void> addReply(String reviewId, String content) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final String displayName = currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'User';

    final reply = ReplyModel(
      id: '',
      userId: currentUser.uid,
      userName: displayName,
      content: content,
    );

    await _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .add(reply.toFirestore());
  }

  Future<void> deleteReply(String reviewId, String replyId) async {
    await _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .doc(replyId)
        .delete();
  }

  // --- 3. HELPERS ---
  Future<List<String>> _uploadPhotos(String eventId, List<File>? photos) async {
    if (photos == null || photos.isEmpty) return [];
    
    List<String> urls = [];
    final uuid = Uuid();

    for (var imageFile in photos) {
      final String fileName = '${uuid.v4()}.jpg';
      final Reference ref = _storage.ref().child('reviews').child(eventId).child(fileName);
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      if (snapshot.state == TaskState.success) {
        urls.add(await snapshot.ref.getDownloadURL());
      }
    }
    return urls;
  }
}