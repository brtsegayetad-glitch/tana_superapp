import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // አዲሱ መስመር እዚህ ጋር

import 'package:audioplayers/audioplayers.dart';
import 'traffic_map_view.dart';
import 'revenue_view.dart'; // 👈 ይህንን መስመር ጨምር

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Logic Variables
  String _searchQuery = "";
  String? _managerAssociation;
  String? _currentUserPhone;
  String _userRole = "manager"; // Default role
  bool isLoading = true;

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
    _loadUserData();
    _listenToSOS();
  }

  // --- 🔐 AUTH & ROLE LOGIC ---
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

          // 🛑 እዚህ ጋር ነው ማስተካከያው የሚደረገው፡
          // 1. በ UID ቼክ ያደርጋል
          // 2. በስልክ ቁጥር ቼክ ያደርጋል
          // 3. በኢሜይል ቼክ ያደርጋል (ለአዲሱ ሎጊን)
          if (user.uid == _superAdminUid ||
              _currentUserPhone == _superAdminPhone ||
              user.email == "0971732729@tana.com" || // ኮንሶል የፈጠረው fake email ካለ
              user.email == "admin@tana.com") {
            // አንተ የምትጠቀምበት ትክክለኛ ኢሜይል
            _userRole = "superadmin";
          } else if (doc.data()?['role'] == "security") {
            _userRole = "security";
          } else {
            _userRole = "manager";
          }

          int tabLength = (_userRole == "superadmin")
              ? 7
              : (_userRole == "security" ? 2 : 1);
          _tabController = TabController(length: tabLength, vsync: this);
          isLoading = false;
        });
      }
    }
  }

  void _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    // Navigate back to login or refresh app
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // --- 🚨 SOS SIREN LOGIC ---
  void _listenToSOS() {
    FirebaseFirestore.instance
        .collection('emergency_alerts')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && mounted) {
        // Only ring for security and superadmin
        if (_userRole == "superadmin" || _userRole == "security") {
          _playSiren();
          _showSOSDialog(snapshot.docs.first);
        }
      }
    });
  }

  void _playSiren() async {
    await _audioPlayer
        .play(UrlSource('https://www.soundjay.com/buttons/beep-01a.mp3'));
  }

  void _showSOSDialog(DocumentSnapshot alert) {
    var data = alert.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red[900],
        title: const Icon(Icons.warning, color: Colors.white, size: 50),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("የአደጋ ጊዜ ጥሪ (SOS)!",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("ሾፌር፡ ${data['driverName'] ?? 'ያልታወቀ'}",
                style: const TextStyle(color: Colors.white)),
            Text("ስልክ፡ ${data['driverPhone'] ?? 'የለም'}",
                style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              alert.reference.update({'status': 'resolved'});
              Navigator.pop(context);
            },
            child: const Text("ችግሩ ተፈቷል"),
          )
        ],
      ),
    );
  }

  // --- 💰 DATABASE LOGICS (ያልተቀነሱ) ---
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
    batch.update(FirebaseFirestore.instance.collection('drivers').doc(docId),
        {'total_debt': 0, 'ride_count': 0, 'is_blocked': false});
    batch.update(FirebaseFirestore.instance.collection('users').doc(docId),
        {'total_debt': 0, 'ride_count': 0, 'is_blocked': false});
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

  // --- 🏗 UI TAB BUILDERS ---

  Widget _buildApprovalsTab() {
    Query query = FirebaseFirestore.instance
        .collection('deposit_requests')
        .where('status', isEqualTo: 'pending');
    if (_userRole != "superadmin" && _managerAssociation != null) {
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
                    title: Text(data['driverName'] ?? "Unknown"),
                    subtitle: Text("${data['amount']} ETB"),
                    trailing: ElevatedButton(
                        onPressed: () => _approveDeposit(docs[index].id, data),
                        child: const Text("APPROVE"))));
          },
        );
      },
    );
  }

  // --- 🛠 NEW: ASSOCIATION SETUP LOGIC ---
  void _showSetupDialog() {
    final nameC = TextEditingController();
    final teleC = TextEditingController();
    final bankC = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Association"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameC,
                decoration:
                    const InputDecoration(labelText: "Association Name")),
            TextField(
                controller: teleC,
                decoration:
                    const InputDecoration(labelText: "Telebirr Number")),
            TextField(
                controller: bankC,
                decoration:
                    const InputDecoration(labelText: "Bank Account Details")),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('associations')
                  .doc(nameC.text.toLowerCase().trim())
                  .set({
                'name': nameC.text.trim(),
                'telebirrId': teleC.text.trim(),
                'bankInfo': bankC.text.trim(),
                'createdAt': FieldValue.serverTimestamp()
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Association Added!")));
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  Widget _buildSetupTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.business_center, size: 80, color: Colors.teal),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showSetupDialog,
            icon: const Icon(Icons.add),
            label: const Text("ADD NEW ASSOCIATION"),
            style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
          ),
        ],
      ),
    );
  }

  // --- 🏗 MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Tana Admin - $_userRole"),
        backgroundColor: Colors.teal[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout)
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _buildTabsByRole(),
          // 👇 ታብ ስንቀይር ስክሪኑ እንዲታደስና ቁልፉ እንዲመጣ ያደርጋል
          onTap: (index) {
            setState(() {});
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _buildViewsByRole(),
      ),
      // 🎯 ይህ ክፍል ነው ማስጠንቀቂያውን የሚያጠፋው እና ቁልፉን የሚያመጣው!
      // 'Managers' ታብ ላይ ስንሆን (index == 5) ቁልፉ ይታያል
      floatingActionButton: _tabController.index == 5
          ? FloatingActionButton.extended(
              onPressed: () => _showAddAdminDialog(), // እዚህ ጋር ተጠራ!
              backgroundColor: Colors.orange[900],
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text("Add Admin/Manager",
                  style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  List<Tab> _buildTabsByRole() {
    if (_userRole == "superadmin") {
      return const [
        Tab(text: "Approvals"),
        Tab(text: "Revenue"),
        Tab(text: "10% Ride debt"),
        Tab(text: "Traffic/SOS"),
        Tab(text: "Dispatch"),
        Tab(text: "Managers"),
        Tab(text: "Setup")
      ];
    } else if (_userRole == "security") {
      return const [Tab(text: "Traffic/SOS"), Tab(text: "Reports")];
    } else {
      return const [Tab(text: "My Approvals")];
    }
  }

  List<Widget> _buildViewsByRole() {
    if (_userRole == "superadmin") {
      return [
        _buildApprovalsTab(),
        const RevenueView(),
        _buildRideHailingDashboard(),
        const TrafficMapView(),
        _buildManualDispatchTab(),
        _buildManagersTab(),
        _buildSetupTab()
      ];
    } else if (_userRole == "security") {
      return [
        const TrafficMapView(),
        const Center(child: Text("Security Reports"))
      ];
    } else {
      return [_buildApprovalsTab()];
    }
  }

  // (Remaining Widgets: _buildRideHailingDashboard, _buildManualDispatchTab, _buildManagersTab kept exactly as provided)
  Widget _buildRideHailingDashboard() {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
              decoration: const InputDecoration(
                  labelText: "Search Driver", prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _searchQuery = v))),
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
                      var driver =
                          filtered[index].data() as Map<String, dynamic>;
                      return ListTile(
                          title: Text(driver['name'] ?? "Driver"),
                          subtitle: Text("Debt: ${driver['total_debt']} ETB"),
                          trailing: ElevatedButton(
                              onPressed: () =>
                                  _clearDriverDebt(filtered[index].id),
                              child: const Text("CLEAR")));
                    });
              })),
    ]);
  }

  Widget _buildManualDispatchTab() {
    return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: "የደዋይ ስልክ ቁጥር")),
          DropdownButtonFormField<String>(
              initialValue: _selectedHotspot,
              items: _bahirDarHotspots
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedHotspot = v!)),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: _dispatchRequest, child: const Text("DISPATCH RIDE")),
        ]));
  }

  // --- 👥 አዲስ አድሚን ለመጨመር የሚረዳ Dialog ---
  // --- 👥 አዲስ አድሚን ለመጨመር የሚረዳ Dialog (የተሻሻለ) ---
  void _showAddAdminDialog() {
    final emailC = TextEditingController();
    final passwordC = TextEditingController();
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final associationC = TextEditingController(); // 👈 አዲስ የማህበር ስም መቀበያ
    String selectedRole = "manager";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // ምርጫ ስትቀይር ፎርሙ እንዲቀየር ይረዳል
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("አዲስ አድሚን/ማናጀር መዝግብ"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameC,
                    decoration: const InputDecoration(labelText: "ሙሉ ስም")),
                TextField(
                    controller: emailC,
                    decoration:
                        const InputDecoration(labelText: "ኢሜይል (Email)")),
                TextField(
                    controller: phoneC,
                    decoration: const InputDecoration(labelText: "ስልክ ቁጥር")),
                TextField(
                    controller: passwordC,
                    decoration: const InputDecoration(labelText: "የይለፍ ቃል"),
                    obscureText: true),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  items: const [
                    DropdownMenuItem(
                        value: "manager", child: Text("Association Manager")),
                    DropdownMenuItem(
                        value: "security", child: Text("City Security")),
                  ],
                  onChanged: (v) => setDialogState(() => selectedRole = v!),
                  decoration: const InputDecoration(labelText: "ስልጣን (Role)"),
                ),
                // 👇 ስልጣኑ ማናጀር ከሆነ ብቻ የማህበሩን ስም ይጠይቃል
                if (selectedRole == "manager")
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: associationC,
                      decoration: const InputDecoration(
                        labelText: "የማህበሩ ስም (Association Name)",
                        hintText: "ለምሳሌ፡ አባይ ማዶ ማህበር",
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("ተመለስ")),
            ElevatedButton(
              onPressed: () async {
                try {
                  FirebaseApp secondaryApp = await Firebase.initializeApp(
                    name: 'SecondaryApp',
                    options: Firebase.app().options,
                  );

                  UserCredential userCredential =
                      await FirebaseAuth.instanceFor(app: secondaryApp)
                          .createUserWithEmailAndPassword(
                              email: emailC.text.trim(),
                              password: passwordC.text.trim());

                  // መረጃውን Firestore ውስጥ ማስቀመጥ
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userCredential.user!.uid)
                      .set({
                    'fullName': nameC.text.trim(),
                    'email': emailC.text.trim(),
                    'phoneNumber': phoneC.text.trim(),
                    'role': selectedRole,
                    'associationId': selectedRole == "manager"
                        ? associationC.text.trim()
                        : "N/A", // 👈 እዚህ ጋር ይቀመጣል
                    'isApproved': true,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  await secondaryApp.delete();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text("ተመዝግቧል!")));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("ስህተት፡ ${e.toString()}")));
                }
              },
              child: const Text("መዝግብ"),
            ),
          ],
        ),
      ),
    );
  }

  // --- 👥 MANAGERS MANAGEMENT TAB (የተሻሻለው) ---
  Widget _buildManagersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['manager', 'security']).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            var user = users[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: Icon(user['role'] == 'security'
                    ? Icons.security
                    : Icons.person_pin),
                title: Text(user['fullName'] ?? 'ስም የለም'),
                subtitle: Text("${user['email']} | Role: ${user['role']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => FirebaseFirestore.instance
                      .collection('users')
                      .doc(users[index].id)
                      .delete(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
} // <--- ይህ የክላሱ መጨረሻ ነው (class _AdminDashboardPageState)
