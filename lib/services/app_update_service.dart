import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class AppUpdateInfo {
  final String tagName;
  final int size;
  final String downloadUrl;

  AppUpdateInfo({
    required this.tagName,
    required this.size,
    required this.downloadUrl,
  });

  String get sizeFormatted {
    if (size <= 0) return '~31.4 MB';
    final mb = size / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get cleanVersion {
    return tagName.replaceAll('v', '').replaceAll('V', '').trim();
  }
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  bool _isChecking = false;
  DateTime? _lastCheckedTime;

  /// Memeriksa apakah ada update versi baru.
  /// [silent] jika true tidak menampilkan notifikasi jika sudah versi terbaru atau gagal koneksi (background).
  Future<void> checkForUpdate(BuildContext context, {bool silent = true}) async {
    // Cegah spam pengecekan berulang dalam rentang 30 detik jika silent
    if (silent && _lastCheckedTime != null) {
      if (DateTime.now().difference(_lastCheckedTime!).inSeconds < 30) {
        return;
      }
    }

    if (_isChecking) return;
    _isChecking = true;
    _lastCheckedTime = DateTime.now();

    try {
      final info = await _fetchLatestVersionInfo();
      _isChecking = false;

      if (!context.mounted) return;

      if (info != null) {
        final isNewer = _isVersionNewer(info.cleanVersion, AppConfig.appVersion);
        if (isNewer) {
          _showUpdateDialog(context, info);
          return;
        }
      }

      // Jika pengecekan manual dan sudah versi terbaru
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aplikasi sudah versi terbaru (v${AppConfig.appVersion})!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppConfig.primaryTeal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      _isChecking = false;
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Gagal memeriksa pembaruan. Pastikan internet terhubung.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  /// Mengambil metadata versi dari web server
  Future<AppUpdateInfo?> _fetchLatestVersionInfo() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/static/apk/version.json');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'IPAY_NATIVE_APP/${AppConfig.appVersion}');
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(responseBody);
        return AppUpdateInfo(
          tagName: data['tag_name'] ?? 'v2.1.0',
          size: data['size'] is int ? data['size'] : int.tryParse(data['size']?.toString() ?? '0') ?? 0,
          downloadUrl: data['download_url'] ?? '${AppConfig.baseUrl}/download/apk',
        );
      }
    } catch (_) {
      // Abaikan error koneksi jaringan
    } finally {
      client.close();
    }
    return null;
  }

  /// Membandingkan semver string (misal: '2.1.0' vs '2.0.0' atau '1.0.7')
  bool _isVersionNewer(String remote, String local) {
    try {
      final remoteParts = remote.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map(int.parse).toList();
      final localParts = local.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map(int.parse).toList();

      final maxLength = remoteParts.length > localParts.length ? remoteParts.length : localParts.length;
      while (remoteParts.length < maxLength) {
        remoteParts.add(0);
      }
      while (localParts.length < maxLength) {
        localParts.add(0);
      }

      for (int i = 0; i < maxLength; i++) {
        if (remoteParts[i] > localParts[i]) return true;
        if (remoteParts[i] < localParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Menampilkan dialog pembaruan yang informatif dan ramah pengguna
  void _showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppConfig.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.system_update, color: AppConfig.primaryTeal, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pembaruan Tersedia! 🚀',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppConfig.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Versi ${info.tagName} (${info.sizeFormatted})',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppConfig.primaryTeal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConfig.backgroundSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Peningkatan & Fitur Baru:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppConfig.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildFeatureItem('Sistem Kasir POS Offline & Database Lokal HP'),
                    _buildFeatureItem('Cetak Struk Bluetooth Thermal 58mm & 80mm'),
                    _buildFeatureItem('Mode Tampilan List & Grid di Layar Kasir'),
                    _buildFeatureItem('Fitur Retur & Pembatalan Barang Transaksi'),
                    _buildFeatureItem('Penyelesaian Konsinyasi & Import/Export Excel'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Data transaksi kasir dan akun Anda tersimpan aman dan tidak akan hilang saat memperbarui.',
                style: TextStyle(fontSize: 11, color: AppConfig.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(modalContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Nanti Saja',
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(modalContext);
                        final downloadUri = Uri.parse(
                          info.downloadUrl.isNotEmpty ? info.downloadUrl : '${AppConfig.baseUrl}/download/apk',
                        );
                        if (await canLaunchUrl(downloadUri)) {
                          await launchUrl(downloadUri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text(
                        'Perbarui Sekarang',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppConfig.primaryTeal, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppConfig.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
