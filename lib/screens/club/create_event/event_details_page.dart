import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/event.dart';
import '../../../services/storage_service.dart';
import 'location_picker_page.dart';

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
  
  // Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController(); // MANUALLY TYPED VENUE NAME
  final _maxAttendeesController = TextEditingController();
  final _scannerPinController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  late EventModel _localEvent;

  // Location Variables
  double? _selectedLat;
  double? _selectedLng;
  String? _linkedMapAddress; // Stores the address purely for display in the "Map" box
  bool _isFetchingLocation = false;

  // Date/Time Variables
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  String _selectedCategory = 'General';
  final List<String> _categories = [
    'General', 'Technology', 'Sports', 'Music', 'Arts', 
    'Business', 'Education', 'Social', 'Workshop', 'Gaming', 'Health'
  ];

  String _checkInMethod = 'self_scan'; 

  @override
  void initState() {
    super.initState();
    _localEvent = widget.eventData;
    _initializeControllers();
    
    // Determine initial location if none set
    if (_localEvent.latitude == null) {
      _determineUserLocation();
    }
  }

  void _initializeControllers() {
    _nameController.text = _localEvent.name;
    _descriptionController.text = _localEvent.description;
    _locationController.text = _localEvent.location; // User's custom text
    _maxAttendeesController.text = _localEvent.maxAttendees > 0 ? _localEvent.maxAttendees.toString() : '';
    _scannerPinController.text = _localEvent.scannerPin ?? ''; 
    
    if (_localEvent.category.isNotEmpty && _categories.contains(_localEvent.category)) {
      _selectedCategory = _localEvent.category;
    }

    if (_localEvent.checkInMethod.isNotEmpty) {
      _checkInMethod = _localEvent.checkInMethod;
    }

    if (_localEvent.date.isNotEmpty) {
      final timestamp = int.tryParse(_localEvent.date);
      if (timestamp != null) {
        _selectedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    }
    
    if (_localEvent.startTime.isNotEmpty) {
      _startTime = _parseTime(_localEvent.startTime);
    }
    if (_localEvent.endTime.isNotEmpty) {
      _endTime = _parseTime(_localEvent.endTime);
    }

    _selectedLat = _localEvent.latitude;
    _selectedLng = _localEvent.longitude;
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return TimeOfDay.now();
    }
  }

  String _formatTimeForDB(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) setState(() => _selectedDate = picked);
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) setState(() => _endTime = picked);
  }

  // Gets coordinates without overwriting text
  Future<void> _determineUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    setState(() => _isFetchingLocation = true);

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      if (!mounted) return;
      
      setState(() {
        _selectedLat = position.latitude;
        _selectedLng = position.longitude;
      });

      // Optional: Get address for "Map Link" display only
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
           Placemark place = placemarks[0];
           setState(() => _linkedMapAddress = "${place.street}, ${place.locality}");
        }
      } catch (e) {}

    } catch (e) {
      print("Location error: $e");
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerPage()),
    );

    // FIX: Only update coordinates and the "Linked Map" display
    // DO NOT overwrite _locationController.text
    if (result != null && result is Map<String, dynamic>) {
       setState(() {
        _linkedMapAddress = result['address'];
        _selectedLat = result['lat'];
        _selectedLng = result['lng'];
      });
    }
  }

  Future<void> _pickImage() async {
     try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (!mounted) return;
      if (image != null) {
         setState(() {
          _localEvent = _localEvent.copyWith(bannerUrl: image.path);
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  void _saveAndContinue() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final combinedDateTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _startTime.hour, _startTime.minute,
      );
      
      String? pin;
      if (_checkInMethod == 'organizer_scan') {
        pin = _scannerPinController.text.trim();
        if (pin.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please set a PIN for the scanners')));
          return;
        }
      }

      _localEvent = _localEvent.copyWith(
        date: combinedDateTime.millisecondsSinceEpoch.toString(),
        startTime: _formatTimeForDB(_startTime),
        endTime: _formatTimeForDB(_endTime),     
        name: _nameController.text,
        description: _descriptionController.text,
        location: _locationController.text, // Uses the manual text
        maxAttendees: int.tryParse(_maxAttendeesController.text) ?? 0,
        latitude: _selectedLat ?? 0.0, // Uses the separate coordinates
        longitude: _selectedLng ?? 0.0,
        category: _selectedCategory,
        checkInMethod: _checkInMethod,
        scannerPin: pin,
      );

      widget.onNext(_localEvent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Header
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.edit_calendar, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Event for: ${_localEvent.clubName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Step 1: Event Basics', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Image Picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Builder(
                    builder: (context) {
                      final rawUrl = _localEvent.bannerUrl;
                      if (rawUrl == null || rawUrl.isEmpty || rawUrl == 'file:///') {
                        return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_photo_alternate, size: 40), Text("Add Banner")]));
                      }
                      if (rawUrl.startsWith('http')) {
                        return FutureBuilder<String?>(
                          future: StorageService().resolveImageUrl(rawUrl),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                            return Image.network(snapshot.data ?? rawUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Center(child: Icon(Icons.broken_image)));
                          },
                        );
                      }
                      return Image.file(File(rawUrl), fit: BoxFit.cover);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Event Name *', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 24),

            // --- SEPARATED LOCATION INPUTS ---
            const Text("Venue Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            
            // 1. Manual Text Input (Specific Location)
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Specific Location (e.g. Room 304)', 
                border: OutlineInputBorder(), 
                prefixIcon: Icon(Icons.business),
                helperText: 'Enter the exact room or hall name.',
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            
            // 2. Separate Map Pin Selector
            InkWell(
              onTap: _openLocationPicker,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _selectedLat != null ? Colors.green[50] : Colors.blue[50], 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _selectedLat != null ? Colors.green : Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedLat != null ? Icons.location_on : Icons.map, 
                      color: _selectedLat != null ? Colors.green : Colors.blue, 
                      size: 30
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLat != null ? "Google Map Linked" : "Link Google Map (Optional)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: _selectedLat != null ? Colors.green[800] : Colors.blue
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedLat != null 
                              ? "Map Address: ${_linkedMapAddress ?? 'Pinned'}"
                              : "Tap to pin location for navigation aid.",
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date & Time
            Row(
              children: [
                Expanded(child: GestureDetector(onTap: _selectDate, child: AbsorbPointer(child: TextFormField(decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()), controller: TextEditingController(text: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'))))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: GestureDetector(onTap: _selectStartTime, child: AbsorbPointer(child: TextFormField(decoration: const InputDecoration(labelText: 'Start Time', prefixIcon: Icon(Icons.access_time), border: OutlineInputBorder()), controller: TextEditingController(text: _startTime.format(context)))))),
                const SizedBox(width: 16),
                Expanded(child: GestureDetector(onTap: _selectEndTime, child: AbsorbPointer(child: TextFormField(decoration: const InputDecoration(labelText: 'End Time', prefixIcon: Icon(Icons.access_time_filled), border: OutlineInputBorder()), controller: TextEditingController(text: _endTime.format(context)))))),
              ],
            ),
            
            const SizedBox(height: 16),
             TextFormField(
              controller: _maxAttendeesController,
              decoration: const InputDecoration(labelText: 'Max Attendees', border: OutlineInputBorder(), prefixIcon: Icon(Icons.people)),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _checkInMethod,
              decoration: const InputDecoration(labelText: 'Check-in Method', border: OutlineInputBorder(), prefixIcon: Icon(Icons.qr_code_scanner)),
              items: const [
                DropdownMenuItem(value: 'self_scan', child: Text('User scans Event QR (Self Check-in)')),
                DropdownMenuItem(value: 'organizer_scan', child: Text('Organizer scans User Ticket')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _checkInMethod = val);
              },
            ),
            
            if (_checkInMethod == 'organizer_scan') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _scannerPinController,
                decoration: const InputDecoration(labelText: 'Scanner Pass PIN', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
            ],

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _saveAndContinue,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('Next: Pricing & Policies'),
            ),
            const SizedBox(height: 30),
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
    _scannerPinController.dispose();
    super.dispose();
  }
}