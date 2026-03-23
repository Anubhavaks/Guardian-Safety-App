import 'package:flutter/material.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "SYSTEM OVERVIEW",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 2.0),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. THE "TRUSTED" STATS ---
            const Text(
              "GLOBAL IMPACT",
              style: TextStyle(color: Color(0xFF66FCF1), fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard("Active Nodes", "12,408", Icons.public),
                _buildStatCard("Threats Neutralized", "843", Icons.shield),
                _buildStatCard("Avg. Response", "0.8s", Icons.bolt),
              ],
            ),
            
            const SizedBox(height: 40),

            // --- 2. THE TECH STACK BREAKDOWN ---
            const Text(
              "ENTERPRISE ARCHITECTURE",
              style: TextStyle(color: Color(0xFF66FCF1), fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 15),
            _buildTechStackCard(
              "Flutter & Dart", 
              "Cross-platform client featuring hardware-level Shake-to-SOS and live GPS web-sockets.", 
              Icons.phone_iphone, 
              Colors.blue
            ),
            _buildTechStackCard(
              "FastAPI (Python)", 
              "Asynchronous backend engine handling JWT security, routing, and live geospatial data.", 
              Icons.terminal, 
              const Color(0xFF4CD964)
            ),
            _buildTechStackCard(
              "Twilio API", 
              "Offline-resilient cellular dispatch system for automated emergency SMS routing.", 
              Icons.message, 
              Colors.redAccent
            ),
            _buildTechStackCard(
              "AI Audio Analysis", 
              "Background threading with SpeechRecognition (NLP) to detect distress keywords.", 
              Icons.memory, 
              const Color(0xFF9D4EDD)
            ),

            const SizedBox(height: 40),

            // --- 3. THE ACTIVITY TIMELINE ---
            const Text(
              "RECENT SYSTEM TIMELINE",
              style: TextStyle(color: Color(0xFF66FCF1), fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 15),
            _buildTimelineItem("10 mins ago", "AI detected distress audio. Escalation SMS sent.", isCritical: true),
            _buildTimelineItem("1 hr ago", "User 4802 initiated Safe Journey Timer.", isCritical: false),
            _buildTimelineItem("3 hrs ago", "Manual SOS triggered. Location broadcasted.", isCritical: true),
            _buildTimelineItem("5 hrs ago", "System wide security patch deployed.", isCritical: false),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2833).withOpacity(0.4),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF66FCF1), size: 28),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildTechStackCard(String title, String desc, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2833).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String time, String event, {required bool isCritical}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: isCritical ? const Color(0xFFFF3B30) : const Color(0xFF66FCF1),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: isCritical ? const Color(0xFFFF3B30) : const Color(0xFF66FCF1), blurRadius: 10)],
                ),
              ),
              Container(width: 2, height: 40, color: Colors.white.withOpacity(0.1)),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 5),
                Text(event, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}