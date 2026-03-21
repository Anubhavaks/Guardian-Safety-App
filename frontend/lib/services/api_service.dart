import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Helps us check if we are on Web or Mobile
import 'package:http/http.dart' as http;

class ApiService {
  // Using localhost since you are running this on Chrome web browser
  static const String baseUrl = 'http://localhost:8000';

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
      print("Register Error: $e");
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
      print("Login Error: $e");
      return false;
    }
  }

  // --- TRIGGER SOS ---
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
      print("SOS Trigger Error: $e");
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
      print("Cancel SOS Error: $e");
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
      print("Add Contact Error: $e");
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
      print("Get Contacts Error: $e");
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
        // Web (Chrome) saves files as temporary blob URLs, so we have to convert it to bytes first
        final response = await http.get(Uri.parse(filePath));
        request.files.add(http.MultipartFile.fromBytes('file', response.bodyBytes, filename: 'web_evidence.m4a'));
      } else {
        // Physical mobile phones use standard file paths
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      }

      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print("Audio upload error: $e");
      return false;
    }
  }
  // --- DELETE A CONTACT ---
  static Future<bool> deleteContact(int contactId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/contacts/$contactId'), // Make sure this matches your FastAPI route!
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting contact: $e");
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
      print("Heatmap Error: $e");
      return [];
    }
  }
}

