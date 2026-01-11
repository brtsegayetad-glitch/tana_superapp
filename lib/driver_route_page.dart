import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'admin_panel.dart';
import 'registration_page.dart';

final Map<String, Map<String, String>> localizedText = {
  'en': {
    'title': 'Tana Wallet',
    'balance': 'Balance',
    'step1': 'STEP 1: DEPOSIT FUNDS (Telebirr or Bank)',
    'pay_to': 'Pay to (Tana Wallet):',
    'bank_details':
        'CBE: 1000312990974\nBOA: 93150996\nName: Biruk Tsegaye Tadesse',
    'step2': 'STEP 2: ENTER DETAILS',
    'amount': 'Amount Sent (Birr)',
    'txid': 'Reference / Transaction ID',
    'submit': 'SUBMIT FOR APPROVAL',
    'permit': 'PERMIT ACTIVE',
    'pay_req': 'PAYMENT REQUIRED',
    'due': 'Total Due',
    'history': 'Recent Activity',
    'pay_btn': 'PAY',
    'receipt_btn': 'SHOW TRAFFIC PERMIT',
    'receipt_header': 'TANA SUPERAPP - DIGITAL RECEIPT',
    'receipt_verified': 'SERVICE ACCESS VERIFIED',
    'receipt_provider': 'Provider:',
    'receipt_name': 'Bajaj Association Name:',
    'receipt_plate': 'Plate Number:',
    'receipt_date': 'Payment Date:',
    'receipt_status': 'Status:',
    'receipt_active': 'ACTIVE ✅',
    'receipt_footer':
        'This receipt confirms the driver is a verified member of the Tana Digital Platform.',
    'close': 'CLOSE',
  },
  'am': {
    'title': 'ጣና ዋሌት',
    'balance': 'ሒሳብ',
    'step1': 'ደረጃ 1፡ ገንዘብ ያስገቡ (በቴሌብር ወይም በባንክ)',
    'pay_to': 'ክፍያ የሚፈጽሙበት ቁጥር፡',
    'bank_details': 'CBE: 1000312990974\nአቢሲኒያ፡ 93150996\nስም፡ ብሩክ ፀጋዬ ታደሰ',
    'step2': 'ደረጃ 2፡ ዝርዝር መረጃ ያስገቡ',
    'amount': 'የተላከው ብር (በብር)',
    'txid': 'የማረጋገጫ ቁጥር (Reference / TXID)',
    'submit': 'ለማረጋገጥ ይላኩ',
    'permit': 'ፈቃድ ገቢ ሆኗል',
    'pay_req': 'ክፍያ ይጠበቅብዎታል',
    'due': 'ጠቅላላ ዕዳ',
    'history': 'የቅርብ ጊዜ እንቅስቃሴዎች',
    'pay_btn': 'ክፍያ ፈጽም',
    'receipt_btn': 'የመንገድ ፈቃድ አሳይ',
    'receipt_header': 'ታና ሱፐር አፕ - ዲጂታል ደረሰኝ',
    'receipt_verified': 'የአገልግሎት ፈቃድ ተረጋግጧል',
    'receipt_provider': 'አቅራቢ፡',
    'receipt_name': 'የባጃጅ ማህበር ስም፡',
    'receipt_plate': 'የሰሌዳ ቁጥር፡',
    'receipt_date': 'የተከፈለበት ቀን፡',
    'receipt_status': 'ሁኔታ፡',
    'receipt_active': 'ተከፍሏል ✅',
    'receipt_footer': 'ይህ ደረሰኝ አሽከርካሪው በጣና ዲጂታል ፕላትፎርም የተመዘገበ መሆኑን ያረጋግጣል።',
    'close': 'ዝጋ',
  }
};

class DriverRoutePage extends StatefulWidget {
  const DriverRoutePage({super.key});

  @override
  State<DriverRoutePage> createState() => _DriverRoutePageState();
}

class _DriverRoutePageState extends State<DriverRoutePage> {
  // 2. The language variable is now inside the state (FIXES DUPLICATE ERROR)
  String lang = 'am';

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
      var doc = await walletRef.get(const GetOptions(source: Source.server));
      if (!mounted) return;

