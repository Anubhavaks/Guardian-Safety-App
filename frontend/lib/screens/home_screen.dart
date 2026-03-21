import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import 'contacts_screen.dart';
import 'login_screen.dart';
import 'package:shake/shake.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:background_sms/background_sms.dart';
import 'package:permission_handler/permission_handler.dart';
import 'fake_call_screen.dart';
import 'heatmap_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- CHECK-IN TIMER VARIABLES ---
  Timer? _checkInTimer;
  int _timeRemaining = 0;
  bool _isTimerActive = false;
  bool isEmergencyActive = false;
  int? currentAlertId;
  final TextEditingController pinController = TextEditingController();

  // --- LIVE TRACKING VARIABLES ---
  WebSocketChannel? _channel;
  StreamSubscription<Position>? _positionStream;
  final AudioRecorder _audioRecorder = AudioRecorder();

  ShakeDetector? _shakeDetector; // <-- ADD THIS VARIABLE

 @override
  void initState() {
    super.initState();
    
    // START THE SHAKE RADAR
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: (_) { // <-- We changed () to (_) right here!
        // Only trigger if an emergency isn't ALREADY active
        if (!isEmergencyActive) {
          print("📱 SHAKE DETECTED! Triggering SOS...");
          _activateSOS();
        }
      },
      minimumShakeCount: 3, 
      shakeThresholdGravity: 2.7, 
    );
  }

  @override
  void dispose() {
    _shakeDetector?.stopListening();
    _stopLiveTracking(); // Clean up if the screen is ever destroyed
    pinController.dispose();
    super.dispose();
  }

  // --- START LIVE TRACKING ---
  void _startLiveTracking(int alertId) {

    // 1. Open the WebSocket connection to FastAPI
    // Notice it starts with ws:// and uses your real IP!
    final wsUrl = Uri.parse('ws://localhost:8000/ws/location/$alertId');

    // 2. Set the radar accuracy (updates every 5 meters)
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, 
    );

    // 3. Start listening to the phone's GPS continuously
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        if (_channel != null) {
          // Send the live movement JSON to the Python backend
          final data = jsonEncode({
            'latitude': position.latitude,
            'longitude': position.longitude,
          });
          _channel!.sink.add(data);
        }
      },
    );
  }

  // --- STOP LIVE TRACKING ---
  void _stopLiveTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> _captureAudioEvidence(int alertId) async {
    try {
      // 1. Ask the user for microphone permission
      if (await _audioRecorder.hasPermission()) {
        String path = '';
        
        // 2. Figure out where to save the file temporarily
        if (!kIsWeb) {
          final dir = await getTemporaryDirectory();
          path = '${dir.path}/evidence_$alertId.m4a';
        }

        // 3. Start Recording!
        await _audioRecorder.start(const RecordConfig(), path: path);
        print("🎙️ RECORDING EVIDENCE FOR 10 SECONDS...");

        // 4. Wait exactly 10 seconds in the background
        await Future.delayed(const Duration(seconds: 10));

        // 5. Stop recording and get the file path
        final String? finalPath = await _audioRecorder.stop();
        print("🛑 Recording stopped. File saved at: $finalPath");

        // 6. Upload to the Python Backend
        if (finalPath != null) {
          bool success = await ApiService.uploadAudio(alertId, finalPath);
          if (success) {
            print("✅ AUDIO EVIDENCE SUCCESSFULLY UPLOADED TO BACKEND!");
          }
        }
      }
    } catch (e) {
      print("Microphone error: $e");
    }
  }

  Future<void> _activateSOS() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      double? lat;
      double? lng;

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (e) {
        print("Location error: $e");
      }

      // --- THE OFFLINE TRAP ---
      try {
        // Try the normal internet route first
        final alertData = await ApiService.triggerSos(token, lat: lat, lng: lng);
        
        if (alertData != null) {
          setState(() {
            isEmergencyActive = true;
            currentAlertId = alertData['id'];
          });
          
          _startLiveTracking(currentAlertId!);
          _captureAudioEvidence(currentAlertId!);
        } 
      } catch (e) {
        // 🔥 IF THE API FAILS (NO INTERNET), THE TRAP CATCHES IT HERE 🔥
        print("API FAILED: $e");
        
        setState(() {
           isEmergencyActive = true; // Still show the UI as active!
        });
        
        // FIRE THE OFFLINE SMS PROTOCOL
        await _sendOfflineSMS(lat, lng);
      }

      // 1. Send the initial SOS HTTP request
      final alertData = await ApiService.triggerSos(token, lat: lat, lng: lng);
      
      if (alertData != null) {
        setState(() {
          isEmergencyActive = true;
          currentAlertId = alertData['id'];
        });
        
        // 2. ACTIVATE THE WEBSOCKET RADAR!
        _startLiveTracking(currentAlertId!);
        
        // 3. START THE SECRET AUDIO RECORDING!
        _captureAudioEvidence(currentAlertId!);
      } 
      else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to trigger SOS. Check connection.")),
        );
      }
    }
  }

  // --- OFFLINE SMS FALLBACK ENGINE ---
  Future<void> _sendOfflineSMS(double? lat, double? lng) async {
    print("📡 NO INTERNET DETECTED! INITIATING OFFLINE SMS FALLBACK...");

    // 1. Ask for SMS Permission
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }

    if (status.isGranted) {
      // 2. Format the Google Maps Link
      String locationLink = (lat != null && lng != null) 
          ? "http://maps.google.com/?q=$lat,$lng" 
          : "Location unavailable";
          
      String message = "🚨 URGENT: I am in danger and have no internet! My last known location is: $locationLink";

      // 3. Get Contacts from Local Cache
      // (We will need to make sure contacts_screen.dart saves to this list!)
      final prefs = await SharedPreferences.getInstance();
      final String? contactsJson = prefs.getString('emergency_contacts_cache');
      
      if (contactsJson != null) {
        final List<dynamic> decoded = jsonDecode(contactsJson);
        
        // 4. Blast the SMS to every contact
        for (var contact in decoded) {
          String phone = contact['contact_phone'];
          
          SmsStatus result = await BackgroundSms.sendMessage(
            phoneNumber: phone, 
            message: message
          );
          
          if (result == SmsStatus.sent) {
            print("✅ OFFLINE SMS SENT TO: $phone");
          } else {
            print("❌ FAILED TO SEND OFFLINE SMS TO: $phone");
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Offline SOS Dispatched via Native SMS!"), backgroundColor: Colors.orange),
        );
      } else {
         print("⚠️ No offline contacts cached!");
      }
    } else {
      print("❌ SMS Permission Denied!");
    }
  }

  // --- START THE DEAD MAN'S SWITCH ---
  void _startSafetyTimer(int minutes) {
    setState(() {
      _timeRemaining = minutes * 60; // Convert minutes to seconds
      _isTimerActive = true;
    });

    _checkInTimer?.cancel(); // Cancel any existing timers
    _checkInTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
      } else {
        // TIMER HIT ZERO! FIRE THE SOS!
        timer.cancel();
        setState(() {
          _isTimerActive = false;
        });
        print("⏰ TIMER EXPIRED! AUTO-TRIGGERING SOS...");
        _activateSOS(); // <--- BOOM.
      }
    });
  }

  // --- I AM SAFE (CANCEL TIMER) ---
  void _cancelSafetyTimer() {
    _checkInTimer?.cancel();
    setState(() {
      _isTimerActive = false;
      _timeRemaining = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Check-in successful. Stay safe!"), backgroundColor: Colors.green),
    );
  }

  Future<void> _cancelSOS() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final pin = pinController.text;

    if (token != null && currentAlertId != null) {
      final success = await ApiService.cancelSos(currentAlertId!, pin, token);
      if (success) {
        // TURN OFF THE RADAR AND CLOSE THE CONNECTION
        _stopLiveTracking();
        
        setState(() {
          isEmergencyActive = false;
          currentAlertId = null;
          pinController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Alert Cancelled Successfully", style: TextStyle(color: Colors.green))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid PIN. Cannot cancel alert.", style: TextStyle(color: Colors.red))),
        );
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); 
    
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
// --- SECURE DISMANTLE DIALOG ---
  void _showDismantleDialog() {
    // 1. REMOVED the duplicate pinController declaration here so it uses your global one!
    pinController.clear(); // Clear out any old numbers before showing the box

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        title: const Text(
          "SECURE DISMANTLE", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        content: TextField(
          controller: pinController, // Now using the correct global controller
          keyboardType: TextInputType.number,
          obscureText: true, 
          style: TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8.0),
          textAlign: TextAlign.center,
          decoration: InputDecoration( 
            hintText: "****",
            hintStyle: TextStyle(color: Colors.white30), 
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context); // Close the dialog box
              
              // 2. THIS IS THE MAGIC LINK! 
              // Send the PIN to the Python backend to verify it and shut down the system
              _cancelSOS(); 
            },
            child: const Text("CONFIRM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TIMER SETUP DIALOG ---
  void _showTimerSetupDialog() {
    TextEditingController minutesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A2E), // Dark theme
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.orangeAccent, width: 1), // Orange border for timer!
        ),
        title: Text(
          "SET JOURNEY TIMER",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "How many minutes until you reach your destination?",
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            TextField(
              controller: minutesController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "15",
                hintStyle: TextStyle(color: Colors.grey),
                suffixText: " min",
                suffixStyle: TextStyle(color: Colors.grey, fontSize: 16),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () {
              // 1. Grab the number they typed in
              int? customMinutes = int.tryParse(minutesController.text);
              
              // 2. Make sure it's a valid number greater than 0
              if (customMinutes != null && customMinutes > 0) {
                Navigator.pop(context); // Close the dialog
                _startSafetyTimer(customMinutes); // Start the timer with THEIR number!
              } else {
                // Show an error if they typed something weird
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Please enter a valid number of minutes."), 
                    backgroundColor: Colors.red
                  ),
                );
              }
            },
            child: Text("START", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  // --- TRIGGER THE FAKE CALL ---
  void _scheduleFakeCall() {
    // Show a stealthy confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Fake call scheduled in 10 seconds. Act natural."), 
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 3),
      ),
    );

    // Wait exactly 10 seconds, then push the full-screen call UI
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FakeCallScreen(callerName: "Dad")),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // A sleek, dark theme makes the red SOS button pop!
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Deep navy/dark background
      appBar: AppBar(
        title: const Text(
          'GUARDIAN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          // THE NEW HEATMAP BUTTON
          IconButton(
            icon: const Icon(Icons.map_outlined, color: Colors.orangeAccent, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HeatmapScreen()),
              );
            },
          ),
          // THE FAKE CALL BUTTON
          IconButton(
            icon: const Icon(Icons.phone_in_talk_outlined, color: Colors.white, size: 28),
            onPressed: () {
              if (!isEmergencyActive) _scheduleFakeCall();
            },
          ),
          // THE NEW TIMER BUTTON
          IconButton(
            icon: const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
            onPressed: () {
              // Open the setup dialog instead of hardcoding 1 minute!
              if (!isEmergencyActive) {
                _showTimerSetupDialog(); 
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add_outlined, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const ContactsScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- STATUS INDICATOR ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isEmergencyActive 
                    ? Colors.redAccent.withOpacity(0.2) 
                    : Colors.greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isEmergencyActive ? Colors.redAccent : Colors.greenAccent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEmergencyActive ? Icons.warning_amber_rounded : Icons.shield_outlined,
                    color: isEmergencyActive ? Colors.redAccent : Colors.greenAccent,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEmergencyActive ? "EMERGENCY ACTIVE" : "SYSTEM STANDBY",
                    style: TextStyle(
                      color: isEmergencyActive ? Colors.redAccent : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // --- THE AUTO-ALERT TIMER UI ---
            if (_isTimerActive && !isEmergencyActive)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Column(
                  children: [
                    Text(
                      "AUTO-SOS IN: ${_timeRemaining ~/ 60}:${(_timeRemaining % 60).toString().padLeft(2, '0')}",
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _cancelSafetyTimer,
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text("I'M SAFE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),
            
            const Spacer(),

            // --- THE HERO SOS BUTTON ---
            GestureDetector(
              onTap: isEmergencyActive ? null : _activateSOS,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isEmergencyActive
                        ? [Colors.grey.shade800, Colors.grey.shade900] // Disabled state
                        : [const Color(0xFFFF416C), const Color(0xFFFF4B2B)], // Vibrant Red Gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isEmergencyActive 
                          ? Colors.transparent 
                          : const Color(0xFFFF4B2B).withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    isEmergencyActive ? "DISPATCHED" : "SOS",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // --- LIVE FEEDBACK CARDS (Only shows when SOS is active) ---
            if (isEmergencyActive)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      children: [
                        _buildFeedbackRow(Icons.location_on, "Transmitting Live GPS", Colors.blueAccent),
                        const SizedBox(height: 15),
                        _buildFeedbackRow(Icons.mic, "Recording Secure Audio", Colors.orangeAccent),
                        const SizedBox(height: 15),
                        _buildFeedbackRow(Icons.sms, "Alerting Emergency Contacts", Colors.greenAccent),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40), // Space before the button
                  
                  // --- DISMANTLE BUTTON ---
                  // --- DISMANTLE BUTTON ---
                  TextButton.icon(
                    onPressed: _showDismantleDialog, // <--- JUST CALL THE NEW FUNCTION HERE!
                    icon: const Icon(Icons.cancel_outlined, color: Colors.white70),
                    label: const Text(
                      "DISMANTLE SOS",
                      style: TextStyle(
                        color: Colors.white70, 
                        letterSpacing: 1.5, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      backgroundColor: Colors.white.withOpacity(0.1), 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),

            const Spacer(),
          ],
        ),
      ),
    );
  }

  // A tiny helper widget to make the feedback rows look clean
  Widget _buildFeedbackRow(IconData icon, String text, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 15),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}