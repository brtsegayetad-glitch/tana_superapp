import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'app_drawer.dart';
import 'driver_route_page.dart';

class BajajDriverPage extends StatefulWidget {
  const BajajDriverPage({super.key});

  @override
  State<BajajDriverPage> createState() => _BajajDriverPageState();
}

class _BajajDriverPageState extends State<BajajDriverPage>
    with WidgetsBindingObserver {
  // 1. Controllers
  int _selectedIndex = 0;
  final TextEditingController _otpInputController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 2. States
  bool _isOnline = false;
  StreamSubscription<Position>? _driverPositionStream;
  final List<String> _ignoredRideIds = [];

  // 3. Driver Info
  String? activeTripId;
  String _currentDriverId = "";
  String _driverName = "Loading...";
  String _plateNumber = "";
  String? _driverPhotoUrl;
  String? _currentUserPhone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDriverData();
    _initDriverLogic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationUpdates();
    _audioPlayer.dispose();
    _otpInputController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint("App is in background - GPS should keep running...");
    }
  }

  Future<void> _loadDriverData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _currentDriverId = user.uid;
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          setState(() {
            _driverName = doc.data()?['fullName'] ?? "Driver";
            _plateNumber = doc.data()?['plateNumber'] ?? "No Plate";
            _driverPhotoUrl = doc.data()?['photoUrl'];
            _currentUserPhone = doc.data()?['phoneNumber'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading driver data: $e");
    }
  }

  Future<void> _initDriverLogic() async {
    await _requestPermissions();
    _listenForAdminReminders();
  }

  Future<void> _requestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // 🔥 CRITICAL: If they only allowed "While in Use", ask for "Always"
    if (permission == LocationPermission.whileInUse) {
      // Usually, you cannot request Always directly on Android 11+,
      // you must direct them to settings or request specifically.
      // But for now, try to get the highest available.
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission is required.")));
      await Geolocator.openAppSettings();
    }

    // 🔥 Add this to stop phone from killing app
    await _checkBatteryOptimization();
  }

  void _startLiveLocationUpdates() {
    _stopLocationUpdates();

    // 🔥 REPLACED: Using AndroidSettings instead of LocationSettings
    // to unlock the enableWakeLock feature.
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      // 🚀 THE MAGIC SWITCH:
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: "Tana Driver Online",
        notificationText: "Tracking your location for ride requests...",
        notificationIcon:
            AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        enableWakeLock: true, // 💡 Keeps CPU awake when screen is off
        setOngoing: true, // Makes notification non-dismissible
      ),
    );

    _driverPositionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (_isOnline) {
        FirebaseFirestore.instance
            .collection('driver_locations')
            .doc(_currentDriverId)
            .set({
          'driver_id': _currentDriverId,
          'driverName': _driverName,
          'plateNumber': _plateNumber,
          'photoUrl': _driverPhotoUrl,
          'lat': position.latitude,
          'lng': position.longitude,
          'is_online': _isOnline,
          'isOnTrip': activeTripId != null,
          'speed': position.speed * 3.6, // Convert to km/h
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (activeTripId != null) {
          FirebaseFirestore.instance
              .collection('ride_requests')
              .doc(activeTripId!)
              .update({
            'driver_lat': position.latitude,
            'driver_lng': position.longitude,
          });
        }
      }
    });
  }

  void _stopLocationUpdates() {
    _driverPositionStream?.cancel();
    _driverPositionStream = null;
  }

