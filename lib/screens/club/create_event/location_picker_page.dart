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
  final TextEditingController _searchController = TextEditingController(); // NEW
  Timer? _debounceTimer;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(5.4141, 100.3288), // Penang
    zoom: 14.4746,
  );

  // Style to hide POIs (Restaurants, etc.)
  final String _mapStyle = '''
  [
    {
      "featureType": "poi",
      "elementType": "labels.icon",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels.icon",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    }
  ]
  ''';

  LatLng? _currentPosition;
  String _currentAddress = "Move map to select location";
  bool _isLoadingAddress = false;
  bool _isSearching = false; // NEW: To show search loader

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // --- NEW: Search Functionality ---
  Future<void> _searchAndNavigate() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    try {
      // 1. Find locations matching the query
      List<Location> locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        final Location loc = locations.first;
        final LatLng target = LatLng(loc.latitude, loc.longitude);

        // 2. Move camera to the found location
        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: 16, // Zoom in closer for search results
          ),
        ));
      } else {
        _showErrorSnackBar("No location found for '$query'");
      }
    } catch (e) {
      _showErrorSnackBar("Could not find location. Try a more specific name.");
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  // ---------------------------------

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    final GoogleMapController controller = await _controller.future;
    
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 16,
      ),
    ));
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() {
      _isLoadingAddress = true;
      _currentAddress = "Fetching address...";
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
        address = address.replaceAll(RegExp(r'^, | , '), ''); 
        
        if (mounted) {
          setState(() {
            _currentAddress = address; 
            _currentPosition = position;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = "Could not fetch address";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentPosition = position.target;
  }

  void _onCameraIdle() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (_currentPosition != null) {
        _getAddressFromLatLng(_currentPosition!);
      }
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
      // Removed standard AppBar to give more map space
      resizeToAvoidBottomInset: false, // Prevents map from squishing when keyboard opens
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // We will build a custom button if needed
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              controller.setMapStyle(_mapStyle);
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),
          
          // Center Pin
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.0),
              child: Icon(Icons.location_on, size: 50, color: Colors.red),
            ),
          ),

          // --- NEW: Floating Search Bar ---
          Positioned(
            top: 50, // Safe area padding
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchAndNavigate(),
                      decoration: const InputDecoration(
                        hintText: "Search venue (e.g. USM Penang)",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                  _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _searchAndNavigate,
                        ),
                ],
              ),
            ),
          ),

          // --- NEW: My Location Button (Custom) ---
          Positioned(
            right: 16,
            top: 120, // Below the search bar
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _determinePosition,
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),

          // Bottom Address Card
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Selected Location:",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingAddress 
                        ? const SizedBox(
                            height: 20, 
                            width: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2)
                          )
                        : Text(
                            _currentAddress,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _currentPosition == null || _isLoadingAddress
                          ? null
                          : () {
                              Navigator.pop(context, _currentAddress);
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      child: const Text("Confirm Location"),
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