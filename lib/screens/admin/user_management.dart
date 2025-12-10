import 'package:flutter/material.dart';

class UserManagementScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text('User Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          _buildUserCard('John Doe', 'participant', 'john@example.com'),
          _buildUserCard('Music Club', 'club', 'music@club.com'),
          _buildUserCard('Tech Society', 'club', 'tech@society.com'),
        ],
      ),
    );
  }

  Widget _buildUserCard(String name, String role, String email) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text(name),
        subtitle: Text(email),
        trailing: DropdownButton<String>(
          value: role,
          items: ['participant', 'club', 'admin']
              .map((String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ))
              .toList(),
          onChanged: (newRole) {
            // Update user role
          },
        ),
      ),
    );
  }
}