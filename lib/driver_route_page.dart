import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Ensure you ran 'flutter pub add intl'
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
  Timestamp? lastPaymentDate;

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
      // Force a fresh fetch from server for Web Preview reliability
      var doc = await walletRef.get(const GetOptions(source: Source.server));
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
          lastPaymentDate = data['lastPaymentDate'] as Timestamp?;
        });
      }
    } catch (e) {
      debugPrint("Firebase Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  double calculateTotalDue() {
    // If already paid, they owe nothing for now
    if (isRoutePaid) return 0.0;
    
    // If they have never paid, they owe the base fee
    if (lastPaymentDate == null) return baseFee;

    DateTime lastPay = lastPaymentDate!.toDate();
    DateTime now = DateTime.now();
    int daysSinceLastPay = now.difference(lastPay).inDays;

    // Within the 7-day grace period
    if (daysSinceLastPay <= 7) return baseFee;

    // LATE LOGIC (e.g., 20 days late)
    int missedWeeks = (daysSinceLastPay / 7).floor();
    double arrears = missedWeeks * baseFee;
    double penalty = daysSinceLastPay * (baseFee * penaltyRate);

    return arrears + penalty;
  }

  void payRoute() async {
    double total = calculateTotalDue();
    var doc = await walletRef.get();
    double currentBalance = (doc['balance'] ?? 0.0).toDouble();
    String assocName = (doc.data() as Map<String, dynamic>)['association'] ?? 'General';

    if (currentBalance >= total) {
      setState(() => isLoading = true);
      final batch = FirebaseFirestore.instance.batch();

      batch.update(walletRef, {
        'balance': FieldValue.increment(-total),
        'isRoutePaid': true,
        'lastPaymentDate': FieldValue.serverTimestamp(), // Update to today
      });

      batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
        'uid': uid,
        'amount': total,
        'type': 'payment',
        'title': 'Weekly Route Fee',
        'association': assocName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await _loadWalletData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient Balance!")));
    }
  }

  // --- SUBMIT DEPOSIT ---
  void submitDepositRequest() async {
    String amountText = _amountController.text.trim();
    String txId = _transactionController.text.trim();

    if (amountText.isNotEmpty && txId.isNotEmpty) {
      double? amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) return;

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Sent!")));
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal)));

    double totalToPay = calculateTotalDue();
    bool isLate = lastPaymentDate != null && DateTime.now().difference(lastPaymentDate!.toDate()).inDays > 7;

    return Scaffold(
      appBar: AppBar(title: const Text("Tana Bajaj - Wallet")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Wallet Card
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
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Amount Sent (Birr)"),
                      ),
                      TextField(
                        controller: _transactionController,
                        decoration: const InputDecoration(labelText: "Transaction ID"),
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
              // Status Container
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
              // Transaction History List...
              const Align(alignment: Alignment.centerLeft, child: Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const Divider(),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('transactions').where('uid', isEqualTo: uid).orderBy('timestamp', descending: true).limit(5).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['title'] ?? "Transaction"),
                        trailing: Text("${data['amount']} ETB"),
                      );
                    },
                  );
                },
              ),
              TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelPage())),
                child: const Text("ADMIN ACCESS", style: TextStyle(color: Colors.grey, fontSize: 10))),
            ],
          ),
        ),
      ),
    );
  }

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
              // ADDED THE DATE HERE:
              _receiptRow("Payment Date:", lastPaymentDate != null ? DateFormat('MMM d, yyyy').format(lastPaymentDate!.toDate()) : "Today"),
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