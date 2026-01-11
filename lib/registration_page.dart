import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // Ensure this points to your HomeScreen

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  // State Variables
  bool _isLogin = true; // Toggles between Login and Register UI
  bool _isLoading = false;
  String _selectedRole = 'Passenger'; // Default for new users
  String _selectedAssociation = 'Tana';

  final List<String> _roles = ['Passenger', 'Driver'];
  final List<String> _associations = [
    'Tana',
    'Abay',
    'Fasilo',
    'Weyto',
    'Blue Nile'
  ];

  // --- AUTH LOGIC (LOGIN / REGISTER) ---
  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Note: Firebase Auth usually uses email. We append '@hullu.com' to the phone
    // to treat the phone number as a unique username/email.
    String fakeEmail = "${_phoneController.text.trim()}@hullu.com";
    String password = _passwordController.text.trim();

    try {
      if (_isLogin) {
        // --- 1. LOGIN ---
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );
      } else {
        // --- 2. REGISTRATION ---
        UserCredential credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );

        String uid = credential.user!.uid;

        // Prepare Universal User Profile
        Map<String, dynamic> userData = {
          'uid': uid,
          'fullName': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'role': _selectedRole,
          'isVendor': false, // Marketplace registration happens later
          'createdAt': FieldValue.serverTimestamp(),
          'total_debt': 0.0,
        };

        // Add Driver specific fields if applicable
        if (_selectedRole == 'Driver') {
          userData['plateNumber'] = _plateController.text.trim();
          userData['association'] = _selectedAssociation;

          // Initialize Driver Wallet
          await FirebaseFirestore.instance.collection('wallets').doc(uid).set({
            'uid': uid,
            'balance': 0.0,
            'isRoutePaid': false,
            'plateNumber': _plateController.text.trim(),
            'association': _selectedAssociation,
          });
        }

        // Save to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData);
      }

      // Success! Move to Home
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String errorMsg = "Auth Error";
      if (e.code == 'user-not-found') {
        errorMsg = "No account found for this phone.";
      } else if (e.code == 'wrong-password')
        errorMsg = "Incorrect password.";
      else if (e.code == 'email-already-in-use')
        errorMsg = "Phone already registered. Please Login.";

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMsg)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? "Login to Hullugebeya" : "Create Account"),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.apps, size: 80, color: Colors.teal),
                const SizedBox(height: 20),

                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: "Phone Number", border: OutlineInputBorder()),
                  validator: (val) =>
                      val!.length < 10 ? "Enter valid phone" : null,
                ),
                const SizedBox(height: 15),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: "Password", border: OutlineInputBorder()),
                  validator: (val) =>
                      val!.length < 6 ? "Password too short" : null,
                ),
                const SizedBox(height: 15),

                // Registration-Only Fields
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: "Full Name", border: OutlineInputBorder()),
                    validator: (val) => val!.isEmpty ? "Enter name" : null,
                  ),
                  const SizedBox(height: 15),

                  // Role Selector
                  DropdownButtonFormField(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                        labelText: "I want to be a...",
                        border: OutlineInputBorder()),
                    items: _roles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedRole = val as String),
                  ),
                  const SizedBox(height: 15),

                  // Driver Details
                  if (_selectedRole == 'Driver') ...[
                    TextFormField(
                      controller: _plateController,
                      decoration: const InputDecoration(
                          labelText: "Plate Number (Targa)",
                          border: OutlineInputBorder()),
                      validator: (val) => val!.isEmpty ? "Enter plate" : null,
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField(
                      initialValue: _selectedAssociation,
                      decoration: const InputDecoration(
                          labelText: "Association",
                          border: OutlineInputBorder()),
                      items: _associations
                          .map(
                              (a) => DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedAssociation = val as String),
                    ),
                  ],
                ],

                const SizedBox(height: 25),

                // Submit Button
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _handleAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(_isLogin ? "LOGIN" : "REGISTER",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18)),
                      ),

                // Toggle Login/Register
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin
                      ? "New to Bahir Dar? Register here"
                      : "Already have an account? Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
