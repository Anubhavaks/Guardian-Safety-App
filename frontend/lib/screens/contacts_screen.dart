import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'dart:convert';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<dynamic> contacts = [];
  bool isLoading = true;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  // --- YOUR ORIGINAL LOGIC: FETCHING & CACHING ---
  Future<void> _fetchContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token != null) {
      final fetchedContacts = await ApiService.getContacts(token);
      
      // Update the Offline Cache for the SMS Fallback
      final String encodedContacts = jsonEncode(fetchedContacts);
      await prefs.setString('emergency_contacts_cache', encodedContacts);

      setState(() {
        contacts = fetchedContacts;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  // --- YOUR ORIGINAL LOGIC: ADDING CONTACTS ---
  Future<void> _showAddContactDialog() async {
    nameController.clear();
    phoneController.clear();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2833), // Matching Home Screen Card color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF66FCF1), width: 1),
        ),
        title: const Text(
          "ADD GUARDIAN",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Name",
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF66FCF1))),
                prefixIcon: Icon(Icons.person, color: Color(0xFF66FCF1)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2.0),
              decoration: const InputDecoration(
                labelText: "Phone Number",
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF66FCF1))),
                prefixIcon: Icon(Icons.phone, color: Color(0xFF66FCF1)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF66FCF1)),
            onPressed: () async {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token');
                
                if (token != null) {
                  final success = await ApiService.addContact(
                    nameController.text, 
                    phoneController.text, 
                    token
                  );
                  
                  if (success && mounted) {
                    Navigator.pop(context);
                    _fetchContacts(); 
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Guardian Locked In!"), backgroundColor: Color(0xFF45A29E)),
                    );
                  }
                }
              }
            },
            child: const Text("SAVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- YOUR ORIGINAL LOGIC: DELETING ---
  Future<void> _deleteContact(int contactId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token != null) {
      final success = await ApiService.deleteContact(contactId, token);
      if (success && mounted) {
        _fetchContacts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contact removed."), backgroundColor: Color(0xFFFF3B30)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10), // The Home Screen Background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "GUARDIANS",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 2.0),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF66FCF1)))
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: contacts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 20),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return _buildGlassContactCard(contact);
                  },
                ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContactDialog,
        backgroundColor: const Color(0xFF66FCF1),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("ADD GUARDIAN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- UI HELPER: THE GLASS CONTACT CARD ---
  Widget _buildGlassContactCard(dynamic contact) {
    String name = contact['contact_name'] ?? "Unknown";
    String phone = contact['contact_phone'] ?? "No Number";
    String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2833).withOpacity(0.4), // Glass effect
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF66FCF1).withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF66FCF1), width: 1.5),
          ),
          child: Center(
            child: Text(initial, style: const TextStyle(color: Color(0xFF66FCF1), fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 14, letterSpacing: 1.1)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30)),
          onPressed: () => _deleteContact(contact['id']),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          const Text("No Guardians Yet", style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Add someone you trust for emergency alerts.", style: TextStyle(color: Colors.white38, fontSize: 14)),
        ],
      ),
    );
  }
}