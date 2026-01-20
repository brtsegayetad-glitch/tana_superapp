import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  String? _managerAssociation;

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
    _tabController = TabController(length: 4, vsync: this);
    _loadManagerData();
  }

  Future<void> _loadManagerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _managerAssociation = doc.data()?['associationId'];
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // --- አዲሱ የፎቶ ማሳያ Dialog ---
  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title:
                  const Text("Payment Receipt", style: TextStyle(fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context))
              ],
              backgroundColor: Colors.teal,
            ),
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("Could not load image"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TEST DATA GENERATOR ---
  Future<void> _createTestTransaction() async {
    await FirebaseFirestore.instance.collection('transactions').add({
      'amount': 150.0,
      'associationId': 'tana_assoc',
      'type': 'route_permit',
      'timestamp': FieldValue.serverTimestamp(),
      'driverName': 'Test Driver Bahir Dar',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Test Transaction Created! Check Route tab.")));
    }
  }

  void _showAssociationSetupDialog() {
    TextEditingController nameC = TextEditingController();
    TextEditingController teleC = TextEditingController();
    TextEditingController bankC = TextEditingController();

    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text("Setup Association Account"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: nameC,
                        decoration: const InputDecoration(
                            labelText: "Assoc Name (e.g. Tana)")),
                    TextField(
                        controller: teleC,
                        decoration: const InputDecoration(
                            labelText: "Telebirr Merchant ID")),
                    TextField(
                        controller: bankC,
                        decoration: const InputDecoration(
                            labelText: "Bank Account & Name"),
                        maxLines: 2),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CANCEL")),
                ElevatedButton(
                    onPressed: () async {
                      if (nameC.text.isEmpty) return;
                      String docId = "${nameC.text.toLowerCase().trim()}_assoc";
                      await FirebaseFirestore.instance
                          .collection('associations')
                          .doc(docId)
                          .set({
                        'telebirrId': teleC.text.trim(),
                        'bankInfo': bankC.text.trim(),
                        'name': nameC.text.trim(),
                      });
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    child: const Text("SAVE"))
              ],
            ));
  }

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

  Widget _buildApprovalsTab() {
    Query query = FirebaseFirestore.instance
        .collection('deposit_requests')
        .where('status', isEqualTo: 'pending');
    if (_managerAssociation != null) {
      query = query.where('associationId', isEqualTo: _managerAssociation);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No pending payments."));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String? imageUrl = data['imageUrl'];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: ListTile(
                leading: GestureDetector(
                  onTap: imageUrl != null
                      ? () => _showImageDialog(imageUrl)
                      : null,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(imageUrl, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.receipt_long, color: Colors.grey),
                  ),
                ),
                title: Text(
                    "${data['driverName'] ?? 'Unknown'} - ${data['amount']} ETB"),
                subtitle: Text("TXID: ${data['transactionId']}"),
                trailing: ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => _approveDeposit(doc.id, data),
                  child: const Text("APPROVE",
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRideHailingDashboard() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: "Search Driver by Phone...",
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) =>
              setState(() => _searchQuery = value.toLowerCase()),
        ),
        const SizedBox(height: 30),
        const Text("DRIVER DEBT (10% RIDE COMMISSION)",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            var filtered = snapshot.data!.docs.where((d) {
              bool matchesSearch =
                  (d['phoneNumber'] ?? "").toString().contains(_searchQuery);
              bool matchesAssoc = _managerAssociation == null ||
                  d['associationId'] == _managerAssociation;
              return matchesSearch && matchesAssoc;
            }).toList();
            return Column(
                children: filtered.map((doc) {
              var driver = doc.data() as Map<String, dynamic>;
              double debt = (driver['total_debt'] ?? 0.0).toDouble();
              return ListTile(
                title: Text(driver['name'] ?? "Unknown"),
                subtitle: Text("Debt: ${debt.toStringAsFixed(2)} ETB"),
                trailing: ElevatedButton(
                    onPressed: () => _clearDriverDebt(doc.id),
                    child: const Text("CLEAR")),
              );
            }).toList());
          },
        ),
      ],
    );
  }

  Widget _buildDashboardTab() {
    String today = DateFormat('MMM d, yyyy').format(DateTime.now());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('type', isEqualTo: 'route_permit')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text("No transactions yet. Click the bug icon to test."));
        }

        Map<String, double> assocTotals = {};
        double grandTotal = 0;

        for (var doc in snapshot.data!.docs) {
          double amt = (doc['amount'] ?? 0.0).toDouble();
          String assocId = doc['associationId'] ?? 'Unknown';
          assocTotals[assocId] = (assocTotals[assocId] ?? 0.0) + amt;
          grandTotal += amt;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Route Report: $today",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.teal)),
              const Divider(),
              const Text("BY ASSOCIATION BREAKDOWN",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey)),
              const SizedBox(height: 10),
              ...assocTotals.entries.map((entry) {
                double commission = entry.value * 0.05;
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 15),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.key.toUpperCase(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal)),
                          subtitle: Text(
                              "Total Collection: ${entry.value} ETB\nMy 5% Share: ${commission.toStringAsFixed(2)} ETB",
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold)),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, color: Colors.teal),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                  text:
                                      "Assoc: ${entry.key}\nTotal: ${entry.value} ETB\nCommission: ${commission.toStringAsFixed(2)} ETB"));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Report Copied")));
                            },
                          ),
                        ),
                        const Divider(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleCommissionPayment(
                                entry.key, snapshot.data!.docs),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text("MARK AS PAID & RESET"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal)),
                child: Column(
                  children: [
                    _row("ALL GROUPS TOTAL:",
                        "${grandTotal.toStringAsFixed(2)} ETB",
                        bold: true),
                    _row("GRAND COMMISSION (5%):",
                        "${(grandTotal * 0.05).toStringAsFixed(2)} ETB",
                        color: Colors.red[900], bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text:
                          "Grand Total: $grandTotal ETB. Total 5% Commission: ${(grandTotal * 0.05).toStringAsFixed(2)} ETB"));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Grand Summary Copied!")));
                },
                icon: const Icon(Icons.copy_all),
                label: const Text("COPY GRAND SUMMARY"),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.teal[800],
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCommissionPayment(
      String assocId, List<DocumentSnapshot> allDocs) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Confirm Payment"),
        content: Text(
            "Did you receive the commission from $assocId? This will reset their balance to zero."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text("NO")),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text("YES, PAID")),
        ],
      ),
    );

    if (confirm == true) {
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in allDocs) {
        if (doc['associationId'] == assocId) {
          var historyRef =
              FirebaseFirestore.instance.collection('paid_history').doc();
          batch.set(historyRef, {
            ...doc.data() as Map<String, dynamic>,
            'paidAt': FieldValue.serverTimestamp(),
          });
          batch.delete(doc.reference);
        }
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Balance for $assocId cleared!")));
      }
    }
  }

  Widget _buildManualDispatchTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                  labelText: "Passenger Phone", border: OutlineInputBorder()),
              keyboardType: TextInputType.phone),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _selectedHotspot,
            items: _bahirDarHotspots
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedHotspot = v!),
            decoration: const InputDecoration(
                labelText: "Pickup Hotspot", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.teal),
              onPressed: _dispatchRequest,
              child: const Text("DISPATCH DRIVER",
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  // --- ADDED MISSING DISPATCH LOGIC ---
  Future<void> _dispatchRequest() async {
    if (_phoneController.text.isEmpty) return;
    await FirebaseFirestore.instance.collection('ride_requests').add({
      'passenger_phone': _phoneController.text.trim(),
      'pickup_location': _selectedHotspot,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'call_center'
    });
    _phoneController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Request Dispatched!")));
    }
  }

  Future<void> _approveDeposit(String reqId, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    String uid = data['uid'] ?? '';
    double amt = (data['amount'] ?? 0.0).toDouble();

    batch.update(FirebaseFirestore.instance.collection('users').doc(uid), {
      'isRoutePaid': true,
      'lastPaymentDate': FieldValue.serverTimestamp(),
    });

    batch.update(
        FirebaseFirestore.instance.collection('deposit_requests').doc(reqId),
        {'status': 'approved'});

    batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
      'uid': uid,
      'amount': amt,
      'type': 'route_permit',
      'associationId': data['associationId'],
      'timestamp': FieldValue.serverTimestamp(),
      'driverName': data['driverName'],
    });

    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Driver Approved! Route is now Active.")));
    }
  }

  Future<void> _clearDriverDebt(String id) async {
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(id)
        .update({'total_debt': 0.0});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_managerAssociation == null ? "SuperAdmin" : "Assoc Manager"),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orangeAccent),
            onPressed: _createTestTransaction,
            tooltip: "Create Test Data",
          ),
          if (_managerAssociation == null)
            IconButton(
                icon: const Icon(Icons.settings_suggest),
                onPressed: _showAssociationSetupDialog,
                tooltip: "Setup Assoc Accounts"),
        ],
        bottom:
            TabBar(controller: _tabController, isScrollable: true, tabs: const [
          Tab(text: "Approvals"),
          Tab(text: "Ride (10%)"),
          Tab(text: "Route (5%)"),
          Tab(text: "Dispatch")
        ]),
      ),
      body: TabBarView(controller: _tabController, children: [
        _buildApprovalsTab(),
        _buildRideHailingDashboard(),
        _buildDashboardTab(),
        _buildManualDispatchTab()
      ]),
    );
  }
}
