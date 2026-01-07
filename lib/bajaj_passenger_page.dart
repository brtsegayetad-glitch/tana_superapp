import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math'; 
import 'package:cloud_firestore/cloud_firestore.dart';

class BajajPassengerPage extends StatefulWidget {
  const BajajPassengerPage({super.key});

  @override
  State<BajajPassengerPage> createState() => _BajajPassengerPageState();
}

class _BajajPassengerPageState extends State<BajajPassengerPage> {
  bool isSearching = false;

  // Your original Bahir Dar positions
  LatLng bajajPosition = const LatLng(11.5880, 37.3600);
  final LatLng customerPosition = const LatLng(11.5742, 37.3614);

  // Your original animation logic
  void startBajajMovement() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        double newLat = bajajPosition.latitude + (customerPosition.latitude - bajajPosition.latitude) * 0.01;
        double newLng = bajajPosition.longitude + (customerPosition.longitude - bajajPosition.longitude) * 0.01;
        bajajPosition = LatLng(newLat, newLng);
        if ((customerPosition.latitude - newLat).abs() < 0.0001) {
          timer.cancel();
        }
      });
    });
  }

  // UPDATED: Rating Dialog function
  void _showRatingDialog(BuildContext context) {
    int selectedStars = 5;
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("How was your ride?", textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Rate your driver (Abebe)"),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedStars ? Icons.star : Icons.star_border,
                          color: Colors.amber, size: 30,
                        ),
                        onPressed: () => setState(() => selectedStars = index + 1),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('ratings').add({
                      'driver': 'Abebe',
                      'rating': selectedStars,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Thank you for your feedback!")),
                    );
                  },
                  child: const Text("SUBMIT"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> sendRequestToCloud() async {
    String newOtp = (1000 + Random().nextInt(9000)).toString();
    try {
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc('test_ride')
          .set({
        'status': 'searching',
        'passenger_name': 'Passenger in Bahir Dar',
        'location': 'Near Bus Station',
        'price': 60,
        'otp': newOtp, 
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Firestore Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: customerPosition,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tana.superapp',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: customerPosition,
                    child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                  ),
                  Marker(
                    point: bajajPosition,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.local_taxi, color: Colors.teal, size: 35),
                  ),
                ],
              ),
            ],
          ),
          
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: isSearching ? _buildDriverFoundCard() : _buildRequestButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () async {
        setState(() => isSearching = true);
        await sendRequestToCloud();
        startBajajMovement();
      },
      child: const Text("REQUEST BAJAJ", style: TextStyle(color: Colors.white, fontSize: 18)),
    );
  }

  Widget _buildDriverFoundCard() {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ride_requests')
            .doc('test_ride')
            .snapshots(),
        builder: (context, snapshot) {
          // CHECK: If trip is finished (deleted), show rating and reset
          if (isSearching && (!snapshot.hasData || !snapshot.data!.exists)) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() => isSearching = false);
                _showRatingDialog(context);
             });
             return const SizedBox(); 
          }

          String displayStatus = "SEARCHING...";
          String otpValue = "----";

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            otpValue = data['otp'] ?? "----";
            if (data['status'] == 'accepted') displayStatus = "BAJAJ IS COMING!";
            if (data['status'] == 'started') displayStatus = "TRIP IN PROGRESS";
          }

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(displayStatus, style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                const Divider(),
                const Text("SHARE THIS CODE WITH DRIVER:", style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text(otpValue, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 5)),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(radius: 25, child: Icon(Icons.person)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Abebe Kebede", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("Plate: AA-3-0456", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Text("ETB 60", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  ],
                ),
              ],
            ),
          );
        });
  }
}