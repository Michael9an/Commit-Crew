import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club.dart';
import '../../models/user.dart';
import '../../services/firestore_service.dart';
import '../../providers/app_provider.dart';

class ClubMembersScreen extends StatefulWidget {
  final Club? club;

  const ClubMembersScreen({super.key, this.club});

  @override
  _ClubMembersScreenState createState() => _ClubMembersScreenState();
}

class _ClubMembersScreenState extends State<ClubMembersScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MemberView _currentView = MemberView.members;

  late Stream<List<UserModel>> _membersStream;
  late Stream<List<UserModel>> _adminsStream;
  late Stream<List<UserModel>> _pendingRequestsStream;

  @override
  void initState() {
    super.initState();
    if (widget.club != null) {
      _membersStream = _firestoreService.getClubMembers(widget.club!.id);
      _adminsStream = _firestoreService.getClubAdmins(widget.club!.id);
      _pendingRequestsStream = _firestoreService.getPendingJoinRequests(widget.club!.id);
    } else {
      // No club provided: use empty streams so the UI can render safely
      _membersStream = Stream.value([]);
      _adminsStream = Stream.value([]);
      _pendingRequestsStream = Stream.value([]);
    }
  }

  void _showMemberOptions(UserModel user, BuildContext context) {
    final isAdmin = widget.club?.adminIds.contains(user.id) ?? false;
    final isCurrentUser = user.id == Provider.of<AppProvider>(context, listen: false).currentUser?.id;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoUrl.isNotEmpty 
                      ? NetworkImage(user.photoUrl) 
                      : null,
                  child: user.photoUrl.isEmpty ? Icon(Icons.person) : null,
                ),
                title: Text(user.name),
                subtitle: Text(user.email),
              ),
              Divider(),
              if (!isAdmin && (widget.club?.canManage(Provider.of<AppProvider>(context, listen: false).currentUser?.id ?? '') ?? false))
                ListTile(
                  leading: Icon(Icons.admin_panel_settings, color: Colors.blue),
                  title: Text('Make Admin'),
                  onTap: () {
                    Navigator.pop(context);
                    _makeAdmin(user);
                  },
                ),
              if (isAdmin && (widget.club?.canManage(Provider.of<AppProvider>(context, listen: false).currentUser?.id ?? '') ?? false) && !isCurrentUser)
                ListTile(
                  leading: Icon(Icons.admin_panel_settings_outlined, color: Colors.orange),
                  title: Text('Remove Admin'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeAdmin(user);
                  },
                ),
              if (!isCurrentUser && (widget.club?.canManage(Provider.of<AppProvider>(context, listen: false).currentUser?.id ?? '') ?? false))
                ListTile(
                  leading: Icon(Icons.person_remove, color: Colors.red),
                  title: Text('Remove from Club'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeMember(user);
                  },
                ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _makeAdmin(UserModel user) async {
    try {
  await _firestoreService.addClubAdmin(widget.club!.id, user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} is now an admin'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to make admin: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeAdmin(UserModel user) async {
    try {
  await _firestoreService.removeClubAdmin(widget.club!.id, user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} is no longer an admin'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove admin: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeMember(UserModel user) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Member'),
  content: Text('Are you sure you want to remove ${user.name} from ${widget.club?.name ?? 'the club'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
  await _firestoreService.removeClubMember(widget.club!.id, user.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} removed from club'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleJoinRequest(UserModel user, bool approved) async {
    try {
      if (approved) {
  await _firestoreService.approveJoinRequest(widget.club!.id, user.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Join request approved for ${user.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
  await _firestoreService.rejectJoinRequest(widget.club!.id, user.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Join request rejected for ${user.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMemberList(Stream<List<UserModel>> stream, {bool showOptions = true}) {
    return StreamBuilder<List<UserModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading members'));
        }

        final members = snapshot.data ?? [];
        final filteredMembers = _searchQuery.isEmpty
            ? members
            : members.where((user) =>
                user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                user.email.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

        if (filteredMembers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty ? 'No members found' : 'No matching members',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredMembers.length,
          itemBuilder: (context, index) {
            final user = filteredMembers[index];
            final isAdmin = widget.club?.adminIds.contains(user.id) ?? false;
            
            return Card(
              margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoUrl.isNotEmpty 
                      ? NetworkImage(user.photoUrl) 
                      : null,
                  child: user.photoUrl.isEmpty ? Icon(Icons.person) : null,
                ),
                title: Text(user.name),
                subtitle: Text(user.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAdmin)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (showOptions && (widget.club?.canManage(Provider.of<AppProvider>(context, listen: false).currentUser?.id ?? '') ?? false))
                      IconButton(
                        icon: Icon(Icons.more_vert),
                        onPressed: () => _showMemberOptions(user, context),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingRequests() {
    return StreamBuilder<List<UserModel>>(
      stream: _pendingRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_disabled, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending join requests',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final user = requests[index];
            return Card(
              margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoUrl.isNotEmpty 
                      ? NetworkImage(user.photoUrl) 
                      : null,
                  child: user.photoUrl.isEmpty ? Icon(Icons.person) : null,
                ),
                title: Text(user.name),
                subtitle: Text(user.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      onPressed: () => _handleJoinRequest(user, true),
                      tooltip: 'Approve',
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: () => _handleJoinRequest(user, false),
                      tooltip: 'Reject',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AppProvider>(context).currentUser?.id;
    final canManage = widget.club?.canManage(currentUserId ?? '') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.club?.name ?? 'Club'} Members'),
        actions: [
          if (canManage && _currentView == MemberView.members)
            IconButton(
              icon: Icon(Icons.person_add),
              onPressed: () {
                // Implement invite functionality
                _showInviteDialog();
              },
              tooltip: 'Invite Members',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // View Tabs
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildViewTab('Members', MemberView.members),
                SizedBox(width: 8),
                _buildViewTab('Admins', MemberView.admins),
                if (canManage) ...[
                  SizedBox(width: 8),
                  _buildViewTab('Requests', MemberView.requests),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),

          // Member Count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StreamBuilder<List<UserModel>>(
                  stream: _membersStream,
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    return Text(
                      'Total Members: $count',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    );
                  },
                ),
                if (_currentView == MemberView.requests)
                  StreamBuilder<List<UserModel>>(
                    stream: _pendingRequestsStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      if (count > 0) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count pending',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return SizedBox();
                    },
                  ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Members List
          Expanded(
            child: _buildCurrentView(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab(String title, MemberView view) {
    final isSelected = _currentView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentView = view;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case MemberView.members:
        return _buildMemberList(_membersStream);
      case MemberView.admins:
        return _buildMemberList(_adminsStream, showOptions: false);
      case MemberView.requests:
        return _buildPendingRequests();
    }
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invite Members'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this club code with others to join:'),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
                child: SelectableText(
                widget.club?.id ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Monospace',
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Or share this link:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            SelectableText(
              'https://yourapp.com/join-club/${widget.club?.id ?? ''}',
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

enum MemberView {
  members,
  admins,
  requests,
}