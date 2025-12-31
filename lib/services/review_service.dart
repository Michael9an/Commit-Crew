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

  // --- 2. SUBMIT REVIEW (Create) ---
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
      
      // --- FIX: AGGRESSIVE USERNAME FETCHING ---
      String displayName = '';
      
      try {
        // Try fetching from 'users' collection
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          // Priority: username -> fullName -> name
          if (data['username'] != null && data['username'].toString().isNotEmpty) {
            displayName = data['username'];
          } else if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
            displayName = data['fullName'];
          } else if (data['name'] != null && data['name'].toString().isNotEmpty) {
            displayName = data['name'];
          }
        }
      } catch (e) {
        print("Error fetching user detail: $e");
      }
      
      // Fallback to Auth Display Name or Email
      if (displayName.isEmpty) {
        displayName = currentUser.displayName ?? '';
      }
      if (displayName.isEmpty && currentUser.email != null) {
        displayName = currentUser.email!.split('@')[0];
      }
      // Final fallback
      if (displayName.isEmpty) {
        displayName = 'Participant';
      }
      // ----------------------------------------

      final newReview = ReviewModel(
        id: reviewId,
        eventId: eventId,
        userId: currentUser.uid,
        userName: displayName,
        rating: rating,
        comment: comment,
        photoUrls: downloadUrls,
        createdAt: DateTime.now(),
      );

      await reviewRef.set(newReview.toFirestore());
    } catch (e) {
      throw Exception('Failed to submit review: $e');
    }
  }

  // --- 3. UPDATE REVIEW (Edit) ---
  Future<void> updateReview({
    required String reviewId,
    required double newRating,
    required String newComment,
  }) async {
    // Note: You can comment out 'rating': newRating if you want to strictly ban rating changes on backend too.
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

    // If NOT a club rep, try to fetch the real user name again
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

  Future<void> deleteReply(String reviewId, String replyId) async {
    await _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .doc(replyId)
        .delete();
  }

  // --- 5. HELPERS & FETCHING ---
  Future<List<String>> _uploadPhotos(String eventId, List<File>? photos) async {
    if (photos == null || photos.isEmpty) return [];
    
    List<String> urls = [];
    final uuid = Uuid();

    for (var imageFile in photos) {
      final String fileName = '${uuid.v4()}.jpg';
      final Reference ref = _storage.ref().child('reviews').child(eventId).child(fileName);
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String url = await snapshot.ref.getDownloadURL();
      urls.add(url);
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
    final userId = _auth.currentUser?.uid;
    await _firestore.collection('reports').add({
      'targetId': reviewId,
      'type': 'review',
      'reason': reason,
      'reportedBy': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}