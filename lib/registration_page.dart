
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'auth_otp_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String _selectedRole = 'Passenger';
  String _selectedAssociation = 'Tana';

  File? _idCardImage;
  final ImagePicker _picker = ImagePicker();

  final String _superAdminPhone = "+251971732729"; // Use international format for Firebase

  final Map<String, String> _associationIds = {
    'Tana': 'tana_assoc',
    'Abay': 'abay_assoc',
    'Fasilo': 'fasilo_assoc',
    'Weyto': 'weyto_assoc',
    'Blue Nile': 'nile_assoc'
  };

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) {
        setState(() => _idCardImage = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Image picking failed: $e")));
      }
    }
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isLogin && _selectedRole == 'Driver' && _idCardImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload your ID card photo."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    String phone = _phoneController.text.trim();
    String formattedPhone = phone.startsWith('+') ? phone : '+251${phone.substring(1)}';

    Map<String, dynamic> userData = {};
    if (!_isLogin) {
      String finalRole = _selectedRole.toLowerCase();
      String assocId = _associationIds[_selectedAssociation] ?? 'tana_assoc';
      bool isMe = (formattedPhone == _superAdminPhone);

      userData = {
        'fullName': _nameController.text.trim(),
        'phoneNumber': formattedPhone,
        'role': isMe ? 'superadmin' : finalRole,
        'createdAt': FieldValue.serverTimestamp(),
        'associationId': assocId,
        'isApproved': isMe ? true : (finalRole == 'manager' ? false : true),
      };

      if (finalRole == 'driver') {
        userData['plate'] = _plateController.text.trim();
      }
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      verificationCompleted: (PhoneAuthCredential credential) {
         setState(() => _isLoading = false);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Phone verification failed: ${e.message}"), backgroundColor: Colors.redAccent),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() => _isLoading = false);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => AuthOtpPage(
            verificationId: verificationId,
            userData: _isLogin ? {'phone': formattedPhone} : userData,
            idCardImage: _isLogin ? null : _idCardImage,
            isLogin: _isLogin,
          ),
        ));
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.teal, Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.electric_rickshaw, size: 60, color: Colors.teal),
                      const SizedBox(height: 10),
                      Text(
                        _isLogin ? "Welcome Back" : "Create New Account",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: "Phone (09...)"),
                        validator: (val) => val!.length < 10 ? "Enter a valid phone number" : null,
                      ),
                      if (!_isLogin) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: "Full Name"),
                          validator: (val) => val!.isEmpty ? "Enter your name" : null,
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          items: ['Passenger', 'Driver', 'Manager'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: (val) => setState(() => _selectedRole = val!),
                          decoration: const InputDecoration(labelText: "User Type"),
                        ),
                        if (_selectedRole != 'Passenger') ...[
                          const SizedBox(height: 10),
                          if (_selectedRole == 'Driver') ...[
                            TextFormField(
                              controller: _plateController,
                              decoration: const InputDecoration(labelText: "Plate Number"),
                            ),
                            const SizedBox(height: 20),
                            Text("National ID Photo", style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 8),
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _idCardImage != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.file(_idCardImage!, fit: BoxFit.cover))
                                  : const Center(child: Text("No photo selected")),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text("Camera")),
                                ElevatedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text("Gallery")),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedAssociation,
                            items: _associationIds.keys.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                            onChanged: (val) => setState(() => _selectedAssociation = val!),
                            decoration: const InputDecoration(labelText: "Select Association"),
                          ),
                        ],
                      ],
                      const SizedBox(height: 30),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _sendOtp,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: Text(_isLogin ? "Send Code" : "Sign Up", style: const TextStyle(color: Colors.white, fontSize: 18)),
                            ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _formKey.currentState?.reset();
                            _phoneController.clear();
                            _nameController.clear();
                            _plateController.clear();
                            _idCardImage = null;
                            _selectedRole = 'Passenger';
                          });
                        },
                        child: Text(_isLogin ? "New user? Sign up" : "Already have an account? Login"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
