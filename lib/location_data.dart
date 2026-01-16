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
      name: "Kulkual Meda Primary",
      nameAmh: "ኩልኳል ሜዳ መሪ ደረጃ ት/ቤት",
      coordinates: LatLng(11.5830, 37.3750),
      category: "School"),
  BahirDarLocation(
      name: "Blessed Ghebre Michael School",
      nameAmh: "ብፁዕ ገብረ ሚካኤል ት/ቤት",
      coordinates: LatLng(11.5975, 37.3910),
      category: "School"),
  BahirDarLocation(
      name: "SOS Hermann Gmeiner School",
      nameAmh: "ኤስ ኦ ኤስ ሄርማን ግመነር ት/ቤት",
      coordinates: LatLng(11.5710, 37.3680),
      category: "School"),
  BahirDarLocation(
      name: "Ayelech Degefu Memorial (ADMS)",
      nameAmh: "አየለች ደገፉ መታሰቢያ ት/ቤት",
      coordinates: LatLng(11.5780, 37.3820),
      category: "School"),
  BahirDarLocation(
      name: "Misraq Ghion Primary",
      nameAmh: "ምስራቅ ጊዮን መሪ ደረጃ ት/ቤት",
      coordinates: LatLng(11.5850, 37.4120),
      category: "School"),
  BahirDarLocation(
      name: "Bahir Dar Academy",
      nameAmh: "ባሕር ዳር አካዳሚ",
      coordinates: LatLng(11.5690, 37.3755),
      category: "School"),

  // --- SECONDARY & PREPARATORY ---
  BahirDarLocation(
      name: "Tana Haik Secondary",
      nameAmh: "ጣና ሐይቅ መሰናዶ ት/ቤት",
      coordinates: LatLng(11.5955, 37.3850),
      category: "High School"),
  BahirDarLocation(
      name: "Fasilo Secondary School",
      nameAmh: "ፋሲሎ ሁለተኛ ደረጃ ት/ቤት",
      coordinates: LatLng(11.5650, 37.3820),
      category: "High School"),
  BahirDarLocation(
      name: "Ethio-Parents School",
      nameAmh: "ኢትዮ-ፓረንትስ ት/ቤት",
      coordinates: LatLng(11.5810, 37.3980),
      category: "High School"),

  // --- UNIVERSITIES & COLLEGES ---
  BahirDarLocation(
      name: "BDU - Peda Campus",
      nameAmh: "ባሕር ዳር ዩኒቨርሲቲ (ፔዳ)",
      coordinates: LatLng(11.5900, 37.3970),
      category: "University"),
  BahirDarLocation(
      name: "BDU - Poly Campus",
      nameAmh: "ባሕር ዳር ዩኒቨርሲቲ (ፖሊ)",
      coordinates: LatLng(11.5845, 37.4055),
      category: "University"),
  BahirDarLocation(
      name: "Wisdom Tower (BDU Admin)",
      nameAmh: "ዊዝደም ታወር (ባዳዩ አስተዳደር)",
      coordinates: LatLng(11.5872, 37.3957),
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
      coordinates: LatLng(11.5990, 37.3915),
      category: "Church"),
  BahirDarLocation(
      name: "Abune Hara Church",
      nameAmh: "አቡነ ሐራ ቤተክርስቲያን",
      coordinates: LatLng(11.5755, 37.3950),
      category: "Church"),
  BahirDarLocation(
      name: "Medhane Alem Church",
      nameAmh: "መድኃኔዓለም ቤተክርስቲያን",
      coordinates: LatLng(11.5875, 37.3780),
      category: "Church"),
  BahirDarLocation(
      name: "St. Michael Church",
      nameAmh: "ቅዱስ ሚካኤል ቤተክርስቲያን",
      coordinates: LatLng(11.5945, 37.3895),
      category: "Church"),
  BahirDarLocation(
      name: "Kidane Mihret Church",
      nameAmh: "ኪዳነ ምሕረት ቤተክርስቲያን",
      coordinates: LatLng(11.5915, 37.4080),
      category: "Church"),
  BahirDarLocation(
      name: "St. Tekle Haymanot",
      nameAmh: "አቡነ ተክለሃይማኖት ቤተክርስቲያን",
      coordinates: LatLng(11.5680, 37.3910),
      category: "Church"),
  BahirDarLocation(
      name: "Hamere Noah Kidane Mihret",
      nameAmh: "ሐመረ ኖኅ ኪዳነ ምሕረት",
      coordinates: LatLng(11.5820, 37.3650),
      category: "Church"),
  BahirDarLocation(
      name: "St. Gabriel Church",
      nameAmh: "ቅዱስ ገብርኤል ቤተክርስቲያን",
      coordinates: LatLng(11.5715, 37.4015),
      category: "Church"),
];
