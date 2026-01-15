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
  String tripStatus = "idle";
  String currentOtp = "";
  StreamSubscription? rideSubscription;
  StreamSubscription<Position>? _positionStream; // To track movement live

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pickupController =
      TextEditingController(text: "My Current Location");
  final TextEditingController _destinationController = TextEditingController();

  // GPS VARIABLES
  LatLng? myRealPosition;
  final LatLng customerPosition = const LatLng(11.5742, 37.3614); // Fallback
  LatLng bajajPosition = const LatLng(11.5880, 37.3600);

  @override
  void initState() {
    super.initState();
    _startLiveTracking(); // Professional: Start live tracking immediately
    listenForTripUpdates();
  }

  // --- PROFESSIONAL GPS LOGIC ---
  void _startLiveTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if GPS services are on
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    // Check for permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // Start listening to the phone's GPS movements
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best, // High precision
        distanceFilter: 2, // Updates every 2 meters you move
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          // This automatically moves your Blue Icon on the map
          myRealPosition = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  void dispose() {
    rideSubscription?.cancel();
    _positionStream?.cancel(); // Close the GPS stream
    _phoneController.dispose();
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void listenForTripUpdates() {
    rideSubscription?.cancel();
    rideSubscription = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc('test_ride')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'searching';

        if (status == 'completed' && tripStatus != "finished") {
          setState(() => tripStatus = "finished");
          _showRatingDialog();
        } else if (status == 'accepted' || status == 'started') {
          if (mounted) setState(() => tripStatus = status);
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
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                          index < selectedStars
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber),
                      onPressed: () =>
                          setDialogState(() => selectedStars = index + 1),
                    );
                  })),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("SUBMIT"))
          ],
        );
      }),
    );
  }

  void startBajajMovement() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        // Bajaj moves toward your real-time GPS position
        double targetLat = (myRealPosition ?? customerPosition).latitude;
        double targetLng = (myRealPosition ?? customerPosition).longitude;

        double newLat = bajajPosition.latitude +
            (targetLat - bajajPosition.latitude) * 0.01;
        double newLng = bajajPosition.longitude +
            (targetLng - bajajPosition.longitude) * 0.01;
        bajajPosition = LatLng(newLat, newLng);
        if ((targetLat - newLat).abs() < 0.0001) timer.cancel();
      });
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
      'passenger_name': 'Passenger',
      'passenger_phone': _phoneController.text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // PROFESSIONAL: Show a loading spinner until GPS is found
          myRealPosition == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.teal),
                      SizedBox(height: 10),
                      Text("Finding your location...",
                          style: TextStyle(color: Colors.teal)),
                    ],
                  ),
                )
              : FlutterMap(
                  options: MapOptions(
                    initialCenter: myRealPosition!, // Centers on real GPS
                    initialZoom: 17.0, // Closer zoom for city streets
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.hullugebeya.app',
                      retinaMode: true,
                    ),
                    MarkerLayer(
                      markers: [
                        // BLUE ICON: Always at your real coordinates
                        Marker(
                            point: myRealPosition!,
                            width: 50,
                            height: 50,
                            child: const Icon(Icons.location_on,
                                color: Colors.blue, size: 45)),
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

          // DRAGGABLE MENU
          tripStatus == "idle"
              ? DraggableScrollableSheet(
                  initialChildSize: 0.35,
                  minChildSize: 0.15,
                  maxChildSize: 0.7,
                  builder: (context, scrollController) {
                    return _buildIdleMenu(scrollController);
                  },
                )
              : Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildLiveRideCard(),
                ),
        ],
      ),
    );
  }

  Widget _buildIdleMenu(ScrollController scrollController) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        children: [
          Center(
              child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone, color: Colors.teal),
              hintText: "Your Phone (e.g. 09...)",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pickupController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.my_location, color: Colors.blue),
              hintText: "Pickup Location",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _destinationController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.location_on, color: Colors.red),
              hintText: "Where to?",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () async {
              if (_phoneController.text.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Enter a valid phone number")));
                return;
              }
              if (_destinationController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Enter destination")));
                return;
              }
              setState(() => tripStatus = "searching");
              await sendRequestToCloud();
              listenForTripUpdates();
              startBajajMovement();
            },
            child: const Text("REQUEST BAJAJ",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.green[700]!, width: 2),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () => _makePhoneCall("8000"),
            icon: Icon(Icons.phone_callback, color: Colors.green[700]),
            label: Text("CALL 8000 (FAST BOOK)",
                style: TextStyle(
                    color: Colors.green[700], fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRideCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  tripStatus == "searching"
                      ? "SEARCHING..."
                      : "DRIVER IS COMING",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.teal)),
              if (tripStatus != "searching")
                const Icon(Icons.local_taxi, color: Colors.teal),
            ],
          ),
          const Divider(),
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text("Abebe Kebede"),
            subtitle: Text("Plate: AA-3-0456"),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.teal[200]!)),
            child: Column(
              children: [
                const Text("SHARE THIS OTP WITH DRIVER",
                    style: TextStyle(fontSize: 12, color: Colors.teal)),
                const SizedBox(height: 5),
                Text(currentOtp,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: Colors.teal)),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Estimated Fare:",
                  style: TextStyle(color: Colors.grey)),
              Text("60 ETB",
                  style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }
}
