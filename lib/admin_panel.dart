import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; 
import 'package:intl/intl.dart'; // This will NO LONGER be red or unused!

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final double myCommissionPercent = 0.05; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
            Tab(text: "Manager Dashboard", icon: Icon(Icons.dashboard)),
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No pending deposits."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text("${data['driverName']} - ${data['amount']} ETB"),
                subtitle: Text("TXID: ${data['transactionId']}"),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => _approveDeposit(docs[index].id, data),
                  child: const Text("APPROVE", style: TextStyle(color: Colors.white)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        Map<String, Map<String, dynamic>> associationStats = {};

        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['type'] == 'payment') {
            String assoc = data['association'] ?? 'General';
            double amt = (data['amount'] ?? 0.0).toDouble();

            if (!associationStats.containsKey(assoc)) {
              associationStats[assoc] = {'total': 0.0, 'count': 0};
            }
            associationStats[assoc]!['total'] += amt;
            associationStats[assoc]!['count'] += 1;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(15),
          children: [
            const Text("Association Summaries", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (associationStats.isEmpty) const Text("No payments collected yet."),
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
                          Text(e.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                          Chip(label: Text("$count Paid")),
                        ],
                      ),
                      const Divider(),
                      _dashboardRow("Total Collected:", "${total.toStringAsFixed(2)} ETB"),
                      _dashboardRow("Your 5% Fee:", "${commission.toStringAsFixed(2)} ETB", color: Colors.blue),
                      _dashboardRow("Net to Association:", "${netToAssoc.toStringAsFixed(2)} ETB", color: Colors.green, isBold: true),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          // USE DATEFORMAT HERE to remove the warning
                          String dateStr = DateFormat('MMM dd, yyyy').format(DateTime.now());
                          String report = "📊 Hullugebeya Report: ${e.key}\n📅 Date: $dateStr\n💰 Total: $total ETB\n🏦 Net Payout: $netToAssoc ETB";
                          Clipboard.setData(ClipboardData(text: report));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report Copied!")));
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text("COPY REPORT FOR TELEGRAM"),
                      )
                    ],
                  ),
                ),
              );
            }).toList(),
            const Divider(height: 40),
            const Text("Detailed History Log", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                bool isDeposit = data['type'] == 'deposit';
                
                // USE DATEFORMAT HERE ALSO to make history look better
                DateTime? date = (data['timestamp'] as Timestamp?)?.toDate();
                String formattedDate = date != null ? DateFormat('MMM d, h:mm a').format(date) : "Recent";

                return ListTile(
                  leading: Icon(isDeposit ? Icons.add_circle : Icons.payment, color: isDeposit ? Colors.green : Colors.red),
                  title: Text(data['title'] ?? "Payment"),
                  subtitle: Text("$formattedDate - ${data['association']}"),
                  trailing: Text("${data['amount']} ETB"),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _dashboardRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  Future<void> _approveDeposit(String reqId, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    String driverId = data['uid'];
    double amount = (data['amount'] ?? 0.0).toDouble();
    var walletDoc = await FirebaseFirestore.instance.collection('wallets').doc(driverId).get();
    String assoc = (walletDoc.data() as Map<String, dynamic>)['association'] ?? 'General';

    batch.update(FirebaseFirestore.instance.collection('wallets').doc(driverId), {'balance': FieldValue.increment(amount)});
    batch.update(FirebaseFirestore.instance.collection('deposit_requests').doc(reqId), {'status': 'approved'});
    batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
      'uid': driverId, 'amount': amount, 'type': 'deposit', 'title': 'Wallet Top-up', 'association': assoc, 'timestamp': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}