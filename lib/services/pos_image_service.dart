import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Layanan Kompresi & Penyimpanan Foto Produk POS secara Offline 100%
/// Mengubah foto kamera/galeri resolusi besar (3-8 MB) menjadi thumbnail
/// ultra-ringan (~30-50 KB, maks 400x400 px) untuk performa instan tanpa lag.
class PosImageService {
  PosImageService._internal();
  static final PosImageService instance = PosImageService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Mengambil foto dari Kamera atau Galeri, mengompres otomatis, dan menyimpannya di memori HP.
  /// Mengembalikan path file gambar lokal (String) atau null jika batal.
  Future<String?> pickAndCompressImage({
    required ImageSource source,
    int maxDimension = 400,
    int quality = 75,
  }) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked == null) return null;

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return null;

      // Decode gambar di memori lokal HP (pure Dart, offline 100%)
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // Hitung dimensi thumbnail ideal kasir (maks 400x400 dengan menjaga rasio aspek)
      int targetWidth = decoded.width;
      int targetHeight = decoded.height;

      if (targetWidth > maxDimension || targetHeight > maxDimension) {
        if (targetWidth > targetHeight) {
          targetHeight = (targetHeight * (maxDimension / targetWidth)).round();
          targetWidth = maxDimension;
        } else {
          targetWidth = (targetWidth * (maxDimension / targetHeight)).round();
          targetHeight = maxDimension;
        }
      }

      // Resize & Compress ke JPEG kualitas 75-80%
      final resized = img.copyResize(
        decoded,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );

      final List<int> compressedBytes = img.encodeJpg(resized, quality: quality);

      // Simpan ke direktori aplikasi terisolasi
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${dir.path}/product_images');
      if (!imagesDir.existsSync()) {
        imagesDir.createSync(recursive: true);
      }

      final fileName = 'prod_${DateTime.now().millisecondsSinceEpoch}_${100 + Random().nextInt(900)}.jpg';
      final savedFile = File('${imagesDir.path}/$fileName');
      await savedFile.writeAsBytes(compressedBytes);

      debugPrint('[PosImageService] Berhasil kompres foto produk: ${compressedBytes.length} bytes -> ${savedFile.path}');
      return savedFile.path;
    } catch (e) {
      debugPrint('[PosImageService] Gagal memproses gambar: $e');
      return null;
    }
  }

  /// Menghapus file foto lama saat foto diganti atau produk dihapus permanen
  Future<void> deleteImageFile(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[PosImageService] File foto lama dihapus: $filePath');
      }
    } catch (e) {
      debugPrint('[PosImageService] Gagal menghapus file foto: $e');
    }
  }

  /// Memeriksa apakah file foto lokal valid dan ada di memori HP
  bool isImageValid(String? filePath) {
    if (filePath == null || filePath.trim().isEmpty) return false;
    try {
      final file = File(filePath);
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }
}
