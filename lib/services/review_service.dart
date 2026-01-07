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

  // --- 1. FETCH EVENT REVIEWS ---
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

  // --- 2. CHECK STATUS ---
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

  // --- 3. SUBMIT REVIEW ---
  Future<void> submitReview({
    required String eventId,
    required double rating,
    required String comment,
    List<File>? photos,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("User must be logged in.");

    final String reviewId = '${eventId}_${currentUser.uid}';
    final DocumentReference reviewRef =
        _firestore.collection('reviews').doc(reviewId);

    final docSnapshot = await reviewRef.get();
    if (docSnapshot.exists) throw Exception('ALREADY_REVIEWED');

    try {
      List<String> downloadUrls = await _uploadPhotos(eventId, photos);

      String displayName = _resolveDisplayName(currentUser);

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

  // --- 4. UPDATE REVIEW ---
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

  // --- 5. REPLIES ---
  Stream<List<ReplyModel>> getReplies(String reviewId) {
    return _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReplyModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addReply(
    String reviewId,
    String content, {
    bool isClubRep = false,
    String? overrideName,
    String? overrideAvatarUrl,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    String displayName = overrideName ?? '';
    if (!isClubRep && displayName.isEmpty) {
      displayName = await _fetchUserName(currentUser.uid) ?? _resolveDisplayName(currentUser);
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

    // --- NOTIFICATION: REPLY ---
    await _sendNotification(
      reviewId: reviewId,
      senderId: currentUser.uid,
      senderName: displayName,
      senderAvatar: overrideAvatarUrl,
      type: 'reply_review',
      title: 'New Reply',
      body: '$displayName replied to your review.',
    );
  }

  Future<void> updateReply(String reviewId, String replyId, String newContent) async {
    await _firestore
        .collection('reviews')
        .doc(reviewId)
        .collection('replies')
        .doc(replyId)
        .update({
      'content': newContent,
    });
  }

  // --- 6. HELPERS & NOTIFICATIONS ---

  Future<void> toggleLikeReview(String reviewId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final docRef = _firestore.collection('reviews').doc(reviewId);
    final doc = await docRef.get();

    if (doc.exists) {
      List<dynamic> likedBy = doc.data()?['likedBy'] ?? [];
      
      if (likedBy.contains(currentUser.uid)) {
        // UNLIKE
        await docRef.update({
          'likedBy': FieldValue.arrayRemove([currentUser.uid])
        });
      } else {
        // LIKE
        await docRef.update({
          'likedBy': FieldValue.arrayUnion([currentUser.uid])
        });

        // --- NOTIFICATION: LIKE ---
        // Fetch fresh name or use fallback
        String displayName = await _fetchUserName(currentUser.uid) ?? _resolveDisplayName(currentUser);
        
        await _sendNotification(
          reviewId: reviewId,
          senderId: currentUser.uid,
          senderName: displayName,
          type: 'like_review',
          title: 'New Like',
          body: '$displayName liked your review.',
        );
      }
    }
  }

  // --- INTERNAL NOTIFICATION LOGIC ---
  Future<void> _sendNotification({
    required String reviewId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String type,
    required String title,
    required String body,
  }) async {
    try {
      // 1. Get the review to find out who owns it (the recipient)
      DocumentSnapshot reviewSnap = await _firestore.collection('reviews').doc(reviewId).get();
      
      if (reviewSnap.exists) {
        final data = reviewSnap.data() as Map<String, dynamic>;
        
        // Safely get owner ID
        String? reviewOwnerId = data['userId']; 
        String? eventId = data['eventId'];

        if (reviewOwnerId == null) {
          print("Warning: Review $reviewId has no userId field. Cannot send notification.");
          return;
        }

        // 2. PREVENT SELF-NOTIFICATION
        // If the person liking/replying is the same as the review owner, do nothing.
        if (reviewOwnerId != senderId) {
          await _firestore.collection('notifications').add({
            'recipientId': reviewOwnerId, // This must match the field user listens to
            'senderId': senderId,
            'senderName': senderName,
            'senderAvatar': senderAvatar,
            'type': type,
            'title': title,
            'body': body,
            'targetId': reviewId,
            'eventId': eventId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          print("Notification sent to $reviewOwnerId");
        }
      }
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> getNotifications() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllNotificationsAsRead() async {
     final userId = _auth.currentUser?.uid;
     if (userId == null) return;
     
     final batch = _firestore.batch();
     final snapshots = await _firestore.collection('notifications')
       .where('recipientId', isEqualTo: userId)
       .where('isRead', isEqualTo: false)
       .get();

     for (var doc in snapshots.docs) {
       batch.update(doc.reference, {'isRead': true});
     }
     await batch.commit();
  }

  // --- UTILS ---
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

  Future<void> deleteReply(String reviewId, String replyId) async {
    await _firestore.collection('reviews').doc(reviewId).collection('replies').doc(replyId).delete();
  }

  Future<void> deleteReview(String reviewId) async => await _firestore.collection('reviews').doc(reviewId).delete();
  
  Future<void> reportReview(String reviewId, String reason) async {
    final userId = _auth.currentUser?.uid;
    await _firestore.collection('reports').add({
      'targetId': reviewId, 'type': 'review', 'reason': reason, 'reportedBy': userId, 'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String _resolveDisplayName(User user) {
    if (user.displayName != null && user.displayName!.isNotEmpty) return user.displayName!;
    return user.email != null ? user.email!.split('@')[0] : 'Participant';
  }

  Future<String?> _fetchUserName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) return doc.data()?['username'] ?? doc.data()?['fullName'];
    } catch (_) {}
    return null;
  }
}