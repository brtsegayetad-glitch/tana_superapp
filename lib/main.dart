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
import 'registration_page.dart'; // This file contains your AuthPage class
import 'admin_panel.dart';

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
      // Logic to decide: Auth Screen or Home Screen?
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

                // If user document doesn't exist in Firestore, send to Registration/AuthPage
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const AuthPage();
                }

                return const HomeScreen();
              },
            );
          }

          // IF NOT LOGGED IN
          return const AuthPage();
        },
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

  // Professional Logout Function
  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    // The StreamBuilder in TanaSuperApp will automatically see the logout
    // and show the AuthPage, so we don't need manual navigation here.
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const AuthPage();
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        String role = userData['role'] ?? 'Passenger';
        String name = userData['fullName'] ?? 'User';

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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style:
                        const TextStyle(fontSize: 14, color: Colors.white70)),
                Text(role == 'Driver' ? "Driver Mode" : "Hullugebeya",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
            backgroundColor: Colors.teal,
            actions: [
              // ADMIN BUTTON: Replace with your actual phone-email
              if (user?.email == "0912345678@hullu.com")
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
                onPressed: _handleLogout,
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
