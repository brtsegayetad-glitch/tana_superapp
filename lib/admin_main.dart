import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'admin_dashboard.dart';
import 'admin_login.dart'; // አዲሱን የሎጊን ገጽ እዚህ አስገብተነዋል

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AdminWebWrapper(),
  ));
}

class AdminWebWrapper extends StatelessWidget {
  const AdminWebWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Firebase ተጠቃሚው ገብቷል ወይስ አልገባም የሚለውን ሁልጊዜ ቼክ ያደርጋል
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ዳታው እስኪመጣ ትንሽ ይጠብቃል
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        // 1. ተጠቃሚው ቀድሞ ሎጊን ካደረገ በቀጥታ ወደ ዳሽቦርድ ይወስደዋል
        if (snapshot.hasData) {
          return const AdminDashboardPage();
        }
        
        // 2. ካልገባ ግን አዲሱን AdminLoginPage ያሳየዋል
        return const AdminLoginPage(); 
      },
    );
  }
}