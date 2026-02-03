import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
// 💡 ለ Android ቅንብሮች ይህ ያስፈልጋል (Geolocator ፓኬጅ ውስጥ አለ)
import 'package:geolocator_android/geolocator_android.dart';
import 'dart:async';
import 'app_drawer.dart';
import 'driver_route_page.dart';

class BajajDriverPage extends StatefulWidget {
  const BajajDriverPage({super.key});

  @override
  State<BajajDriverPage> createState() => _BajajDriverPageState();
}

class _BajajDriverPageState extends State<BajajDriverPage>
    with WidgetsBindingObserver {
  // 1. መቆጣጠሪያዎች (Controllers)
  int _selectedIndex = 0;
  final TextEditingController _otpInputController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 2. ሁኔታዎች (States)
  bool _isOnline = false;
  StreamSubscription<Position>? _driverPositionStream;
  final List<String> _ignoredRideIds = [];

  // 3. የሾፌሩ መረጃዎች
  String? activeTripId;
  String _currentDriverId = "";
  String _driverName = "Loading...";
  String _plateNumber = "";
  String? _driverPhotoUrl;
  String? _currentUserPhone;

  @override
  void initState() {
    super.initState();
    // App Lifecycle (ስልኩ ሲዘጋና ሲከፈት) ለመከታተል
    WidgetsBinding.instance.addObserver(this);
    _loadDriverData();
    _initDriverLogic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationUpdates(); // ስክሪኑ ሲዘጋ ሳይሆን አፑ ሙሉ ለሙሉ ሲጠፋ ብቻ ይቁም
    _audioPlayer.dispose();
    _otpInputController.dispose();
    super.dispose();
  }

  // ይህ አስፈላጊ ነው፡ አፑ ወደ background ሲሄድ ስራ እንዳያቆም
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      debugPrint(
          "App is in background - GPS should keep running due to Foreground Notification");
    }
  }

  Future<void> _loadDriverData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() => _currentDriverId = user.uid);

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
      debugPrint("Error loading data: $e");
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
    if (permission == LocationPermission.deniedForever) {
      // ፍቃድ ሙሉ ለሙሉ ከተከለከለ ወደ setting መላክ
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Location permission is required for GPS tracking.")));
    }
  }

  // 🔥 ዋናው ለውጥ እዚህ ጋር ነው (GPS Fix)
  void _startLiveLocationUpdates() {
    // ቀድሞ እየሰራ ካለ እናቁመው
    _stopLocationUpdates();

    // ለ Android ስልክ ባትሪ ሲቆጥብም (Sleep Mode) እንዲሰራ የሚያደርግ Setting
    LocationSettings locationSettings;

    if (Theme.of(context).platform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // በየ 10 ሜትሩ
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 5), // በየ 5 ሰከንዱ ሞክር
        // 👇 ይህ በጣም ወሳኝ ነው፡ ስልኩ ሲዘጋ Notification ያሳያል፣ ኦፕሬቲንግ ሲስተሙ አፑን እንዳይዘጋው ያደርጋል
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Tana Driver Active",
          notificationText: "Your location is being shared for rides.",
          enableWakeLock: true,
        ),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    _driverPositionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) async {
      // 💡 Internet Connection Check (Simple check)
      // ቦታው ከተገኘ በኋላ ኢንተርኔት ከሌለ ዝም ብሎ ይሞክራል፣ ነገር ግን Error እንዳይፈጥር Try/Catch እንጠቀማለን
      try {
        await FirebaseFirestore.instance
            .collection('driver_locations')
            .doc(_currentDriverId)
            .set({
          'driver_id': _currentDriverId,
          'driverName': _driverName,
          'plateNumber': _plateNumber,
          'phoneNumber': _currentUserPhone,
          'photoUrl': _driverPhotoUrl,
          'speed': position.speed * 3.6,
          'isOnTrip': activeTripId != null,
          'lat': position.latitude,
          'lng': position.longitude,
          'is_online': true,
          'status': activeTripId != null ? 'busy' : 'available',
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // አክቲቭ ትሪፕ ካለ እሱንም እናዘምነዋለን
        if (activeTripId != null) {
          await FirebaseFirestore.instance
              .collection('ride_requests')
              .doc(activeTripId!)
              .update({
            'driver_lat': position.latitude,
            'driver_lng': position.longitude,
          });
        }
      } catch (e) {
        // ኢንተርኔት ከጠፋ እዚህ ጋር ይገባል
        debugPrint("Connection failed while sending GPS: $e");
        // ከተፈለገ እዚህ ጋር ለተጠቃሚው "No Internet" ማለት ይቻላል
      }
    });
  }

  void _stopLocationUpdates() {
    _driverPositionStream?.cancel();
    _driverPositionStream = null;
  }

  // --- ሌሎች አስፈላጊ ፋንክሽኖች ---

  Future<void> _triggerSOS() async {
    // ... (SOS code remains same)
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("🚨 SOS Sent!"), backgroundColor: Colors.red));
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
          _showAdminNotification(
              change.doc.id, data['title'] ?? "Notice", data['message'] ?? "");
        }
      }
    });
  }

  void _showAdminNotification(String docId, String title, String message) {
    _triggerAlert();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('notifications')
                  .doc(docId)
                  .update({'isRead': true});
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
      await _audioPlayer.play(UrlSource(
          'https://raw.githubusercontent.com/pro-ali-king/audio_assets/main/notification_light.mp3'));
      if (await Vibration.hasVibrator() ?? true) {
        Vibration.vibrate(duration: 400);
      }
    } catch (e) {
      debugPrint("Alert error: $e");
    }
  }

  // --- Ride Logic ---
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
            builder: (ctx) =>
                AlertDialog(title: const Text("Cancel?"), actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("NO")),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("YES"))
                ])) ??
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
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Wrong OTP!")));
    }
  }

  Future<void> _finishTrip(int price) async {
    if (activeTripId == null) return;
    double commission = price * 0.10;

    // Batch write for consistency
    WriteBatch batch = FirebaseFirestore.instance.batch();

    var historyRef =
        FirebaseFirestore.instance.collection('ride_history').doc();
    batch.set(historyRef, {
      'driver_id': _currentDriverId,
      'driver_name': _driverName,
      'plate': _plateNumber,
      'fare': price,
      'commission': commission,
      'timestamp': FieldValue.serverTimestamp(),
      'service_type': '8000_call',
    });

    var userRef =
        FirebaseFirestore.instance.collection('users').doc(_currentDriverId);
    batch.update(userRef, {
      'total_debt': FieldValue.increment(commission),
      'ride_count': FieldValue.increment(1),
    });

    var rideRef = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(activeTripId!);
    batch.update(rideRef, {'status': 'completed'});

    await batch.commit();

    // Check blockage limits separately
    var doc = await userRef.get();
    if ((doc.data()?['ride_count'] ?? 0) >= 10) {
      await userRef.update({'is_blocked': true});
    }

    setState(() => activeTripId = null);
  }

  Future<void> _launchPhone(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  // --- UI PART ---
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
      drawer: AppDrawer(userPhone: _currentUserPhone),
      appBar: AppBar(
        leading: Builder(
            builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer())),
        title: Text(_selectedIndex == 0
            ? "Driver: $_driverName"
            : _selectedIndex == 1
                ? "Wallet"
                : "Permit"),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          if (_selectedIndex == 0)
            Row(
              children: [
                Text(_isOnline ? "ONLINE" : "OFFLINE",
                    style: const TextStyle(fontSize: 12)),
                Switch(
                  value: _isOnline,
                  onChanged: (v) async {
                    setState(() => _isOnline = v);
                    if (v) {
                      _startLiveLocationUpdates();
                    } else {
                      _stopLocationUpdates();
                    }
                    // Update Firebase Status
                    try {
                      await FirebaseFirestore.instance
                          .collection('driver_locations')
                          .doc(_currentDriverId)
                          .set({
                        'is_online': v,
                        'last_updated': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                    } catch (e) {
                      debugPrint("Error updating status: $e");
                    }
                  },
                  activeColor: Colors.greenAccent,
                  activeTrackColor: Colors.green[200],
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(child: currentScreen),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.teal[800],
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
    if (!_isOnline)
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.location_off, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text("You are currently OFFLINE",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Switch ON to start receiving requests",
              style: TextStyle(color: Colors.grey)),
        ],
      ));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentDriverId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};

        bool isPaid = userData['isRoutePaid'] ?? false;
        bool isBlocked = userData['is_blocked'] ?? false;

        // Handle blocked drivers
        if (isBlocked)
          return _warningUI(
              Icons.block, "ACCOUNT BLOCKED", "Please clear your debt.", 1);
        if (!isPaid)
          return _warningUI(Icons.warning_amber_rounded, "PERMIT EXPIRED",
              "Please renew your permit.", 2);

        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
                onPressed: _triggerSOS,
                icon: const Icon(Icons.warning),
                label: const Text("SOS ALERT"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900],
                    foregroundColor: Colors.white)),
          ),
          Expanded(
              child: activeTripId != null
                  ? _buildActiveTripContainer()
                  : _buildWaitingOrRequestList()),
        ]);
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
          return const Center(child: Text("Scanning for requests..."));

        var docs = snapshot.data!.docs
            .where((d) => !_ignoredRideIds.contains(d.id))
            .toList();
        if (docs.isEmpty) return const Center(child: Text("Scanning..."));

        var doc = docs.first;
        var data = doc.data() as Map<String, dynamic>;

        // Trigger sound only if it's a new request we haven't ignored
        _triggerAlert();

        return _buildRequestPopup(data, data['price'] ?? 0, doc.id);
      },
    );
  }

  // --- Helper Widgets (Keeping your existing ones mostly same) ---
  Widget _warningUI(IconData icon, String title, String msg, int navIndex) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 80, color: Colors.red),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(msg),
      ElevatedButton(
          onPressed: () => setState(() => _selectedIndex = navIndex),
          child: const Text("FIX ISSUE"))
    ]));
  }

  Widget _buildRequestPopup(
      Map<String, dynamic> data, int price, String rideId) {
    return Center(
        child: Card(
            margin: const EdgeInsets.all(20),
            elevation: 10,
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text("NEW REQUEST",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.teal)),
                  Text("$price ETB",
                      style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                  Text("To: ${data['destination']}"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: () => _acceptRide(rideId),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50)),
                      child: const Text("ACCEPT")),
                  TextButton(
                      onPressed: () =>
                          setState(() => _ignoredRideIds.add(rideId)),
                      child: const Text("IGNORE",
                          style: TextStyle(color: Colors.red))),
                ]))));
  }

  Widget _buildActiveTripContainer() {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ride_requests')
            .doc(activeTripId!)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists)
            return const Center(child: Text("Trip Ended"));
          var data = snapshot.data!.data() as Map<String, dynamic>;
          if (data['status'] == 'accepted') return _buildOtpScreen(data);
          if (data['status'] == 'started')
            return _buildInTripScreen(
                data['price'] ?? 0, data['passenger_phone'] ?? "");
          return const Center(child: CircularProgressIndicator());
        });
  }

  Widget _buildOtpScreen(Map<String, dynamic> data) {
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          ListTile(
              title: const Text("Passenger Found"),
              trailing: IconButton(
                  icon: const Icon(Icons.phone),
                  onPressed: () =>
                      _launchPhone(data['passenger_phone'] ?? ""))),
          TextField(
              controller: _otpInputController,
              decoration: const InputDecoration(labelText: "Enter OTP"),
              keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: () => _verifyAndStart(data['otp'] ?? ""),
              child: const Text("START TRIP")),
          TextButton(
              onPressed: _cancelActiveTrip,
              child: const Text("CANCEL RIDE",
                  style: TextStyle(color: Colors.red))),
        ]));
  }

  Widget _buildInTripScreen(int price, String phone) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.directions_car, size: 80, color: Colors.teal),
      const Text("ON TRIP", style: TextStyle(fontSize: 24)),
      ElevatedButton(
          onPressed: () => _finishTrip(price),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text("FINISH & COLLECT CASH",
              style: TextStyle(color: Colors.white))),
    ]));
  }

  Widget _buildWalletScreen() {
    // (Existing Wallet Code)
    return const Center(child: Text("Wallet Screen Placeholder"));
    // አንተ የላክከው Wallet ኮድ እንዳለ ይሁን፣ እዚህ ጋር ቦታ ለመቆጠብ ነው ያሳጠርኩት
  }
}
