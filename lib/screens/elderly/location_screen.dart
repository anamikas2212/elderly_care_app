import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // Map controller
  final MapController _mapController = MapController();
  
  // Home location (hardcoded for now)
  final LatLng _homeLocation = LatLng(9.998418620839775, 76.361358164756); // hostel
  final double _safeZoneRadius = 670.0; // 1km radius
  
  // Current location (will be updated in real-time)
  LatLng? _currentLocation;

  // Current zoom level
  double _currentZoom = 15.0;
  
  // Location permission status
  bool _locationPermissionGranted = false;
  bool _isLoadingLocation = true;
  
  // Stream subscription for location updates
  StreamSubscription<Position>? _positionStreamSubscription;
  
  // Distance from home
  double? _distanceFromHome;
  bool _isInsideSafeZone = false;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // Request location permission
  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoadingLocation = false);
      _showLocationServiceDialog();
      return;
    }

    // Check permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoadingLocation = false);
      _showPermissionDeniedForeverDialog();
      return;
    }

    setState(() => _locationPermissionGranted = true);
    _startLocationTracking();
  }
  // Start real-time location tracking
  void _startLocationTracking() {
    Geolocator.getCurrentPosition( // Get initial position
      desiredAccuracy: LocationAccuracy.high,
    ).then(_updateLocation).catchError((error) {
      print('Error getting initial position: $error');
      setState(() => _isLoadingLocation = false);
    });
    // Listen to location updates
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateLocation(position);
    });
  }

  // Update current location and calculate distance
  void _updateLocation(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);
    
    // Calculate distance from home
    final distance = Geolocator.distanceBetween(
      _homeLocation.latitude,
      _homeLocation.longitude,
      position.latitude,
      position.longitude,
    );

    setState(() {
      _currentLocation = newLocation;
      _distanceFromHome = distance;
      _isInsideSafeZone = distance <= _safeZoneRadius;
      _isLoadingLocation = false;
    });

    print('Location updated: ${position.latitude}, ${position.longitude}');
    print('Distance from home: ${distance.toStringAsFixed(2)} meters');
    print('Inside safe zone: $_isInsideSafeZone');
  }

  // Show location service disabled dialog
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Location Service Disabled',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Please enable location services to use this feature.',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              _requestLocationPermission();
            },
            child: const Text('Open Settings', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // Show permission denied dialog
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Location Permission Required',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This app needs location permission to show your current position and track if you\'re in the safe zone.',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestLocationPermission();
            },
            child: const Text('Grant Permission', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // Show permission denied forever dialog
  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Permission Permanently Denied',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Location permission has been permanently denied. Please enable it in app settings.',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // Zoom in function
  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(5.0, 18.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(5.0, 18.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  void _centerOnHome() {
    setState(() {
      _currentZoom = 15.0;
      _mapController.move(_homeLocation, _currentZoom);
    });
  }

  // Center on current location
  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      setState(() {
        _currentZoom = 15.0;
        _mapController.move(_currentLocation!, _currentZoom);
      });
    }
  }

  // Format distance for display

  String _formatDistance(double? distance) {
    if (distance == null) return 'Calculating...';
    if (distance < 1000) return '${distance.toStringAsFixed(0)} m';
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '📍 Location',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: _isLoadingLocation
          ? _buildLoadingView()
          : !_locationPermissionGranted
              ? _buildPermissionDeniedView()
              : _buildMapView(),
    );
  }

  // Loading view while getting location
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(strokeWidth: 4),
          SizedBox(height: 24),
          Text(
            'Getting your location...',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          Text(
            'Please wait',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Permission denied view
  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 100, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Location Permission Needed',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please grant location permission to use this feature',
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _requestLocationPermission,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'Grant Permission',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Main map view
  Widget _buildMapView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Status Card
          Container(
            decoration: BoxDecoration(
              color: _isInsideSafeZone ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isInsideSafeZone ? Colors.green.shade300 : Colors.orange.shade300,
                width: 4,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      _isInsideSafeZone ? '🏠' : '⚠️',
                      style: const TextStyle(fontSize: 50),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isInsideSafeZone ? 'You are Home' : 'Outside Safe Zone',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _isInsideSafeZone ? 'Safe Zone ✓' : 'Alert!',
                            style: TextStyle(
                              fontSize: 20,
                              color: _isInsideSafeZone ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.straighten, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Distance from home: ${_formatDistance(_distanceFromHome)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          // Expanded Map Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade300, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Map
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation ?? _homeLocation,
                      initialZoom: _currentZoom,
                      minZoom: 5.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      // Tile Layer
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: 'com.example.elderly_care_app',
                      ),
                      
                      // Circle Layer (Safe Zone)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _homeLocation,
                            radius: _safeZoneRadius,
                            useRadiusInMeter: true,
                            color: Colors.green.withOpacity(0.2),
                            borderColor: Colors.green,
                            borderStrokeWidth: 3,
                          ),
                        ],
                      ),
                      
                      // Marker Layer
                      MarkerLayer(
                        markers: [
                          // Home Location
                          Marker(
                            point: _homeLocation,
                            width: 60,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.home,
                                size: 35,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          
                          // Current Location (only if available)
                          if (_currentLocation != null)
                            Marker(
                              point: _currentLocation!,
                              width: 50,
                              height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Zoom Controls
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Column(
                      children: [
                        _buildZoomButton(Icons.add, _zoomIn),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue.shade300,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '${_currentZoom.toStringAsFixed(0)}x',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildZoomButton(Icons.remove, _zoomOut),
                      ],
                    ),
                  ),
                  
                  // Control Buttons (Bottom)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      children: [
                        // Center on Current Location
                        Expanded(
                          child: _buildControlButton(
                            icon: Icons.my_location,
                            label: 'My Location',
                            onTap: _centerOnCurrentLocation,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Center on Home
                        Expanded(
                          child: _buildControlButton(
                            icon: Icons.home,
                            label: 'Home',
                            onTap: _centerOnHome,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Status Badge
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isInsideSafeZone ? Colors.green : Colors.orange,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isInsideSafeZone ? Icons.check_circle : Icons.warning,
                            color: _isInsideSafeZone ? Colors.green : Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isInsideSafeZone ? 'Safe Zone' : 'Outside',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _isInsideSafeZone ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Map Legend
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(
                  icon: Icons.home,
                  color: Colors.blue,
                  label: 'Home',
                ),
                _buildLegendItem(
                  icon: Icons.person_pin_circle,
                  color: Colors.red,
                  label: 'You',
                ),
                _buildLegendItem(
                  icon: Icons.circle_outlined,
                  color: Colors.green,
                  label: 'Safe Zone (${_safeZoneRadius.toInt()}m)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────────────────

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade300, width: 2),
          ),
          child: Icon(icon, size: 32, color: Colors.blue),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}