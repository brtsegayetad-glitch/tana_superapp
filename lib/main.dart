import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// ገጾቹን እዚህ ጋር እናስገባለን
import 'registration_page.dart';
import 'bajaj_passenger_page.dart';
import 'bajaj_driver_page.dart';
// ማሳሰቢያ፡ 'admin_panel_page.dart' እዚህ አያስፈልገንም ምክንያቱም አድሚን በዌብ ነው የሚገባው

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TanaSuperApp());
}

class TanaSuperApp extends StatelessWidget {
  const TanaSuperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tana SuperApp',
      theme: ThemeData(
        primaryColor: Colors.teal,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const AuthPage(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          return RoleBasedRedirect(userId: snapshot.data!.uid);
        }

        return const AuthPage();
      },
    );
  }
}

class RoleBasedRedirect extends StatelessWidget {
  final String userId;
  const RoleBasedRedirect({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (userSnapshot.hasError || !userSnapshot.data!.exists) {
          return const AuthPage();
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final role = (userData['role'] ?? 'passenger').toString().toLowerCase();

        switch (role) {
          case 'driver':
            return const BajajDriverPage();

          case 'manager':
          case 'superadmin':
            // ማናጀሮች እና አድሚኖች በስልክ አፑ (App) እንዳይገቡ የሚከለክል ገጽ
            return Scaffold(
              backgroundColor: Colors.grey[100],
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.admin_panel_settings,
                          size: 100, color: Colors.teal),
                      const SizedBox(height: 20),
                      const Text(
                        "ይህ የሞባይል አፕ ለሾፌሮች እና ለተሳፋሪዎች ብቻ ነው።",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "እባክዎ የአስተዳደር ስራዎችን ለመስራት (በባህር ዳር ጸጥታና ቁጥጥር) በስልክዎ ወይም በኮምፒውተርዎ ብሮውዘር (Chrome) ዳሽቦርዱን ይጠቀሙ።",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 30),
                      // የዌብሳይቱ ሊንክ ለአድሚኖች እንዲታይ
                      const SelectableText(
                        "https://tana-superapp-bd.web.app",
                        style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text("ውጣ (Logout)"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );

          case 'passenger':
          default:
            return const BajajPassengerPage();
        }
      },
    );
  }
}
