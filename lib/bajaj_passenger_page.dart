import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class BajajPassengerPage extends StatefulWidget {
  const BajajPassengerPage({super.key});

  @override
  State<BajajPassengerPage> createState() => _BajajPassengerPageState();
}

class _BajajPassengerPageState extends State<BajajPassengerPage> {
  // --- APP STATE ---
  String tripStatus = "idle";
  String currentOtp = "";
  StreamSubscription? rideSubscription;
  StreamSubscription<Position>? _positionStream;

  // --- CONTROLLERS ---
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pickupController =
      TextEditingController(text: "My Current Location");
  final TextEditingController _destinationController = TextEditingController();

  // --- GPS & LOCATIONS ---
  LatLng? myRealPosition;
  final LatLng bahirDarCenter = const LatLng(11.5742, 37.3614);
  LatLng bajajPosition = const LatLng(11.5880, 37.3600);

  @override
  void initState() {
    super.initState();
    _initLocationLogic();
  }

  // --- FEATURE: PHONE CALL LOGIC ---
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // --- FEATURE: PROFESSIONAL GPS ---
  Future<void> _initLocationLogic() async {
    // 1. Permissions check
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // 2. THE JUMPSTART (High Power - Only once)
    // We force the GPS hardware just to get the very first coordinate.
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          forceLocationManager: true, // Wake up the hardware
          timeLimit:
              const Duration(seconds: 10), // Kill it after 10s if no signal
        ),
      );
      if (mounted) {
        setState(() =>
            myRealPosition = LatLng(position.latitude, position.longitude));
      }
    } catch (e) {
      debugPrint(
          "Initial high-power fix timed out. Switching to balanced mode.");
    }

    // 3. THE CRUISE CONTROL (Balanced Power - Continuous)
    // This is the "Professional" way: It saves battery by waiting for 5 meters of movement.
    _positionStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high, // Balanced high accuracy
        distanceFilter: 5, // ONLY update if moved 5 meters (Saves 40% battery)
        intervalDuration:
            const Duration(seconds: 5), // Only check every 5 seconds
        forceLocationManager:
            false, // Let Android choose the best sensor (GPS/WiFi/Cell)
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Tana Superapp is keeping you connected",
          notificationTitle: "Location Services Active",
          enableWakeLock: true,
        ),
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() =>
            myRealPosition = LatLng(position.latitude, position.longitude));
      }
    });
  }

  // --- FEATURE: FIREBASE REAL-TIME UPDATES ---
  void listenForTripUpdates() {
    rideSubscription?.cancel();
    rideSubscription = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc('test_ride')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && tripStatus != "idle") {
        var data = snapshot.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'searching';

        if (status == 'completed' && tripStatus != "finished") {
          setState(() => tripStatus = "finished");
          _showRatingDialog();
        } else {
          if (mounted) {
            setState(() {
              tripStatus = status;
              if (data['driver_lat'] != null) {
                bajajPosition = LatLng(data['driver_lat'], data['driver_lng']);
              }
            });
          }
        }
      }
    });
  }

  Future<void> sendRequestToCloud() async {
    String newOtp = (1000 + Random().nextInt(9000)).toString();
    setState(() => currentOtp = newOtp);

    await FirebaseFirestore.instance
        .collection('ride_requests')
        .doc('test_ride')
        .set({
      'status': 'searching',
      'otp': newOtp,
      'price': 60,
      'pickup': _pickupController.text,
      'destination': _destinationController.text,
      'passenger_phone': _phoneController.text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Arrived!"),
        content: const Text("Rate your ride experience:"),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => tripStatus = "idle");
              },
              child: const Text("SUBMIT"))
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel(); // Kill the GPS sensor immediately
    rideSubscription?.cancel();
    _phoneController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LatLng activeCenter = myRealPosition ?? bahirDarCenter;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: activeCenter, initialZoom: 16.5),
            children: [
              TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'),
              MarkerLayer(
                markers: [
                  Marker(
                      point: activeCenter,
                      width: 50,
                      height: 50,
                      child: Icon(Icons.location_on,
                          color: myRealPosition == null
                              ? Colors.grey
                              : Colors.blue,
                          size: 45)),
                  if (tripStatus != "idle")
                    Marker(
                        point: bajajPosition,
                        width: 50,
                        height: 50,
                        child: const Icon(Icons.local_taxi,
                            color: Colors.teal, size: 40)),
                ],
              ),
            ],
          ),
          if (myRealPosition == null)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 5)
                      ]),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.teal)),
                      SizedBox(width: 10),
                      Text("Finding GPS...", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          tripStatus == "idle" ? _buildRequestSheet() : _buildLiveRideSheet(),
        ],
      ),
    );
  }

  Widget _buildRequestSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(25),
            children: [
              _buildTextField(_phoneController, Icons.phone, "Phone Number"),
              const SizedBox(height: 10),
              _buildTextField(
                  _destinationController, Icons.location_on, "Where to?"),
              const SizedBox(height: 20),

              // PRIMARY FEATURE: REQUEST BUTTON
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                onPressed: () async {
                  setState(() => tripStatus = "searching");
                  await sendRequestToCloud();
                  listenForTripUpdates();
                },
                child: const Text("REQUEST BAJAJ",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 12),

              // CRITICAL BACKUP FEATURE: CALL 8000
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.green[700]!, width: 2),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                onPressed: () => _makePhoneCall("8000"),
                icon: Icon(Icons.phone_callback, color: Colors.green[700]),
                label: Text("CALL 8000 (QUICK BOOK)",
                    style: TextStyle(
                        color: Colors.green[700], fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveRideSheet() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("STATUS: ${tripStatus.toUpperCase()}",
                style: const TextStyle(
                    color: Colors.teal, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            if (tripStatus == "searching")
              const Text("Searching for nearby Bajaj...")
            else ...[
              const Text("OTP FOR DRIVER:"),
              Text(currentOtp,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 5,
                      color: Colors.teal)),
            ],
            const SizedBox(height: 20),
            TextButton(
                onPressed: () => setState(() => tripStatus = "idle"),
                child:
                    const Text("CANCEL", style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, IconData icon, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.teal),
          labelText: label,
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none)),
    );
  }
}
