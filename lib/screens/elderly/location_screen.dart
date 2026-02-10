import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // Map controller
  final MapController _mapController = MapController();

  // Default location (you can change this to user's actual location)
  final LatLng _homeLocation = LatLng(
    9.998418620839775,
    76.361358164756,
  ); // my hostel
  final double _safeZoneRadius = 1000.0; // 1km radius

  // Current zoom level
  double _currentZoom = 15.0;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // Zoom in function
  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(5.0, 18.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  // Zoom out function
  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(5.0, 18.0);
      _mapController.move(_mapController.camera.center, _currentZoom);
    });
  }

  // Center on home
  void _centerOnHome() {
    setState(() {
      _currentZoom = 15.0;
      _mapController.move(_homeLocation, _currentZoom);
    });
  }

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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status Card
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade300, width: 4),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text('🏠', style: TextStyle(fontSize: 50)),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'You are Home',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Safe Zone ✓',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
                        initialCenter: _homeLocation,
                        initialZoom: _currentZoom,
                        minZoom: 5.0,
                        maxZoom: 18.0,
                      ),
                      children: [
                        // Tile Layer (OpenStreetMap)
                        TileLayer(
                          urlTemplate:
                              "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
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
                            // Current location
                            Marker(
                              point: LatLng(
                                9.993977613864601,
                                76.35824717746722,
                              ), // rajagiri college
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.person_pin_circle,
                                size: 40,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Zoom Controls (Right Side)
                    Positioned(
                      right: 16,
                      top: 16,
                      child: Column(
                        children: [
                          // Zoom In Button
                          Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: _zoomIn,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 32,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Zoom Level Indicator
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

                          // Zoom Out Button
                          Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: _zoomOut,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade300,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  size: 32,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Center on Home Button (Bottom)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(15),
                        child: InkWell(
                          onTap: _centerOnHome,
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.my_location,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Center on Home',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Location Info Card (Top Left)
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
                          border: Border.all(color: Colors.green, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Safe Zone',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
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
                    label: 'Your Home',
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
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
