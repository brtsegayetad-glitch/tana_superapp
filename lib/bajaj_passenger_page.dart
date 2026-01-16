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
  // --- FEATURE: SMART ADAPTIVE GPS (S22 ULTRA OPTIMIZED) ---
  Future<void> _initLocationLogic() async {
    // 1. Permissions check
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // 2. ADAPTIVE POWER CHECK
    // If the battery is low, we relax the GPS slightly to save the user's phone.
    LocationAccuracy smartAccuracy = LocationAccuracy.best;
    int filterDistance = 5; // Default 5 meters

    try {
      // Note: If you want to use the actual battery % later,
      // you can add the 'battery_plus' package.
      // For now, we set 'best' as the standard for Bajaj rides.
      smartAccuracy = LocationAccuracy.best;
    } catch (e) {
      smartAccuracy = LocationAccuracy.high;
    }

    // 3. THE ANDROID-SPECIFIC SETTINGS
    final AndroidSettings androidSettings = AndroidSettings(
      accuracy: smartAccuracy,
      distanceFilter: filterDistance,
      forceLocationManager: true,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Tana Superapp is protecting your ride",
        notificationTitle: "GPS Service Active",
        enableWakeLock: true, // Stops S22 Ultra from killing the app
      ),
    );

    // 4. THE STARTUP
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: androidSettings,
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() =>
            myRealPosition = LatLng(position.latitude, position.longitude));
      }
    } catch (e) {
      debugPrint("Initial GPS lock failed: $e");
    }

    // 5. THE LIVE STREAM
    _positionStream =
        Geolocator.getPositionStream(locationSettings: androidSettings)
            .listen((Position position) {
      if (mounted) {
        setState(() {
          myRealPosition = LatLng(position.latitude, position.longitude);
        });
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
    // 1. Generate a fresh OTP for security
    String newOtp = (1000 + Random().nextInt(9000)).toString();
    setState(() => currentOtp = newOtp);

    // 2. Send the COMPLETE data to Firebase
    await FirebaseFirestore.instance
        .collection('ride_requests')
        .doc('test_ride')
        .set({
      'status': 'searching',
      'otp': newOtp,
      'price': 60, // Fixed price for now
      'pickup': _pickupController.text,
      'destination': _destinationController.text,
      'passenger_phone': _phoneController.text,

      // --- ADDED THESE CRITICAL GPS LINES ---
      'passenger_lat': myRealPosition?.latitude ?? bahirDarCenter.latitude,
      'passenger_lng': myRealPosition?.longitude ?? bahirDarCenter.longitude,

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
          // 1. THE MAP LAYER (With Zoom Limits for Data/Battery)
          FlutterMap(
            options: MapOptions(
              initialCenter: activeCenter,
              initialZoom: 16.5,
              minZoom: 13.0, // Limit zoom out to save data
              maxZoom: 18.5, // Limit zoom in to save memory
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tana.superapp',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                      point: activeCenter,
                      width: 50, // PRESERVED: Your original size
                      height: 50, // PRESERVED: Your original size
                      child: Icon(Icons.location_on,
                          color: myRealPosition == null
                              ? Colors.grey
                              : Colors.blue,
                          size: 45)),
                  if (tripStatus != "idle")
                    Marker(
                        point: bajajPosition,
                        width: 50, // PRESERVED: Your original size
                        height: 50, // PRESERVED: Your original size
                        child: const Icon(Icons.local_taxi,
                            color: Colors.teal, size: 40)),
                ],
              ),
            ],
          ),

          // 2. THE GPS STATUS INDICATOR
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
                  child: Row(
                    // Note: Removed 'const' for dynamic children
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 15, // PRESERVED: Your original size
                          height: 15, // PRESERVED: Your original size
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.teal)),
                      const SizedBox(width: 10),
                      const Text("Finding GPS...",
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          // 3. THE INTERFACE (Idle vs Live Ride)
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
