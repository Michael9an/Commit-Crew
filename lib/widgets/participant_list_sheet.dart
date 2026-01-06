
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../services/participant_export_service.dart';

class ParticipantListSheet extends StatelessWidget {
  final EventModel event;

  const ParticipantListSheet({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Take up 75% of screen
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Participants", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(event.name, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),
                ),
                // Export Button in Header
                IconButton(
                  icon: const Icon(Icons.file_download),
                  tooltip: 'Export List',
                  onPressed: () => ParticipantExportService.showExportOptions(context, event),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('registers')
                  .where('eventId', isEqualTo: event.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text("No participants yet"),
                      ],
                    ),
                  );
                }

                final participants = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final data = participants[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Text(
                          (data['fullName'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(data['fullName'] ?? 'Unknown'),
                      subtitle: Text(data['email'] ?? ''),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[100]!),
                        ),
                        child: Text(
                          data['status'] ?? 'Registered',
                          style: TextStyle(fontSize: 10, color: Colors.green[700]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
