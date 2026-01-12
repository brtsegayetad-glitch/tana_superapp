import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class BajajPassengerPage extends StatefulWidget {
  const BajajPassengerPage({super.key});

  @override
  State<BajajPassengerPage> createState() => _BajajPassengerPageState();
}

class _BajajPassengerPageState extends State<BajajPassengerPage> {
  String tripStatus = "idle";
  StreamSubscription? rideSubscription;
  
  final TextEditingController _pickupController = TextEditingController(text: "My Current Location");
  final TextEditingController _destinationController = TextEditingController();

  LatLng bajajPosition = const LatLng(11.5880, 37.3600);
  final LatLng customerPosition = const LatLng(11.5742, 37.3614);

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  void dispose() {
    rideSubscription?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  // --- EXISTING LOGIC (Rating/Movement) ---
  void listenForTripCompletion() {
    rideSubscription?.cancel();
    rideSubscription = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc('test_ride')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] == 'completed' && tripStatus != "finished") {
          setState(() => tripStatus = "finished");
          _showRatingDialog();
        }
      }
    });
  }

  void _showRatingDialog() {
    int selectedStars = 5;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Arrival!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Rate your ride:"),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(index < selectedStars ? Icons.star : Icons.star_border, color: Colors.amber),
                  onPressed: () => setDialogState(() => selectedStars = index + 1),
                );
              })),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("SUBMIT"))
          ],
        );
      }),
    );
  }

  void startBajajMovement() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        double newLat = bajajPosition.latitude + (customerPosition.latitude - bajajPosition.latitude) * 0.01;
        double newLng = bajajPosition.longitude + (customerPosition.longitude - bajajPosition.longitude) * 0.01;
        bajajPosition = LatLng(newLat, newLng);
        if ((customerPosition.latitude - newLat).abs() < 0.0001) timer.cancel();
      });
    });
  }

  Future<void> sendRequestToCloud() async {
    String newOtp = (1000 + Random().nextInt(9000)).toString();
    await FirebaseFirestore.instance.collection('ride_requests').doc('test_ride').set({
      'status': 'searching',
      'otp': newOtp,
      'price': 60,
      'pickup': _pickupController.text,
      'destination': _destinationController.text,
      'passenger_phone': '+2519000000', // Placeholder
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // This helps prevent the stripes
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: customerPosition, initialZoom: 14.0),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              MarkerLayer(markers: [
                Marker(point: customerPosition, child: const Icon(Icons.location_on, color: Colors.blue, size: 40)),
                Marker(point: bajajPosition, width: 40, height: 40, child: const Icon(Icons.local_taxi, color: Colors.teal, size: 35)),
              ]),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: tripStatus == "idle" ? _buildIdleMenu() : _buildLiveRideCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleMenu() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: SingleChildScrollView( // FIXED: Prevents yellow/black stripes
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            TextField(
              controller: _pickupController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.my_location, color: Colors.blue),
                hintText: "Pickup Location",
                filled: true, fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                hintText: "Where to?",
                filled: true, fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            
            // --- ACTION BUTTONS ---
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () async {
                if (_destinationController.text.isEmpty) return;
                setState(() => tripStatus = "searching");
                await sendRequestToCloud();
                listenForTripCompletion();
                startBajajMovement();
              },
              child: const Text("REQUEST BAJAJ", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            
            // RESTORED: SHORT CODE BUTTON
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green[700]!, width: 2),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () => _makePhoneCall("8000"),
              icon: Icon(Icons.phone_callback, color: Colors.green[700]),
              label: Text("CALL 8000 (FAST BOOK)", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveRideCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("BAJAJ IS COMING!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          const Divider(),
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text("Abebe Kebede"),
            subtitle: Text("Plate: AA-3-0456"),
            trailing: Text("60 ETB", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ],
      ),
    );
  }
}