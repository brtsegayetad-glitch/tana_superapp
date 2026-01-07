import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Required for Clipboard (Copy Button)
import 'package:intl/intl.dart'; // Required for Weekly Dates

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final double routeCommissionPercent = 0.05; // 5% for Route
  final double rideCommissionPercent = 0.10; // 10% for Ride

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApprovalsTab(),
          _buildRideHailingDashboard(),
          _buildDashboardTab(), // This is where your Weekly Report lives
        ],
      ),
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No pending deposits."));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(10),
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

  // --- 2. RIDE DASHBOARD ---
  Widget _buildRideHailingDashboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('commissions').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        double total = 0;
        for (var doc in snapshot.data!.docs) {
          total += (doc['commission'] ?? 0.0);
        }
        return ListView(
          padding: const EdgeInsets.all(15),
          children: [
            _buildStatCard("Total Ride Commissions",
                "ETB ${total.toStringAsFixed(2)}", Colors.red.shade700),
            const SizedBox(height: 10),
            ...snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text("Driver: ${data['driver']}"),
                subtitle: Text("Trip: ${data['amount']} ETB"),
                trailing: Text("Fee: ${data['commission']} ETB",
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              );
            }),
          ],
        );
      },
    );
  }

  // --- 3. ROUTE DASHBOARD & WEEKLY REPORT ---
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

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
              child: Text("Reporting Period: $dateRange",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            ...associationStats.entries.map((e) {
              double total = e.value['total'];
              double commission = total * routeCommissionPercent;
              double net = total - commission;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      Text(e.key,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                      const Divider(),
                      _row("Total Collected:",
                          "${total.toStringAsFixed(2)} ETB"),
                      _row("Hullugebeya 5%:",
                          "${commission.toStringAsFixed(2)} ETB",
                          color: Colors.red),
                      _row("Pay to Assoc:", "${net.toStringAsFixed(2)} ETB",
                          color: Colors.green, bold: true),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text("COPY WEEKLY REPORT"),
                        onPressed: () {
                          String report =
                              "📊 *HULLUGEBEYA REPORT*\nAssoc: ${e.key}\nPeriod: $dateRange\nTotal: $total ETB\nNet to Association: $net ETB";
                          Clipboard.setData(ClipboardData(text: report));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Report Copied!")));
                        },
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

  // --- HELPERS ---
  Widget _row(String label, String val, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(val,
              style: TextStyle(
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
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
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
