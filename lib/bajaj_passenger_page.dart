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

  LatLng bajajPosition = const LatLng(11.5880, 37.3600);
  final LatLng customerPosition = const LatLng(11.5742, 37.3614);

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint("Could not launch $launchUri");
    }
  }

  @override
  void dispose() {
    rideSubscription?.cancel();
    super.dispose();
  }

  void listenForTripCompletion() {
    rideSubscription?.cancel();
    rideSubscription = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc('test_ride')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';
        if (status == 'completed' && tripStatus != "finished") {
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Arrival!", textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("How was your ride with Abebe?"),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedStars
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 35,
                        ),
                        onPressed: () =>
                            setDialogState(() => selectedStars = index + 1),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('ratings').add({
                      'driver': 'Abebe',
                      'rating': selectedStars,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                    await FirebaseFirestore.instance
                        .collection('ride_requests')
                        .doc('test_ride')
                        .delete();
                    rideSubscription?.cancel();
                    if (!mounted) return;
                    Navigator.pop(context);
                    setState(() => tripStatus = "idle");
                  },
                  child: const Text("SUBMIT",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void startBajajMovement() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        double newLat = bajajPosition.latitude +
            (customerPosition.latitude - bajajPosition.latitude) * 0.01;
        double newLng = bajajPosition.longitude +
            (customerPosition.longitude - bajajPosition.longitude) * 0.01;
        bajajPosition = LatLng(newLat, newLng);
        if ((customerPosition.latitude - newLat).abs() < 0.0001) timer.cancel();
      });
    });
  }

  Future<void> sendRequestToCloud() async {
    var priceDoc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('pricing')
        .get();
    double basePrice = 50.0;
    double pricePerKm = 15.0;
    if (priceDoc.exists) {
      basePrice = (priceDoc.data()!['base_price'] ?? 50.0).toDouble();
      pricePerKm = (priceDoc.data()!['per_km'] ?? 15.0).toDouble();
    }
    const Distance distanceCalculator = Distance();
    double meterDistance = distanceCalculator.as(
        LengthUnit.Meter, bajajPosition, customerPosition);
    double kmDistance = meterDistance / 1000.0;
    double finalFare = basePrice + (kmDistance * pricePerKm);
    String newOtp = (1000 + Random().nextInt(9000)).toString();

    await FirebaseFirestore.instance
        .collection('ride_requests')
        .doc('test_ride')
        .set({
      'status': 'searching',
      'otp': newOtp,
      'price': finalFare.toInt(),
      'distance_km': kmDistance.toStringAsFixed(2),
      'location': 'Near Bus Station',
      'passenger_name': 'Passenger',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options:
                MapOptions(initialCenter: customerPosition, initialZoom: 14.0),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              MarkerLayer(markers: [
                Marker(
                    point: customerPosition,
                    child: const Icon(Icons.location_on,
                        color: Colors.blue, size: 40)),
                Marker(
                    point: bajajPosition,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.local_taxi,
                        color: Colors.teal, size: 35)),
              ]),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child:
                tripStatus == "idle" ? _buildIdleMenu() : _buildLiveRideCard(),
          ),
        ],
      ),
    );
  }

  // --- UI HELPER FUNCTIONS (Outside the Build tree) ---

  Widget _buildIdleMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            minimumSize: const Size(double.infinity, 55),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            setState(() => tripStatus = "searching");
            await sendRequestToCloud();
            listenForTripCompletion();
            startBajajMovement();
          },
          child: const Text("REQUEST BAJAJ VIA APP",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            minimumSize: const Size(double.infinity, 55),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => _makePhoneCall("8000"),
          icon: const Icon(Icons.phone_in_talk, color: Colors.white),
          label: const Text("CALL TO ORDER (SHORT CODE)",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildLiveRideCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .doc('test_ride')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists)
          return const SizedBox();
        var data = snapshot.data!.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';
        String otp = data['otp'] ?? '----';
        int price = data['price'] ?? 0;
        String displayStatus =
            status == 'started' ? "TRIP IN PROGRESS" : "BAJAJ IS COMING!";

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
              Text(displayStatus,
                  style: const TextStyle(
                      color: Colors.teal, fontWeight: FontWeight.bold)),
              const Divider(),
              if (status != 'started') ...[
                const Text("GIVE THIS OTP TO DRIVER:",
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text(otp,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        letterSpacing: 8)),
                const SizedBox(height: 10),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const CircleAvatar(child: Icon(Icons.person)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Abebe Kebede",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Plate: AA-3-0456", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  Text("$price ETB",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 18)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
