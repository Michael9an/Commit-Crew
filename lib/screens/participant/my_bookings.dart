import 'package:flutter/material.dart';

class MyBookingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text('My Bookings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          _buildBookingCard('Music Festival', 'Confirmed', '25 Dec 2024'),
          _buildBookingCard('Tech Conference', 'Pending', '15 Jan 2024'),
        ],
      ),
    );
  }

  Widget _buildBookingCard(String eventName, String status, String date) {
    return Card(
      child: ListTile(
        title: Text(eventName),
        subtitle: Text('Date: $date'),
        trailing: Chip(
          label: Text(status),
          backgroundColor: status == 'Confirmed' ? Colors.green : Colors.orange,
        ),
      ),
    );
  }
}