import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'pos_database_service.dart';

class PosBackupService {
  PosBackupService._internal();
  static final PosBackupService instance = PosBackupService._internal();

  /// Membuat file backup lokal (.db) dengan timestamp waktu
  Future<File?> createBackupFile() async {
    try {
      final dbPath = await PosDatabaseService.instance.getDatabaseFilePath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        debugPrint('[PosBackupService] Database file tidak ditemukan di: $dbPath');
        return null;
      }

      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'backup_garudatel_pos_$dateStr.db';

      final dir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(dir.path, 'pos_backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final targetPath = p.join(backupDir.path, fileName);
      final backupFile = await dbFile.copy(targetPath);
      debugPrint('[PosBackupService] Berhasil membuat backup di: $targetPath');
      return backupFile;
    } catch (e) {
      debugPrint('[PosBackupService] Error createBackupFile: $e');
      return null;
    }
  }

  /// Bagikan file backup via WhatsApp, Email, Google Drive, atau Telegram (Native Android Share Sheet)
  Future<bool> shareBackupDatabase() async {
    try {
      final file = await createBackupFile();
      if (file == null || !await file.exists()) {
        return false;
      }

      final xfile = XFile(file.path, mimeType: 'application/octet-stream', name: p.basename(file.path));
      final result = await Share.shareXFiles(
        [xfile],
        subject: 'Backup Database Kasir POS GarudaTel',
        text: 'File cadangan database Kasir POS GarudaTel (${p.basename(file.path)}). Simpan file ini untuk memulihkan data kasir jika berganti perangkat.',
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (e) {
      debugPrint('[PosBackupService] Error shareBackupDatabase: $e');
      return false;
    }
  }

  /// Memulihkan database dari file .db yang dipilih pengguna
  Future<String?> restoreDatabaseFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Pilih File Backup Database POS (.db)',
      );

      if (result == null || result.files.isEmpty) {
        return 'Pemulihan dibatalkan (tidak ada file yang dipilih).';
      }

      final filePath = result.files.single.path;
      if (filePath == null || filePath.isEmpty) {
        return 'Gagal membaca lokasi file cadangan.';
      }

      final pickedFile = File(filePath);
      if (!await pickedFile.exists()) {
        return 'File cadangan yang dipilih tidak ditemukan.';
      }

      final bytes = await pickedFile.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes);
      if (!header.startsWith('SQLite format 3')) {
        return 'File yang dipilih bukan format database SQLite yang valid.';
      }

      // Tutup koneksi database aktif terlebih dahulu
      await PosDatabaseService.instance.closeDatabase();

      final currentDbPath = await PosDatabaseService.instance.getDatabaseFilePath();
      final currentDbFile = File(currentDbPath);

      // Buat backup darurat database saat ini sebelum ditimpa
      if (await currentDbFile.exists()) {
        final emergencyBakPath = '$currentDbPath.bak';
        await currentDbFile.copy(emergencyBakPath);
      }

      // Salin file backup ke database aplikasi
      await pickedFile.copy(currentDbPath);

      // Buka kembali database dan jalankan migrasi jika perlu
      await PosDatabaseService.instance.database;

      return null; // Null menandakan sukses
    } catch (e) {
      debugPrint('[PosBackupService] Error restoreDatabaseFromFile: $e');
      return 'Terjadi kesalahan saat memulihkan database: $e';
    }
  }
}
