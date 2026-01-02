import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_panel.dart'; 
import 'registration_page.dart'; 

class DriverRoutePage extends StatefulWidget {
  const DriverRoutePage({super.key});

  @override
  State<DriverRoutePage> createState() => _DriverRoutePageState();
}

class _DriverRoutePageState extends State<DriverRoutePage> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  late DocumentReference walletRef;

  bool isRoutePaid = false;
  String bajajName = "Loading...";
  String plateNumber = "---";
  bool isLoading = true;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transactionController = TextEditingController();

  final double baseFee = 50.0;
  final double penaltyRate = 0.10;

  @override
  void initState() {
    super.initState();
    walletRef = FirebaseFirestore.instance.collection('wallets').doc(uid);
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    try {
      var doc = await walletRef.get();
      if (!mounted) return;

      if (!doc.exists || (doc.data() as Map<String, dynamic>)['plateNumber'] == "---") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RegistrationPage()),
        ).then((_) => _loadWalletData());
      } else {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          isRoutePaid = data['isRoutePaid'] ?? false;
          bajajName = data['bajajName'] ?? "Unnamed Bajaj";
          plateNumber = data['plateNumber'] ?? "---";
        });
      }
    } catch (e) {
      debugPrint("Firebase Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void submitDepositRequest() async {
    String amountText = _amountController.text.trim();
    String txId = _transactionController.text.trim();

    if (amountText.isNotEmpty && txId.isNotEmpty) {
      double? amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid number")));
        return;
      }

      setState(() => isLoading = true);
      try {
        await FirebaseFirestore.instance.collection('deposit_requests').add({
          'uid': uid,
          'driverName': bajajName,
          'amount': amount,
          'transactionId': txId,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

        _amountController.clear();
        _transactionController.clear();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request Sent! Admin will verify payment.")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in both Amount and Transaction ID")),
      );
    }
  }

  double calculateTotalDue() {
    DateTime now = DateTime.now();
    int daysSinceMonday = now.weekday - DateTime.monday;
    if (daysSinceMonday < 0) daysSinceMonday += 7;
    DateTime lastMonday = DateTime(now.year, now.month, now.day - daysSinceMonday, 8, 0);

    if (now.isAfter(lastMonday)) {
      int daysLate = now.difference(lastMonday).inDays;
      if (daysLate > 0) return baseFee + (baseFee * penaltyRate * daysLate);
    }
    return baseFee;
  }

  // UPDATED: Now uses Batch to update balance AND log transaction history
  void payRoute() async {
    double total = calculateTotalDue();
    var doc = await walletRef.get();
    double currentBalance = (doc['balance'] ?? 0.0).toDouble();

    if (currentBalance >= total) {
      setState(() => isLoading = true);
      
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update Balance
      batch.update(walletRef, {
        'balance': FieldValue.increment(-total),
        'isRoutePaid': true,
        'lastPaymentDate': Timestamp.now(),
      });

      // 2. Add History Log
      DocumentReference historyRef = FirebaseFirestore.instance.collection('transactions').doc();
      batch.set(historyRef, {
        'uid': uid,
        'amount': total,
        'type': 'payment',
        'title': 'Weekly Route Fee',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await _loadWalletData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient Balance!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal)));

    double totalToPay = calculateTotalDue();
    bool isLate = DateTime.now().weekday > DateTime.monday && !isRoutePaid;

    return Scaffold(
      appBar: AppBar(title: const Text("Tana Bajaj - Wallet")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Card(
                elevation: 4,
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    children: [
                      StreamBuilder<DocumentSnapshot>(
                        stream: walletRef.snapshots(),
                        builder: (context, snapshot) {
                          double balance = 0.0;
                          if (snapshot.hasData && snapshot.data!.exists) {
                            balance = (snapshot.data!['balance'] ?? 0.0).toDouble();
                          }
                          return Text("Balance: $balance Birr",
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal));
                        },
                      ),
                      const Divider(),
                      const Text("Step 1: Send money to 0918-XX-XX-XX (Telebirr)",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Amount Sent (Birr)", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _transactionController,
                        decoration: const InputDecoration(labelText: "Transaction ID (from SMS)", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: submitDepositRequest,
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                        child: const Text("SUBMIT DEPOSIT"),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isRoutePaid ? Colors.green.shade100 : (isLate ? Colors.orange.shade100 : Colors.blue.shade100),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: isRoutePaid ? Colors.green : (isLate ? Colors.orange : Colors.blue)),
                ),
                child: Column(
                  children: [
                    Text(isRoutePaid ? "PERMIT ACTIVE" : "PAYMENT REQUIRED",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (!isRoutePaid)
                      Text("Total Due: $totalToPay Birr", style: const TextStyle(fontSize: 18, color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!isRoutePaid)
                ElevatedButton(
                  onPressed: payRoute,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60)),
                  child: Text("PAY $totalToPay BIRR"),
                ),
              if (isRoutePaid)
                OutlinedButton.icon(
                  onPressed: () => _showTrafficReceipt(context, totalToPay),
                  icon: const Icon(Icons.verified_user),
                  label: const Text("SHOW TRAFFIC PERMIT"),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
              
              const SizedBox(height: 30),
              
              // NEW: TRANSACTION HISTORY LIST
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .where('uid', isEqualTo: uid)
                    .orderBy('timestamp', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text("No transactions yet.", style: TextStyle(color: Colors.grey));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      bool isDeposit = data['type'] == 'deposit';
                      return ListTile(
                        leading: Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward, 
                                     color: isDeposit ? Colors.green : Colors.red),
                        title: Text(data['title'] ?? "Transaction"),
                        subtitle: Text(data['timestamp']?.toDate().toString().split('.')[0] ?? ""),
                        trailing: Text(
                          "${isDeposit ? '+' : '-'}${data['amount']} ETB",
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDeposit ? Colors.green : Colors.red),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 50),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelPage()));
                },
                child: const Text("ADMIN ACCESS", style: TextStyle(color: Colors.grey, fontSize: 10)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Keeping receipt logic exactly as you had it)
  void _showTrafficReceipt(BuildContext context, double paid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(25),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 90),
              const Text("BAHIR DAR CITY ADMINISTRATION", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const Text("VALID ROUTE PERMIT", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Divider(height: 40),
              _receiptRow("Bajaj Name:", bajajName),
              _receiptRow("Plate Number:", plateNumber),
              _receiptRow("Weekly Fee:", "$paid Birr"),
              _receiptRow("Status:", "PAID ✅"),
              const SizedBox(height: 40),
              const Icon(Icons.qr_code_2, size: 200),
              const SizedBox(height: 40),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}