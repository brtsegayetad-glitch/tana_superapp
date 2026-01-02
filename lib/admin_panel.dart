import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key});

  // UPDATED: Now logs a transaction for history/trust
  Future<void> approveDeposit(
      String requestId, String driverUid, double amount) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Update the driver's wallet balance
    DocumentReference walletRef =
        FirebaseFirestore.instance.collection('wallets').doc(driverUid);
    batch.update(walletRef, {'balance': FieldValue.increment(amount)});

    // 2. Mark as "approved"
    DocumentReference requestRef = FirebaseFirestore.instance
        .collection('deposit_requests')
        .doc(requestId);
    batch.update(requestRef, {'status': 'approved'});

    // 3. NEW: Create a Transaction History log
    DocumentReference historyRef = 
        FirebaseFirestore.instance.collection('transactions').doc();
    batch.set(historyRef, {
      'uid': driverUid,
      'amount': amount,
      'type': 'deposit',
      'title': 'Wallet Top-up',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // NEW: Function to Reject fake requests
  Future<void> rejectDeposit(String requestId) async {
    await FirebaseFirestore.instance
        .collection('deposit_requests')
        .doc(requestId)
        .update({'status': 'rejected'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Tana Admin - Approve Deposits"),
          backgroundColor: Colors.redAccent),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('deposit_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return const Center(
                child: Text("No pending deposits. Go enjoy Lake Tana!"));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              var data = requests[index].data() as Map<String, dynamic>;
              String requestId = requests[index].id;

              return Card(
                margin: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                          "${data['driverName']} - ${data['amount']} Birr",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          "ID: ${data['transactionId']}\nSent: ${data['timestamp']?.toDate() ?? 'Just now'}"),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15.0, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // REJECT BUTTON
                          TextButton(
                            onPressed: () => rejectDeposit(requestId),
                            child: const Text("REJECT",
                                style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 10),
                          // APPROVE BUTTON
                          ElevatedButton(
                            onPressed: () {
                              double amount =
                                  (data['amount'] ?? 0.0).toDouble();
                              approveDeposit(requestId, data['uid'], amount);
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                            child: const Text("APPROVE"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}