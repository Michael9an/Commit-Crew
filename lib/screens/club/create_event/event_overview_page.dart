import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/event.dart';

class EventOverviewPage extends StatelessWidget {
  final EventModel eventData;
  final VoidCallback? onSubmit;
  final VoidCallback onBack;
  final bool isSubmitting;

  const EventOverviewPage({
    super.key,
    required this.eventData,
    required this.onSubmit,
    required this.onBack,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Preview Banner
        Container(
          width: double.infinity,
          color: Colors.orange[100],
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.visibility, size: 16, color: Colors.orange[900]),
              SizedBox(width: 8),
              Text(
                "Preview Mode: This is how your event will appear",
                style: TextStyle(fontSize: 12, color: Colors.orange[900], fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Content Area (Scrollable)
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Event Image
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildEventImage(eventData.bannerUrl),
                ),

                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Title & Club Name
                      Text(
                        eventData.name.isEmpty ? "Event Name" : eventData.name,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'by ${eventData.clubName}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      
                      SizedBox(height: 16),

                      // 3. Price Tag
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: eventData.isFree ? Colors.green[50] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: eventData.isFree ? Colors.green : Colors.blue),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Price',
                              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[600]),
                            ),
                            Text(
                              eventData.isFree ? 'FREE' : '\$${eventData.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: eventData.isFree ? Colors.green : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 16),

                      // 4. Date & Time
                      _buildDetailRow(Icons.calendar_today, _formatDate(eventData.date)),
                      SizedBox(height: 8),
                      _buildDetailRow(Icons.access_time, "${eventData.startTime} - ${eventData.endTime}"),
                      SizedBox(height: 8),
                      _buildDetailRow(Icons.location_on, eventData.location.isEmpty ? "Location" : eventData.location),

                      SizedBox(height: 24),

                      // 5. About Section
                      Text('About Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        eventData.description.isEmpty ? "No description provided." : eventData.description,
                        style: TextStyle(color: Colors.grey[600], height: 1.5),
                      ),

                      SizedBox(height: 24),

                      // 6. Info Cards (Attendees & Venue)
                      Row(
                        children: [
                          _buildInfoCard(
                            Icons.people,
                            'Capacity',
                            eventData.maxAttendees == 0 ? "Unlimited" : "${eventData.maxAttendees}",
                            Colors.red,
                          ),
                          SizedBox(width: 16),
                          _buildInfoCard(
                            Icons.category,
                            'Category',
                            eventData.category,
                            Colors.orange,
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 24),
                      
                      // 7. Refund Policy (if paid)
                      if (!eventData.isFree && eventData.refundPolicy != null) ...[
                        Text('Refund Policy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text(eventData.refundPolicy!, style: TextStyle(color: Colors.grey[600])),
                        SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Action Bar
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSubmitting ? null : onBack,
                  style: OutlinedButton.styleFrom(minimumSize: Size(0, 50)),
                  child: Text('Edit'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(minimumSize: Size(0, 50)),
                  child: isSubmitting 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Publish Event'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 50, color: Colors.grey[400]),
            Text("No Image Selected", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    if (imageUrl.startsWith('http')) {
      return Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[200]));
    }
    return Image.file(File(imageUrl), fit: BoxFit.cover);
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: Colors.grey[800], fontSize: 15))),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? millis) {
    if (millis == null) return "Date not set";
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(int.parse(millis));
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return "Invalid Date";
    }
  }
}