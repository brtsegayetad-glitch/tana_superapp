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
  bool isLoading = true;

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
    // መጀመሪያ በ 1 ታብ እንጀምርና ዳታው ሲመጣ እናስተካክላለን
    _tabController = TabController(length: 1, vsync: this);
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
          // ሱፐር አድሚን ከሆነ 6 ታብ፣ ማናጀር ከሆነ 1 ታብ
          _tabController =
              TabController(length: _isSuperAdmin ? 6 : 1, vsync: this);
          isLoading = false;
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

  // --- DATABASE LOGICS ---

  Future<void> _approveDeposit(String reqId, Map<String, dynamic> data) async {
    final batch = FirebaseFirestore.instance.batch();
    String uid = data['uid'] ?? '';
    batch.update(FirebaseFirestore.instance.collection('users').doc(uid),
        {'isRoutePaid': true, 'lastPaymentDate': FieldValue.serverTimestamp()});
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
    final batch = FirebaseFirestore.instance.batch();
    batch.update(FirebaseFirestore.instance.collection('drivers').doc(docId), {
      'total_debt': 0,
      'ride_count': 0,
      'is_blocked': false,
    });
    batch.update(FirebaseFirestore.instance.collection('users').doc(docId), {
      'total_debt': 0,
      'ride_count': 0,
      'is_blocked': false,
    });
    await batch.commit();
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Ride Dispatched!")));
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
                title: const Text("Receipt"), automaticallyImplyLeading: false),
            Image.network(imageUrl,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.broken_image, size: 100)),
          ],
        ),
      ),
    );
  }

  void _showAssociationSetupDialog() {
    TextEditingController nameC = TextEditingController();
    TextEditingController teleC = TextEditingController();
    TextEditingController bankC = TextEditingController();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Setup Association"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: "Name")),
            TextField(
                controller: teleC,
                decoration: const InputDecoration(labelText: "Telebirr ID")),
            TextField(
                controller: bankC,
                decoration: const InputDecoration(labelText: "Bank Info")),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              String docId = "${nameC.text.toLowerCase().trim()}_assoc";
              await FirebaseFirestore.instance
                  .collection('associations')
                  .doc(docId)
                  .set({
                'telebirrId': teleC.text.trim(),
                'bankInfo': bankC.text.trim(),
                'name': nameC.text.trim(),
              });
              Navigator.pop(context);
            },
            child: const Text("SAVE"),
          )
        ],
      ),
    );
  }

  // --- TABS BUILDERS ---

  Widget _buildApprovalsTab() {
    Query query = FirebaseFirestore.instance
        .collection('deposit_requests')
        .where('status', isEqualTo: 'pending');
    if (!_isSuperAdmin && _managerAssociation != null) {
      query = query.where('associationId', isEqualTo: _managerAssociation);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: () => _showImageDialog(data['imageUrl'])),
                title: Text(data['driverName'] ?? "Unknown"),
                subtitle: Text("${data['amount']} ETB"),
                trailing: ElevatedButton(
                    onPressed: () => _approveDeposit(docs[index].id, data),
                    child: const Text("APPROVE")),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardTab() {
    // የ intl ማስጠንቀቂያን የሚያጠፋው ቀን ማሳያ
    String formattedDate = DateFormat('MMM dd, yyyy').format(DateTime.now());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('type', isEqualTo: 'route_permit')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        Map<String, List<DocumentSnapshot>> groupedDocs = {};
        Map<String, double> assocTotals = {};
        double grandTotal = 0;

        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          double amt = (data['amount'] ?? 0.0).toDouble();
          String assocId = data['associationId'] ?? 'Unknown';

          assocTotals[assocId] = (assocTotals[assocId] ?? 0.0) + amt;
          groupedDocs.putIfAbsent(assocId, () => []).add(doc);
          grandTotal += amt;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Revenue Breakdown",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  formattedDate,
                  style: const TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...assocTotals.entries.map((entry) {
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(entry.key.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    "Total: ${entry.value} ETB\nMy 5%: ${(entry.value * 0.05).toStringAsFixed(2)} ETB",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.check_circle,
                        color: Colors.green, size: 30),
                    onPressed: () => _handleCommissionPayment(
                        entry.key, groupedDocs[entry.key]!),
                  ),
                ),
              );
            }),
            const Divider(height: 40, thickness: 2),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _summaryRow("Grand Total Collection:",
                      "${grandTotal.toStringAsFixed(2)} ETB"),
                  const SizedBox(height: 10),
                  _summaryRow("Total My Share (5%):",
                      "${(grandTotal * 0.05).toStringAsFixed(2)} ETB",
                      isRed: true),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ይህ ነው የጎደለው _summaryRow ፈንክሽን
  Widget _summaryRow(String label, String value, {bool isRed = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isRed ? Colors.red : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildRideHailingDashboard() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
                labelText: "Search Driver", prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('drivers').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var filtered = snapshot.data!.docs
                  .where((d) => d.id.contains(_searchQuery))
                  .toList();
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  var driver = filtered[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(driver['name'] ?? "Driver"),
                    subtitle: Text("Debt: ${driver['total_debt']} ETB"),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: (driver['is_blocked'] ?? false)
                              ? Colors.red
                              : Colors.teal),
                      onPressed: () => _clearDriverDebt(filtered[index].id),
                      child: Text((driver['is_blocked'] ?? false)
                          ? "UNBLOCK"
                          : "CLEAR"),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildManagersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'manager')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: snapshot.data!.docs
              .map((doc) => ListTile(
                    title: Text(doc['fullName']),
                    subtitle: Text(
                        "Status: ${doc['isApproved'] ? 'Active' : 'Pending'}"),
                    trailing: doc['isApproved']
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : ElevatedButton(
                            onPressed: () => _approveManager(doc.id),
                            child: const Text("APPROVE")),
                  ))
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      drawer: AppDrawer(userPhone: _currentUserPhone ?? ""),
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _isSuperAdmin
              ? const [
                  Tab(text: "Approvals"),
                  Tab(text: "Revenue"),
                  Tab(text: "10% Ride"),
                  Tab(text: "Dispatch"),
                  Tab(text: "Managers"),
                  Tab(text: "Setup"),
                ]
              : const [Tab(text: "My Approvals")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _isSuperAdmin
            ? [
                _buildApprovalsTab(),
                _buildDashboardTab(),
                _buildRideHailingDashboard(),
                _buildManualDispatchTab(),
                _buildManagersTab(),
                _buildSetupTab(),
              ]
            : [_buildApprovalsTab()],
      ),
    );
  }

  Widget _buildManualDispatchTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: "Passenger Phone")),
          DropdownButtonFormField<String>(
            initialValue: _selectedHotspot,
            items: _bahirDarHotspots
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedHotspot = v!),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: _dispatchRequest, child: const Text("DISPATCH RIDE")),
        ],
      ),
    );
  }

  Widget _buildSetupTab() {
    return Center(
        child: ElevatedButton(
            onPressed: _showAssociationSetupDialog,
            child: const Text("ADD ASSOCIATION")));
  }
}
