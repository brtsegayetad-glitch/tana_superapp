import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String _selectedRole = 'Passenger';
  String _selectedAssociation = 'Tana';

  File? _idCardImage;
  final ImagePicker _picker = ImagePicker();

  final String _superAdminPhone = "0971732729";

  final Map<String, String> _associationIds = {
    'Tana': 'tana_assoc',
    'Abay': 'abay_assoc',
    'Fasilo': 'fasilo_assoc',
    'Weyto': 'weyto_assoc',
    'Blue Nile': 'nile_assoc'
  };

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 50, // Compress image to save space
      );
      if (pickedFile != null) {
        setState(() {
          _idCardImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("የፎቶ ምርጫ አልተሳካም: $e")),
        );
      }
    }
  }

 Future<String> _uploadIdCard(File imageFile) async {
    try {
      // ከ api.imgbb.com ያገኘኸውን ቁጥር እዚህ ጋር በደንብ ተክተህ አስገባ
      String apiKey = "858ef05f1ba7c5262fbb85ea9894c83f"; 
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey'),
      );

      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);
        return json['data']['url']; // የፎቶው ሊንክ
      } else {
        throw Exception("ፎቶውን ወደ ImgBB መጫን አልተሳካም");
      }
    } catch (e) {
      throw Exception("የመታወቂያ ካርድ መስቀል አልተሳካም: $e");
    }
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    // For driver registration, ID card is mandatory
    if (!_isLogin && _selectedRole == 'Driver' && _idCardImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("እባክዎ የመታወቂያ ካርድዎን ፎቶ ያስገቡ"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String phone = _phoneController.text.trim();
    String fakeEmail = "$phone@hullu.com";
    String password = _passwordController.text.trim();

    try {
      if (_isLogin) {
        // --- መግቢያ (Login) ---
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );
      } else {
        // --- ምዝገባ (Sign Up) ---
        UserCredential userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );

        String uid = userCredential.user!.uid;
        String finalRole = _selectedRole.toLowerCase();
        String assocId = _associationIds[_selectedAssociation] ?? 'tana_assoc';
        bool isMe = (phone == _superAdminPhone);

        Map<String, dynamic> userData = {
          'uid': uid,
          'fullName': _nameController.text.trim(),
          'phoneNumber': phone,
          'role': isMe ? 'superadmin' : finalRole,
          'createdAt': FieldValue.serverTimestamp(),
          'associationId': assocId,
          'isApproved': isMe ? true : (finalRole == 'manager' ? false : true),
        };

        // ሾፌር ከሆነ አስፈላጊዎቹን የፋይናንስ ፊልዶች እና የመታወቂያ ካርድ ዩአርኤል እዚህ እንጨምራለን
        if (finalRole == 'driver') {
          // Upload ID card and get URL
          String idCardUrl = await _uploadIdCard(uid, _idCardImage!);
          userData['idCardUrl'] = idCardUrl;

          // 1. በ drivers ኮሌክሽን ውስጥ
          await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
            'name': _nameController.text.trim(),
            'plate': _plateController.text.trim(),
            'idNumber': _idNumberController.text.trim(), // ይህንን አዲስ ጨምር
            'associationId': assocId,
            'isOnline': false,
            'uid': uid,
            'phoneNumber': phone,
            'total_debt': 0, // Number
            'ride_count': 0, // Number
            'is_blocked': false, // Boolean
            'isRoutePaid': true, // ይህንን መጨመርህ በጣም ትክክል ነው!
            'idCardUrl': idCardUrl, // Store URL in drivers collection too
          });

          // 2. በ users ኮሌክሽን ውስጥ (ለ BajajDriverPage ቼክ እንዲያደርግ)
          userData['isRoutePaid'] = true;
          userData['is_blocked'] = false;
          userData['ride_count'] = 0;
          userData['total_debt'] = 0;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData);
      }

      // --- የስህተት መቆጣጠሪያ (The updated Error Handler) ---
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      // ትክክለኛውን የFirebase ስህተት መለየት
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "ይህ ስልክ ቁጥር አልተመዘገበም (User not found)";
          break;
        case 'wrong-password':
          errorMessage = "የተሳሳተ የይለፍ ቃል (Wrong password)";
          break;
        case 'email-already-in-use':
          errorMessage = "ይህ ስልክ ቁጥር ቀድሞ ተመዝግቧል (Already exists)";
          break;
        case 'network-request-failed':
          errorMessage = "የኢንተርኔት ግንኙነት የለም (No Internet)";
          break;
        default:
          errorMessage = "ስህተት: ${e.message}"; // ሌሎች ስህተቶችን በዝርዝር ያሳያል
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ያልታወቀ ስህተት: $e")),
        );
      }
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
                          if (_selectedRole == 'Driver') ...[
                            TextFormField(
                              controller: _plateController,
                              decoration:
                                  const InputDecoration(labelText: "የታርጋ ቁጥር"),
                            ),

                            // --- አዲሱ ኮድ ከዚህ በታች ይጀምራል ---
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _idNumberController,
                              decoration: const InputDecoration(
                                labelText: "የብሔራዊ መታወቂያ ቁጥር",
                                prefixIcon: Icon(Icons.badge),
                              ),
                              validator: (val) {
                                if (!_isLogin &&
                                    _selectedRole == 'Driver' &&
                                    val!.isEmpty) {
                                  return "እባክዎ የመታወቂያ ቁጥር ያስገቡ";
                                }
                                return null;
                              },
                            ),
                            // --- አዲሱ ኮድ እዚህ ያበቃል ---

                            const SizedBox(height: 20),
                            // --- National ID Scanner ---
                            Text("የመታወቂያ ካርድ ፎቶ",
                                style: TextStyle(color: Colors.grey.shade700)),
                            const SizedBox(height: 8),
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _idCardImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: Image.file(_idCardImage!,
                                          fit: BoxFit.cover),
                                    )
                                  : const Center(child: Text("ምንም ፎቶ አልተመረጠም")),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text("ካሜራ"),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _pickImage(ImageSource.gallery),
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text("ጋለሪ"),
                                ),
                              ],
                            ),
                          ],
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
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            // Clear fields when switching forms
                            _formKey.currentState?.reset();
                            _phoneController.clear();
                            _passwordController.clear();
                            _nameController.clear();
                            _plateController.clear();
                            _idCardImage = null;
                            _selectedRole = 'Passenger';
                          });
                        },
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
