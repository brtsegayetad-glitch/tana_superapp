import 'package:latlong2/latlong.dart';

class BahirDarLocation {
  final String name;
  final String nameAmh;
  final LatLng coordinates;
  final String category;

  BahirDarLocation({
    required this.name,
    required this.nameAmh,
    required this.coordinates,
    required this.category,
  });
}

final List<BahirDarLocation> masterDirectory = [
  // --- ELEMENTARY & PRIMARY SCHOOLS ---
  BahirDarLocation(
      name: " Rispins Int School",
      nameAmh: "ሪስፔንስ ት/ቤት",
      coordinates: LatLng(11.580517, 37.369520),
      category: "School"),
  BahirDarLocation(
      name: "SOS Hermann Children School",
      nameAmh: "ኤስ ኦ ኤስ ሄርማን ልጆች ት/ቤት",
      coordinates: LatLng(11.608756, 37.364437),
      category: "School"),
  BahirDarLocation(
      name: "megabit 28 primary School",
      nameAmh: "መጋቢት 28 የመጀ/ደ ት/ቤት",
      coordinates: LatLng(11.595058, 37.379462),
      category: "School"),
  BahirDarLocation(
      name: "Geneme Library",
      nameAmh: "ገነሜ ቤተ መጻህፍት",
      coordinates: LatLng(11.593658, 37.379478),
      category: "School"),
  BahirDarLocation(
      name: "Bahir Dar Academy",
      nameAmh: "ባሕር ዳር አካዳሚ",
      coordinates: LatLng(11.594077, 37.369297),
      category: "School"),

  // --- SECONDARY & PREPARATORY ---
  BahirDarLocation(
      name: "Tana Haik Secondary",
      nameAmh: "ጣና ሐይቅ መሰናዶ ት/ቤት",
      coordinates: LatLng(11.600638, 37.370379),
      category: "High School"),
  BahirDarLocation(
      name: "Fasilo Secondary School",
      nameAmh: "ፋሲሎ ሁለተኛ ደረጃ ት/ቤት",
      coordinates: LatLng(11.593030, 37.379202),
      category: "High School"),
  BahirDarLocation(
      name: "Zehmar Restaurant",
      nameAmh: "ዝማር ሬስቶራንት",
      coordinates: LatLng(11.591427, 37.380022),
      category: "High School"),

  // --- UNIVERSITIES & COLLEGES ---
  BahirDarLocation(
      name: "BDU - Peda Campus",
      nameAmh: "ባሕር ዳር ዩኒቨርሲቲ (ፔዳ)",
      coordinates: LatLng(11.576301, 37.395239),
      category: "University"),
  BahirDarLocation(
      name: "BDU - Poly Campus",
      nameAmh: "ባሕር ዳር ዩኒቨርሲቲ (ፖሊ)",
      coordinates: LatLng(11.597529, 37.396134),
      category: "University"),
  BahirDarLocation(
      name: "Wisdom Tower (BDU Admin)",
      nameAmh: "ዊዝደም ታወር (ባዳዩ አስተዳደር)",
      coordinates: LatLng(11.587384, 37.395661),
      category: "University"),
  BahirDarLocation(
      name: "Bahir Dar Health Science College",
      nameAmh: "ባሕር ዳር ጤና ሳይንስ ኮሌጅ",
      coordinates: LatLng(11.5785, 37.3920),
      category: "College"),
  BahirDarLocation(
      name: "EiTEX (Textile Institute)",
      nameAmh: "ኢትዮጵያ ጨርቃጨርቅና ፋሽን ቴክኖሎጂ",
      coordinates: LatLng(11.5855, 37.4060),
      category: "University"),

// --- CHURCHES & RELIGIOUS SITES ---
  BahirDarLocation(
      name: "St. George Church",
      nameAmh: "ቅዱስ ጊዮርጊስ ቤተክርስቲያን",
      coordinates: LatLng(11.595742, 37.389218),
      category: "Church"),
  BahirDarLocation(
      name: "Abune Hara Church",
      nameAmh: "አቡነ ሐራ ቤተክርስቲያን",
      coordinates: LatLng(11.572892, 37.361040),
      category: "Church"),
  BahirDarLocation(
      name: "Medhane Alem Church",
      nameAmh: "መድኃኔዓለም ቤተክርስቲያን",
      coordinates: LatLng(11.584128, 37.346868),
      category: "Church"),
  BahirDarLocation(
      name: "St. Michael Church",
      nameAmh: "ቅዱስ ሚካኤል ቤተክርስቲያን",
      coordinates: LatLng(11.574013, 37.378057),
      category: "Church"),
  BahirDarLocation(
      name: "Kidane Mihret Church",
      nameAmh: "ኪዳነ ምሕረት ቤተክርስቲያን",
      coordinates: LatLng(11.592404, 37.374224),
      category: "Church"),
  BahirDarLocation(
      name: "St. Tekle Haymanot",
      nameAmh: "አቡነ ተክለሃይማኖት ቤተክርስቲያን",
      coordinates: LatLng(11.615066, 37.367481),
      category: "Church"),
  BahirDarLocation(
      name: "Hamere Noah Kidane Mihret",
      nameAmh: "ሐመረ ኖኅ ኪዳነ ምሕረት ትምህርት ቤት ",
      coordinates: LatLng(11.5820, 37.3650),
      category: "Church"),
  BahirDarLocation(
      name: "St. Gabriel Church",
      nameAmh: "ቅዱስ ገብርኤል ቤተክርስቲያን",
      coordinates: LatLng(11.600108, 37.429718),
      category: "Church"),
  BahirDarLocation(
      name: "Kulkual Meda Primary",
      nameAmh: "ኩልኳል ሜዳ መጀ ደረጃ ት/ቤት",
      coordinates: LatLng(11.590708, 37.3616686), // Updated from your photo!
      category: "School"),
];
