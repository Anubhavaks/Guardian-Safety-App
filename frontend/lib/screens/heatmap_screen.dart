import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_service.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  late GoogleMapController mapController;
  Set<Circle> dangerZones = {};
  bool isLoading = true;

  // Set the initial camera position (e.g., center of Meerut or your campus)
  final CameraPosition initialPosition = const CameraPosition(
    target: LatLng(28.9845, 77.7064), // Defaulting to Meerut coordinates!
    zoom: 13.0,
  );

  @override
  void initState() {
    super.initState();
    _loadDangerZones();
  }

  Future<void> _loadDangerZones() async {
    // 1. Ask FastAPI for the historical SOS coordinates
    final data = await ApiService.getHeatmapData();
    
    Set<Circle> newZones = {};
    int idCounter = 0;

    // 2. Turn every SOS point into a glowing red danger zone on the map
    for (var point in data) {
      newZones.add(
        Circle(
          circleId: CircleId('zone_$idCounter'),
          center: LatLng(point['lat'], point['lng']),
          radius: 200, // 200-meter danger radius
          fillColor: Colors.redAccent.withOpacity(0.3), // Semi-transparent red
          strokeColor: Colors.red,
          strokeWidth: 2,
        ),
      );
      idCounter++;
    }

    setState(() {
      dangerZones = newZones;
      isLoading = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // Optional: You can set a custom dark map style here later!
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Your signature dark navy
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "SAFETY HEATMAP",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2.0),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: initialPosition,
              circles: dangerZones, // This draws all our red blobs!
              myLocationEnabled: true, // Shows the user's current blue dot
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
            ),
    );
  }
}