// 👇 PASTE THIS BLOCK HERE
  Future<void> _checkBatteryOptimization() async {
    try {
      // This checks if the app is already exempted from battery savings
      var status = await Permission.ignoreBatteryOptimizations.status;

      if (status.isDenied) {
        // This triggers the Android system popup
        // "Allow Tana SuperApp to always run in the background?"
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      debugPrint("Battery Optimization Error: $e");
    }
  }

  Future<void> _triggerSOS() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance.collection('sos_alerts').add({
        'driverName': _driverName,
        'phone': _currentUserPhone,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'is_resolved': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      Vibration.vibrate(duration: 1000);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("🚨 SOS Alert Sent!"),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      debugPrint("SOS Error: $e");
    }
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
          if (mounted) {
            _showAdminNotification(change.doc.id, data['title'] ?? "Notice",
                data['message'] ?? "");
          }
        }
      }
    });
  }

  void _showAdminNotification(
      String docId, String title, String message) async {
    await _triggerAlert();
    if (mounted) {
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
  }

  Future<void> _triggerAlert() async {
    try {
      await _audioPlayer
          .play(UrlSource('https://www.soundjay.com/buttons/beep-01a.mp3'));
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 800);
      }
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
            title: const Text("Cancel Ride?"),
            content: const Text("Are you sure you want to cancel this trip?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("NO")),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("YES")),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(activeTripId!)
          .update({'status': 'searching', 'driver_id': null});
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
          .doc(activeTripId!)
          .update({'status': 'started'});
      _otpInputController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Wrong OTP!"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _finishTrip(int price) async {
    if (activeTripId == null) return;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    double commission = price * 0.10;

    // 1. Add to ride_history
    DocumentReference historyRef =
        FirebaseFirestore.instance.collection('ride_history').doc();
    batch.set(historyRef, {
      'driver_id': _currentDriverId,
      'driver_name': _driverName,
      'plate': _plateNumber,
      'fare': price,
      'commission': commission,
      'timestamp': FieldValue.serverTimestamp(),
      'service_type': 'app_ride',
    });

    // 2. Update user's debt and ride count
    DocumentReference userRef =
        FirebaseFirestore.instance.collection('users').doc(_currentDriverId);
    batch.update(userRef, {
      'total_debt': FieldValue.increment(commission),
      'ride_count': FieldValue.increment(1),
    });

    // 3. Mark ride as completed
    DocumentReference rideRef = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(activeTripId!);
    batch.update(rideRef, {'status': 'completed'});

    await batch.commit();

    // Check for blocking after commit
    final userDoc = await userRef.get();
    final rideCount = userDoc.data() as Map<String, dynamic>? ?? {};
    if ((rideCount['ride_count'] ?? 0) >= 10) {
      await userRef.update({'is_blocked': true});
    }

    setState(() => activeTripId = null);
  }

  Future<void> _launchPhone(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not call $number")),
        );
      }
    }
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
        title: FittedBox(
            child: Text(_selectedIndex == 0
                ? "Home - $_driverName"
                : _selectedIndex == 1
                    ? "My Wallet"
                    : "Route Permit")),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          if (_selectedIndex == 0)
            Switch(
                value: _isOnline,
                onChanged: (value) {
                  setState(() => _isOnline = value);
                  if (value) {
                    _startLiveLocationUpdates();
                  } else {
                    _stopLocationUpdates();
                  }
                  FirebaseFirestore.instance
                      .collection('driver_locations')
                      .doc(_currentDriverId)
                      .set({
                    'is_online': value,
                    'last_updated': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                },
                activeTrackColor: Colors.greenAccent),
        ],
      ),
      drawer: AppDrawer(userPhone: _currentUserPhone), // Added AppDrawer
      body: SafeArea(child: currentScreen),
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
    if (!_isOnline) return _buildOfflineUI();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentDriverId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData || !userSnapshot.data!.exists)
          return const Center(child: CircularProgressIndicator());
        var userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        bool isPaid = userData['isRoutePaid'] ?? false;
        bool isBlocked = userData['is_blocked'] ?? false;

        if (!isPaid)
          return _warningUI(Icons.warning_amber_rounded, "PERMIT EXPIRED",
              "Please pay your weekly fee.", 2);
        if (isBlocked)
          return _warningUI(Icons.block, "ACCOUNT BLOCKED",
              "You have reached the ride limit. Please pay commission.", 1);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: ElevatedButton.icon(
                onPressed: _triggerSOS,
                icon: const Icon(Icons.warning, color: Colors.white),
                label: const Text("SOS - EMERGENCY ALERT",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
            Expanded(
                child: activeTripId != null
                    ? _buildActiveTripContainer()
                    : _buildWaitingOrRequestList()),
          ],
        );
      },
    );
  }

  Widget _buildOfflineUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.power_off_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text("You are Offline",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text("Go online to receive ride requests.",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActiveTripContainer() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(activeTripId!)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists)
          return const Center(child: Text("Trip has ended."));
        var data = snapshot.data!.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'searching';
        int price = data['price'] ?? 0;
        if (status == 'accepted') return _buildOtpScreen(data);
        if (status == 'started')
          return _buildInTripScreen(price, data['passenger_phone'] ?? "");
        return const Center(child: Text("Waiting for passenger..."));
      },
    );
  }

  Widget _buildWaitingOrRequestList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .where('status', whereIn: ['searching', 'pending']).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const Center(child: Text("Waiting for ride requests..."));
        var docs = snapshot.data!.docs
            .where((d) => !_ignoredRideIds.contains(d.id))
            .toList();
        if (docs.isEmpty) return const Center(child: Text("No new requests."));
        var doc = docs.first;
        var data = doc.data() as Map<String, dynamic>;
        _triggerAlert();
        return _buildRequestPopup(data, data['price'] ?? 0, doc.id);
      },
    );
  }

  Widget _warningUI(IconData icon, String title, String msg, int navIndex) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.red),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Padding(
              padding: const EdgeInsets.all(20),
              child: Text(msg, textAlign: TextAlign.center)),
          ElevatedButton(
              onPressed: () => setState(() => _selectedIndex = navIndex),
              child: const Text("GO TO PAYMENT")),
        ],
      ),
    );
  }

  Widget _buildRequestPopup(
      Map<String, dynamic> data, int price, String rideId) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("NEW RIDE REQUEST",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 8),
              FittedBox(
                  child: Text("$price ETB",
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.green))),
              const SizedBox(height: 4),
              Text("To: ${data['destination'] ?? 'Unknown'}",
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () => _acceptRide(rideId),
                      child: const Text("ACCEPT"))),
              TextButton(
                  onPressed: () => setState(() => _ignoredRideIds.add(rideId)),
                  child: const Text("IGNORE",
                      style: TextStyle(color: Colors.red))),
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
          ListTile(
              title: const Text("Passenger Pickup"),
              subtitle: Text(rideData['passenger_name'] ?? ""),
              trailing: IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  onPressed: () =>
                      _launchPhone(rideData['passenger_phone'] ?? ""))),
          const SizedBox(height: 10),
          TextField(
              controller: _otpInputController,
              decoration: const InputDecoration(
                  labelText: "Enter Passenger OTP",
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: () => _verifyAndStart(rideData['otp'] ?? ""),
                  child: const Text("VERIFY & START TRIP"))),
          TextButton(
              onPressed: _cancelActiveTrip,
              child: const Text("Cancel Ride",
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
          const Text("TRIP IN PROGRESS...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: () => _finishTrip(price),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("FINISH & COLLECT CASH",
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildWalletScreen() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentDriverId)
          .snapshots(),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                decoration: BoxDecoration(
                    color: Colors.teal[800],
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30))),
                child: Column(
                  children: [
                    const Text("Current Commission Debt",
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Text("${debt.toStringAsFixed(2)} ETB",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Chip(
                      backgroundColor: Colors.amber[300],
                      label: Text("Rides toward next limit: $count / 10",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const Padding(
                  padding: EdgeInsets.all(15.0),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Recent Ride History",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)))),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ride_history')
                    .where('driver_id', isEqualTo: _currentDriverId)
                    .orderBy('timestamp', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, historySnapshot) {
                  if (!historySnapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: historySnapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var trip = historySnapshot.data!.docs[index].data()
                          as Map<String, dynamic>;
                      return ListTile(
                          leading: const Icon(Icons.check_circle,
                              color: Colors.green),
                          title: Text("Fare: ${trip['fare'] ?? 0} ETB"),
                          subtitle: Text(
                              "Commission Paid: ${trip['commission']?.toStringAsFixed(2) ?? '0.00'} ETB"));
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
}
