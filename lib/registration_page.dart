import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ማስታወሻ፡ Navigator አያስፈልገንም፣ ምክንያቱም main.dart በራሱ ስትሪሙን አይቶ ገጽ ይቀይራል

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

  bool _isLogin = true;
  bool _isLoading = false;
  String _selectedRole = 'Passenger';
  String _selectedAssociation = 'Tana';

  final String _superAdminPhone = "0971732729";

  final Map<String, String> _associationIds = {
    'Tana': 'tana_assoc',
    'Abay': 'abay_assoc',
    'Fasilo': 'fasilo_assoc',
    'Weyto': 'weyto_assoc',
    'Blue Nile': 'nile_assoc'
  };

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String phone = _phoneController.text.trim();
    String fakeEmail = "$phone@hullu.com"; // ለቀላል መግቢያ የተፈጠረ
    String password = _passwordController.text.trim();

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );
      } else {
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );

        String uid = userCredential.user!.uid;
        String finalRole = _selectedRole.toLowerCase();
        String assocId = _associationIds[_selectedAssociation] ?? 'tana_assoc';
        bool isMe = (phone == _superAdminPhone);

        // 1. የUser ዳታ ማዘጋጀት
        Map<String, dynamic> userData = {
          'uid': uid,
          'fullName': _nameController.text.trim(),
          'phoneNumber': phone,
          'role': isMe ? 'superadmin' : finalRole,
          'createdAt': FieldValue.serverTimestamp(),
          'associationId': assocId,
          'isApproved': isMe ? true : (finalRole == 'manager' ? false : true),
        };

        // 2. ሾፌር ከሆነ በሾፌሮች ዝርዝር ውስጥ መመዝገብ
        if (finalRole == 'driver') {
          await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
            'name': _nameController.text.trim(),
            'plate': _plateController.text.trim(),
            'associationId': assocId,
            'isOnline': false,
            'uid': uid,
            'phoneNumber': phone,
            'total_debt': 0.0,
          });
          userData['isRoutePaid'] = false; // ለሾፌር ብቻ
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData);
      }
      // ስኬታማ ከሆነ main.dart በራሱ ገጽ ይቀይራል
    } on FirebaseAuthException catch (e) {
      String errorMessage = "ስህተት ተፈጥሯል";
      if (e.code == 'user-not-found') {
        errorMessage = "ተጠቃሚው አልተገኘም";
      } else if (e.code == 'wrong-password') errorMessage = "የተሳሳተ የይለፍ ቃል";

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.electric_rickshaw,
                          size: 60, color: Colors.teal),
                      const SizedBox(height: 10),
                      Text(
                        _isLogin ? "እንኳን ደህና መጡ" : "አዲስ መለያ ይፍጠሩ",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      // ስልክ ቁጥር
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(labelText: "ስልክ (09...)"),
                        validator: (val) =>
                            val!.length < 10 ? "ትክክለኛ ስልክ ያስገቡ" : null,
                      ),
                      const SizedBox(height: 10),
                      // የይለፍ ቃል
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: "የይለፍ ቃል"),
                        validator: (val) =>
                            val!.length < 6 ? "ቢያንስ 6 ፊደል" : null,
                      ),
                      if (!_isLogin) ...[
                        const SizedBox(height: 10),
                        // ስም
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: "ሙሉ ስም"),
                          validator: (val) => val!.isEmpty ? "ስም ያስገቡ" : null,
                        ),
                        const SizedBox(height: 15),
                        // ሚና (Role)
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          items: ['Passenger', 'Driver', 'Manager']
                              .map((r) =>
                                  DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedRole = val!),
                          decoration:
                              const InputDecoration(labelText: "የተጠቃሚ አይነት"),
                        ),
                        if (_selectedRole != 'Passenger') ...[
                          const SizedBox(height: 10),
                          if (_selectedRole == 'Driver')
                            TextFormField(
                              controller: _plateController,
                              decoration:
                                  const InputDecoration(labelText: "የታርጋ ቁጥር"),
                            ),
                          const SizedBox(height: 10),
                          // ማህበር
                          DropdownButtonFormField<String>(
                            initialValue: _selectedAssociation,
                            items: _associationIds.keys
                                .map((a) =>
                                    DropdownMenuItem(value: a, child: Text(a)))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedAssociation = val!),
                            decoration:
                                const InputDecoration(labelText: "ማህበር ይምረጡ"),
                          ),
                        ],
                      ],
                      const SizedBox(height: 30),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _handleAuth,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              child: Text(_isLogin ? "ግባ" : "ተመዝገብ",
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 18)),
                            ),
                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(_isLogin
                            ? "አዲስ ተጠቃሚ ነዎት? ይመዝገቡ"
                            : "ቀድሞ መለያ አለዎት? ይግቡ"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
