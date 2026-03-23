import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_service.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  GoogleMapController? mapController; // Changed to nullable
  Set<Circle> dangerZones = {};
  bool isLoading = true;

  final CameraPosition initialPosition = const CameraPosition(
    target: LatLng(28.9845, 77.7064), 
    zoom: 14.0,
  );

  // --- DARK MAP JSON STYLE ---
  final String _darkMapStyle = '''
  [
    { "elementType": "geometry", "stylers": [ { "color": "#121418" } ] },
    { "elementType": "labels.text.stroke", "stylers": [ { "color": "#121418" } ] },
    { "elementType": "labels.text.fill", "stylers": [ { "color": "#746855" } ] },
    { "featureType": "road", "elementType": "geometry", "stylers": [ { "color": "#1f2833" } ] },
    { "featureType": "road", "elementType": "geometry.stroke", "stylers": [ { "color": "#1f2833" } ] },
    { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#0b0c10" } ] }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadDangerZones();
  }

  Future<void> _loadDangerZones() async {
    final data = await ApiService.getHeatmapData();
    Set<Circle> newZones = {};
    int idCounter = 0;

    for (var point in data) {
      newZones.add(
        Circle(
          circleId: CircleId('zone_$idCounter'),
          center: LatLng(point['lat'], point['lng']),
          radius: 150, 
          fillColor: const Color(0xFFFF3B30).withOpacity(0.2), // Faded neon red
          strokeColor: const Color(0xFFFF3B30).withOpacity(0.6),
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
    // APPLY THE DARK STYLE
    controller.setMapStyle(_darkMapStyle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "SAFETY RADAR",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 2.0),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF66FCF1)))
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: initialPosition,
                  circles: dangerZones,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false, // We'll use a custom button
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                ),
          
          // --- LEGEND OVERLAY ---
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2833).withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFF3B30)),
                    ),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("High-Risk Zone", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text("Historical SOS events detected here.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}