import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  // State Variables
  bool _isLogin = true;
  bool _isLoading = false;
  String _selectedRole = 'Passenger';
  String _selectedAssociation = 'Tana';

  // Images
  File? _idCardImage; // ለመታወቂያ ካርድ
  File? _profileImage; // 🔥 ለሾፌሩ ፊት (Selfie)
  final ImagePicker _picker = ImagePicker();

  final String _superAdminPhone = "0971732729";

  final Map<String, String> _associationIds = {
    'Tana': 'tana_assoc',
    'Abay': 'abay_assoc',
    'Fasilo': 'fasilo_assoc',
    'Weyto': 'weyto_assoc',
    'Blue Nile': 'nile_assoc'
  };

  // 1. ፎቶ መምረጫ (ለፕሮፋይል ወይስ ለመታወቂያ?)
  Future<void> _pickImage(ImageSource source, bool isProfile) async {
    try {
      // 4GB RAM ስለሆነ Quality 50 ይበቃል
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) {
        setState(() {
          if (isProfile) {
            _profileImage = File(pickedFile.path);
          } else {
            _idCardImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      debugPrint("የፎቶ ምርጫ ስህተት: $e");
    }
  }

  // 2. ፎቶ ወደ ImgBB መጫኛ (ሁለገብ)
  Future<String> _uploadImage(File imageFile) async {
    try {
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
      throw Exception("ImgBB Error: $e");
    }
  }

  // 3. ዋናው የምዝገባ/ሎጊን ስራ
  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    // ሾፌር ከሆነ እና እየተመዘገበ ከሆነ ሁለቱም ፎቶዎች ግዴታ ናቸው
    if (!_isLogin && _selectedRole == 'Driver') {
      if (_idCardImage == null || _profileImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("እባክዎ ሁለቱንም ፎቶዎች (ሴልፊ እና መታወቂያ) ያስገቡ"),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
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

        // --- ለሾፌር ልዩ መረጃዎች ---
        if (finalRole == 'driver') {
          // 1. ሁለቱንም ፎቶዎች ወደ ImgBB መጫን
          String profileUrl = await _uploadImage(_profileImage!); // ሴልፊ
          String idCardUrl = await _uploadImage(_idCardImage!);   // መታወቂያ

          // 2. ለ users ኮሌክሽን (አድሚን ማፑ ፎቶውን ከዚህ ያገኘዋል)
          userData['photoUrl'] = profileUrl; 
          userData['idCardUrl'] = idCardUrl;
          userData['plateNumber'] = _plateController.text.trim();
          userData['isRoutePaid'] = false;
          userData['is_blocked'] = false;
          userData['ride_count'] = 0;
          userData['total_debt'] = 0;

          // 3. በ drivers ኮሌክሽን ውስጥ
          await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
            'name': _nameController.text.trim(),
            'plate': _plateController.text.trim(),
            'idNumber': _idNumberController.text.trim(),
            'associationId': assocId,
            'isOnline': false,
            'uid': uid,
            'phoneNumber': phone,
            'photoUrl': profileUrl, // 🔥 ለ Live Map
            'idCardUrl': idCardUrl,
            'total_debt': 0,
            'ride_count': 0,
            'is_blocked': false,
            'isRoutePaid': false,
          });
        }

        // Users ኮሌክሽን ላይ መጻፍ
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData);
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = "ይህ ስልክ ቁጥር አልተመዘገበም";
          break;
        case 'wrong-password':
          errorMessage = "የተሳሳተ የይለፍ ቃል";
          break;
        case 'email-already-in-use':
          errorMessage = "ይህ ስልክ ቁጥር ቀድሞ ተመዝግቧል";
          break;
        case 'network-request-failed':
          errorMessage = "የኢንተርኔት ግንኙነት የለም";
          break;
        default:
          errorMessage = "ስህተት: ${e.message}";
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

                      // የመመዝገቢያ ፊልዶች (Login ካልሆነ ብቻ)
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
                          items: ['Passenger', 'Driver']
                              .map((r) =>
                                  DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedRole = val!),
                          decoration:
                              const InputDecoration(labelText: "የተጠቃሚ አይነት"),
                        ),

                        // ሾፌር ከሆነ የሚመጡ ተጨማሪ ፊልዶች
                        if (_selectedRole != 'Passenger') ...[
                          const SizedBox(height: 10),
                          if (_selectedRole == 'Driver') ...[
                            
                            // 1. የታርጋ ቁጥር
                            TextFormField(
                              controller: _plateController,
                              decoration: const InputDecoration(
                                labelText: "የታርጋ ቁጥር (Plate Number)",
                                prefixIcon: Icon(Icons.minor_crash),
                              ),
                              validator: (val) => (!_isLogin && val!.isEmpty) ? "እባክዎ የታርጋ ቁጥር ያስገቡ" : null,
                            ),
                            const SizedBox(height: 10),

                            // 2. የብሔራዊ መታወቂያ ቁጥር
                            TextFormField(
                              controller: _idNumberController,
                              decoration: const InputDecoration(
                                labelText: "የብሔራዊ መታወቂያ ቁጥር",
                                prefixIcon: Icon(Icons.badge),
                              ),
                              validator: (val) => (!_isLogin && val!.isEmpty) ? "እባክዎ የመታወቂያ ቁጥር ያስገቡ" : null,
                            ),
                            const SizedBox(height: 20),

                            // 3. የሾፌሩ ፕሮፋይል ፎቶ (Selfie)
                            const Text("የሾፌሩ ፕሮፋይል ፎቶ (ሴልፊ)", 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                            const SizedBox(height: 10),
                            Center(
                              child: GestureDetector(
                                onTap: () => _pickImage(ImageSource.camera, true), // true = Profile
                                child: CircleAvatar(
                                  radius: 45,
                                  backgroundColor: Colors.teal[50],
                                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                                  child: _profileImage == null 
                                      ? const Icon(Icons.add_a_photo, size: 35, color: Colors.teal) 
                                      : null,
                                ),
                              ),
                            ),
                            const Text("ለማንሳት ክበቡን ይጫኑ", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 20),

                            // 4. የመታወቂያ ካርድ ፎቶ (ID Card)
                            const Text("የመታወቂያ ካርድ ፎቶ", style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _idCardImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: Image.file(_idCardImage!, fit: BoxFit.cover),
                                    )
                                  : const Center(child: Icon(Icons.contact_mail_outlined, size: 50, color: Colors.grey)),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _pickImage(ImageSource.camera, false), // false = ID
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text("ካሜራ"),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _pickImage(ImageSource.gallery, false),
                                  icon: const Icon(Icons.photo_library),
                                  label: const Text("ጋለሪ"),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          
                          // ማህበር መምረጫ
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
                      
                      // Submit Button
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
                      
                      // Toggle Login/Signup
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            // ፎርሙን ማጽዳት
                            _formKey.currentState?.reset();
                            _phoneController.clear();
                            _passwordController.clear();
                            _nameController.clear();
                            _plateController.clear();
                            _idNumberController.clear();
                            _idCardImage = null;
                            _profileImage = null;
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