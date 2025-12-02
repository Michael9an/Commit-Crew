import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../models/club.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all events
  Stream<List<EventModel>> getEvents() {
    return _firestore
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return EventModel.fromFirestore(doc.data());
      }).toList();
    });
  }

  // Get events by club
  Stream<List<EventModel>> getEventsByClub(String clubId) {
    return _firestore
        .collection('events')
        .where('clubId', isEqualTo: clubId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return EventModel.fromFirestore(doc.data());
      }).toList();
    });
  }

  // Add new event with timeout and retry
  Future<void> addEvent(EventModel event) async {
    try {
      // Add with timeout to prevent hanging
      await _firestore
          .collection('events')
          .doc(event.id)
          .set(
            event.toFirestore(),
            SetOptions(merge: true), // Enable merge to prevent conflicts
          )
          .timeout(
            Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException('Failed to save event: operation timed out');
            },
          );
    } catch (e) {
      print('Error adding event: $e');
      throw e;
    }
  }

  // Update event
  Future<void> updateEvent(String eventId, EventModel event) async {
    try {
      await _firestore.collection('events').doc(eventId).update(event.toFirestore());
    } catch (e) {
      print('Error updating event: $e');
      throw e;
    }
  }

  // Delete event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      print('Error deleting event: $e');
      throw e;
    }
  }

  // Club Members Management
  Stream<List<UserModel>> getClubMembers(String clubId) {
    return _firestore
        .collection('users')
        .where('clubIds', arrayContains: clubId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc.data()))
            .toList());
  }

  Stream<List<UserModel>> getClubAdmins(String clubId) {
    return _firestore
        .collection('users')
        .where('clubIds', arrayContains: clubId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc.data()))
            .where((user) => user.role == 'admin' || user.clubIds.contains(clubId))
            .toList());
  }

  Stream<List<UserModel>> getPendingJoinRequests(String clubId) {
    return _firestore
        .collection('join_requests')
        .where('clubId', isEqualTo: clubId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      final users = <UserModel>[];
      for (final doc in snapshot.docs) {
        final userId = doc.data()['userId'];
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          users.add(UserModel.fromFirestore(userDoc.data()!));
        }
      }
      return users;
    });
  }

  Future<void> addClubAdmin(String clubId, String userId) async {
    await _firestore.collection('clubs').doc(clubId).update({
      'adminIds': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> removeClubAdmin(String clubId, String userId) async {
    await _firestore.collection('clubs').doc(clubId).update({
      'adminIds': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> removeClubMember(String clubId, String userId) async {
    final batch = _firestore.batch();
    
    // Remove from club members
    batch.update(_firestore.collection('clubs').doc(clubId), {
      'memberIds': FieldValue.arrayRemove([userId]),
      'adminIds': FieldValue.arrayRemove([userId]),
    });
    
    // Remove club from user's clubs
    batch.update(_firestore.collection('users').doc(userId), {
      'clubIds': FieldValue.arrayRemove([clubId]),
    });
    
    await batch.commit();
  }

  Future<void> approveJoinRequest(String clubId, String userId) async {
    final batch = _firestore.batch();
    
    // Update join request status
    batch.update(_firestore.collection('join_requests').doc('$clubId-$userId'), {
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });
    
    // Add user to club
    batch.update(_firestore.collection('clubs').doc(clubId), {
      'memberIds': FieldValue.arrayUnion([userId]),
    });
    
    // Add club to user
    batch.update(_firestore.collection('users').doc(userId), {
      'clubIds': FieldValue.arrayUnion([clubId]),
    });
    
    await batch.commit();
  }

  Future<void> rejectJoinRequest(String clubId, String userId) async {
    await _firestore.collection('join_requests').doc('$clubId-$userId').update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  // Analytics Methods
  Stream<ClubAnalytics> getClubAnalytics(String clubId, AnalyticsPeriod period) {
    return getEventsByClub(clubId).map((events) {
      // Filter events by period
      final now = DateTime.now();
      final filteredEvents = events.where((event) {
        final eventDate = DateTime.fromMillisecondsSinceEpoch(int.parse(event.date));
        switch (period) {
          case AnalyticsPeriod.last7Days:
            return eventDate.isAfter(now.subtract(Duration(days: 7)));
          case AnalyticsPeriod.last30Days:
            return eventDate.isAfter(now.subtract(Duration(days: 30)));
          case AnalyticsPeriod.last90Days:
            return eventDate.isAfter(now.subtract(Duration(days: 90)));
          case AnalyticsPeriod.thisYear:
            return eventDate.year == now.year;
        }
      }).toList();

      // Calculate analytics
      return _calculateClubAnalytics(filteredEvents, period);
    });
  }

  ClubAnalytics _calculateClubAnalytics(List<EventModel> events, AnalyticsPeriod period) {
    if (events.isEmpty) {
      return ClubAnalytics.empty();
    }

    final totalEvents = events.length;
    final totalAttendance = events.fold(0, (sum, event) => sum + event.attendees.length);
    final averageAttendance = totalEvents > 0 ? (totalAttendance / totalEvents).toDouble() : 0.0;
    
    final paidEvents = events.where((event) => !event.isFree);
    final totalRevenue = paidEvents.fold(0.0, (sum, event) => sum + (event.price * event.attendees.length));
    
    final completedEvents = events.where((event) => event.status == 'completed').length;
    final completionRate = totalEvents > 0 ? (completedEvents / totalEvents * 100).toDouble() : 0.0;
    
    final cancelledEvents = events.where((event) => event.status == 'cancelled').length;
    final cancellationRate = totalEvents > 0 ? (cancelledEvents / totalEvents * 100).toDouble() : 0.0;
    
    final capacityUtilizations = events
        .where((event) => event.maxAttendees > 0)
        .map((event) => (event.attendees.length / event.maxAttendees * 100).toDouble())
        .toList();
    final averageCapacityUtilization = capacityUtilizations.isNotEmpty
        ? (capacityUtilizations.reduce((a, b) => a + b) / capacityUtilizations.length).toDouble()
        : 0.0;

    // Generate trend data
    final attendanceTrend = _generateAttendanceTrend(events, period);
    final revenueTrend = _generateRevenueTrend(events, period);
    
    // Get top events by attendance
    final sortedEvents = List<EventModel>.from(events); // Create a new list
    sortedEvents.sort((a, b) => b.attendees.length.compareTo(a.attendees.length));
    final topEvents = sortedEvents.take(5).toList();

    return ClubAnalytics(
      totalEvents: totalEvents,
      totalAttendance: totalAttendance,
      averageAttendance: averageAttendance,
      totalRevenue: totalRevenue,
      completionRate: completionRate,
      cancellationRate: cancellationRate,
      averageCapacityUtilization: averageCapacityUtilization,
      attendanceTrend: attendanceTrend,
      revenueTrend: revenueTrend,
      topEvents: topEvents,
    );
  }

  List<AttendanceData> _generateAttendanceTrend(List<EventModel> events, AnalyticsPeriod period) {
    final trend = <AttendanceData>[];
    final now = DateTime.now();
    
    for (var i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = '${date.day}/${date.month}';
      final dayEvents = events.where((event) {
        final eventDate = DateTime.fromMillisecondsSinceEpoch(int.parse(event.date));
        return eventDate.day == date.day && eventDate.month == date.month;
      }).toList();
      
      final attendance = dayEvents.fold(0, (sum, event) => sum + event.attendees.length);
      trend.add(AttendanceData(date: dateStr, attendance: attendance));
    }
    
    return trend;
  }

  List<RevenueData> _generateRevenueTrend(List<EventModel> events, AnalyticsPeriod period) {
    final trend = <RevenueData>[];
    final now = DateTime.now();
    
    for (var i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = '${date.day}/${date.month}';
      final dayEvents = events.where((event) {
        final eventDate = DateTime.fromMillisecondsSinceEpoch(int.parse(event.date));
        return eventDate.day == date.day && eventDate.month == date.month && !event.isFree;
      }).toList();
      
      final revenue = dayEvents.fold(0.0, (sum, event) => sum + (event.price * event.attendees.length));
      trend.add(RevenueData(date: dateStr, revenue: revenue));
    }
    
    return trend;
  }

  // Additional Club Methods
  Stream<List<Club>> getClubs() {
    return _firestore
        .collection('clubs')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Club.fromFirestore(doc.data()))
            .toList());
  }

  Future<Club> getClub(String clubId) async {
    final doc = await _firestore.collection('clubs').doc(clubId).get();
    if (doc.exists) {
      return Club.fromFirestore(doc.data()!);
    }
    throw Exception('Club not found');
  }

  Future<void> joinClub(String clubId, String userId) async {
    final batch = _firestore.batch();
    
    // Add user to club's pending requests or directly to members based on your logic
    batch.set(_firestore.collection('join_requests').doc('$clubId-$userId'), {
      'clubId': clubId,
      'userId': userId,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }

  Future<void> addEventToClub(String clubId, String eventId) async {
  try {
      await _firestore.collection('clubs').doc(clubId).update({
        'events': FieldValue.arrayUnion([eventId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding event to club: $e');
      throw Exception('Failed to update club events: $e');
    }
  }

  // User Management
  Future<UserModel> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc.data()!);
    }
    throw Exception('User not found');
  }

  Future<void> updateUser(UserModel user) async {
    await _firestore.collection('users').doc(user.id).update(user.toFirestore());
  }
}

// Analytics Models - Add these at the bottom of the file
class ClubAnalytics {
  final int totalEvents;
  final int totalAttendance;
  final double averageAttendance;
  final double totalRevenue;
  final double completionRate;
  final double cancellationRate;
  final double averageCapacityUtilization;
  final List<AttendanceData> attendanceTrend;
  final List<RevenueData> revenueTrend;
  final List<EventModel> topEvents;

  ClubAnalytics({
    required this.totalEvents,
    required this.totalAttendance,
    required this.averageAttendance,
    required this.totalRevenue,
    required this.completionRate,
    required this.cancellationRate,
    required this.averageCapacityUtilization,
    required this.attendanceTrend,
    required this.revenueTrend,
    required this.topEvents,
  });

  factory ClubAnalytics.empty() {
    return ClubAnalytics(
      totalEvents: 0,
      totalAttendance: 0,
      averageAttendance: 0,
      totalRevenue: 0,
      completionRate: 0,
      cancellationRate: 0,
      averageCapacityUtilization: 0,
      attendanceTrend: [],
      revenueTrend: [],
      topEvents: [],
    );
  }
}

class AttendanceData {
  final String date;
  final int attendance;

  AttendanceData({required this.date, required this.attendance});
}

class RevenueData {
  final String date;
  final double revenue;

  RevenueData({required this.date, required this.revenue});
}

enum AnalyticsPeriod {
  last7Days,
  last30Days,
  last90Days,
  thisYear,
}
