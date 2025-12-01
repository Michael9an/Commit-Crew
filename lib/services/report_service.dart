import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/report.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Submit a report for an event
  Future<void> submitReport({
    required String eventId,
    required String eventName,
    required String reason,
    String? details,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final reportId = _firestore.collection('reports').doc().id;
      final report = ReportModel(
        id: reportId,
        eventId: eventId,
        eventName: eventName,
        userId: currentUser.uid,
        reason: reason,
        details: details,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('reports')
          .doc(reportId)
          .set(report.toFirestore());

      print('Report submitted successfully');
    } catch (e) {
      print('Error submitting report: $e');
      throw e;
    }
  }

  // Get all reports for an event
  Stream<List<ReportModel>> getEventReports(String eventId) {
    return _firestore
        .collection('reports')
        .where('eventId', isEqualTo: eventId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ReportModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get all reports by a user
  Stream<List<ReportModel>> getUserReports() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('reports')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ReportModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get all pending reports (for admin)
  Stream<List<ReportModel>> getPendingReports() {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ReportModel.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  // Update report status (for admin)
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? reviewerNotes,
  }) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': status,
        'reviewedAt': DateTime.now().millisecondsSinceEpoch,
        'reviewerNotes': reviewerNotes,
      });

      print('Report status updated');
    } catch (e) {
      print('Error updating report status: $e');
      throw e;
    }
  }

  // Check if user has already reported this event
  Future<bool> hasUserReportedEvent(String eventId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      final query = await _firestore
          .collection('reports')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if user reported event: $e');
      return false;
    }
  }
}
