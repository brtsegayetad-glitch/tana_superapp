import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // 🔥 ስልክ ለመደወል
import 'location_data.dart'; // የባህር ዳር ቦታዎች ዝርዝር
import 'package:audioplayers/audioplayers.dart'; // 🔥 यह 'AudioPlayer' और 'UrlSource' को ठीक करता है

class TrafficMapView extends StatefulWidget {
  const TrafficMapView({super.key});

  @override
  State<TrafficMapView> createState() => _TrafficMapViewState();
}

class _TrafficMapViewState extends State<TrafficMapView> {
  final MapController _adminMapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ✅ የድምፅ ማጫወቻ እና መቆጣጠሪያ
  final AudioPlayer _alertPlayer = AudioPlayer();
  bool _isAlertPlaying = false;

  // ✅ ስልክ ለመደወል
  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      debugPrint("Call Error: $e");
    }
  }

  // ✅ ገጹ ሲዘጋ ድምፅ እንዲቆም
  @override
  void dispose() {
    _alertPlayer.dispose();
    super.dispose();
  }

  // 🖱 ባጃጅ ሲነካ ዝርዝር መረጃ የሚያሳይ Dialog
  void _showDriverDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            // 📸 ፎቶው ሲነካ በትልቁ እንዲታይ
            GestureDetector(
              onTap: () {
                if (data['photoUrl'] != null) {
                  showDialog(
                    context: context,
                    builder: (ctx) =>
                        Dialog(child: Image.network(data['photoUrl'])),
                  );
                }
              },
              child: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.teal[50],
                backgroundImage: data['photoUrl'] != null
                    ? NetworkImage(data['photoUrl'])
                    : null,
                child: data['photoUrl'] == null
                    ? const Icon(Icons.person, size: 25)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(data['driverName'] ?? "ሾፌር",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: Column(
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
                child: Text(
                  "ሰሌዳ: ${data['plateNumber'] ?? 'N/A'}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 15),
              // 📞 ስልኩ ሲነካ እንዲደውል (InkWell ተጠቅመን)
              InkWell(
                onTap: () => _makePhoneCall(data['phone']),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.green),
                      const SizedBox(width: 10),
                      Text(
                        data['phone'] ?? 'የለም',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text("🚀 ፍጥነት: ${data['speed']?.toStringAsFixed(1) ?? '0'} km/h",
                  style: const TextStyle(fontSize: 13)),
              const Divider(),
              Row(
                children: [
                  const Text("📜 ፍቃድ: ", style: TextStyle(fontSize: 13)),
                  Text(
                    data['isRoutePaid'] == true ? "የተከፈለ" : "ያልተከፈለ",
                    style: TextStyle(
                      fontSize: 13,
                      color: data['isRoutePaid'] == true
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ዝጋ",
                style: TextStyle(color: Colors.teal, fontSize: 13)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildDriverListDrawer(), // የቀኝ ሜኑ
      body: Stack(
        children: [
          // 1. ካርታው (Map Layer)
          FlutterMap(
            mapController: _adminMapController,
            options: const MapOptions(
              initialCenter: LatLng(11.5742, 37.3614),
              initialZoom: 14.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tana.superapp',
              ),

              // 📍 የከተማው ዋና ዋና ቦታዎች (Static Markers)
              MarkerLayer(
                markers: masterDirectory.map((loc) {
                  return Marker(
                    point: loc.coordinates,
                    width: 100,
                    height: 70,
                    child: Column(
                      children: [
                        Icon(_getMarkerIcon(loc.category),
                            color: _getMarkerColor(loc.category), size: 22),
                        Text(
                          loc.nameAmh,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              backgroundColor: Colors.white.withOpacity(0.7)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              // 📡 የባጃጆች እንቅስቃሴ (Live Stream)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('driver_locations')
                    .where('is_online', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();

                  return MarkerLayer(
                    markers: snapshot.data!.docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      double speed = (data['speed'] ?? 0).toDouble();
                      bool isOnTrip = data['isOnTrip'] ?? false;

                      Color statusColor = isOnTrip
                          ? Colors.blue
                          : (speed < 1 ? Colors.amber : Colors.teal);

                      return Marker(
                        point: LatLng((data['lat'] ?? 11.5742).toDouble(),
                            (data['lng'] ?? 37.3614).toDouble()),
                        width: 60,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => _showDriverDetails(data),
                          child: Column(
                            children: [
                              Icon(
                                isOnTrip
                                    ? Icons.local_taxi
                                    : (speed < 1
                                        ? Icons.pause_circle
                                        : Icons.minor_crash),
                                color: statusColor,
                                size: 30,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: const [
                                      BoxShadow(
                                          blurRadius: 2, color: Colors.black26)
                                    ]),
                                child: Text(
                                  isOnTrip
                                      ? "ጉዞ ላይ"
                                      : (speed < 1 ? "ቆሟል" : "ዝግጁ"),
                                  style: TextStyle(
                                      color: statusColor,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold),
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

          // 2. መረጃ ሰጪ (Stat Overlay)
          Positioned(top: 15, left: 15, child: _buildMapStatsOverlay()),

          // 3. የሾፌሮች ዝርዝር መክፈቻ ቁልፍ
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

          // 🚨 SOS Listener (FIXED)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sos_alerts')
                .where('is_resolved', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                 debugPrint("SOS Stream Error: ${snapshot.error}");
                 return const SizedBox();
              }
              
              final hasAlert = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

              // Play or stop sound based on alert status
              if (hasAlert && !_isAlertPlaying) {
                  _isAlertPlaying = true;
                  // Use an async block to handle the Future
                  () async {
                    try {
                      await _alertPlayer.setReleaseMode(ReleaseMode.loop);
                      await _alertPlayer.play(UrlSource('https://codeskulptor-demos.commondatastorage.googleapis.com/GalaxyInvaders/bonus.wav'));
                    } catch (e) {
                      debugPrint("Sound Play Error: $e");
                      _isAlertPlaying = false; // Reset if playing failed
                    }
                  }();
              } else if (!hasAlert && _isAlertPlaying) {
                  _alertPlayer.stop();
                  _isAlertPlaying = false;
              }

              if (!hasAlert) {
                return const SizedBox();
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
                          leading:
                              const Icon(Icons.warning, color: Colors.white),
                          title: Text("SOS: ${alertData['driverName']}",
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text("ስልክ: ${alertData['phone']}",
                              style: TextStyle(color: Colors.white.withOpacity(0.7))),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () => _adminMapController.move(
                                  LatLng(alertData['lat'], alertData['lng']),
                                  18),
                              child: const Text("ቦታውን እይ"),
                            ),
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
            },
          ),
        ],
      ),
    );
  }

  // 📝 የሾፌሮች ዝርዝር ሜኑ (Right Drawer)
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
                      fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('driver_locations')
                  .where('is_online', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var drivers = snapshot.data!.docs;
                if (drivers.isEmpty) {
                  return const Center(child: Text("ኦንላይን ያለ ሾፌር የለም"));
                }

                return ListView.builder(
                  itemCount: drivers.length,
                  itemBuilder: (context, i) {
                    var data = drivers[i].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: data['photoUrl'] != null
                            ? NetworkImage(data['photoUrl'])
                            : null,
                        child: data['photoUrl'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(data['driverName'] ?? "ሾፌር"),
                      subtitle: Text(data['plateNumber'] ?? "ሰሌዳ የለም"),
                      trailing: const Icon(Icons.gps_fixed,
                          size: 18, color: Colors.teal),
                      onTap: () {
                        _adminMapController.move(
                            LatLng(data['lat'], data['lng']), 17.0);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 📊 የስታቲስቲክስ ሳጥን (በካርታው ላይ የሚታይ)
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
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("ባህር ዳር፡ የቀጥታ ትራፊክ",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                      fontSize: 14)),
              const Divider(),
              Text("🚖 በስራ ላይ፡ ${docs.length} ባጃጆች",
                  style: const TextStyle(fontSize: 12)),
              Text("🔵 በጉዞ ላይ: $activeTrips",
                  style: const TextStyle(fontSize: 12, color: Colors.blue)),
              Text("⚠️ ክፍያ ያልከፈሉ፡ $unpaid",
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  // 🎨 አይኮን እና ከለር መለገጫ
  IconData _getMarkerIcon(String category) {
    String cat = category.toLowerCase().trim();
    if (cat.contains("school") || cat.contains("university")) {
      return Icons.school;
    }
    if (cat.contains("church")) return Icons.church;
    if (cat.contains("mosque")) return Icons.mosque;
    if (cat.contains("hotel")) return Icons.hotel;
    if (cat.contains("hospital")) return Icons.local_hospital;
    if (cat.contains("bank")) return Icons.account_balance_wallet;
    if (cat.contains("square") || cat.contains("dipo")) return Icons.explore;
    return Icons.location_on;
  }

  Color _getMarkerColor(String category) {
    String cat = category.toLowerCase().trim();
    if (cat.contains("square") || cat.contains("dipo")) {
      return Colors.deepOrange;
    }
    if (cat.contains("church") || cat.contains("mosque")) return Colors.purple;
    if (cat.contains("hospital")) return Colors.red;
    if (cat.contains("school")) return Colors.orange;
    return Colors.teal;
  }
}
