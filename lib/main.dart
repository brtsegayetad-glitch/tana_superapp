// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// ገጾች
import 'driver_route_page.dart';
import 'market_home_page.dart';
import 'bajaj_passenger_page.dart';
import 'bajaj_driver_page.dart';
import 'registration_page.dart';
import 'admin_panel_page.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // --- እዚህ ጋር ነው Logout ሲያደርጉ የሚሄዱበትን የምንመዘግበው ---
      routes: {
        '/login': (context) => const AuthPage(),
        '/home': (context) => const HomeScreen(),
        '/admin': (context) => const AdminPanelPage(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

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
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const AuthPage();
                }

                var data = userSnapshot.data!.data() as Map<String, dynamic>;
                String role = (data['role'] ?? '').toString().toLowerCase();
                String phone = data['phoneNumber'] ?? '';

                // ማኔጀር ወይም አድሚን ከሆኑ ወደ Admin Panel
                if (role == 'superadmin' ||
                    role == 'manager' ||
                    phone == "0971732729") {
                  return const AdminPanelPage();
                }

                return const HomeScreen();
              },
            );
          }
          return const AuthPage();
        },
      ),
    );
  }
}

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        var userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        String role =
            (userData['role'] ?? 'passenger').toString().toLowerCase();
        String name = userData['fullName'] ?? 'User';

        List<Widget> pages = [];
        List<BottomNavigationBarItem> navItems = [];

        // 1. Ride (ለሁሉም)
        pages.add(const BajajPassengerPage());
        navItems.add(const BottomNavigationBarItem(
            icon: Icon(Icons.map), label: 'Ride'));

        // 2 & 3. Driver & Route (ለሾፌር ብቻ)
        if (role == 'driver') {
          pages.add(const BajajDriverPage());
          navItems.add(const BottomNavigationBarItem(
              icon: Icon(Icons.electric_rickshaw), label: 'Driver'));

          pages.add(const DriverRoutePage());
          navItems.add(const BottomNavigationBarItem(
              icon: Icon(Icons.payments), label: 'Route Pay'));
        }

        // 4. Market (ለሁሉም)
        pages.add(const TanaMarketPage());
        navItems.add(const BottomNavigationBarItem(
            icon: Icon(Icons.storefront), label: 'Market'));

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.teal[800],
            foregroundColor: Colors.white,
            title: Text(name, style: const TextStyle(fontSize: 18)),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  // Logout ሲያደርግ በቀጥታ ወደ AuthPage (Login) ይመለሳል
                },
              ),
            ],
          ),
          body: pages[_selectedIndex >= pages.length ? 0 : _selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex:
                _selectedIndex >= navItems.length ? 0 : _selectedIndex,
            type: BottomNavigationBarType.fixed,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: navItems,
          ),
        );
      },
    );
  }
}
