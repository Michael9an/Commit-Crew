import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data?.docs ?? [];
          
          // Calculate points (dummy logic for now, replace with actual points logic)
          // For now, we'll just use a random number or a field if it exists
          final userList = users.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'name': data['name'] ?? data['email'] ?? 'Unknown',
              'photoUrl': data['photoUrl'] ?? '',
              'points': data['points'] ?? 0, // Assuming 'points' field exists
            };
          }).toList();

          // Sort by points
          userList.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

          final top3 = userList.take(3).toList();
          final rest = userList.skip(3).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Podium
                if (top3.isNotEmpty)
                  SizedBox(
                    height: 250,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // 2nd Place
                        if (top3.length > 1)
                          Positioned(
                            left: 20,
                            bottom: 0,
                            child: _buildPodiumItem(top3[1], 2),
                          ),
                        
                        // 3rd Place
                        if (top3.length > 2)
                          Positioned(
                            right: 20,
                            bottom: 0,
                            child: _buildPodiumItem(top3[2], 3),
                          ),

                        // 1st Place
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: _buildPodiumItem(top3[0], 1),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),

                // List
                ...rest.asMap().entries.map((entry) {
                  final index = entry.key + 4;
                  final user = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          backgroundImage: user['photoUrl'] != '' 
                              ? NetworkImage(user['photoUrl'] as String) 
                              : null,
                          child: user['photoUrl'] == '' 
                              ? Text((user['name'] as String)[0].toUpperCase()) 
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            user['name'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          '${user['points']} pts',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
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
        },
      ),
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> user, int rank) {
    final isFirst = rank == 1;
    final color = const Color(0xFFB2FF59); // Lime green color
    final avatarSize = isFirst ? 50.0 : 35.0;
    final height = isFirst ? 160.0 : 120.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst)
          const Icon(Icons.emoji_events, color: Color(0xFFB2FF59), size: 40),
        
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
              ),
              child: CircleAvatar(
                radius: avatarSize,
                backgroundImage: user['photoUrl'] != '' 
                    ? NetworkImage(user['photoUrl'] as String) 
                    : null,
                child: user['photoUrl'] == '' 
                    ? Text((user['name'] as String)[0].toUpperCase(), style: TextStyle(fontSize: isFirst ? 24 : 16)) 
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
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  rank.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user['name'] as String,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '${user['points']} pts',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
