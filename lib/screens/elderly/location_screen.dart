//location_screen.dart
// ✅ ENHANCED: Manual Pin-Drop to Set Home Location + Auto Route Guidance

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // Map controller
  final MapController _mapController = MapController();
  
  // Home location (will be loaded from Firebase or set by user)
  LatLng? _homeLocation;
  double _safeZoneRadius = 500.0;
  
  // Current location (will be updated in real-time)
  LatLng? _currentLocation;

  // Current zoom level
  double _currentZoom = 15.0;
  
  // Location permission status
  bool _locationPermissionGranted = false;
  bool _isLoadingLocation = true;
  
  // Stream subscription for location updates
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _positionPollTimer;
  
  // Distance from home
  double? _distanceFromHome;
  bool _isInsideSafeZone = true;
  
  // Route guidance
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  bool _showRoute = false;
  double? _routeDistance;
  String? _routeDuration;
  LatLng? _lastRouteOrigin;
  LatLng? _lastRouteDestination;
  DateTime? _lastRouteFetchAt;
  final double _routeRefreshDistanceMeters = 25.0;
  final Duration _minRouteRefreshInterval = Duration(seconds: 15);
  final double _elderlyWalkingSpeedMps = 1.0; // ~3.6 km/h
  
  // ✅ NEW: Pin-drop mode for setting home
  bool _isSettingHomeMode = false;
  LatLng? _tempHomePin; // Temporary pin position while in setting mode
  bool _isSavingHome = false;
  
  String? _elderlyUserName;

  @override
  void initState() {
    super.initState();
    _loadUserAndHomeLocation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _positionPollTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // Load user name and home location from Firebase
  Future<void> _loadUserAndHomeLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _elderlyUserName = prefs.getString('elderly_user_name') ??
                         prefs.getString('currentUserId') ??
                         prefs.getString('elderly_user_id');

      if (_elderlyUserName == null || _elderlyUserName!.isEmpty) {
        print('⚠️ No elderly user name found');
        setState(() => _isLoadingLocation = false);
        return;
      }

      print('✅ Loading home location for user: $_elderlyUserName');

      // Load home location from Firebase
      final doc = await FirebaseFirestore.instance
          .collection('safe_zones')
          .doc(_elderlyUserName)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final lat = data['homeLatitude'] as double?;
        final lng = data['homeLongitude'] as double?;
        final radius = (data['radius'] as num?)?.toDouble();

        if (lat != null && lng != null) {
          setState(() {
            _homeLocation = LatLng(lat, lng);
            if (radius != null) _safeZoneRadius = radius;
          });
          print('✅ Home location loaded: $lat, $lng (radius: $_safeZoneRadius)');
        }
      } else {
        print('⚠️ No home location saved - user needs to set it');
      }

      _requestLocationPermission();
    } catch (e) {
      print('❌ Error loading home location: $e');
      _requestLocationPermission();
    }
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoadingLocation = false);
      _showLocationServiceDialog();
      return;
    }

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

  void _startLocationTracking() {
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).then(_updateLocation).catchError((error) {
      print('Error getting initial position: $error');
      setState(() => _isLoadingLocation = false);
    });

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _updateLocation(position);
    });

    // Fallback poll to keep UI status fresh even when stream throttles (e.g., web)
    _positionPollTimer?.cancel();
    _positionPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).then(_updateLocation).catchError((error) {
        print('Error polling position: $error');
      });
    });
  }

  Future<void> _updateLocation(Position position) async {
    if (!mounted) return;
    final newLocation = LatLng(position.latitude, position.longitude);
    
    setState(() {
      _currentLocation = newLocation;
      _isLoadingLocation = false;
    });

    if (_homeLocation != null) {
      final distance = Geolocator.distanceBetween(
        _homeLocation!.latitude,
        _homeLocation!.longitude,
        position.latitude,
        position.longitude,
      );

      final wasInside = _isInsideSafeZone;
      bool isInside = distance <= _safeZoneRadius;

      setState(() {
        _distanceFromHome = distance;
        _isInsideSafeZone = isInside;
      });

      print('📍 Location: ${position.latitude}, ${position.longitude}');
      print('📏 Distance from home: ${distance.toStringAsFixed(2)}m');
      print('🏠 Inside safe zone: $isInside');

      // Auto-generate route when leaving safe zone
      if (!isInside && wasInside) {
        print('⚠️ User left safe zone - generating route home');
        _logSafeZoneExit(position, distance);
        _fetchRoute(force: true);
      } else if (!isInside && _showRoute) {
        _fetchRoute();
      } else if (isInside && _showRoute) {
        setState(() {
          _showRoute = false;
          _routePoints.clear();
        });
        _lastRouteOrigin = null;
        _lastRouteDestination = null;
        _lastRouteFetchAt = null;
        print('✅ User back in safe zone - clearing route');
      }

      _saveLocationToFirebase(position, isInside, distance);
    }
  }

  Future<void> _saveLocationToFirebase(Position position, bool isInside, double distance) async {
    try {
      if (_elderlyUserName == null || _elderlyUserName!.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_elderlyUserName)
          .set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'isHome': isInside,
        'distanceFromHome': distance,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error sending location to Firebase: $e');
    }
  }

  Future<void> _logSafeZoneExit(Position position, double distance) async {
    try {
      if (_elderlyUserName == null || _elderlyUserName!.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('safezone_logs')
          .doc(_elderlyUserName)
          .collection('logs')
          .add({
        'action': 'outside_safezone',
        'triggeredAt': FieldValue.serverTimestamp(),
        'distanceFromHome': distance,
        'location': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
        },
      });
    } catch (e) {
      print('❌ Error logging safe zone exit: $e');
    }
  }

  // ✅ NEW: Enter pin-drop mode to set home location
  void _enterSetHomeMode() {
    setState(() {
      _isSettingHomeMode = true;
      // Initialize temp pin at current location or center of map
      _tempHomePin = _currentLocation ?? _homeLocation ?? LatLng(9.998418620839775, 76.361358164756);
      
      // Center map on the pin
      _mapController.move(_tempHomePin!, 16.0);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📍 Tap anywhere on the map to place your home location'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ✅ NEW: Cancel setting home mode
  void _cancelSetHomeMode() {
    setState(() {
      _isSettingHomeMode = false;
      _tempHomePin = null;
    });
  }

  // ✅ NEW: Save the pin-dropped location as home
  Future<void> _saveHomeLocation() async {
    if (_tempHomePin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please tap on the map to set a location'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() => _isSavingHome = true);

      await FirebaseFirestore.instance
          .collection('safe_zones')
          .doc(_elderlyUserName)
          .set({
        'homeLatitude': _tempHomePin!.latitude,
        'homeLongitude': _tempHomePin!.longitude,
        'radius': _safeZoneRadius,
        'setAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _homeLocation = _tempHomePin;
        _isSettingHomeMode = false;
        _tempHomePin = null;
        _isSavingHome = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Home location saved!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      print('✅ Home location set: ${_homeLocation!.latitude}, ${_homeLocation!.longitude}');
      if (_currentLocation != null) {
        _fetchRoute(force: true);
      }
    } catch (e) {
      setState(() => _isSavingHome = false);
      print('❌ Error setting home location: $e');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _shouldRefreshRoute({required LatLng origin, required LatLng destination}) {
    if (_lastRouteOrigin == null || _lastRouteDestination == null || _lastRouteFetchAt == null) {
      return true;
    }

    final now = DateTime.now();
    if (now.difference(_lastRouteFetchAt!) < _minRouteRefreshInterval) {
      return false;
    }

    final movedFromLastOrigin = Geolocator.distanceBetween(
      _lastRouteOrigin!.latitude,
      _lastRouteOrigin!.longitude,
      origin.latitude,
      origin.longitude,
    );

    final movedFromLastDestination = Geolocator.distanceBetween(
      _lastRouteDestination!.latitude,
      _lastRouteDestination!.longitude,
      destination.latitude,
      destination.longitude,
    );

    return movedFromLastOrigin >= _routeRefreshDistanceMeters ||
        movedFromLastDestination >= _routeRefreshDistanceMeters;
  }

  Future<void> _fetchRoute({bool force = false}) async {
    if (_currentLocation == null || _homeLocation == null) return;

    if (!force && !_shouldRefreshRoute(origin: _currentLocation!, destination: _homeLocation!)) {
      return;
    }

    setState(() => _isLoadingRoute = true);

    try {
      final url = 'https://router.project-osrm.org/route/v1/foot/'
          '${_currentLocation!.longitude},${_currentLocation!.latitude};'
          '${_homeLocation!.longitude},${_homeLocation!.latitude}'
          '?overview=full&geometries=geojson';

      print('🗺️ Fetching route from OSRM...');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;
          
          final distance = route['distance'] as num;
          final duration = route['duration'] as num;

          setState(() {
            _routePoints = geometry.map((coord) {
              return LatLng(coord[1] as double, coord[0] as double);
            }).toList();
            
            _routeDistance = distance.toDouble();
            _routeDuration = _estimateWalkingDuration(distance.toDouble());
            _showRoute = true;
            _isLoadingRoute = false;
            _lastRouteOrigin = _currentLocation;
            _lastRouteDestination = _homeLocation;
            _lastRouteFetchAt = DateTime.now();
          });

          print('✅ Route fetched: ${_routePoints.length} points');
        }
      } else {
        setState(() => _isLoadingRoute = false);
      }
    } catch (e) {
      print('❌ Error fetching route: $e');
      setState(() => _isLoadingRoute = false);
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds sec';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours hr $remainingMinutes min';
  }

  String _estimateWalkingDuration(double? distanceMeters) {
    if (distanceMeters == null) return '';
    final seconds = (distanceMeters / _elderlyWalkingSpeedMps).round();
    return _formatDuration(seconds);
  }

  void _toggleRoute() {
    if (_showRoute) {
      setState(() {
        _showRoute = false;
        _routePoints.clear();
      });
      _lastRouteOrigin = null;
      _lastRouteDestination = null;
      _lastRouteFetchAt = null;
    } else {
      _fetchRoute();
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Service Disabled', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        content: const Text('Please enable location services to use this feature.', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('Cancel', style: TextStyle(fontSize: 18))),
          ElevatedButton(onPressed: () async { Navigator.pop(context); await Geolocator.openLocationSettings(); _requestLocationPermission(); }, child: const Text('Open Settings', style: TextStyle(fontSize: 18))),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        content: const Text('This app needs location permission to show your current position and track if you\'re in the safe zone.', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('Cancel', style: TextStyle(fontSize: 18))),
          ElevatedButton(onPressed: () { Navigator.pop(context); _requestLocationPermission(); }, child: const Text('Grant Permission', style: TextStyle(fontSize: 18))),
        ],
      ),
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permission Permanently Denied', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        content: const Text('Location permission has been permanently denied. Please enable it in app settings.', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('Cancel', style: TextStyle(fontSize: 18))),
          ElevatedButton(onPressed: () async { Navigator.pop(context); await Geolocator.openAppSettings(); }, child: const Text('Open Settings', style: TextStyle(fontSize: 18))),
        ],
      ),
    );
  }

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
    if (_homeLocation != null) {
      setState(() {
        _currentZoom = 15.0;
        _mapController.move(_homeLocation!, _currentZoom);
      });
    }
  }

  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      setState(() {
        _currentZoom = 15.0;
        _mapController.move(_currentLocation!, _currentZoom);
      });
    }
  }

  String _formatDistance(double? distance) {
    if (distance == null) return 'Calculating...';
    if (distance < 1000) return '${distance.toStringAsFixed(0)} m';
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _isSettingHomeMode 
            ? null 
            : IconButton(
                icon: const Icon(Icons.arrow_back, size: 32, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          _isSettingHomeMode ? '📍 Set Home Location' : '📍 Location',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        actions: [
          if (_locationPermissionGranted && !_isSettingHomeMode)
            TextButton.icon(
              onPressed: _enterSetHomeMode,
              icon: const Icon(Icons.edit_location, size: 20),
              label: Text(
                _homeLocation == null ? 'Set Home' : 'Change Home',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoadingLocation
          ? _buildLoadingView()
          : !_locationPermissionGranted
              ? _buildPermissionDeniedView()
              : _buildMapView(),
      
      // ✅ NEW: Bottom action bar when in setting mode
      bottomNavigationBar: _isSettingHomeMode
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSavingHome ? null : _cancelSetHomeMode,
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel', style: TextStyle(fontSize: 18)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingHome ? null : _saveHomeLocation,
                        icon: _isSavingHome
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle),
                        label: Text(
                          _isSavingHome ? 'Saving...' : 'Save Home Location',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircularProgressIndicator(strokeWidth: 4),
          SizedBox(height: 24),
          Text('Getting your location...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          Text('Please wait', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 100, color: Colors.red),
            const SizedBox(height: 24),
            const Text('Location Permission Needed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text('Please grant location permission to use this feature', style: TextStyle(fontSize: 18, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _requestLocationPermission,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
              child: const Text('Grant Permission', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    // Show prompt if home not set and not in setting mode
    if (_homeLocation == null && !_isSettingHomeMode) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.home_work, size: 100, color: Colors.blue),
              const SizedBox(height: 24),
              const Text('Set Your Home Location', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text(
                'Tap the "Set Home" button above to mark your home location on the map.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _enterSetHomeMode,
                icon: const Icon(Icons.edit_location, size: 24),
                label: const Text('Set Home on Map', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Status Card (hide when in setting mode)
          if (!_isSettingHomeMode && _homeLocation != null)
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
                      Text(_isInsideSafeZone ? '🏠' : '⚠️', style: const TextStyle(fontSize: 40)),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isInsideSafeZone ? 'You are Home' : 'Outside Safe Zone',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _isInsideSafeZone 
                                  ? 'Safe Zone ✓' 
                                  : _showRoute ? 'Showing route home 🗺️' : 'Alert!',
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
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        if (_isInsideSafeZone) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.straighten, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Distance from home: ${_formatDistance(_distanceFromHome)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                        if (_showRoute && _routeDistance != null) ...[
                          if (_isInsideSafeZone) ...[
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.route, size: 18, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Text('Walking distance: ${_formatDistance(_routeDistance)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 18, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Walking duration: ${_routeDuration ?? ''}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Instruction banner when in setting mode
          if (_isSettingHomeMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade300, width: 2),
              ),
              child: Row(
                children: const [
                  Icon(Icons.touch_app, color: Colors.blue, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap anywhere on the map to place your home location pin',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 20),
          
          // Map Container
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
                  // ✅ MODIFIED: Map with tap handler when in setting mode
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation ?? _homeLocation ?? _tempHomePin ?? LatLng(9.998418620839775, 76.361358164756),
                      initialZoom: _currentZoom,
                      minZoom: 5.0,
                      maxZoom: 18.0,
                      interactionOptions: InteractionOptions(
                        flags: _isSettingHomeMode 
                            ? InteractiveFlag.all & ~InteractiveFlag.rotate // Disable rotation in setting mode
                            : InteractiveFlag.all,
                      ),
                      onTap: _isSettingHomeMode
                          ? (tapPosition, latLng) {
                              setState(() {
                                _tempHomePin = latLng;
                              });
                              print('📍 Pin placed at: ${latLng.latitude}, ${latLng.longitude}');
                            }
                          : null,
                    ),
                    children: [
                        TileLayer(
                          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                          userAgentPackageName: 'com.example.elderly_care_app',
                        ),
                        
                        // Route polyline (only when not in setting mode and route exists)
                        if (!_isSettingHomeMode && _showRoute && _routePoints.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 5,
                                color: Colors.blue,
                                borderStrokeWidth: 2,
                                borderColor: Colors.white,
                              ),
                            ],
                          ),
                        
                        // Safe zone circle (only show when home is set and not in setting mode)
                        if (!_isSettingHomeMode && _homeLocation != null)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: _homeLocation!,
                                radius: _safeZoneRadius,
                                useRadiusInMeter: true,
                                color: Colors.green.withOpacity(0.2),
                                borderColor: Colors.green,
                                borderStrokeWidth: 3,
                              ),
                            ],
                          ),
                        
                        // Markers
                        MarkerLayer(
                          markers: [
                            // ✅ Home Location OR Temp Pin (when setting)
                            if (_isSettingHomeMode && _tempHomePin != null)
                              Marker(
                                point: _tempHomePin!,
                                width: 60,
                                height: 80,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(0.5),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.home, size: 28, color: Colors.white),
                                    ),
                                    Container(
                                      width: 4,
                                      height: 20,
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                              )
                            else if (_homeLocation != null)
                              Marker(
                                point: _homeLocation!,
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
                                  child: const Icon(Icons.home, size: 35, color: Colors.white),
                                ),
                              ),
                            
                            // Current Location (hide when in setting mode)
                            if (!_isSettingHomeMode && _currentLocation != null)
                              Marker(
                                point: _currentLocation!,
                                width: 50,
                                height: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.person, size: 30, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  
                  // Zoom Controls (hide when in setting mode)
                  if (!_isSettingHomeMode)
                    Positioned(
                      right: 16,
                      top: 16,
                      child: Column(
                        children: [
                          _buildZoomButton(Icons.add, _zoomIn),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade300, width: 2),
                            ),
                            child: Text(
                              '${_currentZoom.toStringAsFixed(0)}x',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildZoomButton(Icons.remove, _zoomOut),
                        ],
                      ),
                    ),
                  
                  // Control Buttons (hide when in setting mode)
                  if (!_isSettingHomeMode && _homeLocation != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildControlButton(
                              icon: Icons.my_location,
                              label: 'My Location',
                              onTap: _centerOnCurrentLocation,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildControlButton(
                              icon: Icons.home,
                              label: 'Home',
                              onTap: _centerOnHome,
                              color: Colors.blue,
                            ),
                          ),
                          if (!_isInsideSafeZone) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildControlButton(
                                icon: _isLoadingRoute 
                                    ? Icons.hourglass_empty 
                                    : (_showRoute ? Icons.close : Icons.directions),
                                label: _isLoadingRoute 
                                    ? 'Loading...' 
                                    : (_showRoute ? 'Hide Route' : 'Show Route'),
                                onTap: _isLoadingRoute ? () {} : _toggleRoute,
                                color: _showRoute ? Colors.orange : Colors.green,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  
                  // Status Badge (hide when in setting mode)
                  if (!_isSettingHomeMode && _homeLocation != null)
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          
          // Legend (hide when in setting mode)
          if (!_isSettingHomeMode && _homeLocation != null) ...[
            const SizedBox(height: 20),
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
                  _buildLegendItem(icon: Icons.home, color: Colors.blue, label: 'Home'),
                  _buildLegendItem(icon: Icons.person_pin_circle, color: Colors.red, label: 'You'),
                  _buildLegendItem(icon: Icons.circle_outlined, color: Colors.green, label: 'Safe Zone (${_safeZoneRadius.toInt()}m)'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

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
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({required IconData icon, required Color color, required String label}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
