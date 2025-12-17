import '../models/event.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all events
  Future<List<EventModel>> getEvents() async {
    try {
      final querySnapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'published')
          .where('isCancelled', isEqualTo: false)
          .orderBy('date', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => EventModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting events: $e');
      return _getMockEvents(); // Fallback to mock data
    }
  }

  // Get event by ID
  Future<EventModel?> getEventById(String eventId) async {
    try {
      final doc = await _firestore.collection('events').doc(eventId).get();
      if (doc.exists) {
        return EventModel.fromFirestore(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting event by ID: $e');
      return null;
    }
  }

  // Get events by club
  Future<List<EventModel>> getClubEvents(String clubId) async {
    try {
      final querySnapshot = await _firestore
          .collection('events')
          .where('clubId', isEqualTo: clubId)
          .where('isCancelled', isEqualTo: false)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => EventModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting club events: $e');
      return _getMockEvents().where((event) => event.clubId == clubId).toList();
    }
  }

  // Get upcoming events
  Future<List<EventModel>> getUpcomingEvents() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      
      final querySnapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'published')
          .where('isCancelled', isEqualTo: false)
          .where('date', isGreaterThanOrEqualTo: now)
          .orderBy('date', descending: false)
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => EventModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting upcoming events: $e');
      return _getMockEvents().where((event) {
        final eventDate = DateTime.fromMillisecondsSinceEpoch(int.parse(event.date));
        return eventDate.isAfter(DateTime.now());
      }).toList();
    }
  }

  // Get popular events (by views)
  Future<List<EventModel>> getPopularEvents() async {
    try {
      final querySnapshot = await _firestore
          .collection('events')
          .where('status', isEqualTo: 'published')
          .where('isCancelled', isEqualTo: false)
          .orderBy('views', descending: true)
          .limit(10)
          .get();

      return querySnapshot.docs
          .map((doc) => EventModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting popular events: $e');
      return _getMockEvents();
    }
  }

  // Create new event
  Future<EventModel> createEvent(EventModel event) async {
    try {
      final eventData = event.toFirestore();
      await _firestore.collection('events').doc(event.id).set(eventData);
      return event;
    } catch (e) {
      print('Error creating event: $e');
      throw Exception('Failed to create event: $e');
    }
  }

  // Update event
  Future<void> updateEvent(EventModel event) async {
    try {
      final eventData = event.toFirestore();
      await _firestore.collection('events').doc(event.id).update(eventData);
    } catch (e) {
      print('Error updating event: $e');
      throw Exception('Failed to update event: $e');
    }
  }

  // Delete event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      print('Error deleting event: $e');
      throw Exception('Failed to delete event: $e');
    }
  }

  // Cancel event
  Future<void> cancelEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'isCancelled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error cancelling event: $e');
      throw Exception('Failed to cancel event: $e');
    }
  }

  // Add attendee to event
  Future<void> addAttendee(String eventId, String userId) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'attendees': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding attendee: $e');
      throw Exception('Failed to add attendee: $e');
    }
  }

  // Remove attendee from event
  Future<void> removeAttendee(String eventId, String userId) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'attendees': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error removing attendee: $e');
      throw Exception('Failed to remove attendee: $e');
    }
  }

  // Add to waitlist
  Future<void> addToWaitlist(String eventId, String userId) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'waitlist': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding to waitlist: $e');
      throw Exception('Failed to add to waitlist: $e');
    }
  }

  // Increment event views
  Future<void> incrementViews(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing views: $e');
    }
  }

  // Increment event shares
  Future<void> incrementShares(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        'shares': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing shares: $e');
    }
  }

  // Search events
  Future<List<EventModel>> searchEvents(String query) async {
    try {
      if (query.isEmpty) {
        return getEvents();
      }

      final nameQuery = await _firestore
          .collection('events')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .where('status', isEqualTo: 'published')
          .where('isCancelled', isEqualTo: false)
          .get();

      final locationQuery = await _firestore
          .collection('events')
          .where('location', isGreaterThanOrEqualTo: query)
          .where('location', isLessThanOrEqualTo: query + '\uf8ff')
          .where('status', isEqualTo: 'published')
          .where('isCancelled', isEqualTo: false)
          .get();

      final events = <EventModel>{};
      
      events.addAll(nameQuery.docs.map((doc) => EventModel.fromFirestore(doc.data())));
      events.addAll(locationQuery.docs.map((doc) => EventModel.fromFirestore(doc.data())));

      return events.toList();
    } catch (e) {
      print('Error searching events: $e');
      return _getMockEvents().where((event) => 
        event.name.toLowerCase().contains(query.toLowerCase()) ||
        event.location.toLowerCase().contains(query.toLowerCase()) ||
        event.description.toLowerCase().contains(query.toLowerCase())
      ).toList();
    }
  }

  // Get events by category
  Future<List<EventModel>> getEventsByCategory(String category) async {
    try {
      final querySnapshot = await _firestore
          .collection('events')
          .where('category', isEqualTo: category)
          .where('status', isEqualTo: 'published')
          .where('isCancelled', isEqualTo: false)
          .orderBy('date', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => EventModel.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting events by category: $e');
      return _getMockEvents().where((event) => event.category == category).toList();
    }
  }

  // Get events user is attending
  Future<List<EventModel>> getUserEvents(String userId) async {
    try {
      // This would require a more complex query in a real app
      // For now, we'll filter client-side
      final allEvents = await getEvents();
      return allEvents.where((event) => event.attendees.contains(userId)).toList();
    } catch (e) {
      print('Error getting user events: $e');
      return _getMockEvents().where((event) => event.attendees.contains(userId)).toList();
    }
  }

  // Mock data fallback
  List<EventModel> _getMockEvents() {
    return [
      EventModel(
        id: '1',
        name: 'Music Festival 2024',
        description: 'Annual music festival featuring local bands and artists',
        date: DateTime.now().add(Duration(days: 7)).millisecondsSinceEpoch.toString(),
        startTime: '14:00',
        endTime: '22:00',
        bannerUrl: '',
        location: 'Central Park, New York',
        clubId: '1',
        clubName: 'Music Club',
        clubImageUrl: '',
        maxAttendees: 500,
        price: 25.00,
        isFree: false,
        refundPolicy: 'Refunds available up to 48 hours before the event',
        publishTime: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        status: 'published',
        attendees: ['1', '2', '3'],
        waitlist: [],
        views: 150,
        shares: 25,
        isCancelled: false,
        updatedAt: DateTime.now(),
        category: 'Music',
        tags: ['festival', 'live music', 'outdoor'],
        contactEmail: 'music@club.com',
        contactPhone: '+1234567890',
      ),
      EventModel(
        id: '2',
        name: 'Tech Innovation Summit',
        description: 'Explore the latest in technology and innovation',
        date: DateTime.now().add(Duration(days: 3)).millisecondsSinceEpoch.toString(),
        startTime: '09:00',
        endTime: '17:00',
        bannerUrl: '',
        location: 'Tech Hub, San Francisco',
        clubId: '2',
        clubName: 'Tech Club',
        clubImageUrl: '',
        maxAttendees: 200,
        price: 0.00,
        isFree: true,
        refundPolicy: 'No refunds needed for free event',
        publishTime: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        status: 'published',
        attendees: ['1', '4', '5'],
        waitlist: [],
        views: 89,
        shares: 12,
        isCancelled: false,
        updatedAt: DateTime.now(),
        category: 'Technology',
        tags: ['tech', 'innovation', 'summit'],
        contactEmail: 'tech@club.com',
        contactPhone: '+1234567891',
      ),
      EventModel(
        id: '3',
        name: 'Basketball Tournament',
        description: 'Inter-club basketball championship',
        date: DateTime.now().add(Duration(days: 14)).millisecondsSinceEpoch.toString(),
        startTime: '10:00',
        endTime: '18:00',
        bannerUrl: '',
        location: 'Sports Complex',
        clubId: '3',
        clubName: 'Sports Club',
        clubImageUrl: '',
        maxAttendees: 100,
        price: 10.00,
        isFree: false,
        refundPolicy: 'No refunds after registration',
        publishTime: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        status: 'published',
        attendees: ['2', '3'],
        waitlist: ['6', '7'],
        views: 67,
        shares: 8,
        isCancelled: false,
        updatedAt: DateTime.now(),
        category: 'Sports',
        tags: ['basketball', 'tournament', 'sports'],
        contactEmail: 'sports@club.com',
      ),
    ];
  }
}