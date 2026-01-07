import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../models/club.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<EventModel>> getEvents() {
    return _firestore
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return EventModel.fromFirestore(doc.data(), doc.id); 
      }).toList();
    });
  }

  Stream<List<EventModel>> getEventsByClub(String clubId) {
    return _firestore
        .collection('events')
        .where('clubId', isEqualTo: clubId)
        .snapshots()
        .map((snapshot) {
      final events = snapshot.docs.map((doc) {
        return EventModel.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      events.sort((a, b) {
        final aTime = int.tryParse(a.date ?? '0') ?? 0;
        final bTime = int.tryParse(b.date ?? '0') ?? 0;
        return bTime.compareTo(aTime); 
      });
      
      return events;
    });
  }

  // Add new event with timeout and retry
  Future<void> addEvent(EventModel event) async {
    try {
      await _firestore
          .collection('events')
          .doc(event.id)
          .set(
            event.toFirestore(),
            SetOptions(merge: true), 
          )
          .timeout(
            const Duration(seconds: 15),
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
  // (These methods are kept for backward compatibility but may not be used in the single-admin model)
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

  // Added Method for Club Profile Update
  Future<void> updateClub(String clubId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update(data);
    } catch (e) {
      print('Error updating club: $e');
      throw e;
    }
  }

  Future<void> submitClubVerification(String clubId, String documentUrl) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'approvalLetterUrl': documentUrl,
        'verificationStatus': 'submitted', // New status flag for Admin notification
        'status': 'pending_approval', // Update overall status
        'submittedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error submitting verification: $e');
      throw e;
    }
  }

  Future<void> joinClub(String clubId, String userId) async {
    final batch = _firestore.batch();
    
    // Add user to club's pending requests
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

  // Mark a user as present for an event
  Future<Map<String, dynamic>> markAttendance(String eventId, String userId) async {
    try {
      // 1. Fetch Event Details
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      if (!eventDoc.exists) return {'success': false, 'message': 'Event not found'};

      final eventData = eventDoc.data()!;
      
      // 2. Parse Date
      if (eventData['date'] == null) {
         return {'success': false, 'message': 'Event date configuration error.'};
      }
      final DateTime eventDate = DateTime.fromMillisecondsSinceEpoch(int.parse(eventData['date']));
      
      // 3. Parse Time (With Safe Fallbacks for Issue #4)
      // If start time is missing, assume 12:00 AM
      final TimeOfDay startTime = eventData['startTime'] != null 
          ? _parseTime(eventData['startTime']) 
          : const TimeOfDay(hour: 0, minute: 0);

      // If end time is missing (Issue #4 fix), assume 11:59 PM so attendance works all day
      final TimeOfDay endTime = eventData['endTime'] != null 
          ? _parseTime(eventData['endTime']) 
          : const TimeOfDay(hour: 23, minute: 59);

      // Combine
      final DateTime startDateTime = DateTime(
        eventDate.year, eventDate.month, eventDate.day, 
        startTime.hour, startTime.minute
      );
      
      final DateTime endDateTime = DateTime(
        eventDate.year, eventDate.month, eventDate.day, 
        endTime.hour, endTime.minute
      );

      final DateTime now = DateTime.now();

      // 4. Validate Time Buffer (30 mins before -> End time)
      final DateTime scanStart = startDateTime.subtract(const Duration(minutes: 30));
      
      if (now.isBefore(scanStart)) {
        return {'success': false, 'message': 'Too early! Check-in starts 30 mins before event.'};
      }
      
      if (now.isAfter(endDateTime)) {
        return {'success': false, 'message': 'Event has ended. Check-in closed.'};
      }

      // 5. Check Registration in "registers" collection
      final querySnapshot = await _firestore
          .collection('registers')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {'success': false, 'message': 'You are not registered for this event.'};
      }

      final doc = querySnapshot.docs.first;
      
      // Check if already attended
      if (doc.data()['status'] == 'Attended') {
        return {'success': false, 'message': 'You have already checked in!'};
      }

      // 6. Mark Success
      await _firestore.collection('registers').doc(doc.id).update({
        'status': 'Attended',
        'checkInTime': FieldValue.serverTimestamp(),
      });
      
      return {'success': true, 'message': 'Check-in successful!'};

    } catch (e) {
      print("Error marking attendance: $e");
      return {'success': false, 'message': 'System error: $e'};
    }
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      // Fallback if format is wrong
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }
}


// Analytics Models
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
