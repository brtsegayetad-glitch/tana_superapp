import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Import all the pages we have created
import 'registration_page.dart'; // This file contains the AuthPage class
import 'bajaj_passenger_page.dart';
import 'bajaj_driver_page.dart';
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
      title: 'Hullugebeya SuperApp',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        // Define a consistent color scheme
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      // Define a route for login to handle logout navigation seamlessly
      routes: {
        // Corrected: Using AuthPage instead of RegistrationPage
        '/login': (context) => const AuthPage(),
      },
      home: const AuthWrapper(),
    );
  }
}

// This widget is the main entry point after the app starts.
// It checks if a user is logged in and directs them accordingly.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading spinner while checking the authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If a user is logged in, find their role and redirect them
        if (snapshot.hasData) {
          return RoleBasedRedirect(userId: snapshot.data!.uid);
        }

        // If no user is logged in, show the registration/login page
        // Corrected: Using AuthPage instead of RegistrationPage
        return const AuthPage();
      },
    );
  }
}

// This widget takes a user's ID, fetches their data from Firestore,
// and redirects them to the correct home screen based on their role.
class RoleBasedRedirect extends StatelessWidget {
  final String userId;
  const RoleBasedRedirect({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        // Show a loading spinner while fetching the user's document
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If the user's document doesn't exist (e.g., they didn't finish registration),
        // send them back to the registration page.
        if (userSnapshot.hasError || !userSnapshot.data!.exists) {
          // Corrected: Using AuthPage instead of RegistrationPage
          return const AuthPage();
        }

        // If the document exists, get the role
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final role = (userData['role'] ?? 'passenger').toString().toLowerCase();

        // Redirect to the appropriate screen based on the role
        switch (role) {
          case 'driver':
            // Drivers go to their full-featured dashboard
            return const BajajDriverPage();
          case 'manager':
          case 'superadmin':
            // Admins and managers go to the admin panel
            return const AdminPanelPage();
          case 'passenger':
          default:
            // Passengers and any other roles default to the passenger map view
            return const BajajPassengerPage();
        }
      },
    );
  }
}
