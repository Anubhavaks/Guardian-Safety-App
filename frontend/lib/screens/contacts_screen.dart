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

  Future<void> _fetchContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token != null) {
      final fetchedContacts = await ApiService.getContacts(token);
      
      // 👇 THE NEW CACHE TRAP 👇
      // Convert the server data to a string and lock it in the phone's local memory
      final String encodedContacts = jsonEncode(fetchedContacts);
      await prefs.setString('emergency_contacts_cache', encodedContacts);
      // 👆 ------------------- 👆

      setState(() {
        contacts = fetchedContacts;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false; 
      });
    }
  }

  Future<void> _showAddContactDialog() async {
    nameController.clear();
    phoneController.clear();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E), // Dark theme
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.greenAccent, width: 1), // Green for adding
        ),
        title: const Text(
          "ADD GUARDIAN",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // NAME INPUT
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Name (e.g., Mom, Brother)",
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                prefixIcon: Icon(Icons.person, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            // PHONE INPUT
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2.0),
              decoration: const InputDecoration(
                hintText: "+91 98765 43210",
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                prefixIcon: Icon(Icons.phone, color: Colors.grey),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
                    _fetchContacts(); // Refresh the list from the server
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Contact Added!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
                    );
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to save contact."), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- DELETE CONTACT LOGIC ---
  Future<void> _deleteContact(int contactId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token != null) {
      final success = await ApiService.deleteContact(contactId, token);
      
      if (success && mounted) {
        _fetchContacts(); // Refresh the list from the server!
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contact deleted."), backgroundColor: Colors.redAccent),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete contact."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Deep navy background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "EMERGENCY CONTACTS",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white), // Makes the back arrow white
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
        : contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 20),
                  const Text(
                    "No guardians added yet.",
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Tap + to add people you trust.",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return Card(
                  color: Colors.white.withOpacity(0.05), // Dark card
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.only(bottom: 15),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      child: const Icon(Icons.person, color: Colors.blueAccent),
                    ),
                    title: Text(
                      contact['contact_name'], // Mapped to your backend field
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text(
                      contact['contact_phone'], // Mapped to your backend field
                      style: const TextStyle(color: Colors.white70, letterSpacing: 1.2),
                    ),
                    // 👇 THIS IS THE NEW TRASH CAN BUTTON 👇
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        // Assuming your backend returns the ID as 'id'
                        // If your backend calls it something else like 'contact_id', change it here!
                        _deleteContact(contact['id']); 
                      },
                    ),
                  ),
                );
              },
            ),
      // --- FLOATING ACTION BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContactDialog,
        backgroundColor: Colors.greenAccent,
        icon: const Icon(Icons.add, color: Color(0xFF1A1A2E)),
        label: const Text(
          "ADD CONTACT",
          style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}