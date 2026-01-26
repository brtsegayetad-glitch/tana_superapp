import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert'; // ለ jsonDecode አስፈላጊ ነው
import 'package:http/http.dart' as http; // ለ ImgBB አስፈላጊ ነው
import 'app_drawer.dart';

final Map<String, Map<String, String>> localizedText = {
  'en': {
    'title': 'Route Payment',
    'step1': 'STEP 1: PAY ASSOCIATION DIRECTLY',
    'pay_to': 'Pay via Telebirr:',
    'bank_details': 'Bank Transfer Details',
    'copy_hint': 'Tap to copy account info',
    'step2': 'STEP 2: SUBMIT RECEIPT INFO',
    'pick_img': 'TAKE PHOTO / UPLOAD RECEIPT',
    'amount': 'Amount Sent (Birr)',
    'txid': 'Reference / Transaction ID',
    'submit': 'SUBMIT FOR APPROVAL',
    'permit': 'PERMIT ACTIVE',
    'pay_req': 'PAYMENT REQUIRED',
    'due': 'Total Due',
    'pay_btn': 'PAY NOW (TELEBIRR)',
    'receipt_btn': 'SHOW TRAFFIC PERMIT',
    'receipt_header': 'HULLUGEBEYA - DIGITAL PERMIT',
    'receipt_verified': 'SERVICE ACCESS VERIFIED',
    'receipt_name': 'Driver Name:',
    'receipt_plate': 'Plate Number:',
    'receipt_nid': 'National ID:',
    'receipt_status': 'Status:',
    'receipt_active': 'ACTIVE ✅',
    'close': 'CLOSE',
  },
  'am': {
    'title': 'የመንገድ ክፍያ',
    'step1': 'ደረጃ 1፡ ለማህበሩ በቀጥታ ይክፈሉ',
    'pay_to': 'በቴሌብር ይክፈሉ፡',
    'bank_details': 'የባንክ መረጃ',
    'copy_hint': 'ቁጥሩን ኮፒ ለማድረግ ይንኩት',
    'step2': 'ደረጃ 2፡ የደረሰኝ ፎቶ ያያይዙ',
    'pick_img': 'የደረሰኙን ፎቶ አንሳ ወይም ስክሪንሾት መረጥ',
    'amount': 'የተላከው ብር (በብር)',
    'txid': 'የማረጋገጫ ቁጥር (Reference / TXID)',
    'submit': 'ለማረጋገጥ ይላኩ',
    'permit': 'ፈቃድ ገቢ ሆኗል',
    'pay_req': 'ክፍያ ይጠበቅብዎታል',
    'due': 'ጠቅላላ ዕዳ',
    'pay_btn': 'አሁኑኑ ይክፈሉ (ቴሌብር)',
    'receipt_btn': 'የመንገድ ፈቃድ አሳይ',
    'receipt_header': 'ሁሉገበያ - ዲጂታል ፈቃድ',
    'receipt_verified': 'የአገልግሎት ፈቃድ ተረጋግጧል',
    'receipt_name': 'የአሽከርካሪ ስም፡',
    'receipt_plate': 'የሰሌዳ ቁጥር፡',
    'receipt_nid': 'ብሔራዊ መታወቂያ፡',
    'receipt_status': 'ሁኔታ፡',
    'receipt_active': 'ተከፍሏል ✅',
    'close': 'ዝጋ',
  }
};

class DriverRoutePage extends StatefulWidget {
  const DriverRoutePage({super.key});

  @override
  State<DriverRoutePage> createState() => _DriverRoutePageState();
}

class _DriverRoutePageState extends State<DriverRoutePage> {
  String lang = 'am';
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  bool isRoutePaid = false;
  String bajajName = "Loading...";
  String plateNumber = "---";
  String nationalId = "---";
  String associationId = "";
  bool isLoading = true;
  Timestamp? lastPaymentDate;

  String assocMerchantId = "";
  String assocBankInfo = "Loading bank details...";

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transactionController = TextEditingController();

