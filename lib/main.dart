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

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
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

        var userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        String role = userData['role'] ?? 'Passenger';
        String name = userData['fullName'] ?? 'User';
        String myPhone = userData['phoneNumber'] ?? '';

        // --- THE UPDATED ORDER OF PAGES ---
        // 1. Ride (Passenger Map)
        // 2. Driver (Bajaj Mode - Only for Drivers)
        // 3. Route Pay (Permits - Only for Drivers)
        // 4. Market (Hullugebeya)

        List<Widget> pages = [];
        List<BottomNavigationBarItem> navItems = [];

        // 1. Ride (Always First)
        pages.add(const BajajPassengerPage());
        navItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.map_outlined),
          activeIcon: Icon(Icons.map),
          label: 'Ride',
        ));

        // 2 & 3. Driver and Route (Only show if role is Driver)
        if (role == 'Driver') {
          pages.add(const BajajDriverPage());
          navItems.add(const BottomNavigationBarItem(
            icon: Icon(Icons.electric_rickshaw_outlined), // Bajaj Icon
            activeIcon: Icon(Icons.electric_rickshaw),
            label: 'Driver',
          ));

          pages.add(const DriverRoutePage());
          navItems.add(const BottomNavigationBarItem(
            icon: Icon(Icons.payments_outlined),
            activeIcon: Icon(Icons.payments),
            label: 'Route Pay',
          ));
        }

        // 4. Market (Always Last)
        pages.add(const TanaMarketPage());
        navItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.storefront_outlined),
          activeIcon: Icon(Icons.storefront),
          label: 'Market',
        ));

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.teal[800],
            foregroundColor: Colors.white,
            title: GestureDetector(
              onLongPress: () {
                // Ensure phone matches your admin number
                if (myPhone == "0923456789") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AdminPanelPage()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Admin Portal Locked")),
                  );
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                  const Text("Tana SuperApp",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _handleLogout,
              ),
            ],
          ),
          body: pages[_selectedIndex >= pages.length ? 0 : _selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex:
                _selectedIndex >= navItems.length ? 0 : _selectedIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.teal[800],
            unselectedItemColor: Colors.blueGrey,
            backgroundColor: Colors.white,
            elevation: 10,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            items: navItems,
          ),
        );
      },
    );
  }
}
