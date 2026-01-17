import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = "";

  // Controllers for Dispatch
  final TextEditingController _phoneController = TextEditingController();
  String _selectedHotspot = "Kebele 14 (Stadium)";
  final List<String> _bahirDarHotspots = [
    "Kebele 14 (Stadium)",
    "Papyrus Hotel",
    "Gamby Hospital",
    "Abay Mado",
    "Bus Station (Teras)",
    "Piazza / Tele",
    "Poly / St. George"
  ];

  @override
  void initState() {
    super.initState();
    // Updated length to 4 for the new Dispatch tab
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Helper for Row layout in reports
  Widget _row(String label, String val, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label),
        Text(val,
            style: TextStyle(
                color: color,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal))
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hullugebeya SuperAdmin"),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: "Approvals", icon: Icon(Icons.pending_actions)),
            Tab(text: "Ride (10%)", icon: Icon(Icons.local_taxi)),
            Tab(text: "Route (5%)", icon: Icon(Icons.route)),
            Tab(text: "Dispatch", icon: Icon(Icons.phone_forwarded)), // New Tab
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApprovalsTab(),
          _buildRideHailingDashboard(),
          _buildDashboardTab(),
          _buildManualDispatchTab(), // New UI
        ],
      ),
    );
  }

  // --- 4. NEW: MANUAL DISPATCH TAB ---
  Widget _buildManualDispatchTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("CALL CENTER DISPATCH",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text("Manual entry for phone-call passengers",
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: "Passenger Phone Number",
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedHotspot,
                  decoration: const InputDecoration(
                    labelText: "Pickup Hotspot (Bahir Dar)",
                    border: OutlineInputBorder(),
                  ),
                  items: _bahirDarHotspots.map((String spot) {
                    return DropdownMenuItem(value: spot, child: Text(spot));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedHotspot = val!),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _dispatchRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size(double.infinity, 55),
                  ),
                  child: const Text("SEND TO NEARBY DRIVERS",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 1. WALLET APPROVALS ---
  Widget _buildApprovalsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deposit_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(child: Text("No pending deposits."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: ListTile(
                title: Text(
                    "${data['driverName'] ?? 'Unknown'} - ${data['amount']} ETB"),
                subtitle: Text("TXID: ${data['transactionId'] ?? 'N/A'}"),
                trailing: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => _approveDeposit(doc.id, data),
                  child: const Text("APPROVE",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 2. RIDE DASHBOARD (SYNCED WITH OSRM) ---
  Widget _buildRideHailingDashboard() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: "Search Driver...",
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) =>
              setState(() => _searchQuery = value.toLowerCase()),
        ),
        const SizedBox(height: 20),
        const Text("CITY PRICE SETTINGS (BAHIR DAR)",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 10),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('settings')
              .doc('pricing')
              .snapshots(),
          builder: (context, snapshot) {
            double base = 50.0;
            double perKm = 15.0;
            if (snapshot.hasData && snapshot.data!.exists) {
              var prices = snapshot.data!.data() as Map<String, dynamic>;
              base = (prices['base_fare'] ?? 50.0).toDouble();
              perKm = (prices['per_km'] ?? 15.0).toDouble();
            }
            return Card(
              color: Colors.blue.shade50,
              child: ListTile(
                leading: const Icon(Icons.settings_suggest, color: Colors.blue),
                title: Text("Base: $base ETB | Per KM: $perKm ETB"),
                trailing: const Icon(Icons.edit, color: Colors.blue),
                onTap: () => _showPriceEditDialog(base, perKm),
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        const Text("DRIVER DEBT (10%)",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        const Divider(),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            var filteredDocs = snapshot.data!.docs.where((doc) {
              var driver = doc.data() as Map<String, dynamic>;
              String name = (driver['name'] ?? "").toString().toLowerCase();
              return name.contains(_searchQuery);
            }).toList();

            return Column(
              children: filteredDocs.map((doc) {
                var driver = doc.data() as Map<String, dynamic>;
                double debt = (driver['total_debt'] ?? 0.0).toDouble();
                return Card(
                  child: ListTile(
                    title: Text(driver['name'] ?? "Unknown"),
                    subtitle: Text("Owes: ${debt.toStringAsFixed(2)} ETB"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_active,
                              color: Colors.orange),
                          onPressed: () =>
                              _sendDebtReminder(doc.id, driver['name'], debt),
                        ),
                        ElevatedButton(
                          onPressed: () => _clearDriverDebt(doc.id),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          child: const Text("PAY",
                              style: TextStyle(color: Colors.white)),
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
    );
  }

  // --- 3. ROUTE DASHBOARD (5%) ---
  Widget _buildDashboardTab() {
    DateTime now = DateTime.now();
    DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
    String dateRange =
        "${DateFormat('MMM d').format(sevenDaysAgo)} - ${DateFormat('MMM d, yyyy').format(now)}";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        Map<String, Map<String, dynamic>> associationStats = {};
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          Timestamp? ts = data['timestamp'] as Timestamp?;
          if (ts != null &&
              data['type'] == 'payment' &&
              ts.toDate().isAfter(sevenDaysAgo)) {
            String assoc = data['association'] ?? 'General';
            double amt = (data['amount'] ?? 0.0).toDouble();
            associationStats.putIfAbsent(
                assoc, () => {'total': 0.0, 'count': 0});
            associationStats[assoc]!['total'] += amt;
            associationStats[assoc]!['count'] += 1;
          }
        }
        return ListView(
          padding: const EdgeInsets.all(15),
          children: [
            Container(
                padding: const EdgeInsets.all(12),
                color: Colors.blue.shade50,
                child: Text("Period: $dateRange",
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            ...associationStats.entries.map((e) {
              double total = e.value['total'];
              double commission = total * 0.05;
              double net = total - commission;
              return Card(
                margin: const EdgeInsets.only(top: 15),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      Text(e.key,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const Divider(),
                      _row("Total Collected:",
                          "${total.toStringAsFixed(2)} ETB"),
                      _row("Hullugebeya 5%:",
                          "${commission.toStringAsFixed(2)} ETB",
                          color: Colors.red),
                      _row("Net to Assoc:", "${net.toStringAsFixed(2)} ETB",
                          color: Colors.green, bold: true),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text:
                                  "Assoc: ${e.key}, Total: $total, Net: $net"));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Report Copied!")));
                        },
                        label: const Text("COPY REPORT"),
                      )
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // --- ACTIONS & DIALOGS ---

  // THIS IS THE NEW DISPATCH LOGIC
  Future<void> _dispatchRequest() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter passenger phone")));
      return;
    }

    await FirebaseFirestore.instance.collection('ride_requests').add({
      'passenger_phone': _phoneController.text,
      'pickup_location': _selectedHotspot,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'call_center'
    });

    _phoneController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request sent for $_selectedHotspot!")));
  }

  void _showPriceEditDialog(double currentBase, double currentPerKm) {
    TextEditingController baseCtrl =
        TextEditingController(text: currentBase.toString());
    TextEditingController kmCtrl =
        TextEditingController(text: currentPerKm.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update City Pricing"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: baseCtrl,
              decoration: const InputDecoration(labelText: "Base Fare"),
              keyboardType: TextInputType.number),
          TextField(
              controller: kmCtrl,
              decoration: const InputDecoration(labelText: "Per KM"),
              keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL")),
          ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('settings')
                    .doc('pricing')
                    .set({
                  'base_fare': double.parse(baseCtrl.text),
                  'per_km': double.parse(kmCtrl.text),
                });
                Navigator.pop(context);
              },
              child: const Text("SAVE")),
        ],
      ),
    );
  }

  Future<void> _approveDeposit(String reqId, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    String uid = data['uid'] ?? '';
    double amt = (data['amount'] ?? 0.0).toDouble();
    batch.update(FirebaseFirestore.instance.collection('wallets').doc(uid),
        {'balance': FieldValue.increment(amt)});
    batch.update(
        FirebaseFirestore.instance.collection('deposit_requests').doc(reqId),
        {'status': 'approved'});
    batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
      'uid': uid,
      'amount': amt,
      'type': 'deposit',
      'timestamp': FieldValue.serverTimestamp()
    });
    await batch.commit();
  }

  Future<void> _sendDebtReminder(String id, String name, double debt) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'target_driver_id': id,
      'title': "Debt Reminder",
      'message': "Hello $name, you owe $debt ETB.",
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _clearDriverDebt(String driverId) async {
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .update({'total_debt': 0.0});
  }
}
