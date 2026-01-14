import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(5.4141, 100.3288), // Penang
    zoom: 14.4746,
  );

  final String _mapStyle = '''
  [
    {
      "featureType": "poi",
      "elementType": "labels.icon",
      "stylers": [{"visibility": "off"}]
    }
  ]
  ''';

  LatLng? _currentPosition;
  String _currentAddress = "Move map to select location";
  bool _isLoadingAddress = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _searchAndNavigate() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final Location loc = locations.first;
        final LatLng target = LatLng(loc.latitude, loc.longitude);

        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 16),
        ));
      } else {
        _showError("No location found");
      }
    } catch (e) {
      _showError("Search failed");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    final GoogleMapController controller = await _controller.future;
    
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 16),
    ));
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() {
      _isLoadingAddress = true;
      _currentAddress = "Fetching address...";
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Clean address format
        String address = "${place.street}, ${place.locality}, ${place.country}";
        address = address.replaceAll(RegExp(r'^, | , '), ''); 
        
        if (mounted) {
          setState(() {
            _currentAddress = address; 
            _currentPosition = position;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _currentAddress = "Location Selected");
    } finally {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentPosition = position.target;
  }

  void _onCameraIdle() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (_currentPosition != null) {
        _getAddressFromLatLng(_currentPosition!);
      }
    });
  }

  void _confirmSelection() {
    if (_currentPosition == null) return;
    
    // Return a Map with all details instead of just a String
    Navigator.pop(context, {
      'address': _currentAddress,
      'lat': _currentPosition!.latitude,
      'lng': _currentPosition!.longitude,
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) {
              _controller.complete(c);
              c.setMapStyle(_mapStyle);
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),
          
          const Center(child: Padding(padding: EdgeInsets.only(bottom: 40.0), child: Icon(Icons.location_on, size: 50, color: Colors.red))),

          // Search Bar
          Positioned(
            top: 50, left: 16, right: 16,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchAndNavigate(),
                      decoration: const InputDecoration(hintText: "Search map...", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.search), onPressed: _searchAndNavigate),
                ],
              ),
            ),
          ),

          // My Location Button
          Positioned(
            right: 16, top: 120,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _determinePosition,
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),

          // Confirm Button
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Map Reference:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    _isLoadingAddress 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_currentAddress, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _currentPosition == null || _isLoadingAddress ? null : _confirmSelection,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                      child: const Text("Use This Map Location"),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}