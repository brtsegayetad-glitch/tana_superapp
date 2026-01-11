import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorRegistrationPage extends StatefulWidget {
  const VendorRegistrationPage({super.key});

  @override
  State<VendorRegistrationPage> createState() => _VendorRegistrationPageState();
}

class _VendorRegistrationPageState extends State<VendorRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for Shop details
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _shopAddressController = TextEditingController();
  final TextEditingController _businessTypeController = TextEditingController();

  bool _isSaving = false;

  Future<void> _upgradeToVendor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    String uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // 1. UPDATE the existing user document (don't overwrite it!)
      // This keeps their Passenger/Driver data safe.
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isVendor': true,
        'shopName': _shopNameController.text.trim(),
        'shopAddress': _shopAddressController.text.trim(),
        'businessType': _businessTypeController.text.trim(),
        'vendorStatus': 'pending', // Admin can approve later
        'vendorJoinedAt': FieldValue.serverTimestamp(),
      });

      // 2. Optional: Create a separate 'shops' collection for easier searching in the market
      await FirebaseFirestore.instance.collection('shops').doc(uid).set({
        'ownerUid': uid,
        'shopName': _shopNameController.text.trim(),
        'address': _shopAddressController.text.trim(),
        'type': _businessTypeController.text.trim(),
        'rating': 5.0,
        'isOpen': true,
      });

      if (!mounted) return;

      // Show success and go back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Congratulations! You are now a Hullugebeya Vendor.")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error upgrading: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vendor Registration"),
        backgroundColor: Colors.orange[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Open your Shop in Bahir Dar",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Fill in your shop details to start selling on the marketplace.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Shop Name
              TextFormField(
                controller: _shopNameController,
                decoration: const InputDecoration(
                  labelText: "Shop Name (e.g., Tana Electronics)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
                validator: (val) =>
                    val!.isEmpty ? "Enter your shop name" : null,
              ),
              const SizedBox(height: 20),

              // Shop Address
              TextFormField(
                controller: _shopAddressController,
                decoration: const InputDecoration(
                  labelText: "Physical Address (e.g., Near Kebele 04)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (val) => val!.isEmpty ? "Enter shop address" : null,
              ),
              const SizedBox(height: 20),

              // Business Type
              TextFormField(
                controller: _businessTypeController,
                decoration: const InputDecoration(
                  labelText: "What do you sell? (e.g., Clothes, Food)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                validator: (val) => val!.isEmpty ? "Enter business type" : null,
              ),
              const SizedBox(height: 40),

              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _upgradeToVendor,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        "START SELLING",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
