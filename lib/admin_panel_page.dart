import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'app_drawer.dart';

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
  String? _currentUserPhone;

  // --- ሱፐር አድሚን መለያዎች ---
  final String _superAdminUid = "xRFKCJFvfzX4mpkaNKsbLwhie9o1";
  final String _superAdminPhone = "0971732729";

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
    _tabController = TabController(length: _isSuperAdmin ? 5 : 1, vsync: this);
    _loadUserData();
  }

  bool get _isSuperAdmin {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.uid == _superAdminUid || _currentUserPhone == _superAdminPhone;
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _managerAssociation = doc.data()?['associationId'];
          _currentUserPhone = doc.data()?['phoneNumber'];
          _tabController =
              TabController(length: _isSuperAdmin ? 5 : 1, vsync: this);
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

  // --- ASSOCIATION SETUP ---
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
                  decoration: const InputDecoration(labelText: "Assoc Name")),
              TextField(
                  controller: teleC,
                  decoration: const InputDecoration(labelText: "Telebirr ID")),
              TextField(
                  controller: bankC,
                  decoration: const InputDecoration(labelText: "Bank Info"),
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
              if (mounted) Navigator.pop(context);
            },
            child: const Text("SAVE"),
          )
        ],
      ),
    );
  }

  // --- TEST DATA ---
  Future<void> _createTestTransaction() async {
    await FirebaseFirestore.instance.collection('transactions').add({
      'amount': 150.0,
      'associationId': 'tana_assoc',
      'type': 'route_permit',
      'timestamp': FieldValue.serverTimestamp(),
      'driverName': 'Test Driver Bahir Dar',
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Test Data Created!")));
    }
  }

  // --- UI HELPERS ---
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
            InteractiveViewer(child: Image.network(imageUrl)),
          ],
        ),
      ),
    );
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

  // --- DATABASE LOGIC ---
  Future<void> _approveDeposit(String reqId, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    String uid = data['uid'] ?? '';
    batch.update(FirebaseFirestore.instance.collection('users').doc(uid),
        {'isRoutePaid': true});
    batch.update(
        FirebaseFirestore.instance.collection('deposit_requests').doc(reqId),
        {'status': 'approved'});
    batch.set(FirebaseFirestore.instance.collection('transactions').doc(), {
      'uid': uid,
      'amount': data['amount'],
      'type': 'route_permit',
      'associationId': data['associationId'],
      'timestamp': FieldValue.serverTimestamp(),
      'driverName': data['driverName'],
    });
    await batch.commit();
  }

  Future<void> _clearDriverDebt(String docId) async {
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(docId)
        .update({'total_debt': 0.0});
  }

  Future<void> _approveManager(String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'isApproved': true});
  }

  Future<void> _handleCommissionPayment(
      String assocId, List<DocumentSnapshot> allDocs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in allDocs) {
      if (doc['associationId'] == assocId) batch.delete(doc.reference);
    }
    await batch.commit();
  }

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
  }

  // --- TABS ---
  Widget _buildApprovalsTab() {
    Query query = FirebaseFirestore.instance
        .collection('deposit_requests')
        .where('status', isEqualTo: 'pending');
    if (_managerAssociation != null && !_isSuperAdmin) {
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
          return const Center(child: Text("No pending requests"));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: ListTile(
                leading: IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: () => data['imageUrl'] != null
                        ? _showImageDialog(data['imageUrl'])
                        : null),
                title: Text(
                    "${data['driverName'] ?? 'Unknown'} - ${data['amount']} ETB"),
                trailing: ElevatedButton(
                    onPressed: () => _approveDeposit(doc.id, data),
                    child: const Text("APPROVE")),
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
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          onChanged: (value) =>
              setState(() => _searchQuery = value.toLowerCase()),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            var filtered = snapshot.data!.docs
                .where((d) =>
                    (d['phoneNumber'] ?? "").toString().contains(_searchQuery))
                .toList();
            return Column(
                children: filtered.map((doc) {
              var driver = doc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(driver['name'] ?? "Unknown"),
                subtitle: Text(
                    "Debt: ${(driver['total_debt'] ?? 0.0).toStringAsFixed(2)} ETB"),
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
        Map<String, double> assocTotals = {};
        double grandTotal = 0;
        for (var doc in snapshot.data!.docs) {
          double amt = (doc['amount'] ?? 0.0).toDouble();
          assocTotals[doc['associationId'] ?? 'Unknown'] =
              (assocTotals[doc['associationId'] ?? 'Unknown'] ?? 0.0) + amt;
          grandTotal += amt;
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text("Route Report: $today",
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.teal)),
            ...assocTotals.entries.map((entry) => Card(
                  child: ListTile(
                    title: Text(entry.key.toUpperCase()),
                    subtitle: Text(
                        "Total: ${entry.value} ETB\nMy 5%: ${(entry.value * 0.05).toStringAsFixed(2)} ETB"),
                    trailing: IconButton(
                        icon:
                            const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _handleCommissionPayment(
                            entry.key, snapshot.data!.docs)),
                  ),
                )),
            const Divider(),
            _row("Grand Total Collection:",
                "${grandTotal.toStringAsFixed(2)} ETB",
                bold: true),
            _row("Total My Share (5%):",
                "${(grandTotal * 0.05).toStringAsFixed(2)} ETB",
                color: Colors.red, bold: true),
          ],
        );
      },
    );
  }

  Widget _buildManualDispatchTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                  labelText: "Passenger Phone", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            initialValue: _selectedHotspot,
            items: _bahirDarHotspots
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedHotspot = v!),
            decoration: const InputDecoration(
                labelText: "Hotspot", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: _dispatchRequest,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.teal),
              child: const Text("DISPATCH",
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildManagersTab() {
    return Column(
      children: [
        const Padding(
            padding: EdgeInsets.all(10.0),
            child: Text("Pending Approvals",
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
        Expanded(
          flex: 1,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'manager')
                .where('isApproved', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                  children: snapshot.data!.docs
                      .map((doc) => ListTile(
                          title: Text(doc['fullName'] ?? "No Name"),
                          subtitle: Text(doc['associationId'] ?? ""),
                          trailing: ElevatedButton(
                              onPressed: () => _approveManager(doc.id),
                              child: const Text("APPROVE"))))
                      .toList());
            },
          ),
        ),
        const Divider(thickness: 2),
        const Padding(
            padding: EdgeInsets.all(10.0),
            child: Text("Active Managers",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green))),
        Expanded(
          flex: 2,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'manager')
                .where('isApproved', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                  children: snapshot.data!.docs
                      .map((doc) => ListTile(
                          leading:
                              const Icon(Icons.verified, color: Colors.green),
                          title: Text(doc['fullName'] ?? "No Name"),
                          subtitle: Text("Assoc: ${doc['associationId']}"),
                          trailing: IconButton(
                              icon: const Icon(Icons.block, color: Colors.red),
                              onPressed: () async => await FirebaseFirestore
                                  .instance
                                  .collection('users')
                                  .doc(doc.id)
                                  .update({'isApproved': false}))))
                      .toList());
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSuperAdmin ? "Super Admin" : "Assoc. Manager"),
        backgroundColor: Colors.teal,
        actions: [
          if (_isSuperAdmin) ...[
            IconButton(
                icon: const Icon(Icons.bug_report),
                onPressed: _createTestTransaction),
            IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _showAssociationSetupDialog),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: _isSuperAdmin,
          tabs: [
            const Tab(text: "Approvals"),
            if (_isSuperAdmin) ...[
              const Tab(text: "Ride Debt"),
              const Tab(text: "Route (5%)"),
              const Tab(text: "Dispatch"),
              const Tab(text: "Managers"),
            ],
          ],
        ),
      ),
      drawer: AppDrawer(userPhone: _currentUserPhone),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApprovalsTab(),
          if (_isSuperAdmin) ...[
            _buildRideHailingDashboard(),
            _buildDashboardTab(),
            _buildManualDispatchTab(),
            _buildManagersTab(),
          ],
        ],
      ),
    );
  }
}
