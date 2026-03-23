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
import 'analytics_screen.dart';

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
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Incoming call in 10 seconds..."), 
      backgroundColor: Colors.blueGrey,
    ),
  );

  Future.delayed(const Duration(seconds: 10), () {
    // CRITICAL: Check if the screen is still "mounted" before navigating
    if (mounted && !isEmergencyActive) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FakeCallScreen(callerName: "Dad")),
      );
    }
  });
}

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10), // The deep dark background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.shield_moon, color: Color(0xFF66FCF1), size: 28),
            const SizedBox(width: 10),
            const Text(
              "GuardianAI",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
             // --- 1. LIVE SYSTEM STATUS CARD ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2833).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("System Status", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        _buildStatusIndicator(),
                      ],
                    ),
                    
                    // 👇 NEW: THE LIVE COUNTDOWN ROW 👇
                    // 👇 THE UPGRADED COUNTDOWN ROW 👇
                    if (_isTimerActive) ...[
                      const Divider(color: Colors.white10, height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: Color(0xFF66FCF1), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_timeRemaining),
                                style: const TextStyle(
                                  color: Color(0xFF66FCF1), 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 18,
                                  fontFamily: 'monospace', 
                                ),
                              ),
                            ],
                          ),
                          // THE NEW "I'M SAFE" CANCEL BUTTON
                          TextButton.icon(
                            onPressed: _cancelSafetyTimer, // This calls your existing cancel function!
                            icon: const Icon(Icons.check_circle, color: Color(0xFF4CD964), size: 18),
                            label: const Text(
                              "I'M SAFE", 
                              style: TextStyle(color: Color(0xFF4CD964), fontWeight: FontWeight.bold)
                            ),
                          )
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 50),

              // --- 2. THE HERO SOS BUTTON ---
              GestureDetector(
                onTap: () {
  if (!isEmergencyActive) {
    // Start the emergency
    _activateSOS();
  } else {
    // FIXED: This MUST call the PIN dialog to turn it off
    _showDismantleDialog();
  }
},
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isEmergencyActive ? Colors.transparent : const Color(0xFFFF3B30),
                    border: isEmergencyActive ? Border.all(color: const Color(0xFFFF3B30), width: 4) : null,
                    boxShadow: isEmergencyActive ? [] : [
                      BoxShadow(
                        color: const Color(0xFFFF3B30).withOpacity(0.6),
                        blurRadius: 60,
                        spreadRadius: 15,
                      )
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isEmergencyActive ? Icons.lock_outline : Icons.power_settings_new, 
                          color: isEmergencyActive ? const Color(0xFFFF3B30) : Colors.white, 
                          size: 60
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isEmergencyActive ? "DISARM" : "SOS",
                          style: TextStyle(
                            color: isEmergencyActive ? const Color(0xFFFF3B30) : Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 60),

// --- 3. ENTERPRISE FEATURE GRID ---
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFeatureCard(
                        title: "Heatmap",
                        icon: Icons.map_outlined,
                        color: const Color(0xFF66FCF1),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const HeatmapScreen()));
                        },
                      ),
                      _buildFeatureCard(
                        title: "Fake Call",
                        icon: Icons.phone_in_talk,
                        color: const Color(0xFF9D4EDD), 
                        onTap: () {
                          if (!isEmergencyActive) _scheduleFakeCall();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFeatureCard(
                        title: "Contacts", // FIXED: Changed title from Timer to Contacts
                        icon: Icons.shield_outlined, // FIXED: Icon for Contacts
                        color: const Color(0xFFFF9500), 
                        onTap: () {
                          // FIXED: Now navigates to ContactsScreen
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactsScreen()));
                        },
                      ),
                      _buildFeatureCard(
                        title: "Timer",
                        icon: Icons.timer,
                        color: const Color(0xFFC5C6C7), 
                        onTap: () {
                          // FIXED: Now triggers your orange Setup Dialog
                          _showTimerSetupDialog();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // --- 4. SYSTEM ANALYTICS BUTTON (NEW) ---
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsScreen()));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2833).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF66FCF1).withOpacity(0.3), width: 1),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, color: Color(0xFF66FCF1)),
                      SizedBox(width: 10),
                      Text(
                        "SYSTEM ANALYTICS & ARCHITECTURE",
                        style: TextStyle(
                          color: Color(0xFF66FCF1), 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40), // Give it some breathing room at the bottom
            ],
          ),
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
  // --- GLASSMORPHISM CARD WIDGET ---
  Widget _buildFeatureCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.42,
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2833).withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
  // --- HELPER 1: FORMAT SECONDS TO MM:SS ---
  String _formatDuration(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // --- HELPER 2: SYSTEM STATUS INDICATOR ---
  Widget _buildStatusIndicator() {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: isEmergencyActive ? const Color(0xFFFF3B30) : const Color(0xFF66FCF1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: isEmergencyActive ? const Color(0xFFFF3B30) : const Color(0xFF66FCF1), 
                blurRadius: 10
              )
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isEmergencyActive ? "EMERGENCY ACTIVE" : "ARMED & READY", 
          style: TextStyle(
            color: isEmergencyActive ? const Color(0xFFFF3B30) : const Color(0xFF66FCF1), 
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 1.5
          )
        ),
      ],
    );
  }
}
// 👇 PASTE THIS AT THE VERY BOTTOM OF YOUR FILE 👇

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int selectedMinutes = 15;
  int remainingSeconds = 0;
  Timer? _countdownTimer;
  bool isRunning = false;

  void _startTimer() {
    setState(() {
      remainingSeconds = selectedMinutes * 60;
      isRunning = true;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        _countdownTimer?.cancel();
        // TRIGGER YOUR ACTUAL SOS HERE!
        print("🚨 DEAD MAN'S SWITCH TRIGGERED 🚨");
        setState(() => isRunning = false);
      }
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    setState(() => isRunning = false);
  }

  String get _formattedTime {
    int m = remainingSeconds ~/ 60;
    int s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Dead Man's Switch", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2833).withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
              ),
              child: Column(
                children: [
                  isRunning 
                    ? Text(_formattedTime, style: const TextStyle(color: Color(0xFF66FCF1), fontSize: 60, fontWeight: FontWeight.bold, fontFamily: 'monospace'))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white, size: 30),
                            onPressed: () => setState(() { if (selectedMinutes > 1) selectedMinutes--; }),
                          ),
                          Text("$selectedMinutes min", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 30),
                            onPressed: () => setState(() { selectedMinutes++; }),
                          ),
                        ],
                      ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRunning ? const Color(0xFFFF3B30) : const Color(0xFF66FCF1),
                      foregroundColor: isRunning ? Colors.white : Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: isRunning ? _stopTimer : _startTimer,
                    child: Text(isRunning ? "CANCEL TIMER" : "START TIMER", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
// 👇 PASTE THIS RIGHT BELOW YOUR TIMERSCREEN CLASS 👇

// 👇 REPLACE YOUR OLD CONTACTSSCREEN WITH THIS 👇
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // Your live list of contacts
  List<Map<String, String>> savedContacts = [
    {"name": "Mom", "phone": "+91 98765-XXXXX", "initial": "M", "color": "0xFF66FCF1"},
    {"name": "Dad", "phone": "+91 87654-XXXXX", "initial": "D", "color": "0xFFFF9500"},
  ];

  void _showAddContactDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2833),
        title: const Text("Add Contact", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Name", labelStyle: TextStyle(color: Colors.grey)),
            ),
            TextField(
              controller: phoneController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Phone Number", labelStyle: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                setState(() {
                  savedContacts.add({
                    "name": nameController.text,
                    "phone": phoneController.text,
                    "initial": nameController.text[0].toUpperCase(),
                    "color": "0xFF9D4EDD", // Purple for new contacts
                  });
                });
                Navigator.pop(context);
              }
            }, 
            child: const Text("Save", style: TextStyle(color: Color(0xFF66FCF1)))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Emergency Contacts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Dynamically generate the list!
            ...savedContacts.map((contact) => Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: _buildContactCard(
                contact["name"]!, 
                contact["phone"]!, 
                contact["initial"]!, 
                Color(int.parse(contact["color"]!))
              ),
            )),
            
            const SizedBox(height: 15),
            
            // The Add Contact Button
            GestureDetector(
              onTap: _showAddContactDialog,
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.transparent, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF66FCF1).withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_add_alt_1, color: Color(0xFF66FCF1)),
                    SizedBox(width: 10),
                    Text("Add Trusted Contact", style: TextStyle(color: Color(0xFF66FCF1), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(String name, String phone, String initial, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2833).withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: accentColor.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: accentColor, width: 2)),
            child: Center(child: Text(initial, style: TextStyle(color: accentColor, fontSize: 20, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
          Icon(Icons.star, color: accentColor, size: 24),
        ],
      ),
    );
  }
}