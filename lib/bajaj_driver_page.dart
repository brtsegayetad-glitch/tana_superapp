import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BajajDriverPage extends StatefulWidget {
  const BajajDriverPage({super.key});

  @override
  State<BajajDriverPage> createState() => _BajajDriverPageState();
}

class _BajajDriverPageState extends State<BajajDriverPage> {
  final TextEditingController _otpInputController = TextEditingController();

  // 1. ACCEPT RIDE
  Future<void> _acceptRide() async {
    await FirebaseFirestore.instance
        .collection('ride_requests')
        .doc('test_ride')
        .update({'status': 'accepted'});
  }

  // 2. VERIFY OTP AND START
  Future<void> _verifyAndStart(String correctOtp) async {
    if (_otpInputController.text.trim() == correctOtp) {
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc('test_ride')
          .update({'status': 'started'});

      _otpInputController.clear();
      // This hides the keyboard so you can see the "Finish" button
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wrong OTP! Check passenger's phone.")),
      );
    }
  }

  // 3. FINISH TRIP (This triggers the Passenger's Rating)
  Future<void> _finishTrip(int price) async {
    double myCommission = price * 0.10;

    try {
      // Record your 10% profit
      await FirebaseFirestore.instance.collection('commissions').add({
        'driver': 'Abebe (Test)',
        'amount': price,
        'commission': myCommission,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // SIGNAL: Change to 'completed' so passenger sees the stars
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc('test_ride')
          .update({'status': 'completed'});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Trip Finished! Commission: $myCommission ETB")),
      );
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tana Driver Mode"),
        backgroundColor: Colors.teal,
      ),
      // FIX: SingleChildScrollView prevents the "Yellow Stripe" error
      body: SingleChildScrollView(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ride_requests')
              .doc('test_ride')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Padding(
                padding: EdgeInsets.only(top: 100),
                child:
                    Center(child: Text("Waiting for requests in Bahir Dar...")),
              );
            }

            var data = snapshot.data!.data() as Map<String, dynamic>;
            String status = data['status'] ?? 'searching';
            int price = data['price'] ?? 60;
            String tripOtp = data['otp'] ?? "0000";

            // If trip is completed, show a success message
            if (status == 'completed') {
              return const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, size: 80, color: Colors.green),
                      Text("Trip Done!",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("Passenger is rating you now."),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildTripCard(data, status, price),
                  const SizedBox(height: 20),

                  // STEP 1: ACCEPT
                  if (status == 'searching')
                    ElevatedButton(
                      onPressed: _acceptRide,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size(double.infinity, 55)),
                      child: const Text("ACCEPT RIDE",
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),

                  // STEP 2: VERIFY OTP
                  if (status == 'accepted') ...[
                    const Text("Enter Passenger OTP:"),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _otpInputController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8),
                      decoration: const InputDecoration(
                          hintText: "0000",
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white10),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => _verifyAndStart(tripOtp),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          minimumSize: const Size(double.infinity, 55)),
                      child: const Text("VERIFY & START TRIP",
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ],

                  // STEP 3: FINISH
                  if (status == 'started')
                    ElevatedButton(
                      onPressed: () => _finishTrip(price),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size(double.infinity, 55)),
                      child: const Text("FINISH TRIP (COLLECT CASH)",
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),

                  // Extra space so the keyboard doesn't hide the buttons
                  const SizedBox(height: 250),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> data, String status, int price) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Icon(Icons.local_taxi,
            color: status == 'started' ? Colors.green : Colors.grey),
        title: Text("STATUS: ${status.toUpperCase()}"),
        subtitle: Text("Pickup: ${data['location']}\nFare: $price ETB"),
      ),
    );
  }
}
