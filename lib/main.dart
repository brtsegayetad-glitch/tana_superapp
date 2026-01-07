// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Your Actual App Pages
import 'driver_route_page.dart';
import 'market_home_page.dart';
import 'bajaj_passenger_page.dart';
import 'bajaj_driver_page.dart';
import 'registration_page.dart';
import 'admin_panel.dart'; // Import your unified admin panel here

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Logic to decide: Login Screen or Home Screen?
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          // IF LOGGED IN
          if (snapshot.hasData) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(snapshot.data!.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }

                // If document doesn't exist, they need to register
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const RegistrationPage();
                }

                return const HomeScreen();
              },
            );
          }

          // IF NOT LOGGED IN
          return const AuthScreen();
        },
      ),
    );
  }
}

// --- AUTHENTICATION SCREEN ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _handleAuth() async {
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.water_drop, size: 80, color: Colors.teal),
              Text(
                isLogin ? "TANA LOGIN" : "TANA SIGNUP",
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                    labelText: "Email", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                    labelText: "Password", border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _handleAuth,
                child: Text(isLogin ? "LOGIN" : "CREATE ACCOUNT",
                    style: const TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(isLogin
                    ? "Don't have an account? Sign Up"
                    : "Back to Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MAIN HOME SCREEN (WITH ROLE LOGIC) ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        String role = userData['role'] ?? 'Passenger';

        // 1. Pages for everyone
        List<Widget> pages = [
          const TanaMarketPage(),
          const BajajPassengerPage()
        ];
        List<BottomNavigationBarItem> navItems = [
          const BottomNavigationBarItem(
              icon: Icon(Icons.store), label: 'Market'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.local_taxi), label: 'Ride'),
        ];

        // 2. Additional pages for Drivers only
        if (role == 'Driver') {
          pages.add(const DriverRoutePage());
          pages.add(const BajajDriverPage());
          navItems.add(const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Pay'));
          navItems.add(const BottomNavigationBarItem(
              icon: Icon(Icons.drive_eta), label: 'Driver'));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(role == 'Driver' ? "Tana Driver Mode" : "Tana SuperApp",
                style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.teal,
            actions: [
              // --- SECRET ADMIN BUTTON ---
              // Replace 'your-email@gmail.com' with your actual email
              if (user?.email == "your-email@gmail.com")
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings,
                      color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminPanelPage()),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async => await FirebaseAuth.instance.signOut(),
              ),
            ],
          ),
          body: pages[_selectedIndex >= pages.length ? 0 : _selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex:
                _selectedIndex >= navItems.length ? 0 : _selectedIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.teal,
            unselectedItemColor: Colors.grey,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: navItems,
          ),
        );
      },
    );
  }
}
