import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; 

class ApiService {
  // 🟢 CHANGE THIS for the Demo:
  // If using Android Emulator: 'http://10.0.2.2:8000'
  // If using Physical Phone: Use your Laptop's IP (e.g., 'http://192.168.1.XX:8000')
  static const String baseUrl = kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

  // --- REGISTER ---
  static Future<bool> register(String name, String phone, String password, String pin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': name,
          'phone_number': phone,
          'password': password,
          'safe_pin': pin,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Register Error: $e");
      return false;
    }
  }

  // --- LOGIN ---
  static Future<bool> login(String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': phone,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['access_token']);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Login Error: $e");
      return false;
    }
  }

  // --- TRIGGER SOS ---
  static Future<Map<String, dynamic>?> triggerSos(String token, {double? lat, double? lng}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/alerts/sos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'alert_type': 'MANUAL_BUTTON',
          'latitude': lat,
          'longitude': lng,
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body); 
      }
      return null;
    } catch (e) {
      debugPrint("SOS Trigger Error: $e");
      return null;
    }
  }

  // --- CANCEL SOS ---
  static Future<bool> cancelSos(int alertId, String pin, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/alerts/$alertId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'safe_pin': pin}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Cancel SOS Error: $e");
      return false;
    }
  }

  // --- ADD CONTACT ---
  static Future<bool> addContact(String name, String phone, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/contacts/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'contact_name': name,
          'contact_phone': phone,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Add Contact Error: $e");
      return false;
    }
  }

  // --- GET CONTACTS ---
  static Future<List<dynamic>> getContacts(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/contacts/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint("Get Contacts Error: $e");
      return [];
    }
  }

  // --- UPLOAD AUDIO EVIDENCE ---
  static Future<bool> uploadAudio(int alertId, String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/alerts/$alertId/audio'),
      );

      if (kIsWeb) {
        final response = await http.get(Uri.parse(filePath));
        request.files.add(http.MultipartFile.fromBytes('file', response.bodyBytes, filename: 'web_evidence.m4a'));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      }

      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Audio upload error: $e");
      return false;
    }
  }

  // --- DELETE A CONTACT ---
  static Future<bool> deleteContact(int contactId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/contacts/$contactId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error deleting contact: $e");
      return false;
    }
  }

  // --- FETCH HEATMAP DATA ---
  static Future<List<dynamic>> getHeatmapData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/alerts/history/heatmap'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint("Heatmap Error: $e");
      return [];
    }
  }
}