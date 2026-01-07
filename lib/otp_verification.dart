import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String correctOtp; 
  const OtpVerificationScreen({super.key, required this.correctOtp});

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  String errorMessage = "";
  bool isLoading = false;

  // This function updates Firebase to tell everyone the trip has started
  void verifyAndStart() async {
    if (_otpController.text == widget.correctOtp) {
      setState(() => isLoading = true);
      
      try {
        // Update the status in Firebase to 'started'
        await FirebaseFirestore.instance
            .collection('ride_requests')
            .doc('test_ride')
            .update({'status': 'started'});

        // Go back to the Driver Page
        Navigator.pop(context); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip Started! Drive safely."), backgroundColor: Colors.green),
        );
      } catch (e) {
        setState(() {
          errorMessage = "Connection Error. Try again.";
          isLoading = false;
        });
      }
    } else {
      setState(() {
        errorMessage = "Incorrect Code. Ask the passenger for the code on their screen.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Passenger"), backgroundColor: Colors.orange),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.security, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text("Enter the 4-digit code shown on the passenger's phone", 
                 textAlign: TextAlign.center,
                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 10),
              decoration: InputDecoration(
                hintText: "0000",
                errorText: errorMessage.isEmpty ? null : errorMessage,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: verifyAndStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 50)
                  ),
                  child: const Text("START TRIP", style: TextStyle(color: Colors.white, fontSize: 18)),
                )
          ],
        ),
      ),
    );
  }
}