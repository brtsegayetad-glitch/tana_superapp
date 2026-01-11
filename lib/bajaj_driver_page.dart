import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

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

  // Set the current driver's ID (this will come from login later)
  final String _currentDriverId = 'abebe_test_id';

  @override
  void initState() {
    super.initState();
    _listenForNewRequests();
    _listenForAdminReminders();
  }

  // --- 1. ADMIN NOTIFICATION LISTENER ---
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

  // --- 2. RIDE REQUEST LISTENER ---
  void _listenForNewRequests() {
    FirebaseFirestore.instance
        .collection('ride_requests')
        .doc('test_ride')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && _isOnline) {
        var data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] == 'searching') {
          _triggerAlert();
        }
      }
    });
  }

  void _triggerAlert() async {
    await _audioPlayer
        .play(UrlSource('https://www.soundjay.com/buttons/beep-01a.mp3'));
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 800);
    }
  }

  // --- 3. TRIP LOGIC ---
  Future<void> _acceptRide() async {
    await FirebaseFirestore.instance
        .collection('ride_requests')
        .doc('test_ride')
        .update({'status': 'accepted'});
  }

  Future<void> _verifyAndStart(String correctOtp) async {
    if (_otpInputController.text.trim() == correctOtp) {
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc('test_ride')
          .update({'status': 'started'});
      _otpInputController.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wrong OTP! Check passenger's phone.")),
      );
    }
  }

  Future<void> _finishTrip(int price) async {
    double commission = price * 0.10;
    try {
      await FirebaseFirestore.instance.collection('ride_history').add({
        'driver_id': _currentDriverId,
        'driver_name': 'Abebe (Test)',
        'fare': price,
        'commission': commission,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_currentDriverId)
          .set({
        'total_debt': FieldValue.increment(commission),
        'name': 'Abebe (Test)',
        'plate': 'AA-3-0456',
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc('test_ride')
          .update({'status': 'completed'});
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  // --- 4. UI BUILDING ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? "Tana Driver Mode" : "My Wallet"),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          if (_selectedIndex == 0)
            Switch(
              value: _isOnline,
              onChanged: (v) => setState(() => _isOnline = v),
              activeThumbColor: Colors.greenAccent,
            )
        ],
      ),
      // FIXED: Wrapped in SingleChildScrollView to prevent yellow/black stripes when keyboard opens
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height -
              kToolbarHeight -
              kBottomNavigationBarHeight -
              30,
          child:
              _selectedIndex == 0 ? _buildHomeScreen() : _buildWalletScreen(),
        ),
      ),
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
    if (!_isOnline) {
      return const Center(child: Text("You are currently Offline"));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .doc('test_ride')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("Waiting for requests..."));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'searching';
        int price = data['price'] ?? 0;

        if (status == 'searching') return _buildRequestPopup(data, price);
        if (status == 'accepted') return _buildOtpScreen(data['otp']);
        if (status == 'started') return _buildInTripScreen(price);

        return const Center(
            child: Text("Searching for passengers in Bahir Dar..."));
      },
    );
  }

  Widget _buildWalletScreen() {
    return Column(
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('drivers')
              .doc(_currentDriverId)
              .snapshots(),
          builder: (context, snapshot) {
            double debt = 0;
            if (snapshot.hasData && snapshot.data!.exists) {
              debt = (snapshot.data!['total_debt'] ?? 0).toDouble();
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: Colors.teal[700]),
              child: Column(
                children: [
                  const Text("TOTAL COMMISSION DEBT",
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 5),
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
                      leading:
                          const Icon(Icons.check_circle, color: Colors.green),
                      title: Text("Fare: ${trip['fare']} ETB"),
                      subtitle: Text("Commission: ${trip['commission']} ETB"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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

  Widget _buildRequestPopup(data, price) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("NEW REQUEST!",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("$price ETB",
                  style: const TextStyle(
                      fontSize: 45,
                      color: Colors.green,
                      fontWeight: FontWeight.bold)),
              const Divider(),
              Text("Pickup: ${data['location'] ?? 'Nearby'}"),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _acceptRide,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size(double.infinity, 55)),
                child: const Text("ACCEPT RIDE",
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpScreen(otp) {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("ENTER PASSENGER OTP",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _otpInputController,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 40, letterSpacing: 10),
            decoration: const InputDecoration(
                border: OutlineInputBorder(), hintText: "0000"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _verifyAndStart(otp),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 55)),
            child:
                const Text("START TRIP", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildInTripScreen(price) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_taxi, size: 120, color: Colors.teal),
          const Text("TRIP IN PROGRESS",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("Collect $price ETB from Passenger",
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => _finishTrip(price),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, minimumSize: const Size(200, 60)),
            child: const Text("FINISH TRIP",
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _otpInputController.dispose();
    super.dispose();
  }
}
