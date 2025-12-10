import '../models/club.dart';
import '../models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all clubs
  Future<List<Club>> getClubs() async {
    try {
      final querySnapshot = await _firestore
          .collection('clubs')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Club.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting clubs: $e');
      return _getMockClubs(); // Fallback to mock data
    }
  }

  // Get club by ID
  Future<Club?> getClubById(String clubId) async {
    try {
      final doc = await _firestore.collection('clubs').doc(clubId).get();
      if (doc.exists) {
        return Club.fromFirestore(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting club by ID: $e');
      return null;
    }
  }

  // Get clubs by user (clubs where user is member or admin)
  Future<List<Club>> getUserClubs(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('clubs')
          .where('isActive', isEqualTo: true)
          .where('memberIds', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Club.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting user clubs: $e');
      return _getMockClubs().where((club) => club.memberIds.contains(userId)).toList();
    }
  }

  // Get clubs managed by user (creator or admin)
  Future<List<Club>> getManagedClubs(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('clubs')
          .where('isActive', isEqualTo: true)
          .where('adminIds', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Club.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting managed clubs: $e');
      return _getMockClubs().where((club) => club.adminIds.contains(userId)).toList();
    }
  }

  // Create new club
  Future<Club> createClub(Club club) async {
    try {
      final clubData = club.toFirestore();
      await _firestore.collection('clubs').doc(club.id).set(clubData);
      return club;
    } catch (e) {
      print('Error creating club: $e');
      throw Exception('Failed to create club: $e');
    }
  }

  // Update club
  Future<void> updateClub(Club club) async {
    try {
      final clubData = club.toFirestore();
      await _firestore.collection('clubs').doc(club.id).update(clubData);
    } catch (e) {
      print('Error updating club: $e');
      throw Exception('Failed to update club: $e');
    }
  }

  // Add member to club
  Future<void> addMember(String clubId, String userId) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding member: $e');
      throw Exception('Failed to add member: $e');
    }
  }

  // Remove member from club
  Future<void> removeMember(String clubId, String userId) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'adminIds': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error removing member: $e');
      throw Exception('Failed to remove member: $e');
    }
  }

  // Add admin to club
  Future<void> addAdmin(String clubId, String userId) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'adminIds': FieldValue.arrayUnion([userId]),
        'memberIds': FieldValue.arrayUnion([userId]), // Ensure they're also a member
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding admin: $e');
      throw Exception('Failed to add admin: $e');
    }
  }

  // Remove admin from club
  Future<void> removeAdmin(String clubId, String userId) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'adminIds': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error removing admin: $e');
      throw Exception('Failed to remove admin: $e');
    }
  }

  // Search clubs by name or category
  Future<List<Club>> searchClubs(String query) async {
    try {
      if (query.isEmpty) {
        return getClubs();
      }

      final nameQuery = await _firestore
          .collection('clubs')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .where('isActive', isEqualTo: true)
          .get();

      final categoryQuery = await _firestore
          .collection('clubs')
          .where('categories', arrayContains: query.toLowerCase())
          .where('isActive', isEqualTo: true)
          .get();

      final clubs = <Club>{};
      
      clubs.addAll(nameQuery.docs.map((doc) => Club.fromFirestore(doc.data())));
      clubs.addAll(categoryQuery.docs.map((doc) => Club.fromFirestore(doc.data())));

      return clubs.toList();
    } catch (e) {
      print('Error searching clubs: $e');
      return _getMockClubs().where((club) => 
        club.name.toLowerCase().contains(query.toLowerCase()) ||
        club.categories.any((category) => category.toLowerCase().contains(query.toLowerCase()))
      ).toList();
    }
  }

  // Get clubs by status
  Future<List<Club>> getClubsByStatus(String status) async {
    try {
      final querySnapshot = await _firestore
          .collection('clubs')
          .where('status', isEqualTo: status)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Club.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting clubs by status: $e');
      return _getMockClubs().where((club) => club.status == status).toList();
    }
  }

  // Update club status
  Future<void> updateClubStatus(String clubId, String status) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating club status: $e');
      throw Exception('Failed to update club status: $e');
    }
  }

  // Delete club (soft delete)
  Future<void> deleteClub(String clubId) async {
    try {
      await _firestore.collection('clubs').doc(clubId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error deleting club: $e');
      throw Exception('Failed to delete club: $e');
    }
  }

  // Mock data fallback
  List<Club> _getMockClubs() {
    const mockUserId = '1';
    
    return [
      Club(
        id: '1',
        name: 'Music Club',
        description: 'For music enthusiasts',
        createdBy: mockUserId,
        imageUrl: '',
        memberIds: [mockUserId],
        adminIds: [mockUserId],
        eventIds: ['1', '2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        status: 'approved',
        contactEmail: 'music@club.com',
        contactPhone: '+1234567890',
        location: 'Music Building',
        categories: ['Music', 'Arts'],
      ),
      Club(
        id: '2',
        name: 'Tech Club',
        description: 'Technology and innovation',
        createdBy: mockUserId,
        imageUrl: '',
        memberIds: [mockUserId],
        adminIds: [mockUserId],
        eventIds: ['3'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        status: 'approved',
        contactEmail: 'tech@club.com',
        contactPhone: '+1234567891',
        location: 'Tech Center',
        categories: ['Technology', 'Programming'],
      ),
      Club(
        id: '3',
        name: 'Sports Club',
        description: 'All about sports and fitness',
        createdBy: '2',
        imageUrl: '',
        memberIds: ['2'],
        adminIds: ['2'],
        eventIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        status: 'pending',
        contactEmail: 'sports@club.com',
        categories: ['Sports', 'Fitness'],
      ),
    ];
  }
}