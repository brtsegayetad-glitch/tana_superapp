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
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  // Local Bahir Dar Associations
  String _selectedAssociation = 'Tana';
  final List<String> _associations = ['Tana', 'Abay', 'Fasilo', 'Weyto', 'Blue Nile'];

  bool _isSaving = false;

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      String uid = FirebaseAuth.instance.currentUser!.uid;

      try {
        await FirebaseFirestore.instance.collection('wallets').doc(uid).set({
          'bajajName': _nameController.text.trim(),
          'plateNumber': _plateController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'association': _selectedAssociation,
          'registrationDate': FieldValue.serverTimestamp(),
          'balance': 0.0, // Initialize wallet
          'isRoutePaid': false,
        }, SetOptions(merge: true));

        if (!mounted) return;
        Navigator.pop(context); // Go back to the main page
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Registration")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text("Complete your profile to start using Tana Bajaj",
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
                  validator: (value) => value!.isEmpty ? "Enter your name" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _plateController,
                  decoration: const InputDecoration(labelText: "Plate Number (Targa)", hintText: "Code 2 - 12345", border: OutlineInputBorder()),
                  validator: (value) => value!.isEmpty ? "Enter plate number" : null,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField(
                  initialValue: _selectedAssociation,
                  decoration: const InputDecoration(labelText: "Association", border: OutlineInputBorder()),
                  items: _associations.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                  onChanged: (val) => setState(() => _selectedAssociation = val as String),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: "Telebirr Phone Number", border: OutlineInputBorder()),
                  validator: (value) => value!.length < 10 ? "Enter valid phone" : null,
                ),
                const SizedBox(height: 30),
                _isSaving 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.teal),
                      child: const Text("FINISH REGISTRATION", style: TextStyle(color: Colors.white)),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}