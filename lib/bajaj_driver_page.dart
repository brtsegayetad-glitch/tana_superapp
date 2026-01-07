import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_verification.dart'; // Ensure you created this file as we discussed!

class BajajDriverPage extends StatelessWidget {
  const BajajDriverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tana Driver Mode"),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ride_requests')
            .doc('test_ride')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text("Waiting for passengers in Bahir Dar..."),
            );
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String status = data['status'] ?? 'searching';

          return Column(
            children: [
              _buildIncomingCard(context, data, status),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIncomingCard(BuildContext context, Map<String, dynamic> data, String status) {
    int price = data['price'] ?? 60;
    // We get the OTP from the passenger's request data in Firebase
    String tripOtp = data['otp'] ?? "0000"; 

    return Card(
      margin: const EdgeInsets.all(20),
      elevation: 5,
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              status == 'searching' ? Icons.notifications_active : Icons.directions_bike,
              color: Colors.orange,
            ),
            title: Text(
              status == 'searching' ? "NEW REQUEST" : 
              status == 'accepted' ? "ARRIVED AT PICKUP" : "TRIP IN PROGRESS"
            ),
            subtitle: Text("Location: ${data['location']}\nFare: ETB $price"),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: _buildActionButton(context, status, price, tripOtp),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String status, int price, String tripOtp) {
    // 1. STEP: DRIVER SEES NEW REQUEST
    if (status == 'searching') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        onPressed: () {
          FirebaseFirestore.instance
              .collection('ride_requests')
              .doc('test_ride')
              .update({'status': 'accepted'});
        },
        child: const Text("ACCEPT RIDE", style: TextStyle(color: Colors.white)),
      );
    } 
    
    // 2. STEP: DRIVER HAS ACCEPTED, NOW MUST VERIFY PASSENGER
    else if (status == 'accepted') {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        onPressed: () {
          // Go to the OTP screen we created
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(correctOtp: tripOtp),
            ),
          );
        },
        child: const Text("VERIFY PASSENGER (ENTER OTP)", style: TextStyle(color: Colors.white)),
      );
    } 
    
    // 3. STEP: TRIP IS STARTED, NOW CAN FINISH
    else {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        onPressed: () async {
          double myCommission = price * 0.10;
          await FirebaseFirestore.instance.collection('commissions').add({
            'driver': 'Abebe',
            'amount': price,
            'commission': myCommission,
            'timestamp': FieldValue.serverTimestamp(),
          });
          await FirebaseFirestore.instance
              .collection('ride_requests')
              .doc('test_ride')
              .delete();
        },
        child: const Text("FINISH TRIP (COLLECT CASH)", style: TextStyle(color: Colors.white)),
      );
    }
  }
}