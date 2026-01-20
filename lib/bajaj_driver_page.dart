import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'driver_route_page.dart'; // Ensure this file exists

class BajajDriverPage extends StatefulWidget {
  const BajajDriverPage({super.key});

  @override
  State<BajajDriverPage> createState() => _BajajDriverPageState();
}

class _BajajDriverPageState extends State<BajajDriverPage> {
  // --- STATE & CONTROLLERS ---
  int _selectedIndex = 0;
  final TextEditingController _otpInputController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isOnline = true;
  StreamSubscription<Position>? _driverPositionStream;

  final List<String> _ignoredRideIds = [];

  // AUTH SYNCED DATA
  String? activeTripId;
  String _currentDriverId = "";
  String _driverName = "Loading...";
  String _plateNumber = "";

  @override
  void initState() {
    super.initState();
    _fetchDriverProfile();
  }

  Future<void> _fetchDriverProfile() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentDriverId = user.uid;
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentDriverId)
          .get();

      if (doc.exists) {
        setState(() {
          _driverName = doc.data()?['fullName'] ?? "Driver";
          _plateNumber = doc.data()?['plateNumber'] ?? "No Plate";
        });
      }
    }
    _initDriverLogic();
  }

  Future<void> _initDriverLogic() async {
    await _requestPermissions();
    _listenForAdminReminders();
    _startLiveLocationUpdates();
  }

  Future<void> _requestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  void _startLiveLocationUpdates() {
    _driverPositionStream?.cancel();
    _driverPositionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (_isOnline && activeTripId != null) {
        FirebaseFirestore.instance
            .collection('ride_requests')
            .doc(activeTripId)
            .update({
          'driver_lat': position.latitude,
          'driver_lng': position.longitude,
        });
      }
    });
  }

  void _listenForAdminReminders() {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('target_driver_id', isEqualTo: _currentDriverId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          _showAdminNotification(change.doc.id, data['title'], data['message']);
        }
      }
    });
  }

  void _showAdminNotification(
      String docId, String title, String message) async {
    _triggerAlert();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(docId)
                  .update({'isRead': true});
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text("OK, UNDERSTOOD"),
          ),
        ],
      ),
    );
  }

  void _triggerAlert() async {
    try {
      await _audioPlayer
          .play(UrlSource('https://www.soundjay.com/buttons/beep-01a.mp3'));
      Vibration.vibrate(duration: 800);
    } catch (e) {
      debugPrint("Alert error: $e");
    }
  }

  Future<void> _acceptRide(String rideId) async {
    await FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(rideId)
        .update({
      'status': 'accepted',
      'driver_id': _currentDriverId,
      'driver_name': _driverName,
      'driver_plate': _plateNumber,
    });
    setState(() => activeTripId = rideId);
  }

  Future<void> _cancelActiveTrip() async {
    if (activeTripId == null) return;
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Cancel Trip?"),
            content: const Text(
                "This will release the passenger for other drivers."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("NO")),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("YES, CANCEL")),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(activeTripId)
          .update({
        'status': 'searching',
        'driver_id': null,
        'driver_name': null,
      });
      setState(() {
        activeTripId = null;
        _otpInputController.clear();
      });
    }
  }

  Future<void> _verifyAndStart(String correctOtp) async {
    if (_otpInputController.text.trim() == correctOtp && activeTripId != null) {
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(activeTripId)
          .update({'status': 'started'});
      _otpInputController.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Wrong OTP!")));
    }
  }

  Future<void> _finishTrip(int price) async {
    if (activeTripId == null) return;
    var tripSnapshot = await FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(activeTripId)
        .get();
    var tripData = tripSnapshot.data() ?? {};
    double commission = price * 0.10;

    await FirebaseFirestore.instance.collection('ride_history').add({
      'driver_id': _currentDriverId,
      'driver_name': _driverName,
      'plate': _plateNumber,
      'fare': price,
      'commission': commission,
      'distance_km': tripData['distance_km'] ?? "0.0",
      'timestamp': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentDriverId)
        .update({
      'total_debt': FieldValue.increment(commission),
    });

    await FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(activeTripId)
        .update({'status': 'completed'});
    setState(() => activeTripId = null);
  }

  Future<void> _launchPhone(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    // Choose screen based on Bottom Nav selection
    Widget currentScreen;
    if (_selectedIndex == 0) {
      currentScreen = _buildHomeScreen();
    } else if (_selectedIndex == 1) {
      currentScreen = _buildWalletScreen();
    } else {
      currentScreen = const DriverRoutePage(); // Third tab for Permit
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_selectedIndex == 0
            ? "Tana Driver: $_driverName"
            : _selectedIndex == 1
                ? "My Wallet"
                : "Route Permit"),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          if (_selectedIndex == 0)
            Switch(
              value: _isOnline,
              onChanged: (v) => setState(() => _isOnline = v),
              activeTrackColor: Colors.greenAccent,
            )
        ],
      ),
      body: currentScreen,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.teal[800],
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: "Wallet"),
          BottomNavigationBarItem(icon: Icon(Icons.badge), label: "Permit"),
        ],
      ),
    );
  }

  Widget _buildHomeScreen() {
    if (!_isOnline) return const Center(child: Text("You are Offline"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wallets')
          .doc(_currentDriverId)
          .snapshots(),
      builder: (context, walletSnapshot) {
        if (!walletSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        bool isPaid = false;
        if (walletSnapshot.data!.exists) {
          isPaid = walletSnapshot.data!['isRoutePaid'] ?? false;
        }

        if (!isPaid) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 80, color: Colors.red),
                const Text("WEEKLY PERMIT EXPIRED",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Padding(
                  padding: EdgeInsets.all(25.0),
                  child: Text(
                      "You must pay your weekly route association fee before you can accept new rides.",
                      textAlign: TextAlign.center),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[800]),
                  onPressed: () => setState(() => _selectedIndex = 2),
                  child: const Text("GO TO PAYMENT",
                      style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
        }

        // Normal Ride Logic
        if (activeTripId != null) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('ride_requests')
                .doc(activeTripId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text("Trip Ended"));
              }
              var data = snapshot.data!.data() as Map<String, dynamic>;
              String status = data['status'] ?? 'searching';
              int price = data['price'] ?? 0;
              if (status == 'accepted') return _buildOtpScreen(data);
              if (status == 'started') {
                return _buildInTripScreen(price, data['passenger_phone'] ?? "");
              }
              return const Center(child: CircularProgressIndicator());
            },
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ride_requests')
              .where('status', whereIn: ['searching', 'pending']).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("Waiting for requests..."));
            }
            var docs = snapshot.data!.docs
                .where((d) => !_ignoredRideIds.contains(d.id))
                .toList();
            if (docs.isEmpty) {
              return const Center(child: Text("Waiting for new requests..."));
            }

            docs.sort((a, b) {
              var aTime = a['timestamp'] as Timestamp?;
              var bTime = b['timestamp'] as Timestamp?;
              return (bTime ?? Timestamp.now())
                  .compareTo(aTime ?? Timestamp.now());
            });

            var doc = docs.first;
            var data = doc.data() as Map<String, dynamic>;
            _triggerAlert();
            return _buildRequestPopup(data, data['price'] ?? 0, doc.id);
          },
        );
      },
    );
  }

  Widget _buildRequestPopup(
      Map<String, dynamic> data, int price, String rideId) {
    bool isCallCenter = data['type'] == 'call_center';
    return Center(
      child: SingleChildScrollView(
        child: Card(
          margin: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isCallCenter ? "OFFLINE CALL" : "NEW RIDE",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.teal)),
                const Divider(height: 30),
                Text(isCallCenter ? data['pickup_location'] : "$price ETB",
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                const SizedBox(height: 20),
                Text("To: ${data['destination'] ?? 'Piazza area'}",
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[800],
                      minimumSize: const Size(double.infinity, 55)),
                  onPressed: () => _acceptRide(rideId),
                  child: const Text("ACCEPT RIDE",
                      style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                    onPressed: () =>
                        setState(() => _ignoredRideIds.add(rideId)),
                    child: const Text("IGNORE / DECLINE",
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpScreen(Map<String, dynamic> rideData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ListTile(
            title: const Text("Passenger Found"),
            trailing: IconButton(
                icon: const Icon(Icons.phone, color: Colors.green),
                onPressed: () =>
                    _launchPhone(rideData['passenger_phone'] ?? "")),
          ),
          TextField(
              controller: _otpInputController,
              decoration: const InputDecoration(
                  labelText: "Enter 4-Digit OTP", border: OutlineInputBorder()),
              keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
              onPressed: () => _verifyAndStart(rideData['otp'] ?? ""),
              child: const Text("START TRIP")),
          const SizedBox(height: 10),
          OutlinedButton(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 45)),
              onPressed: _cancelActiveTrip,
              child: const Text("CANCEL TRIP",
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildInTripScreen(int price, String phone) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_taxi, size: 80, color: Colors.teal),
          const Text("IN PROGRESS",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: () => _finishTrip(price),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("FINISH & COLLECT CASH",
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildWalletScreen() {
    return Column(
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_currentDriverId)
              .snapshots(),
          builder: (context, snapshot) {
            double debt = (snapshot.hasData && snapshot.data!.exists)
                ? (snapshot.data!['total_debt'] ?? 0.0).toDouble()
                : 0.0;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              color: Colors.teal[700],
              child: Column(children: [
                const Text("COMMISSION DEBT",
                    style: TextStyle(color: Colors.white70)),
                Text("${debt.toStringAsFixed(2)} ETB",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold)),
              ]),
            );
          },
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('ride_history')
                .where('driver_id', isEqualTo: _currentDriverId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var trip = snapshot.data!.docs[index];
                  return ListTile(
                      title: Text("Fare: ${trip['fare']} ETB"),
                      subtitle: Text("Commission: ${trip['commission']} ETB"));
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _driverPositionStream?.cancel();
    _audioPlayer.dispose();
    _otpInputController.dispose();
    super.dispose();
  }
}
