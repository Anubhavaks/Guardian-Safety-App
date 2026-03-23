import 'package:flutter/material.dart';
import 'dart:async';

class FakeCallScreen extends StatefulWidget {
  final String callerName;
  
  const FakeCallScreen({super.key, this.callerName = "Dad"});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  bool isAnswered = false;
  int secondsElapsed = 0;
  Timer? _callTimer;

  void _answerCall() {
    setState(() {
      isAnswered = true;
    });
    
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        secondsElapsed++;
      });
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          // Subtle gradient to prevent pure flatness
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [Colors.white.withOpacity(0.05), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // --- CALLER ID SECTION ---
              Column(
                children: [
                  const SizedBox(height: 80),
                  // User Avatar (Standard Call Look)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 60),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isAnswered ? _formatTime(secondsElapsed) : "Mobile",
                    style: TextStyle(
                      color: isAnswered ? const Color(0xFF66FCF1) : Colors.grey.shade500,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),

              // --- BUTTONS ---
              Padding(
                padding: const EdgeInsets.only(bottom: 80.0, left: 50, right: 50),
                child: isAnswered 
                  ? _buildAnsweredControls() 
                  : _buildIncomingControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // UI when the call is active
  Widget _buildAnsweredControls() {
    return Column(
      children: [
        // Mock Grid of call features (Mute, Keypad, Speaker)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCallActionIcon(Icons.mic_off, "Mute"),
            _buildCallActionIcon(Icons.dialpad, "Keypad"),
            _buildCallActionIcon(Icons.volume_up, "Speaker"),
          ],
        ),
        const SizedBox(height: 60),
        GestureDetector(
          onTap: _endCall,
          child: Container(
            height: 75,
            width: 75,
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0xFFFF3B30), blurRadius: 20)],
            ),
            child: const Icon(Icons.call_end, color: Colors.white, size: 35),
          ),
        ),
      ],
    );
  }

  // UI for the incoming ringing state
  Widget _buildIncomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // DECLINE
        Column(
          children: [
            GestureDetector(
              onTap: _endCall,
              child: Container(
                height: 70,
                width: 70,
                decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
                child: const Icon(Icons.call_end, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 12),
            const Text("Decline", style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        // ACCEPT
        Column(
          children: [
            GestureDetector(
              onTap: _answerCall,
              child: Container(
                height: 70,
                width: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CD964), // Modern iOS/Android Green
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0xFF4CD964), blurRadius: 20)],
                ),
                child: const Icon(Icons.call, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 12),
            const Text("Accept", style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildCallActionIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}