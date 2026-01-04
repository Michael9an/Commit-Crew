import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/event.dart';
import '../../models/club.dart';

class SystemAnalyticsScreen extends StatefulWidget {
  const SystemAnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<SystemAnalyticsScreen> createState() => _SystemAnalyticsScreenState();
}

class _SystemAnalyticsScreenState extends State<SystemAnalyticsScreen> {
  DateTimeRange? _selectedDateRange;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  
                  TextButton(
                    onPressed: () => _selectDateRange(context),
                    child: Text(
                      _formatDateRange(_selectedDateRange),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _buildOverviewView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewView() {
    return StreamBuilder<List<EventModel>>(
      stream: _firestoreService.getEvents(),
      builder: (context, eventSnapshot) {
        return StreamBuilder<List<Club>>(
          stream: _firestoreService.getClubs(),
          builder: (context, clubSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('reports').snapshots(),
              builder: (context, reportSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').snapshots(),
                  builder: (context, userSnapshot) {
                    if (eventSnapshot.connectionState == ConnectionState.waiting || 
                        clubSnapshot.connectionState == ConnectionState.waiting ||
                        reportSnapshot.connectionState == ConnectionState.waiting ||
                        userSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (eventSnapshot.hasError) {
                      return Center(child: Text('Error: ${eventSnapshot.error}'));
                    }

                    final allEvents = eventSnapshot.data ?? [];
                    final allClubs = clubSnapshot.data ?? [];
                    final allReports = reportSnapshot.data?.docs ?? [];
                    final allUsers = userSnapshot.data?.docs ?? [];
                    
                    // Current Date Data
                    final currentEvents = _filterEventsByDateRange(allEvents, _selectedDateRange);
                    final currentReports = _filterReportsByDateRange(allReports, _selectedDateRange);
                    final currentStats = _calculateStats(currentEvents, allClubs, currentReports);
                    
                    final topParticipants = _getTopParticipants(currentEvents, allUsers);
                    final topClubs = _getTopClubs(currentEvents, allClubs);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero Card - Active Participants
                          _buildHeroStatCard(
                            'Active Participants',
                            (currentStats['activeParticipants'] ?? 0).toString(),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Grid for other stats
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.8,
                            children: [
                              _buildStatCard(
                                'Total Registrations',
                                (currentStats['totalRegistrations'] ?? 0).toString(),
                                Icons.app_registration,
                                Colors.blue,
                              ),
                              _buildStatCard(
                                'Events Created',
                                (currentStats['eventCount'] ?? 0).toString(),
                                Icons.event,
                                Colors.orange,
                              ),
                              _buildStatCard(
                                'Active Clubs',
                                (currentStats['activeClubs'] ?? 0).toString(),
                                Icons.business_center,
                                Colors.purple,
                              ),
                              _buildStatCard(
                                'Total Reports',
                                (currentStats['reportCount'] ?? 0).toString(),
                                Icons.report,
                                Colors.red,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          _buildTopList('Most Registrations Participant', topParticipants, Colors.blue),
                          const SizedBox(height: 16),
                          _buildTopList('Most Registrations Club', topClubs, Colors.purple),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeroStatCard(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101213),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopList(String title, List<Map<String, dynamic>> data, Color color) {
    if (data.isEmpty && title.contains('Top 5')) {
      // Still show empty podium if no data
    } else if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final top3 = List<Map<String, dynamic>?>.filled(3, null);
    for (int i = 0; i < data.length && i < 3; i++) {
      top3[i] = data[i];
    }
    final rest = data.length > 3 ? data.skip(3).toList() : [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          
          // Podium
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // 2nd Place (Left)
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: _buildPodiumItem(top3[1], 2, color),
                ),
                
                // 3rd Place (Right)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildPodiumItem(top3[2], 3, color),
                ),

                // 1st Place (Center, Higher)
                Positioned(
                  top: 0,
                  left: 0, 
                  right: 0,
                  child: _buildPodiumItem(top3[0], 1, color),
                ),
              ],
            ),
          ),
            
          const SizedBox(height: 30),
          
          // Rest of the list
          if (rest.isNotEmpty)
            ...rest.asMap().entries.map((entry) {
              final index = entry.key + 4; // 4th, 5th, etc.
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      index.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: color.withOpacity(0.1),
                      backgroundImage: item['photoUrl'] != null && item['photoUrl'].isNotEmpty 
                          ? NetworkImage(item['photoUrl']) 
                          : null,
                      child: item['photoUrl'] == null || item['photoUrl'].isEmpty
                          ? Text(
                              (item['name'] as String).isNotEmpty ? item['name'][0].toUpperCase() : '?',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${item['count']}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic>? item, int rank, Color color) {
    final isFirst = rank == 1;
    final avatarSize = isFirst ? 40.0 : 30.0;
    final name = item?['name'] ?? 'N/A';
    final count = item?['count']?.toString() ?? '0';
    final photoUrl = item?['photoUrl'] as String?;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Icon(Icons.emoji_events, color: Colors.amber, size: 32),
          ),
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: item != null ? color : Colors.grey.shade300, width: 2),
              ),
              child: CircleAvatar(
                radius: avatarSize,
                backgroundColor: item != null ? color.withOpacity(0.1) : Colors.grey.shade100,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty 
                    ? NetworkImage(photoUrl) 
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? Text(
                        name != 'N/A' ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: item != null ? color : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: isFirst ? 24 : 18,
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              bottom: -10,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item != null ? color : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  rank.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 100,
          child: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: item != null ? Colors.black87 : Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          count,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Time'),
                onTap: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Last 7 Days'),
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: now.subtract(const Duration(days: 7)),
                      end: now,
                    );
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Last 30 Days'),
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: now.subtract(const Duration(days: 30)),
                      end: now,
                    );
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Last 90 Days'),
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: now.subtract(const Duration(days: 90)),
                      end: now,
                    );
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateRange(DateTimeRange? range) {
    if (range == null) return 'All Time';
    
    final now = DateTime.now();
    final diff = now.difference(range.start).inDays;
    
    if (diff >= 6 && diff <= 7) return 'Last 7 Days';
    if (diff >= 29 && diff <= 30) return 'Last 30 Days';
    if (diff >= 89 && diff <= 90) return 'Last 90 Days';

    if (range.start.year == range.end.year && 
        range.start.month == range.end.month && 
        range.start.day == range.end.day) {
      return DateFormat('MMM d, yyyy').format(range.start);
    }
    return '${DateFormat('MMM d').format(range.start)} - ${DateFormat('MMM d, yyyy').format(range.end)}';
  }

  List<EventModel> _filterEventsByDateRange(List<EventModel> events, DateTimeRange? range) {
    if (range == null) return events;
    return events.where((event) {
      if (event.createdAt == null) return false;
      final eventDate = DateTime(event.createdAt!.year, event.createdAt!.month, event.createdAt!.day);
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      return (eventDate.isAtSameMomentAs(start) || eventDate.isAfter(start)) && 
             (eventDate.isAtSameMomentAs(end) || eventDate.isBefore(end));
    }).toList();
  }

  List<QueryDocumentSnapshot> _filterReportsByDateRange(List<QueryDocumentSnapshot> reports, DateTimeRange? range) {
    if (range == null) return reports;
    return reports.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      DateTime? createdAt;
      if (data['createdAt'] is Timestamp) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
      }
      
      if (createdAt == null) return false;
      final reportDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(range.end.year, range.end.month, range.end.day);
      return (reportDate.isAtSameMomentAs(start) || reportDate.isAfter(start)) && 
             (reportDate.isAtSameMomentAs(end) || reportDate.isBefore(end));
    }).toList();
  }

  Map<String, int> _calculateStats(List<EventModel> events, List<Club> clubs, List<QueryDocumentSnapshot> reports) {
    int totalRegistrations = 0;
    Set<String> uniqueParticipants = {};
    Set<String> activeClubIds = {};

    for (var event in events) {
      totalRegistrations += event.attendees.length;
      uniqueParticipants.addAll(event.attendees);
      activeClubIds.add(event.clubId);
    }

    return {
      'eventCount': events.length,
      'totalRegistrations': totalRegistrations,
      'activeParticipants': uniqueParticipants.length,
      'activeClubs': activeClubIds.length,
      'reportCount': reports.length,
    };
  }

  List<Map<String, dynamic>> _getTopParticipants(List<EventModel> events, List<QueryDocumentSnapshot> users) {
    Map<String, int> userCounts = {};
    for (var event in events) {
      for (var userId in event.attendees) {
        userCounts[userId] = (userCounts[userId] ?? 0) + 1;
      }
    }
    
    var sortedKeys = userCounts.keys.toList()
      ..sort((k1, k2) => userCounts[k2]!.compareTo(userCounts[k1]!));
      
    return sortedKeys.take(5).map((uid) {
      String name = 'Unknown User';
      String photoUrl = '';
      try {
          final user = users.firstWhere((u) => u.id == uid);
          final data = user.data() as Map<String, dynamic>;
          name = data['name'] ?? data['email'] ?? 'Unknown';
          photoUrl = data['photoUrl'] ?? '';
      } catch (e) {}
      
      return {'name': name, 'count': userCounts[uid], 'photoUrl': photoUrl};
    }).toList();
  }

  List<Map<String, dynamic>> _getTopClubs(List<EventModel> events, List<Club> clubs) {
     Map<String, int> clubCounts = {};
     for (var event in events) {
       clubCounts[event.clubId] = (clubCounts[event.clubId] ?? 0) + event.attendees.length;
     }
     
     var sortedKeys = clubCounts.keys.toList()
      ..sort((k1, k2) => clubCounts[k2]!.compareTo(clubCounts[k1]!));

     return sortedKeys.take(5).map((cid) {
       String name = 'Unknown Club';
       String photoUrl = '';
       try {
         final club = clubs.firstWhere((c) => c.id == cid);
         name = club.name;
         photoUrl = club.imageUrl;
       } catch (e) {}
       return {'name': name, 'count': clubCounts[cid], 'photoUrl': photoUrl};
     }).toList();
  }
}