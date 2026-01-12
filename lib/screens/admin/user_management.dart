import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'analytics_detail_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _selectedFilter = 'Participant';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_isSearching)
                  const Text('User Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
                else
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => setState(() {}),
                        ),
                      ),
                      onSubmitted: (value) => setState(() {}),
                    ),
                  ),
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      if (_isSearching) {
                        _searchController.clear();
                      }
                      _isSearching = !_isSearching;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total Counts Summary
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                
                final allUsers = snapshot.data!.docs;
                final participantCount = allUsers.where((doc) => (doc.data() as Map<String, dynamic>)['role'] == 'participant').length;
                final clubCount = allUsers.where((doc) => (doc.data() as Map<String, dynamic>)['role'] == 'club').length;
                final adminCount = allUsers.where((doc) => (doc.data() as Map<String, dynamic>)['role'] == 'admin').length;

                return Container(
                  padding: const EdgeInsets.all(4),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(child: _buildCountItem('Participants', participantCount, 'Participant')),
                      Expanded(child: _buildCountItem('Clubs', clubCount, 'Club')),
                      Expanded(child: _buildCountItem('Admins', adminCount, 'Admin')),
                    ],
                  ),
                );
              },
            ),
            
            // User list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: _selectedFilter.toLowerCase())
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final users = snapshot.data?.docs ?? [];

                  final filteredUsers = users.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    final search = _searchController.text.toLowerCase();
                    return name.contains(search) || email.contains(search);
                  }).toList();

                  if (filteredUsers.isEmpty) {
                    return Center(child: Text('No ${_selectedFilter.toLowerCase()} users found'));
                  }

                  return ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final userData = filteredUsers[index].data() as Map<String, dynamic>;
                      final userId = filteredUsers[index].id;
                      final name = userData['name'] ?? 'Unknown';
                      final email = userData['email'] ?? 'No Email';
                      final role = userData['role'] ?? 'participant';
                      final photoUrl = userData['photoUrl']?.toString();
                      final clubIds = List<String>.from(userData['clubIds'] ?? []);
                      final createdAt = userData['createdAt'] != null 
                          ? (userData['createdAt'] as Timestamp).toDate() 
                          : null;

                      return _buildUserCard(userId, name, role, email, createdAt, clubIds, photoUrl);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(String userId, String name, String role, String email, DateTime? registeredAt, List<String> clubIds, String? photoUrl) {
    bool showRegistrationDate = role == 'participant' || role == 'club';
    
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl == null || photoUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Row(
          children: [
            Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
            if (role == 'club' && clubIds.isNotEmpty)
              _buildClubStatus(clubIds.first),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email),
            if (showRegistrationDate && registeredAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Registered: ${_formatDateTime(registeredAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        isThreeLine: showRegistrationDate && registeredAt != null,
        trailing: (role == 'participant' || role == 'club') 
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [Icon(Icons.chevron_right)],
              )
            : null,
        onTap: (role == 'participant' || role == 'club') 
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnalyticsDetailScreen(
                      id: userId,
                      name: name,
                      email: email,
                      role: role,
                      imageUrl: photoUrl,
                      clubId: role == 'club' && clubIds.isNotEmpty ? clubIds.first : null,
                    ),
                  ),
                );
              }
            : null,
      ),
    );
  }

  Widget _buildCountItem(String label, int count, String filterValue) {
    final isSelected = _selectedFilter == filterValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterValue),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              )
            : null,
        child: Text(
          '$label ($count)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildClubStatus(String clubId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('clubs').doc(clubId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();
        
        final vStatus = data['verificationStatus'] as String?;
        
        String label = 'Not Verified';
        Color color = Colors.grey;
        
        if (vStatus == 'verified') {
          label = 'Verified';
          color = Colors.green;
        } else if (vStatus == 'submitted') {
          label = 'Pending';
          color = Colors.orange;
        } else if (vStatus == 'rejected') {
          label = 'Rejected';
          color = Colors.red;
        }
        
        return Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
  
  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}