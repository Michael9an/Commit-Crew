import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../../services/review_service.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ReviewService reviewService = ReviewService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: "Mark all as read",
            onPressed: () => reviewService.markAllNotificationsAsRead(),
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: reviewService.getNotifications(),
        builder: (context, snapshot) {
          // 1. Show Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Show Error (CRITICAL FIX: This catches the missing index error)
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Error loading notifications:\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          // 3. Empty State
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("No notifications yet", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // 4. List State
          bool allRead = notifications.every((n) => n['isRead'] == true);

          return Column(
            children: [
               if (allRead)
                 Container(
                   width: double.infinity,
                   color: Colors.grey[100],
                   padding: const EdgeInsets.all(8),
                   child: Text(
                     "Every notification has been read",
                     textAlign: TextAlign.center,
                     style: TextStyle(color: Colors.grey[600], fontSize: 12),
                   ),
                 ),
               
               Expanded(
                 child: ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final bool isRead = notification['isRead'] ?? false;
                    final String title = notification['title'] ?? 'Notification';
                    final String body = notification['body'] ?? '';
                    final Timestamp? timestamp = notification['createdAt'];
                    
                    String timeText = '';
                    if (timestamp != null) {
                      final dt = timestamp.toDate();
                      timeText = "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
                    }

                    // Determine Icon
                    IconData iconData;
                    Color iconColor;
                    Color bgColor;

                    if (notification['type'] == 'like_review') {
                      iconData = Icons.favorite;
                      iconColor = Colors.red;
                      bgColor = Colors.red[100]!;
                    } else if (notification['type'] == 'reply_review') {
                      iconData = Icons.comment; 
                      iconColor = Colors.blue;
                      bgColor = Colors.blue[100]!;
                    } else {
                      iconData = Icons.notifications;
                      iconColor = Colors.grey;
                      bgColor = Colors.grey[300]!;
                    }

                    if (isRead) {
                      iconColor = Colors.grey;
                      bgColor = Colors.grey[200]!;
                    }

                    return Container(
                      color: isRead ? Colors.white : Colors.blue[50],
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: bgColor,
                          child: Icon(iconData, color: iconColor, size: 20),
                        ),
                        title: Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(timeText, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        onTap: () {
                          if (!isRead) {
                            reviewService.markNotificationAsRead(notification['id']);
                          }
                        },
                      ),
                    );
                  },
                ),
               ),
            ],
          );
        },
      ),
    );
  }
}