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
      coordinates: const LatLng(11.580517, 37.369520),
      category: "School"),
  BahirDarLocation(
      name: "SOS Hermann Children School",
      nameAmh: "ኤስ ኦ ኤስ ሄርማን ልጆች ት/ቤት",
      coordinates: const LatLng(11.608756, 37.364437),
      category: "School"),
  BahirDarLocation(
      name: "megabit 28 primary School",
      nameAmh: "መጋቢት 28 የመጀ/ደ ት/ቤት",
      coordinates: const LatLng(11.595058, 37.379462),
      category: "School"),
  BahirDarLocation(
      name: "Geneme Library",
      nameAmh: "ገነሜ ቤተ መጻህፍት",
      coordinates: const LatLng(11.593658, 37.379478),
      category: "School"),
  BahirDarLocation(
      name: "Bahir Dar Academy",
      nameAmh: "ባሕር ዳር አካዳሚ",
      coordinates: const LatLng(11.594077, 37.369297),
      category: "School"),

  // --- SECONDARY & PREPARATORY ---
  BahirDarLocation(
      name: "Tana Haik Secondary",
      nameAmh: "ጣና ሐይቅ መሰናዶ ት/ቤት",
      coordinates: const LatLng(11.600638, 37.370379),
      category: "High School"),
  BahirDarLocation(
      name: "Fasilo Secondary School",
      nameAmh: "ፋሲሎ ሁለተኛ ደረጃ ት/ቤት",
      coordinates: const LatLng(11.593030, 37.379202),
      category: "High School"),
  BahirDarLocation(
      name: "Zehmar Restaurant",
      nameAmh: "ዝማር ሬስቶራንት",
      coordinates: const LatLng(11.591427, 37.380022),
      category: "Restaurant"),

  // --- UNIVERSITIES & COLLEGES ---
  BahirDarLocation(
      name: "BDU - Peda Campus",
      nameAmh: "ባሕር ዳር ዩኒቨርሲቲ (ፔዳ)",
      coordinates: const LatLng(11.576301, 37.395239),
      category: "University"),
  BahirDarLocation(
      name: "BDU - Poly Campus",
      nameAmh: "ባሕር ዳር ዩኒቨርሲቲ (ፖሊ)",
      coordinates: const LatLng(11.597529, 37.396134),
      category: "University"),
  BahirDarLocation(
      name: "Wisdom Tower (BDU Admin)",
      nameAmh: "ዊዝደም ታወር (ባዳዩ አስተዳደር)",
      coordinates: const LatLng(11.587384, 37.395661),
      category: "University"),
  BahirDarLocation(
      name: "Bahir Dar Health Science College",
      nameAmh: "ባሕር ዳር ጤና ሳይንስ ኮሌጅ",
      coordinates: const LatLng(11.5785, 37.3920),
      category: "College"),
  BahirDarLocation(
      name: "EiTEX (Textile Institute)",
      nameAmh: "ኢትዮጵያ ጨርቃጨርቅና ፋሽን ቴክኖሎጂ",
      coordinates: const LatLng(11.5855, 37.4060),
      category: "University"),

// --- CHURCHES & RELIGIOUS SITES ---
  BahirDarLocation(
      name: "St. George Church",
      nameAmh: "ቅዱስ ጊዮርጊስ ቤተክርስቲያን",
      coordinates: const LatLng(11.595742, 37.389218),
      category: "Church"),
  BahirDarLocation(
      name: "Abune Hara Church",
      nameAmh: "አቡነ ሐራ ቤተክርስቲያን",
      coordinates: const LatLng(11.572892, 37.361040),
      category: "Church"),
  BahirDarLocation(
      name: "Medhane Alem Church",
      nameAmh: "መድኃኔዓለም ቤተክርስቲያን",
      coordinates: const LatLng(11.584128, 37.346868),
      category: "Church"),
  BahirDarLocation(
      name: "St. Michael Church",
      nameAmh: "ቅዱስ ሚካኤል ቤተክርስቲያን",
      coordinates: const LatLng(11.574013, 37.378057),
      category: "Church"),
  BahirDarLocation(
      name: "St. Rufael Church",
      nameAmh: "ቅዱስ ሩፋኤል ቤተክርስቲያን",
      coordinates: const LatLng(11.586736, 37.406702),
      category: "Church"),
  BahirDarLocation(
      name: "Kidane Mihret Church",
      nameAmh: "ኪዳነ ምሕረት ቤተክርስቲያን",
      coordinates: const LatLng(11.592404, 37.374224),
      category: "Church"),
  BahirDarLocation(
      name: "St. Tekle Haymanot",
      nameAmh: "አቡነ ተክለሃይማኖት ቤተክርስቲያን",
      coordinates: const LatLng(11.615066, 37.367481),
      category: "Church"),
  BahirDarLocation(
      name: "Hamere Noah Kidane Mihret",
      nameAmh: "ሐመረ ኖኅ ኪዳነ ምሕረት ትምህርት ቤት ",
      coordinates: const LatLng(11.5820, 37.3650),
      category: "School"),
  BahirDarLocation(
      name: "St. Gabriel Church",
      nameAmh: "ቅዱስ ገብርኤል ቤተክርስቲያን",
      coordinates: const LatLng(11.600108, 37.429718),
      category: "Church"),
  BahirDarLocation(
      name: "Kulkual Meda Primary",
      nameAmh: "ኩልኳል ሜዳ መጀ ደረጃ ት/ቤት",
      coordinates:
          const LatLng(11.590708, 37.3616686), // Updated from your photo!
      category: "School"),

