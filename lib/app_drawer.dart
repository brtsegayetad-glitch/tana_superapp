import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDrawer extends StatelessWidget {
  final String? userPhone;
  const AppDrawer({super.key, this.userPhone});

  // ስልክ ለመደወል የሚያገለግል ፈንክሽን
  Future<void> _launchPhone(String number) async {
    final Uri url = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // 1. የሜኑው የላይኛው ክፍል (Header)
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.teal[800]),
            accountName: const Text("Hullugebeya SuperApp"),
            accountEmail: Text(userPhone ?? "No Phone Number"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 50, color: Colors.teal),
            ),
          ),

          // 2. የሜኑ ዝርዝሮች
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 🛒 ወደ ገበያው መሸጋገሪያ (ለወደፊቱ የምንጨምረው)
                ListTile(
                  leading: const Icon(Icons.storefront, color: Colors.orange),
                  title: const Text("Hullugebeya Market (Vendor)"),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("የሻጭ ገጽ በቅርቡ ይከፈታል...")),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.teal),
                  title: const Text("About Us (ስለ እኛ)"),
                  onTap: () => _showAboutDialog(context),
                ),
                ListTile(
                  leading: const Icon(Icons.contact_support_outlined,
                      color: Colors.teal),
                  title: const Text("Contact Us (እኛን ለማግኘት)"),
                  onTap: () => _showContactDialog(context),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: Colors.teal),
                  title: const Text("Privacy Policy (የግል መረጃ ጥበቃ)"),
                  onTap: () => _showPrivacyDialog(context),
                ),

                const Divider(),

                // 🚪 የ Logout ክፍል (የተስተካከለ)
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title:
                      const Text("Logout", style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    // መጀመሪያ ሾፌሩን Offline እናድርገው
                    String? uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      try {
                        await FirebaseFirestore.instance
                            .collection('driver_locations')
                            .doc(uid)
                            .update({'is_online': false});
                      } catch (e) {
                        debugPrint("Offline status update failed: $e");
                      }
                    }

                    // ከዚያ Sign out እናድርግ
                    await FirebaseAuth.instance.signOut();

                    if (!context.mounted) return;

                    // ሁሉንም ገጾች ዘግተን ወደ Login ገጽ እንመለስ
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (route) => false);
                  },
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Version 1.0.0 - Bahir Dar",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          )
        ],
      ),
    );
  }

  // --- 🏮 የ Dialog ኮዶች (About, Contact, Privacy) ---
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: "Hullugebeya (ሁሉገበያ)",
      applicationVersion: "1.0.0",
      applicationIcon:
          const Icon(Icons.local_taxi, color: Colors.teal, size: 50),
      children: [
        const Text(
            "ሁሉገበያ በባህር ዳር ከተማ የሚሰሩ የባጃጅ ትራንስፖርት እና የገበያ አገልግሎቶችን በአንድ ላይ የያዘ መተግበሪያ ነው።"),
      ],
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Contact Us"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text("8000 (Call Center)"),
              onTap: () => _launchPhone("8000"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("ዝጋ"))
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Privacy Policy"),
        content: const Text(
            "መተግበሪያው የእርስዎን ስልክ ቁጥር እና ቦታ ለደህንነት እና ለአገልግሎት ጥራት ሲባል ብቻ ይጠቀማል።"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ተስማምቻለሁ"))
        ],
      ),
    );
  }
}
