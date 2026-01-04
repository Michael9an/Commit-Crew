import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  final _locationController = TextEditingController();
  final _maxAttendeesController = TextEditingController();
  final _mapSearchController = TextEditingController();
  final _scannerPinController = TextEditingController(); // NEW: PIN Controller

  final ImagePicker _picker = ImagePicker();
  late EventModel _localEvent;

  // Map Variables
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng _currentMapPosition = const LatLng(5.4141, 100.3288);
  String? _detectedMapAddress;
  bool _isMapLoading = false;
  Timer? _debounceTimer;
  Set<Marker> _markers = {};

  // Date/Time Variables
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  // Category Logic
  String _selectedCategory = 'General';
  final List<String> _categories = [
    'General', 'Technology', 'Sports', 'Music', 'Arts', 
    'Business', 'Education', 'Social', 'Workshop', 'Gaming', 'Health'
  ];

  String _checkInMethod = 'self_scan'; 

  final String _mapStyle = '''
  [
    {
      "featureType": "poi",
      "elementType": "labels.icon",
      "stylers": [{"visibility": "off"}]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _localEvent = widget.eventData;
    _initializeControllers();
    _determineUserLocation();
  }

  void _initializeControllers() {
    _nameController.text = _localEvent.name;
    _descriptionController.text = _localEvent.description;
    _locationController.text = _localEvent.location;
    _maxAttendeesController.text = _localEvent.maxAttendees > 0 ? _localEvent.maxAttendees.toString() : '';
    _scannerPinController.text = _localEvent.scannerPin ?? ''; // Load PIN
    
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

    if (_localEvent.latitude != null && _localEvent.longitude != null) {
      _currentMapPosition = LatLng(_localEvent.latitude!, _localEvent.longitude!);
      _markers.add(Marker(markerId: const MarkerId('selected'), position: _currentMapPosition));
    }
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
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _determineUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _currentMapPosition = LatLng(position.latitude, position.longitude);
    });

    final GoogleMapController controller = await _mapController.future;
    if (!mounted) return;
    controller.animateCamera(CameraUpdate.newLatLng(_currentMapPosition));
  }

  Future<void> _searchMapLocation() async {
    final query = _mapSearchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isMapLoading = true);

    try {
      List<Location> locations = await locationFromAddress(query);
      if (!mounted) return;

      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);
        
        final controller = await _mapController.future;
        if (mounted) controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
        
        setState(() {
          _currentMapPosition = target;
          _markers = {Marker(markerId: const MarkerId('selected'), position: target)};
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location not found")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Search failed")));
    } finally {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  Future<void> _resolveAddressFromPin() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentMapPosition.latitude, _currentMapPosition.longitude
      );
      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = "${place.street}, ${place.locality}";
        if (place.name != null && place.name != place.street) {
          address = "${place.name}, $address";
        }
        setState(() => _detectedMapAddress = address);
      }
    } catch (e) {}
  }

  void _onCameraMove(CameraPosition position) {
    _currentMapPosition = position.target;
    if (_detectedMapAddress != null) {
      setState(() => _detectedMapAddress = null);
    }
  }

  void _onCameraIdle() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _resolveAddressFromPin();
    });
  }

  void _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LocationPickerPage()),
    );

    if (result != null && result is String) {
       setState(() {
        _locationController.text = result;
      });
    }
  }

  Future<void> _pickImage() async {
     try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
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
      
      // Save Scanner PIN logic
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
        location: _locationController.text,
        maxAttendees: int.tryParse(_maxAttendeesController.text) ?? 0,
        latitude: _currentMapPosition.latitude,
        longitude: _currentMapPosition.longitude,
        category: _selectedCategory,
        checkInMethod: _checkInMethod,
        scannerPin: pin, // Save the PIN
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
            // Club Info
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    FutureBuilder<String?>(
                      future: StorageService().resolveImageUrl(_localEvent.clubImageUrl),
                      builder: (context, snapshot) {
                        ImageProvider? imageProvider;
                        if (snapshot.hasData && snapshot.data != null) {
                          imageProvider = NetworkImage(snapshot.data!);
                        }
                        return CircleAvatar(
                          radius: 24,
                          backgroundImage: imageProvider,
                          backgroundColor: Colors.grey[300],
                          child: imageProvider == null ? const Icon(Icons.group, color: Colors.grey) : null,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Creating event for', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          Text(_localEvent.clubName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Builder(
                    builder: (context) {
                      final rawUrl = _localEvent.bannerUrl;
                      if (rawUrl == null || rawUrl.isEmpty || rawUrl == 'file:///') {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [Icon(Icons.add_photo_alternate, size: 40), Text("Add Banner")],
                          ),
                        );
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

            // Name & Description
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

            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 24),

            // Map Section
            const Text("Event Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Venue Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Container(
              height: 300,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey[400]!), borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    GoogleMap(
                      mapType: MapType.normal,
                      initialCameraPosition: CameraPosition(target: _currentMapPosition, zoom: 15),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      onMapCreated: (c) { 
                        if (!_mapController.isCompleted) _mapController.complete(c); 
                        c.setMapStyle(_mapStyle); 
                      },
                      onCameraMove: _onCameraMove,
                      onCameraIdle: _onCameraIdle,
                      markers: _markers, 
                    ),
                    const Center(child: Padding(padding: EdgeInsets.only(bottom: 35), child: Icon(Icons.location_on, size: 45, color: Colors.red))),
                    Positioned(
                      top: 10, left: 10, right: 10,
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                        child: TextField(
                          controller: _mapSearchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _searchMapLocation(),
                          decoration: InputDecoration(
                            hintText: 'Search map...',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            suffixIcon: IconButton(icon: _isMapLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search), onPressed: _searchMapLocation),
                          ),
                        ),
                      ),
                    ),
                    if (_detectedMapAddress != null)
                      Positioned(
                        bottom: 10, left: 10, right: 10,
                        child: GestureDetector(
                          onTap: () { setState(() { _locationController.text = _detectedMapAddress!; _detectedMapAddress = null; }); },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(color: Colors.blue[600], borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [const Icon(Icons.copy, color: Colors.white, size: 16), const SizedBox(width: 8), Flexible(child: Text("Use: $_detectedMapAddress", style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis))],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date & Time
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
                        controller: TextEditingController(text: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectStartTime,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'Start Time', prefixIcon: Icon(Icons.access_time), border: OutlineInputBorder()),
                        controller: TextEditingController(text: _startTime.format(context)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectEndTime,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: const InputDecoration(labelText: 'End Time', prefixIcon: Icon(Icons.access_time_filled), border: OutlineInputBorder()),
                        controller: TextEditingController(text: _endTime.format(context)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
             TextFormField(
              controller: _maxAttendeesController,
              decoration: const InputDecoration(labelText: 'Max Attendees', border: OutlineInputBorder(), prefixIcon: Icon(Icons.people)),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 16),

            // --- CHECK-IN METHOD SELECTION ---
            DropdownButtonFormField<String>(
              value: _checkInMethod,
              decoration: const InputDecoration(
                labelText: 'Check-in Method',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code_scanner),
                helperText: 'Choose who scans the QR code',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'self_scan', 
                  child: Text('User scans Event QR (Self Check-in)')
                ),
                DropdownMenuItem(
                  value: 'organizer_scan', 
                  child: Text('Organizer scans User Ticket')
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _checkInMethod = val);
              },
            ),
            
            // --- OPTION B: SCANNER PIN (Visible only if Organizer Scan) ---
            if (_checkInMethod == 'organizer_scan') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _scannerPinController,
                decoration: const InputDecoration(
                  labelText: 'Scanner Pass PIN',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  helperText: 'Share this PIN with volunteers to access the scanner.',
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
            ],
            // -----------------------------------------------------------

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
    _mapSearchController.dispose();
    _scannerPinController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}