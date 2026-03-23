import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true; 

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10), // The signature deep dark background
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [const Color(0xFF66FCF1).withOpacity(0.05), const Color(0xFF0B0C10)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: [
                const SizedBox(height: 60),
                // --- LOGO / ICON ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF66FCF1), width: 2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF66FCF1).withOpacity(0.2), blurRadius: 20)
                    ],
                  ),
                  child: const Icon(Icons.shield_moon, color: Color(0xFF66FCF1), size: 60),
                ),
                const SizedBox(height: 20),
                Text(
                  isLogin ? "WELCOME BACK" : "JOIN THE GUARD",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isLogin ? "Secure your world." : "Enterprise safety for everyone.",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 50),

                // --- FORM FIELDS ---
                if (!isLogin) ...[
                  _buildTextField(nameController, "Full Name", Icons.person),
                  const SizedBox(height: 20),
                ],
                
                _buildTextField(phoneController, "Phone Number", Icons.phone, keyboard: TextInputType.phone),
                const SizedBox(height: 20),
                
                _buildTextField(passwordController, "Password", Icons.lock, obscure: true),
                const SizedBox(height: 20),

                if (!isLogin) ...[
                  _buildTextField(pinController, "4-Digit Safe PIN", Icons.security, 
                    keyboard: TextInputType.number, length: 4, obscure: true),
                  const SizedBox(height: 20),
                ],

                const SizedBox(height: 30),

                // --- SUBMIT BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF66FCF1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: isLoading ? null : _handleAuth,
                    child: isLoading 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          isLogin ? "LOGIN" : "CREATE ACCOUNT",
                          style: const TextStyle(
                            color: Colors.black, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                  ),
                ),

                const SizedBox(height: 20),
                
                // --- TOGGLE BUTTON ---
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin 
                      ? "Don't have an account? Register" 
                      : "Already have an account? Login",
                    style: const TextStyle(color: Color(0xFF66FCF1), fontWeight: FontWeight.w600),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- REUSABLE DARK TEXTFIELD ---
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, 
      {bool obscure = false, TextInputType keyboard = TextInputType.text, int? length}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      maxLength: length,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFF66FCF1), size: 20),
        counterText: "",
        filled: true,
        fillColor: const Color(0xFF1F2833).withOpacity(0.3),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF66FCF1)),
        ),
      ),
    );
  }

  // --- AUTH LOGIC ---
  Future<void> _handleAuth() async {
    setState(() => isLoading = true);

    final phone = phoneController.text;
    final password = passwordController.text;
    bool success = false;

    try {
      if (isLogin) {
        success = await ApiService.login(phone, password);
      } else {
        final name = nameController.text;
        final pin = pinController.text;
        success = await ApiService.register(name, phone, password, pin);
        if (success) success = await ApiService.login(phone, password);
      }
    } catch (e) {
      success = false;
    }

    setState(() => isLoading = false);

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Authentication Failed. Check server or details."),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }
}