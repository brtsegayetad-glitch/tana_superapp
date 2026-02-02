import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'location_data.dart'; // Ensure this file exists
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TrafficMapView extends StatefulWidget {
  const TrafficMapView({super.key});

  @override
  State<TrafficMapView> createState() => _TrafficMapViewState();
}

class _TrafficMapViewState extends State<TrafficMapView> {
  final MapController _adminMapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // ✅ UPDATE 1: Variable to track zoom level for text labels
  double _currentZoom = 14.5; 

  final AudioPlayer _alertPlayer = AudioPlayer();
  bool _isSOSActive = false;
  Timer? _flashTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    _alertPlayer.dispose();
    super.dispose();
  }

  // ✅ Phone Call Function
  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null ||
        phoneNumber.isEmpty ||
        phoneNumber == 'ስልክ የለም') {
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      debugPrint("Call Error: $e");
    }
  }

  // 🖱 Show Driver Details Dialog
  void _showDriverDetails(Map<String, dynamic> data) {
    final String? rawPhone = data['phoneNumber'] ??
        data['phone'] ??
        data['driverPhone'] ??
        data['tel'];
    final String driverPhone =
        (rawPhone != null && rawPhone.toString().isNotEmpty)
            ? rawPhone.toString()
            : 'ስልክ የለም';

    final String driverName =
        data['driverName'] ?? data['driver_name'] ?? 'ስም የለም';
    final String plate = data['plateNumber'] ?? data['plate'] ?? 'ሰሌዳ የለም';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: data['photoUrl'] != null
                  ? NetworkImage(data['photoUrl'])
                  : null,
              child: data['photoUrl'] == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(driverName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.yellow[600],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: Text("ሰሌዳ: $plate",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(height: 15),

            // Phone Button
            InkWell(
              onTap: () => _makePhoneCall(driverPhone),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: driverPhone != 'ስልክ የለም'
                        ? Colors.green[50]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3))),
                child: Row(
                  children: [
                    Icon(Icons.phone,
                        color: driverPhone != 'ስልክ የለም'
                            ? Colors.green
                            : Colors.grey),
                    const SizedBox(width: 10),
                    Text(driverPhone,
                        style: TextStyle(
                            color: driverPhone != 'ስልክ የለም'
                                ? Colors.green
                                : Colors.black54,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (driverPhone != 'ስልክ የለም')
                      const Icon(Icons.call, size: 16, color: Colors.green),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text("🚀 ፍጥነት: ${data['speed']?.toStringAsFixed(1) ?? '0'} km/h"),
            const Divider(),
            Text("📜 ፍቃድ: ${data['isRoutePaid'] == true ? 'የተከፈለ' : 'ያልተከፈለ'}",
                style: TextStyle(
                    color:
                        data['isRoutePaid'] == true ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("ዝጋ"))
        ],
      ),
    );
  }

  // Show Report Date Picker
  void _showReportDialog() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null) return;

    final startOfDay =
        DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    if (!mounted) return;
    showDialog(
        context: context,
        builder: (c) => const Center(child: CircularProgressIndicator()));

    // Fetch Data
    var onlineSnap = await FirebaseFirestore.instance
        .collection('driver_locations')
        .where('is_online', isEqualTo: true)
        .get();
    var rideSnap = await FirebaseFirestore.instance
        .collection('ride_requests')
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('timestamp', isLessThan: endOfDay)
        .get();

    int onlineCount = onlineSnap.docs.length;
    int totalRides = rideSnap.docs.length;
    int completedCount =
        rideSnap.docs.where((d) => d['status'] == 'completed').length;
    double revenue = completedCount * 5.0;

    if (!mounted) return;
    Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${DateFormat('yyyy-MM-dd').format(pickedDate)} ሪፖርት",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
                title: const Text("በስራ ላይ ያሉ"), trailing: Text("$onlineCount")),
            ListTile(
                title: const Text("የተጠናቀቁ ጉዞዎች"),
                trailing: Text("$completedCount")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _generateDailyReport(
                  onlineCount, totalRides, completedCount, revenue, pickedDate),
              child: const Text("PDF አውርድ"),
            )
          ],
        ),
      ),
    );
  }

  // Generate PDF Report
  Future<void> _generateDailyReport(int online, int total, int completed,
      double revenue, DateTime date) async {
    final pdf = pw.Document();

    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(children: [
            pw.Header(
                level: 0, child: pw.Text("Bahir Dar Bajaj - Traffic Report")),
            pw.SizedBox(height: 20),
            pw.Text(
                "Report For Date: ${DateFormat('EEEE, MMM dd, yyyy').format(date)}"),
            pw.Divider(),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Online Drivers:"),
                  pw.Text("$online"),
                ]),
            pw.SizedBox(height: 10),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Total Requests:"),
                  pw.Text("$total"),
                ]),
            pw.SizedBox(height: 10),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Completed Trips:"),
                  pw.Text("$completed"),
                ]),
            pw.SizedBox(height: 10),
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Total Revenue (Est):"),
                  pw.Text("$revenue ETB"),
                ]),
            pw.Spacer(),
            pw.Divider(),
            pw.Center(child: pw.Text("Generated via Tana SuperApp Admin")),
          ]);
        }));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // ✅ MAIN BUILD METHOD (UPDATED)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildDriverListDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _adminMapController,
            options: MapOptions(
              initialCenter: const LatLng(11.5742, 37.3614),
              initialZoom: 14.5,
              // ✅ UPDATE 2: Track zoom level to toggle text visibility
              onPositionChanged: (position, hasGesture) {
                setState(() {
                  _currentZoom = position.zoom;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tana.superapp',
              ),

              // 📍 1. Places Layer (Names show only when zoomed in)
              MarkerLayer(
                markers: masterDirectory.map((loc) {
                  // Only show names when zoomed in close (> 15.5)
                  bool showText = _currentZoom > 15.5; 
                  return Marker(
                    point: loc.coordinates,
                    width: showText ? 100 : 30,
                    height: 65,
                    child: Column(
                      children: [
                        Icon(_getMarkerIcon(loc.category),
                            color: _getMarkerColor(loc.category), size: 22),
                        // Only show text container if showText is true
                        if (showText)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              loc.nameAmh,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              // 📡 2. Live Bajaj Layer (Fixed Logic)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('driver_locations')
                    .where('is_online', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return MarkerLayer(
                    markers: snapshot.data!.docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      double speed = (data['speed'] ?? 0).toDouble();
                      bool isOnTrip = data['isOnTrip'] ?? false;
                      Color statusColor = isOnTrip ? Colors.blue : (speed < 1 ? Colors.amber : Colors.teal);

                      return Marker(
                        // ✅ UPDATE 3: ValueKey forces the marker to move when coordinates change
                        key: ValueKey(doc.id), 
                        point: LatLng((data['lat'] ?? 11.5742).toDouble(), (data['lng'] ?? 37.3614).toDouble()),
                        width: 60,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => _showDriverDetails(data),
                          child: Column(
                            children: [
                              Icon(
                                isOnTrip ? Icons.local_taxi : (speed < 1 ? Icons.pause_circle : Icons.minor_crash),
                                color: statusColor,
                                size: 30,
                              ),
                              Text(
                                isOnTrip ? "ጉዞ ላይ" : (speed < 1 ? "ቆሟል" : "ዝግጁ"),
                                style: TextStyle(
                                  color: statusColor, 
                                  fontSize: 8, 
                                  fontWeight: FontWeight.bold, 
                                  backgroundColor: Colors.white70
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),

          // --- Overlays & Buttons ---
          _buildSOSOverlay(),
          Positioned(top: 15, left: 15, child: _buildMapStatsOverlay()),

          // Driver List Button
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.teal,
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              child: const Icon(Icons.people, color: Colors.white),
            ),
          ),

          // Report Button
          Positioned(
            top: 80,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.orange,
              onPressed: _showReportDialog,
              child: const Icon(Icons.analytics, color: Colors.white),
            ),
          ),

          // 🚨 SOS Alert Logic
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sos_alerts')
                .where('is_resolved', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final hasAlert =
                  snapshot.hasData && snapshot.data!.docs.isNotEmpty;

              if (hasAlert) {
                if (!_isSOSActive) {
                  _isSOSActive = true;
                  _flashTimer = Timer.periodic(
                      const Duration(milliseconds: 500),
                      (t) => setState(() {}));
                  _alertPlayer.setVolume(1.0);
                  _alertPlayer.setReleaseMode(ReleaseMode.loop);
                  _alertPlayer.play(UrlSource(
                      'https://codeskulptor-demos.commondatastorage.googleapis.com/GalaxyInvaders/bonus.wav'));
                }
                var alertDoc = snapshot.data!.docs.first;
                var alertData = alertDoc.data() as Map<String, dynamic>;

                return Positioned(
                  bottom: 20,
                  left: 10,
                  right: 10,
                  child: Card(
                    color: Colors.red[900],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.warning,
                                color: Colors.white, size: 40),
                            title: Text("🚨 SOS: ${alertData['driverName']}",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                "ስልክ: ${alertData['phone'] ?? alertData['phoneNumber'] ?? 'የለም'}",
                                style: const TextStyle(color: Colors.white70)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                  onPressed: () => _adminMapController.move(
                                      LatLng(
                                          alertData['lat'], alertData['lng']),
                                      18),
                                  child: const Text("ቦታውን እይ")),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                onPressed: () => FirebaseFirestore.instance
                                    .collection('sos_alerts')
                                    .doc(alertDoc.id)
                                    .update({'is_resolved': true}),
                                child: const Text("ጨርሻለሁ"),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                if (_isSOSActive) {
                  _isSOSActive = false;
                  _flashTimer?.cancel();
                  _alertPlayer.stop();
                }
                return const SizedBox();
              }
            },
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildMapStatsOverlay() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('driver_locations')
          .where('is_online', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var docs = snapshot.data!.docs;
        int unpaid =
            docs.where((d) => (d.data() as Map)['isRoutePaid'] != true).length;
        int activeTrips =
            docs.where((d) => (d.data() as Map)['isOnTrip'] == true).length;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("ባህር ዳር፡ ቀጥታ ትራፊክ",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.teal)),
              const Divider(),
              Text("🚖 በስራ ላይ: ${docs.length}"),
              Text("🔵 በጉዞ ላይ: $activeTrips",
                  style: const TextStyle(color: Colors.blue)),
              Text("⚠️ ያልከፈሉ: $unpaid",
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriverListDrawer() {
    return Drawer(
      width: 300,
      child: Column(
        children: [
          const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Center(
                  child: Text("በስራ ላይ ያሉ ሾፌሮች",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)))),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('driver_locations')
                  .where('is_online', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                return ListView(
                    children: snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                        backgroundImage: data['photoUrl'] != null
                            ? NetworkImage(data['photoUrl'])
                            : null),
                    title: Text(data['driverName'] ?? "ሾፌር"),
                    subtitle: Text(data['plateNumber'] ?? "ሰሌዳ የለም"),
                    onTap: () {
                      _adminMapController.move(
                          LatLng(data['lat'], data['lng']), 17.0);
                      Navigator.pop(context);
                    },
                  );
                }).toList());
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMarkerIcon(String category) {
    String cat = category.toLowerCase().trim();
    if (cat.contains("school") || cat.contains("university"))
      return Icons.school;
    if (cat.contains("church")) return Icons.church;
    if (cat.contains("mosque")) return Icons.mosque;
    if (cat.contains("hotel")) return Icons.hotel;
    if (cat.contains("hospital") || cat.contains("clinic"))
      return Icons.local_hospital;
    if (cat.contains("bank")) return Icons.account_balance;
    if (cat.contains("square") || cat.contains("አደባባይ"))
      return Icons.brightness_low;
    if (cat.contains("station") || cat.contains("መነሻ"))
      return Icons.directions_bus;
    return Icons.location_on;
  }

  Color _getMarkerColor(String category) {
    String cat = category.toLowerCase().trim();
    if (cat.contains("hospital")) return Colors.red;
    if (cat.contains("church") || cat.contains("mosque")) return Colors.purple;
    if (cat.contains("school")) return Colors.orange;
    if (cat.contains("bank")) return Colors.blue;
    return Colors.teal;
  }

  Widget _buildSOSOverlay() {
    if (!_isSOSActive) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
            border: Border.all(
                color: (DateTime.now().second % 2 == 0)
                    ? Colors.red
                    : Colors.transparent,
                width: 15)),
      ),
    );
  }
}