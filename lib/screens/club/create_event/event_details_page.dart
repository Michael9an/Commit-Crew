import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/event.dart';
import '../../../services/storage_service.dart';

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

  final ImagePicker _picker = ImagePicker();
  late EventModel _localEvent;

  // Map Variables
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng _currentMapPosition = const LatLng(5.4141, 100.3288);
  String? _detectedMapAddress;
  bool _isMapLoading = false;
  Timer? _debounceTimer;

  // Date/Time Variables
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Clean Map Style
  final String _mapStyle = '''
  [
    {
      "featureType": "poi",
      "elementType": "labels.icon",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "transit",
      "elementType": "labels.icon",
      "stylers": [{"visibility": "off"}]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _localEvent = widget.eventData;
    _nameController.text = _localEvent.name;
    _descriptionController.text = _localEvent.description;
    _locationController.text = _localEvent.location;
    _maxAttendeesController.text = _localEvent.maxAttendees.toString();
    
    if (_localEvent.date != null) {
      final timestamp = int.tryParse(_localEvent.date!);
      if (timestamp != null) {
        final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        _selectedDate = dateTime;
        _selectedTime = TimeOfDay.fromDateTime(dateTime);
      }
    }

    _determineUserLocation();
  }

  // --- DATE & TIME LOGIC ---
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

  // --- MAP LOGIC ---
  Future<void> _determineUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentMapPosition = LatLng(position.latitude, position.longitude);
    });

    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLng(_currentMapPosition));
  }

  Future<void> _searchMapLocation() async {
    final query = _mapSearchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isMapLoading = true);

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);
        
        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location not found")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Search failed")));
    } finally {
      setState(() => _isMapLoading = false);
    }
  }

  Future<void> _resolveAddressFromPin() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _currentMapPosition.latitude, 
        _currentMapPosition.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = "${place.street}, ${place.locality}";
        if (place.name != null && place.name != place.street) {
          address = "${place.name}, $address";
        }
        
        setState(() {
          _detectedMapAddress = address;
        });
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
      _resolveAddressFromPin();
    });
  }

  Future<void> _pickImage() async {
     try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
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
        _selectedTime.hour, _selectedTime.minute,
      );
      
      _localEvent = _localEvent.copyWith(
        date: combinedDateTime.millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        description: _descriptionController.text,
        location: _locationController.text,
        maxAttendees: int.tryParse(_maxAttendeesController.text) ?? 0,
        latitude: _currentMapPosition.latitude,
        longitude: _currentMapPosition.longitude,
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
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: _localEvent.clubImageUrl != null ? NetworkImage(_localEvent.clubImageUrl!) : null,
                      child: _localEvent.clubImageUrl == null ? const Icon(Icons.group) : null,
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
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: _localEvent.bannerUrl != null && !_localEvent.bannerUrl!.startsWith('http')
                    ? DecorationImage(image: FileImage(File(_localEvent.bannerUrl!)), fit: BoxFit.cover)
                    : null
                ),
                child: _localEvent.bannerUrl == null 
                  ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_photo_alternate), Text("Add Banner")]))
                  : null,
              ),
            ),
            const SizedBox(height: 20),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Event Name *', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // --- EMBEDDED MAP SECTION ---
            const Text("Event Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Venue Name (e.g. Main Hall, Level 2)',
                hintText: 'Type venue name or search map',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (v) => v!.isEmpty ? 'Please enter a location name' : null,
            ),
            
            const SizedBox(height: 12),
            
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(12),
              ),
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
                        _mapController.complete(c);
                        c.setMapStyle(_mapStyle);
                      },
                      onCameraMove: _onCameraMove,
                      onCameraIdle: _onCameraIdle,
                      gestureRecognizers: {}, 
                    ),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 35),
                        child: Icon(Icons.location_on, size: 45, color: Colors.red),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: TextField(
                          controller: _mapSearchController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _searchMapLocation(),
                          decoration: InputDecoration(
                            hintText: 'Search map (e.g. USM)...',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            suffixIcon: IconButton(
                              icon: _isMapLoading 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.search),
                              onPressed: _searchMapLocation,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_detectedMapAddress != null)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _locationController.text = _detectedMapAddress!;
                              _detectedMapAddress = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.blue[600],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.copy, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    "Use: $_detectedMapAddress", 
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // --- FIXED DATE & TIME SECTION ---
            // The fix: Wrapped AbsorbPointer with GestureDetector
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectDate, // This was missing!
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Date', 
                          prefixIcon: Icon(Icons.calendar_today), 
                          border: OutlineInputBorder()
                        ),
                        controller: TextEditingController(
                          text: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectTime, // This was missing!
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Time', 
                          prefixIcon: Icon(Icons.access_time), 
                          border: OutlineInputBorder()
                        ),
                        controller: TextEditingController(
                          text: _selectedTime.format(context)
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
             TextFormField(
              controller: _maxAttendeesController,
              decoration: const InputDecoration(
                labelText: 'Max Attendees',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
              keyboardType: TextInputType.number,
            ),
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
    _debounceTimer?.cancel();
    super.dispose();
  }
}