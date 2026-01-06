import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/club.dart';
import '../../services/firestore_service.dart';

class AdminVerificationScreen extends StatelessWidget {
  final FirestoreService firestoreService = FirestoreService();

  AdminVerificationScreen({super.key});

  Future<void> _launchDocument(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No document URL found')),
      );
      return;
    }

    final Uri uri = Uri.parse(url);
    try {
      // FORCE OPEN IN BROWSER (Fixes the "No Google Account" crash)
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication, // Tries browser/PDF viewer
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      // Fallback: Try In-App WebView if external fails
      try {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } catch (e2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $e')),
        );
      }
    }
  }

  Future<void> _processVerification(BuildContext context, Club club, bool isApproved) async {
    try {
      await FirebaseFirestore.instance.collection('clubs').doc(club.id).update({
        'verificationStatus': isApproved ? 'verified' : 'rejected',
        'status': isApproved ? 'approved' : 'rejected',
        'isApproved': isApproved, // Helper flag if you use it
        'processedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApproved ? 'Club Approved' : 'Club Rejected'),
          backgroundColor: isApproved ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pending Verifications')),
      body: StreamBuilder<QuerySnapshot>(
        // Query clubs that have submitted verification
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .where('verificationStatus', isEqualTo: 'submitted')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('All caught up! No pending requests.'),
                ],
              ),
            );
          }

          final clubs = snapshot.data!.docs.map((doc) {
            return Club.fromFirestore(doc.data() as Map<String, dynamic>);
          }).toList();

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              return Card(
                elevation: 3,
                margin: EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: club.imageUrl.isNotEmpty
                                ? NetworkImage(club.imageUrl)
                                : null,
                            child: club.imageUrl.isEmpty ? Text(club.name[0]) : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  club.name,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Submitted: ${_formatDate(club.submittedAt)}',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(club.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 16),
                      
                      // View Document Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.description, color: Colors.blue),
                          label: Text('View Verification Document'),
                          onPressed: () => _launchDocument(context, club.approvalLetterUrl),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: BorderSide(color: Colors.blue),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _processVerification(context, club, false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[50],
                                foregroundColor: Colors.red,
                              ),
                              child: Text('Reject'),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _processVerification(context, club, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return '${date.day}/${date.month}/${date.year}';
  }
}