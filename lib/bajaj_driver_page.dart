import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

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
        .collection('drivers')
        .doc(_currentDriverId)
        .set({
      'total_debt': FieldValue.increment(commission),
      'name': _driverName,
      'plate': _plateNumber,
    }, SetOptions(merge: true));

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
    return Scaffold(
      // FIXED: Prevents the background from squishing when the keyboard opens
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
            _selectedIndex == 0 ? "Tana Driver: $_driverName" : "My Wallet"),
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
      body: _selectedIndex == 0 ? _buildHomeScreen() : _buildWalletScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.teal[800],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: "Wallet"),
        ],
      ),
    );
  }

  Widget _buildHomeScreen() {
    if (!_isOnline) return const Center(child: Text("You are Offline"));

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

    // FIXED QUERY: Removed orderBy to avoid Index errors and ensure Admin dispatches show up
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ride_requests').where(
          'status',
          whereIn: ['searching', 'pending']).snapshots(), // No orderBy here
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text("Waiting for requests in Bahir Dar..."));
        }

        // Sort in-memory instead of in the cloud (Better for 4GB RAM & avoids Index errors)
        var docs = snapshot.data!.docs;
        docs.sort((a, b) {
          var aTime = a['timestamp'] as Timestamp?;
          var bTime = b['timestamp'] as Timestamp?;
          if (aTime == null) return -1;
          if (bTime == null) return 1;
          return bTime.compareTo(aTime);
        });

        var doc = docs.first;
        var data = doc.data() as Map<String, dynamic>;

        // Only trigger sound for new ones
        _triggerAlert();

        int displayPrice = data['price'] ?? 0;
        return _buildRequestPopup(data, displayPrice, doc.id);
      },
    );
  }

  Widget _buildRequestPopup(
      Map<String, dynamic> data, int price, String rideId) {
    bool isCallCenter = data['type'] == 'call_center';

    return Center(
      // FIXED: Added SingleChildScrollView inside the popup to avoid overflow
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
                Text(isCallCenter ? "OFFLINE CALL REQUEST" : "NEW RIDE REQUEST",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.teal)),
                const Divider(height: 30),
                Text(isCallCenter ? data['pickup_location'] : "$price ETB",
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                if (!isCallCenter)
                  Text("Distance: ${data['distance_km'] ?? '0.0'} KM",
                      style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          isCallCenter
                              ? "Pick up at: ${data['pickup_location']}"
                              : "To: ${data['destination'] ?? 'Unknown'}",
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[800],
                      minimumSize: const Size(double.infinity, 55)),
                  onPressed: () => _acceptRide(rideId),
                  child: const Text("ACCEPT RIDE",
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpScreen(Map<String, dynamic> rideData) {
    bool isCallCenter = rideData['type'] == 'call_center';

    // FIXED: Wrapped in SingleChildScrollView to allow space for the keyboard
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ListTile(
            title: const Text("Passenger Found"),
            trailing: IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () => _launchPhone(rideData['passenger_phone'] ?? ""),
            ),
          ),
          if (!isCallCenter) ...[
            TextField(
              controller: _otpInputController,
              decoration: const InputDecoration(
                  labelText: "Enter 4-Digit OTP", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)),
                onPressed: () => _verifyAndStart(rideData['otp'] ?? ""),
                child: const Text("START TRIP")),
          ] else
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size(double.infinity, 50)),
                onPressed: () => _verifyAndStart(""),
                child: const Text("START TRIP (NO OTP)",
                    style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildInTripScreen(int price, String phone) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_taxi, size: 80, color: Colors.teal),
            const Text("DRIVING TO DESTINATION",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _launchPhone(phone),
              icon: const Icon(Icons.phone),
              label: const Text("CALL PASSENGER"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _finishTrip(price),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("FINISH & COLLECT CASH",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
            double debt = 0;
            if (snapshot.hasData && snapshot.data!.exists) {
              debt = (snapshot.data!['total_debt'] ?? 0.0).toDouble();
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: Colors.teal[700]),
              child: Column(
                children: [
                  const Text("TOTAL COMMISSION DEBT",
                      style: TextStyle(color: Colors.white70)),
                  Text("${debt.toStringAsFixed(2)} ETB",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text("RECENT TRIPS",
                  style: TextStyle(fontWeight: FontWeight.bold))),
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
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    child: ListTile(
                      title: Text("Fare: ${trip['fare']} ETB"),
                      subtitle: Text("Commission: ${trip['commission']} ETB"),
                    ),
                  );
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
