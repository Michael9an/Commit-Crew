import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event.dart';
import '../models/register.dart';
import '../models/user.dart';

class RegistrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register participant to an event
  Future<Map<String, dynamic>> registerToEvent({
    required String eventId,
    required String fullName,
    required String email,
    required String phoneNumber,
    required int ticketQuantity,
    double amountPaid = 0.0,
    String? userId,
    bool isFree = false,
  }) async {
    try {
      final registerId = '${eventId}_${DateTime.now().millisecondsSinceEpoch}';

      return await _firestore.runTransaction<Map<String, dynamic>>(
        (transaction) async {
          // 1. Get event document
          final eventRef = _firestore.collection('events').doc(eventId);
          final eventDoc = await transaction.get(eventRef);

          if (!eventDoc.exists) {
            throw Exception('Event not found');
          }

          final eventData = eventDoc.data()!;
          final event = EventModel.fromFirestore(eventData);

          // 2. Check if event is published and not cancelled
          if (event.status != 'published' || event.isCancelled) {
            throw Exception('Event is not available for registration');
          }

          // 3. Check if event date is in the future
          final eventDate = event.dateTime;
          if (eventDate.isBefore(DateTime.now())) {
            throw Exception('Event has already passed');
          }

          // 4. Check available spots
          final maxAttendees = event.maxAttendees;
          final currentAttendees = event.attendees.length;
          if (maxAttendees > 0 && (currentAttendees + ticketQuantity) > maxAttendees) {
            throw Exception('Not enough spots available. Only ${maxAttendees - currentAttendees} spots left');
          }

          // 5. Check for duplicate registration by email
          final duplicateCheck = await _firestore
              .collection('registers')
              .where('eventId', isEqualTo: eventId)
              .where('email', isEqualTo: email)
              .where('status', whereIn: ['registered', 'pending'])
              .limit(1)
              .get();

          if (duplicateCheck.docs.isNotEmpty) {
            throw Exception('You are already registered for this event');
          }

          // 6. Create registration object
          final register = Register(
            id: registerId,
            eventId: eventId,
            clubId: event.clubId,
            fullName: fullName.trim(),
            email: email.trim(),
            phoneNumber: phoneNumber.trim(),
            registrationDate: DateTime.now(),
            userId: userId,
            status: 'registered',
            paymentStatus: isFree ? null : 'pending',
            ticketQuantity: ticketQuantity,
            amountPaid: amountPaid,
          );

          // 7. Update event attendees (add user ID if available)
          final updates = <String, dynamic>{
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (userId != null && userId.isNotEmpty) {
            updates['attendees'] = FieldValue.arrayUnion([userId]);
          }

          // 8. Execute transaction
          transaction.set(
            _firestore.collection('registers').doc(registerId),
            register.toFirestore(),
          );

          transaction.update(eventRef, updates);

          return {
            'success': true,
            'registerId': registerId,
            'message': 'Registration successful',
            'register': register.toFirestore(),
          };
        },
      );
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Complete payment for registration
  Future<Map<String, dynamic>> completePayment({
    required String registerId,
    required double amount,
    required String paymentId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Get registration document
        final registerRef = _firestore.collection('registers').doc(registerId);
        final registerDoc = await transaction.get(registerRef);

        if (!registerDoc.exists) {
          throw Exception('Registration not found');
        }

        final data = registerDoc.data()! as Map<String, dynamic>;
        final register = Register.fromFirestore(data);

        // 2. Update registration with payment details
        final updatedRegister = register.copyWith(
          paymentStatus: 'paid',
          paymentId: paymentId,
          amountPaid: amount,
        );

        transaction.update(registerRef, updatedRegister.toFirestore());
      });

      return {
        'success': true,
        'message': 'Payment completed successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get registration by ID
  Future<Register?> getRegistration(String registerId) async {
    try {
      final doc = await _firestore.collection('registers').doc(registerId).get();
      if (doc.exists) {
        final data = doc.data()! as Map<String, dynamic>;
        return Register.fromFirestore(data);
      }
      return null;
    } catch (e) {
      print('Error getting registration: $e');
      return null;
    }
  }

  // Get registrations for an event
  Future<List<Register>> getEventRegistrations(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('registers')
          .where('eventId', isEqualTo: eventId)
          .orderBy('registrationDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Register.fromFirestore(data);
      }).toList();
    } catch (e) {
      print('Error getting event registrations: $e');
      return [];
    }
  }

  // Get user's registrations
  Future<List<Register>> getUserRegistrations({String? userId, String? email}) async {
    try {
      Query query = _firestore.collection('registers');

      if (userId != null && userId.isNotEmpty) {
        query = query.where('userId', isEqualTo: userId);
      } else if (email != null && email.isNotEmpty) {
        query = query.where('email', isEqualTo: email);
      } else {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return [];
        
        if (currentUser.uid.isNotEmpty) {
          query = query.where('userId', isEqualTo: currentUser.uid);
        } else if (currentUser.email != null) {
          query = query.where('email', isEqualTo: currentUser.email);
        } else {
          return [];
        }
      }

      query = query.orderBy('registrationDate', descending: true);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Register.fromFirestore(data);
      }).toList();
    } catch (e) {
      print('Error getting user registrations: $e');
      return [];
    }
  }

  // Cancel registration
  Future<Map<String, dynamic>> cancelRegistration(String registerId, {String? reason}) async {
    try {
      return await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        // 1. Get registration document
        final registerRef = _firestore.collection('registers').doc(registerId);
        final registerDoc = await transaction.get(registerRef);

        if (!registerDoc.exists) {
          throw Exception('Registration not found');
        }

        final data = registerDoc.data()! as Map<String, dynamic>;
        final register = Register.fromFirestore(data);

        // 2. Check if cancellation is allowed
        if (register.isCancelled) {
          throw Exception('Registration already cancelled');
        }

        if (register.hasAttended) {
          throw Exception('Cannot cancel attended registration');
        }

        // 3. Get event document
        final eventRef = _firestore.collection('events').doc(register.eventId);
        final eventDoc = await transaction.get(eventRef);

        if (!eventDoc.exists) {
          throw Exception('Event not found');
        }

        final eventData = eventDoc.data()! as Map<String, dynamic>;
        final event = EventModel.fromFirestore(eventData);

        // 4. Update registration status
        final updatedRegister = register.markAsCancelled(reason: reason);
        transaction.update(registerRef, updatedRegister.toFirestore());

        // 5. Remove from event attendees if user ID exists
        if (register.userId != null && register.userId!.isNotEmpty) {
          transaction.update(eventRef, {
            'attendees': FieldValue.arrayRemove([register.userId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // 6. If paid registration, update payment status
        if (register.isPaid) {
          transaction.update(registerRef, {
            'paymentStatus': 'refunded',
          });
        }

        return {
          'success': true,
          'message': 'Registration cancelled successfully',
        };
      });
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Mark attendance
  Future<Map<String, dynamic>> markAttendance(String registerId) async {
    try {
      await _firestore.collection('registers').doc(registerId).update({
        'status': 'attended',
        'attendedAt': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'message': 'Attendance marked'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Check if user is registered for an event
  Future<bool> isUserRegistered(String eventId, {String? userId, String? email}) async {
    try {
      Query query = _firestore
          .collection('registers')
          .where('eventId', isEqualTo: eventId)
          .where('status', whereIn: ['registered', 'pending']);

      if (userId != null && userId.isNotEmpty) {
        query = query.where('userId', isEqualTo: userId);
      } else if (email != null && email.isNotEmpty) {
        query = query.where('email', isEqualTo: email);
      } else {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return false;
        
        if (currentUser.uid.isNotEmpty) {
          query = query.where('userId', isEqualTo: currentUser.uid);
        } else if (currentUser.email != null) {
          query = query.where('email', isEqualTo: currentUser.email);
        } else {
          return false;
        }
      }

      final snapshot = await query.limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking registration: $e');
      return false;
    }
  }

  // Get registration statistics for an event
  Future<Map<String, dynamic>> getEventRegistrationStats(String eventId) async {
    try {
      final registrations = await getEventRegistrations(eventId);
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      
      if (!eventDoc.exists) {
        throw Exception('Event not found');
      }

      final eventData = eventDoc.data()! as Map<String, dynamic>;
      final event = EventModel.fromFirestore(eventData);
      
      final registeredCount = registrations.where((r) => r.isActive).length;
      final attendedCount = registrations.where((r) => r.hasAttended).length;
      final cancelledCount = registrations.where((r) => r.isCancelled).length;
      final paidCount = registrations.where((r) => r.isPaid).length;
      final totalRevenue = registrations.fold<double>(0, (sum, r) => sum + r.amountPaid);

      return {
        'event': event.toFirestore(),
        'totalRegistrations': registrations.length,
        'registeredCount': registeredCount,
        'attendedCount': attendedCount,
        'cancelledCount': cancelledCount,
        'paidCount': paidCount,
        'totalRevenue': totalRevenue,
        'availableSpots': event.maxAttendees > 0 ? event.maxAttendees - registeredCount : null,
        'capacityUtilization': event.maxAttendees > 0 ? (registeredCount / event.maxAttendees * 100) : 100,
      };
    } catch (e) {
      print('Error getting registration stats: $e');
      return {};
    }
  }

  // Stream registrations for real-time updates
  Stream<List<Register>> streamEventRegistrations(String eventId) {
    return _firestore
        .collection('registers')
        .where('eventId', isEqualTo: eventId)
        .orderBy('registrationDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Register.fromFirestore(data);
            }).toList());
  }

  // Stream user registrations for real-time updates
  Stream<List<Register>> streamUserRegistrations(String userId) {
    return _firestore
        .collection('registers')
        .where('userId', isEqualTo: userId)
        .orderBy('registrationDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Register.fromFirestore(data);
            }).toList());
  }
}