      if (!doc.exists ||
          (doc.data() as Map<String, dynamic>)['plateNumber'] == "---") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AuthPage()),
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
    if (isRoutePaid) return 0.0;
    if (lastPaymentDate == null) return baseFee;

    DateTime lastPay = lastPaymentDate!.toDate();
    DateTime now = DateTime.now();
    int daysSinceLastPay = now.difference(lastPay).inDays;

    if (daysSinceLastPay <= 7) return baseFee;

    int missedWeeks = (daysSinceLastPay / 7).floor();
    double arrears = missedWeeks * baseFee;
    double penalty = daysSinceLastPay * (baseFee * penaltyRate);

    return arrears + penalty;
  }

  void payRoute() async {
    double total = calculateTotalDue();
    var doc = await walletRef.get();
    double currentBalance = (doc['balance'] ?? 0.0).toDouble();
    String assocName =
        (doc.data() as Map<String, dynamic>)['association'] ?? 'General';

    if (currentBalance >= total) {
      setState(() => isLoading = true);
      final batch = FirebaseFirestore.instance.batch();

      batch.update(walletRef, {
        'balance': FieldValue.increment(-total),
        'isRoutePaid': true,
        'lastPaymentDate': FieldValue.serverTimestamp(),
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
      if (!mounted) return;
      await _loadWalletData();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Insufficient Balance!")));
    }
  }

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
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Request Sent!")));
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: Colors.teal)));
    }

    double totalToPay = calculateTotalDue();
    bool isLate = lastPaymentDate != null &&
        DateTime.now().difference(lastPaymentDate!.toDate()).inDays > 7;

    return Scaffold(
      // 3. UPDATED APPBAR WITH LANGUAGE TOGGLE
      appBar: AppBar(
        title: Text(localizedText[lang]!['title']!),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                lang = (lang == 'en') ? 'am' : 'en';
              });
            },
            child: Text(
              lang == 'en' ? "አማርኛ" : "English",
              style: const TextStyle(
                  color: Colors.yellow, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
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
                            balance =
                                (snapshot.data!['balance'] ?? 0.0).toDouble();
                          }
                          return Text(
                              "${localizedText[lang]!['balance']}: $balance ብር",
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal));
                        },
                      ),
                      const Divider(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(localizedText[lang]!['step1']!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Column(
                          children: [
                            Text(localizedText[lang]!['pay_to']!,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            const Text(
                              "0940651491 (Telebirr)",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red),
                            ),
                            const Divider(),
                            Text(
                              localizedText[lang]!['bank_details']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(localizedText[lang]!['step2']!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: localizedText[lang]!['amount'],
                            prefixIcon: const Icon(Icons.money_outlined)),
                      ),
                      TextField(
                        controller: _transactionController,
                        decoration: InputDecoration(
                            labelText: localizedText[lang]!['txid'],
                            prefixIcon:
                                const Icon(Icons.receipt_long_outlined)),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: isLoading ? null : submitDepositRequest,
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 45),
                            backgroundColor:
                                isLoading ? Colors.grey : Colors.teal,
                            foregroundColor: Colors.white),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(localizedText[lang]!['submit']!),
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
                  color: isRoutePaid
                      ? Colors.green.shade100
                      : (isLate
                          ? Colors.orange.shade100
                          : Colors.blue.shade100),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: isRoutePaid
                          ? Colors.green
                          : (isLate ? Colors.orange : Colors.blue)),
                ),
                child: Column(
                  children: [
                    Text(
                        isRoutePaid
                            ? localizedText[lang]!['permit']!
                            : localizedText[lang]!['pay_req']!,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    if (!isRoutePaid)
                      Text("${localizedText[lang]!['due']}: $totalToPay ብር",
                          style:
                              const TextStyle(fontSize: 18, color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!isRoutePaid)
                ElevatedButton(
                  onPressed: payRoute,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 60)),
                  child:
                      Text("${localizedText[lang]!['pay_btn']} $totalToPay ብር"),
                ),
              if (isRoutePaid)
                OutlinedButton.icon(
                  onPressed: () => _showTrafficReceipt(context),
                  icon: const Icon(Icons.verified_user),
                  label: Text(localizedText[lang]!['receipt_btn']!),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50)),
                ),
              const SizedBox(height: 30),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(localizedText[lang]!['history']!,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
              const Divider(),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .where('uid', isEqualTo: uid)
                    .orderBy('timestamp', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var docs = snapshot.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['title'] ?? "Transaction"),
                        subtitle: Text(data['timestamp'] != null
                            ? DateFormat('MMM d, h:mm a').format(
                                (data['timestamp'] as Timestamp).toDate())
                            : ""),
                        trailing: Text("${data['amount']} ETB"),
                      );
                    },
                  );
                },
              ),
              TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminPanelPage())),
                child: const Text("ADMIN ACCESS",
                    style: TextStyle(color: Colors.grey, fontSize: 10)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrafficReceipt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(25),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.verified, color: Colors.teal, size: 90),
              Text(localizedText[lang]!['receipt_header']!,
                  style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Text(localizedText[lang]!['receipt_verified']!,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const Divider(height: 40),
              _receiptRow(localizedText[lang]!['receipt_provider']!,
                  "Tana Digital Solutions"),
              _receiptRow(localizedText[lang]!['receipt_name']!, bajajName),
              _receiptRow(localizedText[lang]!['receipt_plate']!, plateNumber),
              _receiptRow(
                  localizedText[lang]!['receipt_date']!,
                  lastPaymentDate != null
                      ? DateFormat('MMM d, yyyy')
                          .format(lastPaymentDate!.toDate())
                      : "Today"),
              _receiptRow(localizedText[lang]!['receipt_status']!,
                  localizedText[lang]!['receipt_active']!),
              const SizedBox(height: 40),
              const Icon(Icons.qr_code_scanner,
                  size: 180, color: Colors.black87),
              const SizedBox(height: 20),
              Text(localizedText[lang]!['receipt_footer']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 30),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizedText[lang]!['close']!)),
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
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
