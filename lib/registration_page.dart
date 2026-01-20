import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'bajaj_driver_page.dart';
import 'bajaj_passenger_page.dart';
import 'admin_panel_page.dart'; // ማሳሰቢያ፡ የፋይሉ ስም በዚህ መጠራቱን አረጋግጥ

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String _selectedRole = 'Passenger';
  String _selectedAssociation = 'Tana';

  final Map<String, String> _associationIds = {
    'Tana': 'tana_assoc',
    'Abay': 'abay_assoc',
    'Fasilo': 'fasilo_assoc',
    'Weyto': 'weyto_assoc',
    'Blue Nile': 'nile_assoc'
  };

  final List<String> _roles = ['Passenger', 'Driver'];
  final List<String> _associations = [
    'Tana',
    'Abay',
    'Fasilo',
    'Weyto',
    'Blue Nile'
  ];

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String fakeEmail = "${_phoneController.text.trim()}@hullu.com";
    String password = _passwordController.text.trim();

    try {
      String? finalRole;

      if (_isLogin) {
        // --- LOGIN LOGIC ---
        UserCredential cred =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();
        finalRole = userDoc.data()?['role'];
      } else {
        // --- REGISTER LOGIC ---
        UserCredential credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );

        String uid = credential.user!.uid;
        finalRole = _selectedRole;
        String assocId = _associationIds[_selectedAssociation] ?? 'tana_assoc';

        Map<String, dynamic> userData = {
          'uid': uid,
          'fullName': _nameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
          'isRoutePaid': false,
        };

        if (_selectedRole == 'Driver') {
          userData['plateNumber'] = _plateController.text.trim();
          userData['associationId'] = assocId;
          userData['nationalId'] = _nationalIdController.text.trim();

          await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
            'name': _nameController.text.trim(),
            'plate': _plateController.text.trim(),
            'associationId': assocId,
            'nationalId': _nationalIdController.text.trim(),
            'isOnline': false,
            'uid': uid,
            'phoneNumber': _phoneController.text.trim(),
            'total_debt': 0.0,
          });

          await FirebaseFirestore.instance.collection('wallets').doc(uid).set({
            'fullName': _nameController.text.trim(),
            'associationId': assocId,
            'isRoutePaid': false,
            'lastPaymentDate': null,
            'plateNumber': _plateController.text.trim(),
            'nationalId': _nationalIdController.text.trim(),
          });
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData);
      }

      if (!mounted) return;

      // --- NAVIGATION LOGIC ---
      Widget nextScreen;
      if (finalRole == 'manager') {
        nextScreen = const AdminPanelPage();
      } else if (finalRole == 'Driver') {
        nextScreen = const BajajDriverPage();
      } else {
        nextScreen = const BajajPassengerPage();
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => nextScreen),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isLogin ? "Hullugebeya Login" : "Join the Community"),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(Icons.local_taxi, size: 80, color: Colors.teal),
                const SizedBox(height: 10),
                const Text("BAHIR DAR SUPERAPP",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: "Phone Number",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone)),
                  validator: (val) =>
                      val!.length < 10 ? "Enter valid phone" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock)),
                  validator: (val) =>
                      val!.length < 6 ? "Password too short" : null,
                ),
                if (!_isLogin) ...[
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: "Full Name",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person)),
                    validator: (val) => val!.isEmpty ? "Enter name" : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                        labelText: "I want to be a...",
                        border: OutlineInputBorder()),
                    items: _roles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedRole = val as String),
                  ),
                  if (_selectedRole == 'Driver') ...[
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _nationalIdController,
                      decoration: const InputDecoration(
                          labelText: "National ID Number",
                          hintText: "As shown on your ID card",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge)),
                      validator: (val) =>
                          val!.isEmpty ? "National ID is required" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _plateController,
                      decoration: const InputDecoration(
                          labelText: "Bajaj Plate Number",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.numbers)),
                      validator: (val) => val!.isEmpty ? "Enter plate" : null,
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField(
                      initialValue: _selectedAssociation,
                      decoration: const InputDecoration(
                          labelText: "Select Association",
                          border: OutlineInputBorder()),
                      items: _associations
                          .map(
                              (a) => DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedAssociation = val as String),
                    ),
                  ],
                ],
                const SizedBox(height: 25),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _handleAuth,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: Text(_isLogin ? "LOGIN" : "CREATE ACCOUNT",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin
                      ? "New to Hullugebeya? Register here"
                      : "Already have an account? Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
