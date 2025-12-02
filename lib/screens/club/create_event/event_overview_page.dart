// event_overview_page.dart
import 'package:flutter/material.dart';
import '../../../models/event.dart';

class EventOverviewPage extends StatefulWidget {
  final EventModel eventData;
  final VoidCallback? onSubmit;
  final VoidCallback onBack;
  final bool isSubmitting;

  const EventOverviewPage({super.key, 
    required this.eventData,
    required this.onSubmit,
    required this.onBack,
    this.isSubmitting = false,
  });

  @override
  _EventOverviewPageState createState() => _EventOverviewPageState();
}

class _EventOverviewPageState extends State<EventOverviewPage> {
  String _formatDateTime(String? timestamp) {
    if (timestamp == null) return 'Not set';
    
    final milliseconds = int.tryParse(timestamp);
    if (milliseconds == null) return 'Invalid date';
    
    final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Club Header
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: widget.eventData.clubImageUrl != null 
                        ? NetworkImage(widget.eventData.clubImageUrl!)
                        : null,
                    child: widget.eventData.clubImageUrl == null 
                        ? Icon(Icons.group, size: 24)
                        : null,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Club',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          widget.eventData.clubName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          Expanded(
            child: ListView(
              children: [
                _buildSectionHeader('Event Details'),
                _buildInfoCard(
                  title: 'Event Name',
                  value: widget.eventData.name.isEmpty ? 'Not provided' : widget.eventData.name,
                  icon: Icons.event,
                ),
                _buildInfoCard(
                  title: 'Description',
                  value: widget.eventData.description.isEmpty ? 'Not provided' : widget.eventData.description,
                  icon: Icons.description,
                ),
                _buildInfoCard(
                  title: 'Date & Time',
                  value: _formatDateTime(widget.eventData.date),
                  icon: Icons.calendar_today,
                ),
                _buildInfoCard(
                  title: 'Location',
                  value: widget.eventData.location.isEmpty ? 'Not provided' : widget.eventData.location,
                  icon: Icons.location_on,
                ),
                _buildInfoCard(
                  title: 'Max Attendees',
                  value: widget.eventData.maxAttendees == 0 
                      ? 'Unlimited' 
                      : widget.eventData.maxAttendees.toString(),
                  icon: Icons.people,
                ),

                _buildSectionHeader('Pricing & Policies'),
                _buildInfoCard(
                  title: 'Event Type',
                  value: widget.eventData.isFree ? 'Free' : 'Paid',
                  icon: Icons.attach_money,
                ),
                if (!widget.eventData.isFree)
                  _buildInfoCard(
                    title: 'Ticket Price',
                    value: '\$${widget.eventData.price.toStringAsFixed(2)}',
                    icon: Icons.payment,
                  ),
                if (widget.eventData.refundPolicy?.isNotEmpty ?? false)
                  _buildInfoCard(
                    title: 'Refund Policy',
                    value: widget.eventData.refundPolicy!,
                    icon: Icons.policy,
                  ),
                _buildInfoCard(
                  title: 'Publish Time',
                  value: _formatDateTime(widget.eventData.publishTime),
                  icon: Icons.schedule,
                ),
              ],
            ),
          ),

          // Submit Button
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.isSubmitting ? null : widget.onBack,
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(0, 50),
                  ),
                  child: Text('Back'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.isSubmitting ? null : widget.onSubmit,
                  child: widget.isSubmitting 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Create Event'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value),
      ),
    );
  }
}