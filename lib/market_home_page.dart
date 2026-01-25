import 'package:flutter/material.dart';

class TanaMarketPage extends StatelessWidget {
  const TanaMarketPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 80, color: Colors.teal),
            SizedBox(height: 20),
            Text(
              "ጣና ገበያ (Hullugebeya)",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            Text("Online Marketplace Coming Soon"),
          ],
        ),
      ),
    );
  }
}
