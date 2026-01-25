
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthOtpPage extends StatefulWidget {
  final String verificationId;
  final Map<String, dynamic> userData;
  final File? idCardImage; // Receive the image file
  final bool isLogin;

  const AuthOtpPage({
    super.key,
    required this.verificationId,
    required this.userData,
    this.idCardImage,
    this.isLogin = false,
  });

  @override
  State<AuthOtpPage> createState() => _AuthOtpPageState();
}

class _AuthOtpPageState extends State<AuthOtpPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  // Moved from registration_page.dart
  Future<String> _uploadIdCard(String uid, File imageFile) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('id_cards').child('$uid.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception("ID card upload failed: $e");
    }
  }

  Future<void> _verifyOtpAndProceed() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 6-digit OTP.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text.trim(),
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      String uid = userCredential.user!.uid;

      if (!widget.isLogin) {
        widget.userData['uid'] = uid;

        // Handle ID card upload for drivers
        if (widget.userData['role'] == 'driver' && widget.idCardImage != null) {
          String idCardUrl = await _uploadIdCard(uid, widget.idCardImage!);
          widget.userData['idCardUrl'] = idCardUrl;
        }

        // Create user document in Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).set(widget.userData);

        // Create driver document if applicable
        if (widget.userData['role'] == 'driver') {
          await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
            'name': widget.userData['fullName'],
            'plate': widget.userData['plate'],
            'associationId': widget.userData['associationId'],
            'isOnline': false,
            'uid': uid,
            'phoneNumber': widget.userData['phoneNumber'],
            'total_debt': 0,
            'ride_count': 0,
            'is_blocked': false,
            'isRoutePaid': true,
            'idCardUrl': widget.userData['idCardUrl'], // Save URL here too
          });
        }
      }

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to verify OTP: ${e.message}"), backgroundColor: Colors.redAccent));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("An unexpected error occurred: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Phone Number"),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Enter the 6-digit code sent to ${widget.userData['phoneNumber'] ?? widget.userData['phone']}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: "OTP Code", counterText: "", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _verifyOtpAndProceed,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.teal,
                      ),
                      child: Text(widget.isLogin ? "Login" : "Verify & Create Account", style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
