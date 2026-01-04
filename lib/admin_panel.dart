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
  final double myCommissionPercent = 0.05;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Hullugebeya Admin"),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.yellow,
          tabs: const [
            Tab(text: "Approvals", icon: Icon(Icons.pending_actions)),
            Tab(text: "Dashboard", icon: Icon(Icons.dashboard)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApprovalsTab(),
          _buildDashboardTab(),
        ],
      ),
    );
  }

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
                title: Text("${data['driverName']} - ${data['amount']} ETB"),
                subtitle: Text("TXID: ${data['transactionId']}"),
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

          if (ts != null) {
            DateTime txDate = ts.toDate();
            if (data['type'] == 'payment' && txDate.isAfter(sevenDaysAgo)) {
              String assoc = data['association'] ?? 'General';
              double amt = (data['amount'] ?? 0.0).toDouble();

              if (!associationStats.containsKey(assoc)) {
                associationStats[assoc] = {'total': 0.0, 'count': 0};
              }
              associationStats[assoc]!['total'] += amt;
              associationStats[assoc]!['count'] += 1;
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.all(15),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Weekly Report",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(dateRange,
                      style: const TextStyle(
                          color: Colors.teal, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            ...associationStats.entries.map((e) {
              double total = e.value['total'];
              int count = e.value['count'];
              double commission = total * myCommissionPercent;
              double netToAssoc = total - commission;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 15),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal)),
                          Chip(label: Text("$count Bajajs Paid")),
                        ],
                      ),
                      const Divider(),
                      _dashboardRow("Gross Collected:",
                          "${total.toStringAsFixed(2)} ETB"),
                      _dashboardRow("Hullugebeya Fee (5%):",
                          "${commission.toStringAsFixed(2)} ETB",
                          color: Colors.blue),
                      _dashboardRow("Pay to Association:",
                          "${netToAssoc.toStringAsFixed(2)} ETB",
                          color: Colors.green, isBold: true),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          String report = "📊 *Hullugebeya Weekly Report*\n"
                              "🏢 Assoc: ${e.key}\n"
                              "📅 Period: $dateRange\n"
                              "✅ Drivers: $count\n"
                              "💰 Total: ${total.toStringAsFixed(2)} ETB\n"
                              "🏦 Payout: ${netToAssoc.toStringAsFixed(2)} ETB";
                          Clipboard.setData(ClipboardData(text: report));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Weekly Report Copied!")));
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text("COPY WEEKLY REPORT"),
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 35)),
                      )
                    ],
                  ),
                ),
              );
            }),
            const Divider(height: 40),
            const Text("Recent History",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length > 20
                  ? 20
                  : snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map<String, dynamic>;
                DateTime? date = (data['timestamp'] as Timestamp?)?.toDate();
                String formattedDate = date != null
                    ? DateFormat('MMM d, h:mm a').format(date)
                    : "Recent";

                return ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.person, color: Colors.white)),
                  title: Text(data['driverName'] ?? "Driver"),
                  subtitle: Text(
                      "$formattedDate\nTXID: ${data['transactionId'] ?? 'N/A'}"),
                  trailing: Text("${data['amount']} ETB",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _dashboardRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  Future<void> _approveDeposit(String reqId, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    String driverId = data['uid'];
    double amount = (data['amount'] ?? 0.0).toDouble();

    var walletDoc = await FirebaseFirestore.instance
        .collection('wallets')
        .doc(driverId)
        .get();
    String assoc = walletDoc.exists
        ? (walletDoc.data() as Map<String, dynamic>)['association'] ?? 'General'
        : 'General';

    batch.update(FirebaseFirestore.instance.collection('wallets').doc(driverId),
        {'balance': FieldValue.increment(amount)});
    batch.update(
        FirebaseFirestore.instance.collection('deposit_requests').doc(reqId),
        {'status': 'approved'});
    batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
      'uid': driverId,
      'driverName': data['driverName'],
      'amount': amount,
      'type': 'deposit',
      'title': 'Wallet Top-up',
      'association': assoc,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
