import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_config.dart';
import 'pos_database_service.dart';

/// Layanan Cadangkan & Pulihkan Seluruh Data POS (Database + Foto Produk)
class PosBackupService {
  PosBackupService._internal();
  static final PosBackupService instance = PosBackupService._internal();

  /// Mengemas database SQLite dan seluruh folder foto produk ke dalam 1 file ZIP
  Future<File> createBackupZip() async {
    final archive = Archive();

    // 1. Ambil File Database SQLite
    final dbPath = await PosDatabaseService.instance.getDatabaseFilePath();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('database/garudatel_pos.db', dbBytes.length, dbBytes));
    }

    // 2. Ambil Folder Foto Produk Offline
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(appDir.path, 'product_images'));
    int imageCount = 0;
    if (await imageDir.exists()) {
      final files = imageDir.listSync(recursive: false);
      for (final f in files) {
        if (f is File) {
          final bytes = await f.readAsBytes();
          final filename = p.basename(f.path);
          archive.addFile(ArchiveFile('images/$filename', bytes.length, bytes));
          imageCount++;
        }
      }
    }

    // 3. Tambahkan Manifest Metadata Cadangan
    final manifest = {
      'app': 'GarudaTel iPay POS Offline',
      'app_version': AppConfig.appVersion,
      'db_version': 5,
      'created_at': DateTime.now().toIso8601String(),
      'image_count': imageCount,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('backup_manifest.json', manifestBytes.length, manifestBytes));

    // 4. Encode ZIP
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    if (zipData == null) {
      throw Exception('Gagal mengompresi file arsip cadangan.');
    }

    // 5. Simpan ke Direktori Sementara / Dokumen
    final tempDir = await getTemporaryDirectory();
    final nowStr = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\.\-]'), '').substring(0, 14);
    final backupFileName = 'ipay_pos_backup_$nowStr.zip';
    final backupFile = File(p.join(tempDir.path, backupFileName));
    await backupFile.writeAsBytes(zipData);

    return backupFile;
  }

  /// Bagikan file cadangan via WhatsApp, Google Drive, Gmail, atau Simpan ke HP
  Future<void> shareBackup(BuildContext context) async {
    try {
      final backupFile = await createBackupZip();
      final sizeMb = (await backupFile.length()) / (1024 * 1024);
      final sizeStr = sizeMb < 1 ? '${(sizeMb * 1024).toStringAsFixed(0)} KB' : '${sizeMb.toStringAsFixed(2)} MB';

      await Share.shareXFiles(
        [XFile(backupFile.path)],
        subject: 'Cadangan Data iPay POS (${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year})',
        text: 'File Cadangan Data GarudaTel iPay POS Offline ($sizeStr). Simpan file ini di Google Drive atau memori aman untuk pemulihan sewaktu-waktu.',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Gagal membuat cadangan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Wrapper untuk shareBackup tanpa BuildContext
  Future<bool> shareBackupDatabase() async {
    try {
      final backupFile = await createBackupZip();
      final sizeMb = (await backupFile.length()) / (1024 * 1024);
      final sizeStr = sizeMb < 1 ? '${(sizeMb * 1024).toStringAsFixed(0)} KB' : '${sizeMb.toStringAsFixed(2)} MB';
      await Share.shareXFiles(
        [XFile(backupFile.path)],
        subject: 'Cadangan Data iPay POS (${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year})',
        text: 'File Cadangan Data GarudaTel iPay POS Offline ($sizeStr). Simpan file ini di Google Drive atau memori aman untuk pemulihan sewaktu-waktu.',
      );
      return true;
    } catch (e) {
      debugPrint('[PosBackupService] Error shareBackupDatabase: $e');
      return false;
    }
  }

  /// Memulihkan database dan foto produk dari file ZIP cadangan
  Future<bool> restoreBackupZip(String zipFilePath) async {
    final zipFile = File(zipFilePath);
    if (!await zipFile.exists()) {
      throw Exception('File cadangan tidak ditemukan.');
    }

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Cari file database di dalam arsip
    ArchiveFile? dbArchiveFile;
    final imageFiles = <ArchiveFile>[];

    for (final file in archive) {
      final normName = file.name.replaceAll('\\', '/');
      if (normName.endsWith('garudatel_pos.db')) {
        dbArchiveFile = file;
      } else if (normName.startsWith('images/') && file.isFile) {
        imageFiles.add(file);
      }
    }

    if (dbArchiveFile == null) {
      throw Exception('File cadangan tidak valid (database POS tidak ditemukan di dalam file ZIP).');
    }

    // 1. Tutup koneksi database aktif
    await PosDatabaseService.instance.closeDatabase();

    // 2. Ganti file database dengan yang dari backup
    final targetDbPath = await PosDatabaseService.instance.getDatabaseFilePath();
    final targetDbFile = File(targetDbPath);
    if (await targetDbFile.exists()) {
      await targetDbFile.delete();
    }
    await targetDbFile.writeAsBytes(dbArchiveFile.content as List<int>);

    // 3. Ekstrak foto-foto produk ke direktori product_images
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(appDir.path, 'product_images'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }

    for (final imgFile in imageFiles) {
      final imgFileName = p.basename(imgFile.name);
      if (imgFileName.isNotEmpty) {
        final dest = File(p.join(imageDir.path, imgFileName));
        await dest.writeAsBytes(imgFile.content as List<int>);
      }
    }

    // 4. Inisialisasi ulang database (buka kembali)
    await PosDatabaseService.instance.database;

    return true;
  }

  /// Dialog pilih file dan pulihkan sistem
  Future<bool> pickAndRestoreBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'ipay'],
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return false;
      }

      final path = result.files.first.path!;
      final ok = await restoreBackupZip(path);
      return ok;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Gagal memulihkan cadangan: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  /// Wrapper untuk restore dari file tanpa BuildContext
  Future<String?> restoreDatabaseFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'ipay'],
      );
      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return 'Batal memilih file cadangan.';
      }
      final path = result.files.first.path!;
      await restoreBackupZip(path);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
