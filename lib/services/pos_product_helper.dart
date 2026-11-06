import 'dart:math';

/// Helper utilitas untuk produk POS:
/// Generate kode otomatis, pemformatan, dan sanitasi data
class PosProductHelper {
  /// Generate kode produk otomatis jika dikosongkan.
  /// Rumus: 3 s/d 5 huruf singkatan nama produk + '-' + 4 digit angka acak (1000 - 9999).
  /// Contoh:
  /// - "Kopi Susu Gula Aren" -> "KSGA-4821"
  /// - "Air Galon Isi Ulang" -> "AGIU-7193"
  /// - "Adaptor Charger 2A Fast" -> "ACF-3042"
  /// - "Beras" -> "BERAS-6510"
  /// - "Aqua" -> "AQUA-8291"
  /// - "Es" -> "ESX-1124"
  static String generateCodeFromName(String productName, {Set<String>? existingCodes}) {
    final cleanName = productName.trim();
    if (cleanName.isEmpty) {
      final rand = 1000 + Random().nextInt(9000);
      return 'PRD-$rand';
    }

    final words = cleanName.split(RegExp(r'\s+'));
    String prefix = '';

    if (words.length > 1) {
      // Lebih dari 1 kata: ambil huruf pertama setiap kata (maksimal 5 huruf)
      for (final w in words) {
        final cleanLetters = w.replaceAll(RegExp(r'[^a-zA-Z]'), '');
        if (cleanLetters.isNotEmpty) {
          prefix += cleanLetters[0].toUpperCase();
          if (prefix.length >= 5) break;
        }
      }
      // Jika singkatan masih kurang dari 3 huruf (misal "Es Teh"),
      // ambil huruf berikutnya dari seluruh teks yang ada agar mencapai 3-5 huruf
      if (prefix.length < 3) {
        final allLetters = cleanName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
        if (allLetters.length >= 3) {
          prefix = allLetters.substring(0, min(5, allLetters.length));
        } else {
          prefix = allLetters.padRight(3, 'X');
        }
      }
    } else {
      // Hanya 1 kata: ambil 3 hingga 5 huruf pertama
      final cleanLetters = words[0].replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
      if (cleanLetters.length >= 5) {
        prefix = cleanLetters.substring(0, 5);
      } else if (cleanLetters.length >= 3) {
        prefix = cleanLetters;
      } else {
        // Jika nama < 3 huruf (misal: "Es", "Mi"), pad dengan huruf 'X'
        prefix = cleanLetters.padRight(3, 'X');
      }
    }

    if (prefix.isEmpty) prefix = 'PRD';

    // Loop angka acak 4 digit (1000 s/d 9999) hingga dipastikan unik
    String candidate = '';
    int attempts = 0;
    final randGen = Random();
    do {
      final digits = 1000 + randGen.nextInt(9000);
      candidate = '$prefix-$digits';
      attempts++;
    } while (existingCodes != null && existingCodes.contains(candidate) && attempts < 100);

    return candidate;
  }
}
