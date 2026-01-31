import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RevenueView extends StatefulWidget {
  const RevenueView({super.key});

  @override
  State<RevenueView> createState() => _RevenueViewState();
}

class _RevenueViewState extends State<RevenueView> {
  // 📅 እነዚህ ቀናት ሪፖርቱ ከየት እስከ የት እንደሆነ ይይዛሉ
  // መጀመሪያ ስንከፍተው የዛሬውን ቀን ይይዛሉ
  DateTime _startDate =
      DateTime.now().subtract(const Duration(days: 30)); // ከ30 ቀን በፊት
  DateTime _endDate = DateTime.now();

  // --- 📅 የቀን መምረጫ (Calendar) ---
  Future<void> _pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025), // ፕሮጀክቱ የጀመረበት ዓመት
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // 🔥 ክፍያው ሲፈጸም ዳታውን ከመሰረዝ ይልቅ "ተከፍሏል" ብሎ ምልክት ማድረጊያ
  Future<void> _handleCommissionPayment(
      String assocId, List<DocumentSnapshot> allDocs) async {
    // ለተጠቃሚው ማረጋገጫ መጠየቂያ (Confirm Dialog) ቢጨመርበት ይመረጣል
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in allDocs) {
      // ማሳሰቢያ፡ 'associationId' በካፒታል እና በትንሽ ሌተር መሳሳቱን አረጋግጥ
      if (doc['associationId'] == assocId) {
        batch.update(doc.reference, {
          'status': 'paid', // ሁኔታውን ወደ ተከፈለ መቀየር
          'paidAt': FieldValue.serverTimestamp(), // የተከፈለበትን ሰዓት መመዝገብ
        });
      }
    }

    await batch.commit();

    // ለኦፕሬተሩ መልዕክት ማሳያ
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$assocId ክፍያ በስኬት ተመዝግቧል")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // 🔍 የሪፖርት ማጣሪያ ቁልፍ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            color: Colors.teal[800],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("የሪፖርት ጊዜ",
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      "${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text("ቀን መምረጫ"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      foregroundColor: Colors.white),
                )
              ],
            ),
          ),
          Container(
            color: Colors.teal[50],
            child: const TabBar(
              labelColor: Colors.teal,
              indicatorColor: Colors.teal,
              tabs: [
                Tab(text: "Route (5%)"),
                Tab(text: "Ride (10%)"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRevenueContent('route_permit'),
                _buildRevenueContent('ride_commission'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueContent(String type) {
    return StreamBuilder<QuerySnapshot>(
      // 🔥 እዚህ ጋር ነው ፊልተሩ የሚሰራው!
      // Firestore ውስጥ በቀናት መካከል ያሉትን ብቻ አምጣ እንለዋለን።
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('type', isEqualTo: type)
          .where('status', isEqualTo: 'unpaid') // 🔥 ይህንን መስመር ጨምር!
          .where('timestamp', isGreaterThanOrEqualTo: _startDate)
          .where('timestamp',
              isLessThanOrEqualTo: _endDate.add(const Duration(days: 1)))
          // 🔥 ይህንን መስመር ጨምር - ከኢንዴክሱ ጋር እንዲገጥም ያደርገዋል
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("ስህተት፡ ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        double total = 0;
        Map<String, double> assocTotals = {};
        Map<String, List<DocumentSnapshot>> groupedDocs = {};

        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          double amt = (data['amount'] ?? 0.0).toDouble();
          String assocId = data['associationId'] ?? 'Unknown';

          total += amt;
          assocTotals[assocId] = (assocTotals[assocId] ?? 0.0) + amt;
          groupedDocs.putIfAbsent(assocId, () => []).add(doc);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statCard(
                type == 'route_permit' ? "ጠቅላላ የ5% ድርሻ" : "ጠቅላላ የ10% ገቢ",
                type == 'route_permit' ? total * 0.05 : total,
                type == 'route_permit' ? Colors.teal : Colors.orange[900]!),
            const SizedBox(height: 20),
            if (type == 'route_permit')
              ...assocTotals.entries.map((e) => Card(
                    child: ListTile(
                      title: Text(e.key.toUpperCase()),
                      subtitle: Text(
                          "5% ድርሻ፡ ${(e.value * 0.05).toStringAsFixed(2)} ETB"),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _handleCommissionPayment(
                            e.key, groupedDocs[e.key]!),
                      ),
                    ),
                  )),
            if (type == 'ride_commission')
              const Center(child: Text("በተመረጠው ቀን ውስጥ የተሰበሰበ ኮሚሽን")),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 5),
          Text("${amount.toStringAsFixed(2)} ETB",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
