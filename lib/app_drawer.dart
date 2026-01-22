import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          // የሜኑው የላይኛው ክፍል (Header)
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.teal[800]),
            accountName: const Text("Hullugebeya SuperApp"),
            accountEmail: Text(userPhone ?? "No Phone Number"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 50, color: Colors.teal),
            ),
          ),

          // የሜኑ ዝርዝሮች
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
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
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text("Logout"),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacementNamed('/login');
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

  // --- 1. ስለ እኛ (About Us) መረጃ ---
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: "Hullugebeya (ሁሉገበያ)",
      applicationVersion: "1.0.0",
      applicationIcon:
          const Icon(Icons.local_taxi, color: Colors.teal, size: 50),
      children: [
        const Text(
          "ሁሉገበያ በባህር ዳር ከተማ የሚሰሩ የባጃጅ ትራንስፖርት እና የገበያ አገልግሎቶችን በአንድ ላይ የያዘ መተግበሪያ ነው። "
          "አላማችን የከተማዋን ነዋሪዎች ዘመናዊና ቀልጣፋ የዲጂታል አገልግሎት ተጠቃሚ ማድረግ ነው።",
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  // --- 2. እኛን ለማግኘት (Contact Us) መረጃ ---
  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Contact Us"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("ለማንኛውም ቅሬታ ወይም ጥያቄ እኛን ያግኙን፡"),
            const SizedBox(height: 15),
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text("8000 (Call Center)"),
              onTap: () => _launchPhone("8000"),
            ),
            const ListTile(
              leading: Icon(Icons.location_on, color: Colors.red),
              title: Text("ባህር ዳር - ጣና ህንፃ"),
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

  // --- 3. የግል መረጃ ጥበቃ (Privacy Policy) ---
  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Privacy Policy"),
        content: const SingleChildScrollView(
          child: Text(
            "1. መተግበሪያው የእርስዎን ስልክ ቁጥር እና ስም ለምዝገባ አገልግሎት ብቻ ይጠቀማል።\n\n"
            "2. የባጃጅ አገልግሎት ሲጠቀሙ የቆሙበትን ቦታ (GPS) ለሹፌሩ እና ለደህንነት ሲባል ለሲስተሙ እናሳውቃለን።\n\n"
            "3. የእርስዎን መረጃ ለሶስተኛ ወገን አናሳልፍም ወይም አንሸጥም።\n\n"
            "4. አፑን ሲጠቀሙ መረጃዎ በFirebase Cloud ላይ በከፍተኛ ጥበቃ ይቀመጣል።",
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ተስማምቻለሁ"))
        ],
      ),
    );
  }
}
