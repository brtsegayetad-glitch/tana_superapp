import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AdminSecurityDashboard extends StatefulWidget {
  const AdminSecurityDashboard({super.key});

  @override
  State<AdminSecurityDashboard> createState() => _AdminSecurityDashboardState();
}

class _AdminSecurityDashboardState extends State<AdminSecurityDashboard> {
  // የባህር ዳር መጋጠሚያ (Center of Bahir Dar)
  final LatLng _bahirDarCenter = const LatLng(11.5936, 37.3908);
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tana SuperApp - የከተማ ፀጥታ ቁጥጥር ዳሽቦርድ"),
        backgroundColor: Colors.blueGrey[900],
        actions: [
          _buildSOSNotificationCount(), // SOS ማሳያ
        ],
      ),
      body: Row(
        children: [
          // የጎን ዝርዝር (Sidebar)
          Container(
            width: 250,
            color: Colors.grey[200],
            child: _buildDriverStatusList(),
          ),
          // ዋናው ካርታ
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('driver_locations')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<Marker> markers = snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return Marker(
                    point: LatLng(data['lat'], data['lng']),
                    width: 40,
                    height: 40,
                    child: Tooltip(
                      message:
                          "${data['driver_name']} (${data['plateNumber']})",
                      child: Icon(
                        Icons.local_taxi,
                        color: data['status'] == 'busy'
                            ? Colors.red
                            : Colors.green,
                        size: 30,
                      ),
                    ),
                  );
                }).toList();

                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _bahirDarCenter,
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tana.superapp',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ሾፌሮችን በዝርዝር የሚያሳይ (Sidebar Logic)
  Widget _buildDriverStatusList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance.collection('driver_locations').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text("ሾፌሮች በከተማው",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ...snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      data['status'] == 'busy' ? Colors.red : Colors.green,
                  radius: 5,
                ),
                title: Text(data['driver_name'] ?? "Driver"),
                subtitle: Text(data['plateNumber'] ?? "No Plate"),
                onTap: () {
                  _mapController.move(LatLng(data['lat'], data['lng']), 16.0);
                },
              );
            }),
          ],
        );
      },
    );
  }

  // የ SOS መልዕክት መቆጣጠሪያ
  Widget _buildSOSNotificationCount() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emergency_alerts')
          .where('status', isEqualTo: 'urgent')
          .snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.orange),
              onPressed: () => _showSOSDialog(snapshot.data?.docs ?? []),
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10)),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text('$count',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showSOSDialog(List<QueryDocumentSnapshot> alerts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("የአደጋ ጊዜ ጥሪዎች (SOS)"),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              var data = alerts[index].data() as Map<String, dynamic>;
              return ListTile(
                tileColor: Colors.red[50],
                title: Text("${data['driver_name']} - ${data['plate']}"),
                subtitle: const Text("አስቸኳይ እርዳታ ይፈልጋል!"),
                trailing: const Icon(Icons.warning, color: Colors.red),
                onTap: () {
                  GeoPoint loc = data['location'];
                  _mapController.move(
                      LatLng(loc.latitude, loc.longitude), 17.0);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