// --- HOTELS & PENSIONS ---
  BahirDarLocation(
      name: "Old Airport Pension",
      nameAmh: "አሮጌው አየር ማረፊያ ፔንሲዮን",
      coordinates: const LatLng(11.589842, 37.383207),
      category: "Pension/Hotel"),
  BahirDarLocation(
      name: "Hareg Pension",
      nameAmh: "ሐረግ ፔንሲዮን",
      coordinates: const LatLng(11.594942, 37.383311),
      category: "Pension/Hotel"),
  BahirDarLocation(
      name: "Fidel Hotel",
      nameAmh: "ፊደል ሆቴል",
      coordinates: const LatLng(11.591412, 37.379533),
      category: "Pension/Hotel"),

  BahirDarLocation(
      name: "Kibiyad 15 Apartments",
      nameAmh: "ኪቢያድ 15 አፓርትመንት",
      coordinates: const LatLng(11.589950, 37.380081),
      category: "Apartment/Building"),

// --- CLINICS & HOSPITALS ---
  BahirDarLocation(
      name: "Eyasta Medical Center",
      nameAmh: "እያስታ የሕክምና ማዕከል",
      coordinates: const LatLng(11.585736, 37.376116),
      category: "Clinic"),
  BahirDarLocation(
      name: "Dream Care General Hospital",
      nameAmh: "ድሪም ኬር አጠቃላይ ሆስፒታል",
      coordinates: const LatLng(11.579304, 37.374301),
      category: "Hospital"),
  BahirDarLocation(
      name: "Afilas General Hospital",
      nameAmh: "አፊላስ አጠቃላይ ሆስፒታል",
      coordinates: const LatLng(11.606335, 37.371228),
      category: "Hospital"),
  BahirDarLocation(
      name: "Amaris kids clinic",
      nameAmh: "አማሪስ የልጆች ክሊኒክ",
      coordinates: const LatLng(11.589093, 37.375254),
      category: "Hospital"),
  BahirDarLocation(
      name: "Abay Health Center",
      nameAmh: "አባይ ጤና ጣቢያ",
      coordinates: const LatLng(11.6035, 37.4082),
      category: "Clinic"),

// --- SQUARES & LANDMARKS ---
  BahirDarLocation(
      name: "Noc Square",
      nameAmh: "ኖክ አደባባይ",
      coordinates: const LatLng(11.585440, 37.375013),
      category: "Square"),
  BahirDarLocation(
      name: "Yetebaberut Square",
      nameAmh: "የተባባሩት አደባባይ",
      coordinates: const LatLng(11.585410, 37.367691),
      category: "Square"),
  BahirDarLocation(
      name: "Dipo",
      nameAmh: "ዲፖ",
      coordinates: const LatLng(11.600224, 37.375246),
      category: "Square"),
  BahirDarLocation(
      name: "Papyrus Square",
      nameAmh: "ፓፒረስ አደባባይ",
      coordinates: const LatLng(11.587729, 37.387986),
      category: "Square"),
  BahirDarLocation(
      name: "Giorgis Square",
      nameAmh: "ጊዮርጊስ አደባባይ",
      coordinates: const LatLng(11.594735, 37.388025),
      category: "Square"),
  BahirDarLocation(
      name: "Wisdom Square",
      nameAmh: "ዊዝደም አደባባይ",
      coordinates: const LatLng(11.587654, 37.395260),
      category: "Square"),
  BahirDarLocation(
      name: "Polytechnic College",
      nameAmh: "ፖሊ ቴክኒክ ኮሌጅ",
      coordinates: const LatLng(11.601668, 37.424980),
      category: "College"),
];
