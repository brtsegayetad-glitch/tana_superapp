import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import 'driver_route_page.dart';
import 'app_drawer.dart';

class BajajDriverPage extends StatefulWidget {
  const BajajDriverPage({super.key});

  @override
  State<BajajDriverPage> createState() => _BajajDriverPageState();
}

class _BajajDriverPageState extends State<BajajDriverPage> {
  int _selectedIndex = 0;
  final TextEditingController _otpInputController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isOnline = true;
  StreamSubscription<Position>? _driverPositionStream;
  final List<String> _ignoredRideIds = [];

  String? activeTripId;
  String _currentDriverId = "";
  String _driverName = "Loading...";
  String _plateNumber = "";
  String? _currentUserPhone;

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
        if (mounted) {
          setState(() {
            _driverName = doc.data()?['fullName'] ?? "Driver";
            _plateNumber = doc.data()?['plateNumber'] ?? "No Plate";
            _currentUserPhone = doc.data()?['phoneNumber'];
          });
        }
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
          accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      if (_isOnline && activeTripId != null) {
        FirebaseFirestore.instance
            .collection('ride_requests')
            .doc(activeTripId!)
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
          _showAdminNotification(
              change.doc.id, data['title'] ?? "Notice", data['message'] ?? "");
        }
      }
    });
  }

  void _showAdminNotification(String docId, String title, String message) async {
    _triggerAlert();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
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
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _triggerAlert() async {
    try {
      await _audioPlayer.play(UrlSource('https://www.soundjay.com/buttons/beep-01a.mp3'));
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
            title: const Text("Cancel?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("NO")),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("YES")),
            ],
          ),
        ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('ride_requests').doc(activeTripId!).update({
        'status': 'searching',
        'driver_id': null,
      });
      setState(() {
        activeTripId = null;
        _otpInputController.clear();
      });
    }
  }

  Future<void> _verifyAndStart(String correctOtp) async {
    if (_otpInputController.text.trim() == correctOtp && activeTripId != null) {
      await FirebaseFirestore.instance.collection('ride_requests').doc(activeTripId!).update({'status': 'started'});
      _otpInputController.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wrong OTP!")));
    }
  }

  Future<void> _finishTrip(int price) async {
    if (activeTripId == null) return;
    double commission = price * 0.10;

    // Log ride history
    await FirebaseFirestore.instance.collection('ride_history').add({
      'driver_id': _currentDriverId,
      'driver_name': _driverName,
      'plate': _plateNumber,
      'fare': price,
      'commission': commission,
      'timestamp': FieldValue.serverTimestamp(),
      'service_type': '8000_call',
    });

    // Increment debt and ride count in users collection
    await FirebaseFirestore.instance.collection('users').doc(_currentDriverId).update({
      'total_debt': FieldValue.increment(commission),
      'ride_count': FieldValue.increment(1),
    });

    // Block driver if they reach 10 rides
    var doc = await FirebaseFirestore.instance.collection('users').doc(_currentDriverId).get();
    int rideCount = doc.data()?['ride_count'] ?? 0;
    if (rideCount >= 10) {
      await FirebaseFirestore.instance.collection('users').doc(_currentDriverId).update({'is_blocked': true});
    }

    await FirebaseFirestore.instance.collection('ride_requests').doc(activeTripId!).update({'status': 'completed'});
    setState(() => activeTripId = null);
  }

  Future<void> _launchPhone(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;
    if (_selectedIndex == 0) {
      currentScreen = _buildHomeScreen();
    } else if (_selectedIndex == 1) {
      currentScreen = _buildWalletScreen();
    } else {
      currentScreen = const DriverRoutePage();
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: FittedBox(child: Text(_selectedIndex == 0 ? "Driver: $_driverName" : _selectedIndex == 1 ? "Wallet" : "Permit")),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          if (_selectedIndex == 0)
            Switch(value: _isOnline, onChanged: (v) => setState(() => _isOnline = v), activeTrackColor: Colors.greenAccent)
        ],
      ),
      drawer: AppDrawer(userPhone: _currentUserPhone),
      body: SafeArea(child: currentScreen),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.teal[800],
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "Wallet"),
          BottomNavigationBarItem(icon: Icon(Icons.badge), label: "Permit"),
        ],
      ),
    );
  }

  Widget _buildHomeScreen() {
    if (!_isOnline) return const Center(child: Text("You are Offline"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_currentDriverId).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        bool isPaid = userData['isRoutePaid'] ?? false;
        bool isBlocked = userData['is_blocked'] ?? false;
        int rideCount = userData['ride_count'] ?? 0;

        // --- Block 1: Route Permit ---
        if (!isPaid) {
          return _warningUI(Icons.warning_amber_rounded, "PERMIT EXPIRED", "Please pay your weekly fee.", 2);
        }

        // --- Block 2: 10 Ride Limit ---
        if (isBlocked || rideCount >= 10) {
          return _warningUI(Icons.block, "LIMIT REACHED", "You have completed 10 rides. Please pay commission.", 1);
        }

        if (activeTripId != null) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('ride_requests').doc(activeTripId!).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text("Trip Ended"));
              var data = snapshot.data!.data() as Map<String, dynamic>;
              String status = data['status'] ?? 'searching';
              int price = data['price'] ?? 0;
              if (status == 'accepted') return _buildOtpScreen(data);
              if (status == 'started') return _buildInTripScreen(price, data['passenger_phone'] ?? "");
              return const Center(child: CircularProgressIndicator());
            },
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('ride_requests').where('status', whereIn: ['searching', 'pending']).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Waiting for requests..."));
            var docs = snapshot.data!.docs.where((d) => !_ignoredRideIds.contains(d.id)).toList();
            if (docs.isEmpty) return const Center(child: Text("Waiting..."));
            var doc = docs.first;
            var data = doc.data() as Map<String, dynamic>;
            _triggerAlert();
            return _buildRequestPopup(data, data['price'] ?? 0, doc.id);
          },
        );
      },
    );
  }

  Widget _warningUI(IconData icon, String title, String msg, int navIndex) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.red),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Padding(padding: const EdgeInsets.all(20), child: Text(msg, textAlign: TextAlign.center)),
          ElevatedButton(onPressed: () => setState(() => _selectedIndex = navIndex), child: const Text("GO TO PAYMENT")),
        ],
      ),
    );
  }

  Widget _buildRequestPopup(Map<String, dynamic> data, int price, String rideId) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("NEW RIDE REQUEST", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              FittedBox(child: Text("$price ETB", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.green))),
              Text("To: ${data['destination'] ?? 'Piazza'}", textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _acceptRide(rideId), child: const Text("ACCEPT"))),
              TextButton(onPressed: () => setState(() => _ignoredRideIds.add(rideId)), child: const Text("IGNORE", style: TextStyle(color: Colors.red))),
            ],
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
          ListTile(title: const Text("Passenger Found"), trailing: IconButton(icon: const Icon(Icons.phone, color: Colors.green), onPressed: () => _launchPhone(rideData['passenger_phone'] ?? ""))),
          TextField(controller: _otpInputController, decoration: const InputDecoration(labelText: "OTP Code", border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _verifyAndStart(rideData['otp'] ?? ""), child: const Text("START TRIP"))),
          TextButton(onPressed: _cancelActiveTrip, child: const Text("CANCEL", style: TextStyle(color: Colors.red))),
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
          const Text("TRIP IN PROGRESS"),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => _finishTrip(price), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("FINISH & COLLECT CASH", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildWalletScreen() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_currentDriverId).snapshots(),
      builder: (context, userSnapshot) {
        double debt = 0.0;
        int count = 0;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
          debt = (userData['total_debt'] ?? 0.0).toDouble();
          count = userData['ride_count'] ?? 0;
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                decoration: BoxDecoration(color: Colors.teal[800], borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
                child: Column(
                  children: [
                    const Text("Commission Debt", style: TextStyle(color: Colors.white70)),
                    Text("${debt.toStringAsFixed(2)} ETB", style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text("Rides: $count / 10", style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Padding(padding: EdgeInsets.all(15.0), child: Align(alignment: Alignment.centerLeft, child: Text("History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('ride_history').where('driver_id', isEqualTo: _currentDriverId).orderBy('timestamp', descending: true).snapshots(),
                builder: (context, historySnapshot) {
                  if (!historySnapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return ListView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    itemCount: historySnapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var trip = historySnapshot.data!.docs[index].data() as Map<String, dynamic>;
                      return ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: Text("${trip['fare'] ?? 0} ETB"), subtitle: Text("Commission: ${trip['commission'] ?? 0} ETB"));
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
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