  final double baseFee = 50.0;
  final double penaltyRate = 0.10;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      var doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          isRoutePaid = data['isRoutePaid'] ?? false;
          bajajName = data['fullName'] ?? "Unnamed Bajaj";
          plateNumber = data['plateNumber'] ?? "---";
          nationalId = data['idNumber'] ??
              "---"; // 'nationalId' ወደ 'idNumber' ተቀይሯል (registration page ላይ እንዳለው)
          associationId = data['associationId'] ?? 'tana_assoc';
          lastPaymentDate = data['lastPaymentDate'] as Timestamp?;
        });

        var assocDoc = await FirebaseFirestore.instance
            .collection('associations')
            .doc(associationId)
            .get();
        if (assocDoc.exists && mounted) {
          setState(() {
            assocMerchantId = assocDoc.data()?['telebirrId'] ?? "000000";
            assocBankInfo =
                assocDoc.data()?['bankInfo'] ?? "No bank info listed.";
          });
        }
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  double calculateTotalDue() {
    if (isRoutePaid) return 0.0;
    if (lastPaymentDate == null) return baseFee;
    DateTime lastPay = lastPaymentDate!.toDate();
    DateTime now = DateTime.now();
    int daysSinceLastPay = now.difference(lastPay).inDays;
    if (daysSinceLastPay <= 7) return baseFee;
    int missedWeeks = (daysSinceLastPay / 7).floor();
    return (missedWeeks * baseFee) +
        (daysSinceLastPay * (baseFee * penaltyRate));
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Receipt Source"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Text("Camera (ካሜራ)")),
          TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Text("Gallery / Screenshot (ጋለሪ)")),
        ],
      ),
    );

    if (source != null) {
      final XFile? pickedFile =
          await _picker.pickImage(source: source, imageQuality: 50);
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    }
  }

  Future<void> submitDepositRequest() async {
    if (_amountController.text.isEmpty ||
        _transactionController.text.isEmpty ||
        _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("እባክዎ ሁሉንም መረጃ ይሙሉ እና ፎቶ ይምረጡ!")));
      return;
    }
    setState(() => isLoading = true);
    try {
      // 1. ፎቶውን ወደ ImgBB መላክ
      String apiKey = "858ef05f1ba7c5262fbb85ea9894c83f";
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey'),
      );
      request.files
          .add(await http.MultipartFile.fromPath('image', _imageFile!.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var json = jsonDecode(responseData);

      if (json['data'] == null) throw Exception("ImgBB Upload Failed");
      String imageUrl = json['data']['url'];

      // 2. መረጃውን Firestore ውስጥ ማስቀመጥ
      await FirebaseFirestore.instance.collection('deposit_requests').add({
        'uid': uid,
        'driverName': bajajName,
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'transactionId': _transactionController.text.trim(),
        'associationId': associationId,
        'status': 'pending',
        'imageUrl': imageUrl,
        'paymentMethod': 'Digital',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _amountController.clear();
      _transactionController.clear();
      setState(() {
        _imageFile = null;
        isLoading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("ለማረጋገጫ ተልኳል!")));
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print("Error: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("ስህተት ተከስቷል: $e")));
    }
  }

  Future<void> _launchTelebirr() async {
    double total = calculateTotalDue();

    if (assocMerchantId == "000000" || assocMerchantId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("የማህበሩ ስልክ ቁጥር አልተገኘም")));
      return;
    }

    // ቁጥሩን ለሾፌሩ አስቀድመን ኮፒ እናደርጋለን (ለማንኛውም ቢፈለግ)
    await Clipboard.setData(ClipboardData(text: assocMerchantId));

    // 1. መደበኛ ሙከራ (Regular App)
    final Uri teleUri = Uri.parse("telebirr://");
    // 2. ሱፐር አፕ ሙከራ (SuperApp)
    final Uri superAppUri = Uri.parse("superapp://");

    try {
      // መጀመሪያ ሱፐር አፑን ለመክፈት መሞከር
      bool launched =
          await launchUrl(superAppUri, mode: LaunchMode.externalApplication);

      if (!launched) {
        // ካልሆነ መደበኛውን ቴሌብር መሞከር
        launched =
            await launchUrl(teleUri, mode: LaunchMode.externalApplication);
      }

      if (launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "ቴሌብር ተከፍቷል። ወደ $assocMerchantId ብር $total ይላኩ (ቁጥሩ ኮፒ ተደርጓል)"),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      } else {
        throw "Could not launch";
      }
    } catch (e) {
      // 3. አፑ ጭራሽ ካልተገኘ (Play Store እንዲከፍት ማድረግ)
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("ቴሌብር አልተገኘም"),
            content: Text(
                "የቴሌብር አፕሊኬሽን አልተከፈተም። እባክዎ በስልክዎ ወደ $assocMerchantId ብር $total ይላኩ።"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("እሺ"),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    double totalToPay = calculateTotalDue();

    return Scaffold(
      drawer: AppDrawer(
          userPhone: FirebaseAuth.instance.currentUser?.phoneNumber ?? ""),
      appBar: AppBar(
        title: Text(localizedText[lang]!['title']!),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () =>
                setState(() => lang = (lang == 'en' ? 'am' : 'en')),
            child: Text(lang == 'en' ? "አማርኛ" : "English",
                style: const TextStyle(color: Colors.yellow)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    Text(localizedText[lang]!['step1']!,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _launchTelebirr,
                      icon: const Icon(Icons.account_balance_wallet),
                      label: Text(localizedText[lang]!['pay_btn']!),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50)),
                    ),
                    const Divider(height: 30),
                    Text(localizedText[lang]!['bank_details']!,
                        style: const TextStyle(fontSize: 12)),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: assocBankInfo));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Copied!")));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200)),
                        child: Column(children: [
                          Text(assocBankInfo,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(localizedText[lang]!['copy_hint']!,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.blue)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(localizedText[lang]!['step2']!,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.teal.shade200)),
                        child: _imageFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    const Icon(Icons.camera_enhance,
                                        size: 40, color: Colors.teal),
                                    Text(localizedText[lang]!['pick_img']!,
                                        style: const TextStyle(fontSize: 12))
                                  ])
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child:
                                    Image.file(_imageFile!, fit: BoxFit.cover)),
                      ),
                    ),
                    TextField(
                        controller: _amountController,
                        decoration: InputDecoration(
                            labelText: localizedText[lang]!['amount']),
                        keyboardType: TextInputType.number),
                    TextField(
                        controller: _transactionController,
                        decoration: InputDecoration(
                            labelText: localizedText[lang]!['txid'])),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: submitDepositRequest,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 45),
                          backgroundColor: Colors.teal),
                      child: Text(localizedText[lang]!['submit']!,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color:
                      isRoutePaid ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: isRoutePaid ? Colors.green : Colors.red)),
              child: Column(children: [
                Text(
                    isRoutePaid
                        ? localizedText[lang]!['permit']!
                        : localizedText[lang]!['pay_req']!,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            isRoutePaid ? Colors.green[800] : Colors.red[800])),
                if (!isRoutePaid)
                  Text("${localizedText[lang]!['due']}: $totalToPay ETB",
                      style: const TextStyle(fontSize: 18, color: Colors.red)),
              ]),
            ),
            if (isRoutePaid)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: OutlinedButton.icon(
                  onPressed: () => _showTrafficReceipt(context),
                  icon: const Icon(Icons.verified_user),
                  label: Text(localizedText[lang]!['receipt_btn']!),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTrafficReceipt(BuildContext context) {
    String qrData =
        "HULLUGEBEYA PERMIT\nDriver: $bajajName\nPlate: $plateNumber\nStatus: VERIFIED ✅";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(25),
        child: Column(children: [
          const Icon(Icons.check_circle, color: Colors.teal, size: 80),
          Text(localizedText[lang]!['receipt_header']!,
              style: const TextStyle(
                  color: Colors.teal, fontWeight: FontWeight.bold)),
          const Divider(height: 40),
          _receiptRow(localizedText[lang]!['receipt_name']!, bajajName),
          _receiptRow(localizedText[lang]!['receipt_plate']!, plateNumber),
          _receiptRow(localizedText[lang]!['receipt_nid']!, nationalId),
          _receiptRow(localizedText[lang]!['receipt_status']!,
              localizedText[lang]!['receipt_active']!),
          const Spacer(),
          QrImageView(data: qrData, version: QrVersions.auto, size: 180.0),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizedText[lang]!['close']!)),
        ]),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
      ]),
    );
  }
}
