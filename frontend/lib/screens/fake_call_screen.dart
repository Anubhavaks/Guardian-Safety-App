import 'package:flutter/material.dart';
import 'dart:async';

class FakeCallScreen extends StatefulWidget {
  final String callerName;
  
  // You can change "Dad" to "Mom", "Home", or "Police"
  const FakeCallScreen({super.key, this.callerName = "Dad"});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  bool isAnswered = false;
  int secondsElapsed = 0;
  Timer? _callTimer;

  // --- ANSWER THE CALL ---
  void _answerCall() {
    setState(() {
      isAnswered = true;
    });
    
    // Start the live call duration timer
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        secondsElapsed++;
      });
    });
    
    // NOTE: For the hackathon, you can optionally add the 'audioplayers' package 
    // later and play a pre-recorded MP3 here!
  }

  // --- END THE CALL ---
  void _endCall() {
    _callTimer?.cancel();
    Navigator.pop(context); // Close the screen and go back to the app
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  // Format seconds into 00:00
  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Pure black like a real lock screen
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // --- CALLER ID SECTION ---
            Column(
              children: [
                const SizedBox(height: 60),
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isAnswered ? _formatTime(secondsElapsed) : "Incoming call...",
                  style: TextStyle(
                    color: isAnswered ? Colors.white : Colors.grey.shade400,
                    fontSize: 18,
                  ),
                ),
              ],
            ),

            // --- THE BUTTONS ---
            Padding(
              padding: const EdgeInsets.only(bottom: 60.0, left: 40, right: 40),
              child: isAnswered 
                ? // 🟢 IF ANSWERED: Show only the red End Call button
                  Center(
                    child: GestureDetector(
                      onTap: _endCall,
                      child: Container(
                        height: 75,
                        width: 75,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 35),
                      ),
                    ),
                  )
                : // 🔴 IF RINGING: Show Decline and Accept buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // DECLINE BUTTON
                      GestureDetector(
                        onTap: _endCall,
                        child: Column(
                          children: [
                            Container(
                              height: 75,
                              width: 75,
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.call_end, color: Colors.white, size: 35),
                            ),
                            const SizedBox(height: 10),
                            const Text("Decline", style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      
                      // ACCEPT BUTTON
                      GestureDetector(
                        onTap: _answerCall,
                        child: Column(
                          children: [
                            Container(
                              height: 75,
                              width: 75,
                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                              child: const Icon(Icons.call, color: Colors.white, size: 35),
                            ),
                            const SizedBox(height: 10),
                            const Text("Accept", style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}