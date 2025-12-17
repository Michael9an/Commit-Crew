import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../models/event.dart';

class EventDetailsPage extends StatefulWidget {
  final EventModel eventData;
  final ValueChanged<EventModel> onNext;

  const EventDetailsPage({super.key, 
    required this.eventData,
    required this.onNext,
  });

  @override
  _EventDetailsPageState createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxAttendeesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late EventModel _localEvent;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _localEvent = widget.eventData;
    _nameController.text = _localEvent.name;
    _descriptionController.text = _localEvent.description;
    _locationController.text = _localEvent.location;
    _maxAttendeesController.text = _localEvent.maxAttendees.toString();
    
    // Set initial date/time from event data if exists
    if (_localEvent.date != null) {
      final timestamp = int.tryParse(_localEvent.date!);
      if (timestamp != null) {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        _selectedDate = dateTime;
        _selectedTime = TimeOfDay.fromDateTime(dateTime);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _pickImage() async {
  try {
      // Show loading indicator while compressing
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing image...'),
                  ],
                ),
              ),
            ),
          );
        },
      );

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 70,
      );

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      if (image != null) {
        // Verify file size
        final file = File(image.path);
        final size = await file.length();
        if (size > 5 * 1024 * 1024) { // 5MB limit
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select an image under 5MB'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Store the local path temporarily for display
        setState(() {
          _localEvent = _localEvent.copyWith(bannerUrl: image.path);
        });
      }
    } catch (e) {
      // Close loading dialog if error occurs
      if (!mounted) return;
      Navigator.of(context).maybePop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  void _saveAndContinue() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      // Combine date and time
      final combinedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      _localEvent = _localEvent.copyWith(
        date: combinedDateTime.millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        description: _descriptionController.text,
        location: _locationController.text,
        maxAttendees: int.tryParse(_maxAttendeesController.text) ?? 0,
      );

      widget.onNext(_localEvent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Club Info Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: _localEvent.clubImageUrl != null 
                          ? NetworkImage(_localEvent.clubImageUrl!)
                          : null,
                      child: _localEvent.clubImageUrl == null 
                          ? Icon(Icons.group, size: 24)
                          : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Creating event for',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            _localEvent.clubName,
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
            SizedBox(height: 20),

            // Image Upload
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: (_localEvent.bannerUrl == null || _localEvent.bannerUrl!.isEmpty)
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Tap to upload event banner'),
                        ],
                      )
                    : (_localEvent.bannerUrl!.startsWith('http')
                        ? Image.network(_localEvent.bannerUrl!, fit: BoxFit.cover)
                        : Image.file(File(_localEvent.bannerUrl!), fit: BoxFit.cover)),
              ),
            ),
            SizedBox(height: 20),

            // Event Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Event Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter event name';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter event description';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Date and Time
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Date *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        controller: TextEditingController(
                          text: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectTime,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Time *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        controller: TextEditingController(
                          text: _selectedTime.format(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Venue/Location *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter event location';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Maximum Attendees
            TextFormField(
              controller: _maxAttendeesController,
              decoration: InputDecoration(
                labelText: 'Maximum Attendees',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
                hintText: '0 for unlimited',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 30),

            // Next Button
            ElevatedButton(
              onPressed: _saveAndContinue,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Next: Pricing & Policies'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxAttendeesController.dispose();
    super.dispose();
  }
}