import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event.dart';
import '../models/register.dart';

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
      // Generate unique registration ID
      final registerId = '${eventId}_${DateTime.now().millisecondsSinceEpoch}';

      // Get event reference
      final eventRef = _firestore.collection('events').doc(eventId);
      final eventDoc = await eventRef.get();

      if (!eventDoc.exists) {
        return {
          'succcess': false,
          'error': 'Event no found',
        };
      }

      final eventData = eventDoc.data()!;
      final event = EventModel.fromFirestore(eventData, eventDoc.id);

      // Check if event is available
      if (event.status != 'published') {
        return{
          'success': false,
          'error': 'Event is not available for registration',
        };
      }

      // Check if event is no cancelled
      if(event.isCancelled) {
        return {
          'success': false,
          'error': 'Event has been cancelled',
        };
      }

      // Check if event date is in the future
      final eventDate = event.dateTime;
      if (eventDate.isBefore(DateTime.now())) {
        return {
          'success': false,
          'error': 'Event has already passed'
        };
      }

      // Check capacity
      final maxAttendees = event.maxAttendees;
      final currentAttendees = event.attendees.length;
      if (maxAttendees > 0 && (currentAttendees + ticketQuantity) > maxAttendees) {
        return {
          'success': false,
          'error': 'Not enough spots available',
        };
      }

      // Check for duplicate registration by email
      final duplicateCheck = await _firestore
          .collection('registers')
          .where('eventId', isEqualTo: eventId)
          .where('email', isEqualTo: email.trim().toLowerCase())
          .where('status', whereIn: ['registered', 'pending'])
          .limit(1)
          .get();

      if (duplicateCheck.docs.isNotEmpty) {
        return {
          'success': false,
          'error': 'You are already registered for this event', 
        };
      }

      // Create registration object
      final register = Register(
        id: registerId,
        eventId: eventId,
        clubId: event.clubId,
        fullName: fullName.trim(),
        email: email.trim().toLowerCase(),
        phoneNumber: phoneNumber.trim(),
        registrationDate: DateTime.now(),
        userId: userId,
        status: 'registered',
        paymentStatus: isFree ? null : 'pending',
        ticketQuantity: ticketQuantity,
        amountPaid: amountPaid,
      );

      final batch = _firestore.batch();

      // Save registration docs
      final registerRef = _firestore.collection('registers').doc(registerId);
      batch.set(registerRef, register.toFirestore());

      // Update event attendees
      if (userId != null && userId.isNotEmpty) {
        batch.update(eventRef, {
          'attendees': FieldValue.arrayUnion([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // For guest registration, track by email
        batch.update(eventRef, {
          'attendeesEmails': FieldValue.arrayUnion([email.trim().toLowerCase()]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Execute batch
      await batch.commit();

      return {
        'success': true,
        'registerId': registerId,
        'message': 'Registration successful',
        'register': register.toFirestore(),
      };
      
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
        final register = Register.fromFirestore(data, documentId: registerDoc.id);

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
        return Register.fromFirestore(data, documentId: doc.id);
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
        return Register.fromFirestore(data, documentId: doc.id);
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
        query = query.where('email', isEqualTo: email.trim().toLowerCase());
      } else {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return [];
        
        if (currentUser.uid.isNotEmpty) {
          query = query.where('userId', isEqualTo: currentUser.uid);
        } else if (currentUser.email != null) {
          query = query.where('email', isEqualTo: currentUser.email!.trim().toLowerCase());
        } else {
          return [];
        }
      }

      // Don't use orderBy here to avoid requiring a composite index
      // We'll sort in memory instead
      final snapshot = await query.get();
      final registrations = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Register.fromFirestore(data, documentId: doc.id);
      }).toList();
      
      // Sort by registration date descending (most recent first)
      registrations.sort((a, b) => b.registrationDate.compareTo(a.registrationDate));
      return registrations;
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
        final register = Register.fromFirestore(data, documentId: registerDoc.id);

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
        final event = EventModel.fromFirestore(eventData, eventDoc.id);

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
        query = query.where('email', isEqualTo: email.trim().toLowerCase());
      } else {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return false;
        
        if (currentUser.uid.isNotEmpty) {
          query = query.where('userId', isEqualTo: currentUser.uid);
        } else if (currentUser.email != null) {
          query = query.where('email', isEqualTo: currentUser.email!.trim().toLowerCase());
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
      final event = EventModel.fromFirestore(eventData, eventDoc.id);
      
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
              return Register.fromFirestore(data, documentId: doc.id);
            }).toList());
  }

  // Stream user registrations for real-time updates
  Stream<List<Register>> streamUserRegistrations(String userId) {
    return _firestore
        .collection('registers')
        .where('userId', isEqualTo: userId)
        // Don't use orderBy here to avoid requiring a composite index
        .snapshots()
        .map((snapshot) {
          final registrations = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Register.fromFirestore(data, documentId: doc.id);
          }).toList();
          // Sort by registration date descending (most recent first)
          registrations.sort((a, b) => b.registrationDate.compareTo(a.registrationDate));
          return registrations;
        });
  }

  // for testing
  Future<void> testRegistrationConnection() async {
    try {
      print('Testing Firestore connection...');
      
      // Test write
      await _firestore.collection('test_registration').doc('test').set({
        'test': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✓ Write test passed');
      
      // Test read
      final doc = await _firestore.collection('test_registration').doc('test').get();
      print('✓ Read test passed: ${doc.exists}');
      
      // Test registration collection
      final registers = await _firestore.collection('registers').limit(1).get();
      print('✓ Registers collection accessible: ${registers.docs.length}');
      
    } catch (e) {
      print('✗ Firestore connection error: $e');
      rethrow;
    }
  }

  // debug method:
  Future<void> debugUserRegistrations(String userId, String email) async {
    try {
      print('=== DEBUG USER REGISTRATIONS ===');
      print('User ID: $userId');
      print('User Email: $email');
      
      // Check by userId
      final userIdQuery = await _firestore
          .collection('registers')
          .where('userId', isEqualTo: userId)
          .get();
      
      print('Query by userId found: ${userIdQuery.docs.length}');
      for (var doc in userIdQuery.docs) {
        print('  - ${doc.id}: ${doc.data()}');
      }
      
      // Check by email
      final emailQuery = await _firestore
          .collection('registers')
          .where('email', isEqualTo: email)
          .get();
      
      print('Query by email found: ${emailQuery.docs.length}');
      for (var doc in emailQuery.docs) {
        print('  - ${doc.id}: ${doc.data()}');
      }
      
      print('=== DEBUG COMPLETE ===');
    } catch (e) {
      print('Debug error: $e');
    }
  }
}