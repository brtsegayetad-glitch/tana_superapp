import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'bajaj_driver_page.dart';
import 'bajaj_passenger_page.dart';

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

    String fakeEmail = "${_phoneController.text.trim()}@hullu.com";
    String password = _passwordController.text.trim();

    try {
      String? finalRole;

      if (_isLogin) {
        // --- 1. LOGIN ---
        UserCredential cred =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );

        // Fetch the role from Firestore because we don't know it yet
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();
        finalRole = userDoc.data()?['role'];
      } else {
        // --- 2. REGISTRATION ---
        UserCredential credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );

        String uid = credential.user!.uid;
        finalRole = _selectedRole;

        // Universal User Profile
        Map<String, dynamic> userData = {
          'uid': uid,
          'fullName': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
          'total_debt': 0.0,
        };

        if (_selectedRole == 'Driver') {
          userData['plateNumber'] = _plateController.text.trim();
          userData['association'] = _selectedAssociation;

          // CRITICAL: Also create the document in the 'drivers' collection
          // so the Admin Panel and Driver Page work correctly!
          await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
            'name': _nameController.text.trim(),
            'plate': _plateController.text.trim(),
            'association': _selectedAssociation,
            'total_debt': 0.0,
            'isOnline': false,
            'uid': uid,
          });
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData);
      }

      if (!mounted) return;

      // --- 3. THE SMART REDIRECT ---
      Widget nextScreen;
      if (finalRole == 'Driver') {
        nextScreen = const BajajDriverPage(); // Go to Driver side
      } else {
        nextScreen = const BajajPassengerPage(); // Go to Passenger side
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => nextScreen),
        (route) => false,
      );
    } on FirebaseAuthException {
      // ... your existing error handling ...
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
