import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'location_data.dart';
import 'app_drawer.dart'; // ይህን መስመር ጨምር

class BajajPassengerPage extends StatefulWidget {
  const BajajPassengerPage({super.key});

  @override
  State<BajajPassengerPage> createState() => _BajajPassengerPageState();
}

class _BajajPassengerPageState extends State<BajajPassengerPage> {
  // --- AUTH PROFILE DATA ---
  String _userName = "Passenger";

  // --- MAP STATE ---
  double _currentZoom = 15.0;

  // --- APP STATE ---
  String tripStatus = "idle";
  String currentOtp = "";
  StreamSubscription? rideSubscription;
  StreamSubscription<Position>? _positionStream;
  String? activeRideId;

  // --- SEARCH & PRICE STATE ---
  List<Map<String, dynamic>> _filteredPlaces = [];
  LatLng? _selectedDestination;
  double _calculatedKm = 0.0;
  int _estimatedPrice = 0;
  bool _isCalculatingPrice = false;

  // --- CONTROLLERS ---
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  // --- GPS & LOCATIONS ---
  LatLng? myRealPosition;
  final LatLng bahirDarCenter = const LatLng(11.5742, 37.3614);
  LatLng bajajPosition = const LatLng(11.5880, 37.3600);

  @override
  void initState() {
    super.initState();
    _loadPassengerProfile();
    _initLocationLogic();
  }

