import 'main.dart'; // This allows this file to see HomeScreen
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  String _selectedRole = 'Passenger'; // Default role
  final List<String> _roles = ['Passenger', 'Driver', 'Vendor'];

  String _selectedAssociation = 'Tana';
  final List<String> _associations = [
    'Tana',
    'Abay',
    'Fasilo',
    'Weyto',
    'Blue Nile'
  ];

  bool _isSaving = false;

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      String uid = FirebaseAuth.instance.currentUser!.uid;

      try {
        // 1. Create the General User Profile
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fullName': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'role': _selectedRole,
          'uid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. If they are a Driver, initialize their Wallet
        if (_selectedRole == 'Driver') {
          await FirebaseFirestore.instance.collection('wallets').doc(uid).set({
            'bajajName': _nameController.text.trim(),
            'plateNumber': _plateController.text.trim(),
            'association': _selectedAssociation,
            'phoneNumber': _phoneController.text.trim(),
            'balance': 0.0,
            'uid': uid,
            'isRoutePaid': false,
          });
        }

        if (!mounted) return;

        // --- NEW CODE: FORCING THE NAVIGATION ---
        // Instead of waiting for the Stream, we manually send them to the App
        // Import your main.dart or use the HomeScreen class directly
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Tana Registration"), backgroundColor: Colors.teal),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text("Welcome to Bahir Dar's Superapp",
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 20),

                // Role Selection
                DropdownButtonFormField(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                      labelText: "Register as", border: OutlineInputBorder()),
                  items: _roles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedRole = val as String),
                ),

                const SizedBox(height: 15),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: "Full Name", border: OutlineInputBorder()),
                  validator: (value) =>
                      value!.isEmpty ? "Please enter your name" : null,
                ),

                const SizedBox(height: 15),

                // Show Bajaj details ONLY if they are a Driver
                if (_selectedRole == 'Driver') ...[
                  TextFormField(
                    controller: _plateController,
                    decoration: const InputDecoration(
                        labelText: "Plate Number (Targa)",
                        border: OutlineInputBorder()),
                    validator: (value) =>
                        value!.isEmpty ? "Enter plate number" : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField(
                    initialValue: _selectedAssociation,
                    decoration: const InputDecoration(
                        labelText: "Association", border: OutlineInputBorder()),
                    items: _associations
                        .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedAssociation = val as String),
                  ),
                ],

                const SizedBox(height: 15),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: "Telebirr Phone Number",
                      border: OutlineInputBorder()),
                  validator: (value) =>
                      value!.length < 10 ? "Enter valid phone" : null,
                ),

                const SizedBox(height: 30),
                _isSaving
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.teal),
                        child: const Text("COMPLETE REGISTRATION",
                            style: TextStyle(color: Colors.white)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
