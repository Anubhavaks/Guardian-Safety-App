import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // This boolean lets us toggle between the Login and Register forms
  bool isLogin = true; 

  // Controllers to grab the text the user types
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  // A loading state to show a spinner while waiting for the backend
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? "Guardian Login" : "Guardian Register"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            
            // --- NAME FIELD (Only for Register) ---
            if (!isLogin) ...[
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // --- PHONE NUMBER FIELD (Both) ---
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),
            
            // --- PASSWORD FIELD (Both) ---
            TextField(
              controller: passwordController,
              obscureText: true, // Hides the password
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 16),

            // --- SAFE PIN FIELD (Only for Register) ---
            if (!isLogin) ...[
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "4-Digit Safe PIN",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security),
                  counterText: "", // Hides the '0/4' character counter
                ),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 20),
            
            // --- MAIN SUBMIT BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : () async {
                  setState(() {
                    isLoading = true; // Start loading spinner
                  });

                  final phone = phoneController.text;
                  final password = passwordController.text;
                  bool success = false;

                  if (isLogin) {
                    // RUN LOGIN
                    success = await ApiService.login(phone, password);
                  } else {
                    // RUN REGISTER
                    final name = nameController.text;
                    final pin = pinController.text;
                    success = await ApiService.register(name, phone, password, pin);
                    
                    // Auto-login after successful registration
                    if (success) {
                      success = await ApiService.login(phone, password);
                    }
                  }

                  setState(() {
                    isLoading = false; // Stop loading spinner
                  });

                  if (!context.mounted) return;

                  // SHOW RESULT TO USER
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Success! You are logged in."),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // TODO: Navigate to Home Screen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Failed. Check your details or server connection."),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isLogin ? "LOGIN" : "REGISTER",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            const SizedBox(height: 16),
            
            // --- TOGGLE LOGIN/REGISTER BUTTON ---
            TextButton(
              onPressed: () {
                setState(() {
                  isLogin = !isLogin;
                });
              },
              child: Text(
                isLogin 
                  ? "Don't have an account? Register here" 
                  : "Already have an account? Login here",
              ),
            )
          ],
        ),
      ),
    );
  }
}