  Future<void> _loadPassengerProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _phoneController.text = doc.data()?['phoneNumber'] ?? "";
          _userName = doc.data()?['fullName'] ?? "Passenger";
        });
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _calculateRoadPrice(LatLng destination) async {
    LatLng startPos = myRealPosition ?? bahirDarCenter;
    setState(() => _isCalculatingPrice = true);

    try {
      final url = "https://router.project-osrm.org/route/v1/driving/"
          "${startPos.longitude},${startPos.latitude};"
          "${destination.longitude},${destination.latitude}?overview=false";

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        double distanceInMeters = data['routes'][0]['distance'].toDouble();
        double km = distanceInMeters / 1000;

        var settings = await FirebaseFirestore.instance
            .collection('settings')
            .doc('pricing')
            .get();

        double base = 50.0;
        double perKm = 15.0;
        if (settings.exists) {
          base = (settings.data()?['base_fare'] ?? 50.0).toDouble();
          perKm = (settings.data()?['per_km'] ?? 15.0).toDouble();
        }

        setState(() {
          _calculatedKm = km;
          _estimatedPrice = (base + (km * perKm)).round();
          _isCalculatingPrice = false;
        });
      }
    } catch (e) {
      setState(() {
        _calculatedKm = 2.0;
        _estimatedPrice = 50;
        _isCalculatingPrice = false;
      });
    }
  }

  Future<void> _initLocationLogic() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 10),
    ).listen((Position position) {
      if (mounted) {
        setState(() =>
            myRealPosition = LatLng(position.latitude, position.longitude));
      }
    });
  }

  Future<void> sendRequestToCloud() async {
    if (_estimatedPrice == 0) return;
    String newOtp = (1000 + Random().nextInt(9000)).toString();
    setState(() => currentOtp = newOtp);

    DocumentReference docRef =
        await FirebaseFirestore.instance.collection('ride_requests').add({
      'status': 'searching',
      'otp': newOtp,
      'price': _estimatedPrice,
      'distance_km': _calculatedKm.toStringAsFixed(2),
      'destination': _destinationController.text,
      'passenger_phone': _phoneController.text,
      'passenger_name': _userName,
      'passenger_lat': (myRealPosition ?? bahirDarCenter).latitude,
      'passenger_lng': (myRealPosition ?? bahirDarCenter).longitude,
      'dest_lat': _selectedDestination?.latitude,
      'dest_lng': _selectedDestination?.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() => activeRideId = docRef.id);
    listenForTripUpdates(docRef.id);
  }

  void listenForTripUpdates(String rideId) {
    rideSubscription?.cancel();
    rideSubscription = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(rideId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'searching';
        if (status == 'completed' && tripStatus != "finished") {
          setState(() => tripStatus = "finished");
          _showRatingDialog(rideId);
        } else if (mounted) {
          setState(() {
            tripStatus = status;
            if (data['driver_lat'] != null) {
              bajajPosition = LatLng(data['driver_lat'], data['driver_lng']);
            }
          });
        }
      }
    });
  }

  Future<void> _performSmartSearch(String v) async {
    if (v.isEmpty) {
      setState(() => _filteredPlaces = []);
      return;
    }

    List<Map<String, dynamic>> localMatches = masterDirectory
        .where((p) =>
            p.name.toLowerCase().contains(v.toLowerCase()) ||
            p.nameAmh.contains(v))
        .map((p) => {
              "nameAmh": p.nameAmh,
              "lat": p.coordinates.latitude,
              "lng": p.coordinates.longitude,
              "sub": "Local Place"
            })
        .toList();

    setState(() => _filteredPlaces = localMatches);

    if (v.length > 3) {
      final url = Uri.parse(
          "https://nominatim.openstreetmap.org/search?q=$v, Bahir Dar&format=json&limit=3");
      try {
        final response =
            await http.get(url, headers: {'User-Agent': 'BahirDarSuperApp'});
        if (response.statusCode == 200) {
          List data = json.decode(response.body);
          List<Map<String, dynamic>> webMatches = data.map((item) {
            return {
              "nameAmh": item['display_name'].split(',')[0],
              "lat": double.parse(item['lat']),
              "lng": double.parse(item['lon']),
              "sub": "Map Result"
            };
          }).toList();

          setState(() {
            _filteredPlaces = [...localMatches, ...webMatches];
          });
        }
      } catch (e) {
        debugPrint("Web search error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng activeCenter = myRealPosition ?? bahirDarCenter;

    return Scaffold(
      // --- 1. ድራወሩ እዚህ ተጨምሯል ---
      drawer: AppDrawer(userPhone: _phoneController.text),

      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ካርታው
          FlutterMap(
            options: MapOptions(
              initialCenter: activeCenter,
              initialZoom: 15,
              onPositionChanged: (position, hasGesture) {
                setState(() {
                  _currentZoom = position.zoom;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: activeCenter,
                    child: const Icon(Icons.person_pin_circle,
                        color: Colors.blue, size: 40),
                  ),
                  if (_selectedDestination != null)
                    Marker(
                      point: _selectedDestination!,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 40),
                    ),
                  if (tripStatus != "idle")
                    Marker(
                      point: bajajPosition,
                      child: const Icon(Icons.local_taxi,
                          color: Colors.teal, size: 35),
                    ),
                  ...masterDirectory.map((loc) {
                    String cat = loc.category.toLowerCase();
                    bool isAnchor = cat.contains("square") ||
                        cat.contains("hospital") ||
                        cat.contains("church") ||
                        cat.contains("mosque");

                    if (!isAnchor && _currentZoom < 14.5) {
                      return const Marker(
                          point: LatLng(0, 0), child: SizedBox.shrink());
                    }

                    return Marker(
                      point: loc.coordinates,
                      width: 120,
                      height: 80,
                      child: Column(
                        children: [
                          Icon(
                            getMarkerIcon(loc.category),
                            color: getMarkerColor(loc.category),
                            size: isAnchor ? 30 : 20,
                          ),
                          if (isAnchor || _currentZoom > 15.5)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                                border: Border.all(
                                    color: getMarkerColor(loc.category)
                                        .withOpacity(0.8),
                                    width: 1),
                              ),
                              child: Text(
                                loc.nameAmh,
                                style: TextStyle(
                                  fontSize: isAnchor ? 11 : 9,
                                  fontWeight: isAnchor
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // --- 2. የሜኑ አዝራር (ድራወሩን ለመክፈት) ---
          Positioned(
            top: 50,
            left: 20,
            child: Builder(
              builder: (context) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.teal, size: 30),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
            ),
          ),

          // የታችኛው የመጠየቂያ ፎርም (Sheet)
          tripStatus == "idle" ? _buildRequestSheet() : _buildLiveRideSheet(),
        ],
      ),
    );
  }

  Widget _buildRequestSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(25),
            children: [
              _buildTextField(
                  _phoneController, Icons.phone, "Phone (Auto)", (v) {},
                  readOnly: true),
              const SizedBox(height: 15),
              _buildTextField(_destinationController, Icons.search,
                  "Where to? (e.g. Gamby)", (v) => _performSmartSearch(v)),
              if (_filteredPlaces.isNotEmpty)
                Container(
                  height: 200,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15)),
                  child: ListView.builder(
                    itemCount: _filteredPlaces.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: Icon(
                          _filteredPlaces[i]['sub'] == "Local Place"
                              ? Icons.star
                              : Icons.public,
                          size: 18),
                      title: Text(_filteredPlaces[i]['nameAmh']),
                      subtitle: Text(_filteredPlaces[i]['sub']),
                      onTap: () {
                        setState(() {
                          _destinationController.text =
                              _filteredPlaces[i]['nameAmh'];
                          _selectedDestination = LatLng(
                              _filteredPlaces[i]['lat'],
                              _filteredPlaces[i]['lng']);
                          _filteredPlaces = [];
                        });
                        _calculateRoadPrice(_selectedDestination!);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (_isCalculatingPrice)
                const Center(child: CircularProgressIndicator())
              else if (_estimatedPrice > 0)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Distance: ${_calculatedKm.toStringAsFixed(1)} KM"),
                      Text("Fare: $_estimatedPrice ETB",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.teal)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size(double.infinity, 55)),
                onPressed:
                    _estimatedPrice > 0 ? () => sendRequestToCloud() : null,
                child: const Text("REQUEST BAJAJ",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _makePhoneCall("8000"),
                icon: const Icon(Icons.phone_callback, color: Colors.green),
                label: const Text("CALL 8000 (QUICK BOOK)"),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("STATUS: ${tripStatus.toUpperCase()}",
                style: const TextStyle(
                    color: Colors.teal, fontWeight: FontWeight.bold)),
            const Divider(),
            if (tripStatus == "searching")
              const Text("Finding your Bajaj...")
            else
              Text("OTP: $currentOtp",
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.bold)),
            TextButton(
                onPressed: () => setState(() => tripStatus = "idle"),
                child: const Text("CANCEL")),
          ]),
        ));
  }

  Widget _buildTextField(TextEditingController controller, IconData icon,
      String label, Function(String) onChange,
      {bool readOnly = false}) {
    return TextField(
      controller: controller,
      onChanged: onChange,
      readOnly: readOnly,
      decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.teal),
          labelText: label,
          filled: readOnly,
          fillColor: readOnly ? Colors.grey[200] : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
    );
  }

  void _showRatingDialog(String rideId) {
    int selectedStars = 5;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Arrived!"),
          content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (index) => IconButton(
                        onPressed: () =>
                            setDialogState(() => selectedStars = index + 1),
                        icon: Icon(
                            index < selectedStars
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber),
                      ))),
          actions: [
            TextButton(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('ride_requests')
                      .doc(rideId)
                      .update({'rating': selectedStars});
                  Navigator.pop(context);
                  setState(() => tripStatus = "idle");
                },
                child: const Text("SUBMIT"))
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    rideSubscription?.cancel();
    _phoneController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  IconData getMarkerIcon(String category) {
    String cat = category.toLowerCase().trim();
    if (cat.contains("school") ||
        cat.contains("university") ||
        cat.contains("college")) {
      return Icons.school;
    }
    if (cat.contains("church")) return Icons.church;
    if (cat.contains("mosque")) return Icons.mosque;
    if (cat.contains("pension") || cat.contains("hotel")) return Icons.hotel;
    if (cat.contains("apartment") || cat.contains("building")) {
      return Icons.business;
    }
    if (cat.contains("clinic") || cat.contains("hospital")) {
      return Icons.local_hospital;
    }
    if (cat.contains("restaurant") || cat.contains("cafe")) {
      return Icons.restaurant;
    }
    if (cat.contains("shop") ||
        cat.contains("mall") ||
        cat.contains("market")) {
      return Icons.shopping_bag;
    }
    if (cat.contains("bank") || cat.contains("atm")) {
      return Icons.account_balance_wallet;
    }
    if (cat.contains("square") || cat.contains("dipo")) return Icons.explore;
    return Icons.location_on;
  }

  Color getMarkerColor(String category) {
    String cat = category.toLowerCase().trim();
    if (cat.contains("square") || cat.contains("dipo")) {
      return Colors.deepOrange;
    }
    if (cat.contains("church") || cat.contains("mosque")) return Colors.purple;
    if (cat.contains("hospital") || cat.contains("clinic")) return Colors.red;
    if (cat.contains("school") || cat.contains("university")) {
      return Colors.orange;
    }
    if (cat.contains("restaurant")) return Colors.green;
    if (cat.contains("pension") || cat.contains("hotel")) {
      return Colors.blueGrey;
    }
    if (cat.contains("bank")) return Colors.amber[800]!;
    return Colors.teal;
  }
}
