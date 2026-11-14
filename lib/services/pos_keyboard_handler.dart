import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';

/// Item deskripsi shortcut keyboard untuk dialog bantuan cheat-sheet
class PosShortcutItem {
  final List<String> keys;
  final String description;
  final String? note;

  const PosShortcutItem({
    required this.keys,
    required this.description,
    this.note,
  });
}

/// Kategori shortcut keyboard untuk memudahkan pengelompokan
class PosShortcutCategory {
  final String title;
  final IconData icon;
  final List<PosShortcutItem> shortcuts;

  const PosShortcutCategory({
    required this.title,
    required this.icon,
    required this.shortcuts,
  });
}

/// Handler dan buffer pendeteksi input Hardware Keyboard & Barcode Scanner Wedge
class PosKeyboardHandler {
  // Buffer penampung karakter barcode dari hardware scanner
  final StringBuffer _scannerBuffer = StringBuffer();
  DateTime _lastCharTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Ambang batas waktu jeda antar karakter scanner (ms)
  // Scanner barcode fisik biasanya mengirim karakter dengan jeda < 40ms
  static const int scannerLatencyThresholdMs = 60;

  /// Daftar lengkap panduan pintasan keyboard kasir POS
  static const List<PosShortcutCategory> categories = [
    PosShortcutCategory(
      title: 'Navigasi Global',
      icon: Icons.navigation_rounded,
      shortcuts: [
        PosShortcutItem(keys: ['Ctrl', '1'], description: 'Buka Tab Kasir POS'),
        PosShortcutItem(keys: ['Ctrl', '2'], description: 'Buka Tab Data Pelanggan & Kasbon'),
        PosShortcutItem(keys: ['Ctrl', '3'], description: 'Buka Tab Konsinyasi Titipan'),
        PosShortcutItem(keys: ['Ctrl', '4'], description: 'Buka Tab Produk & Stok Excel'),
        PosShortcutItem(keys: ['Ctrl', '5'], description: 'Buka Tab Riwayat Transaksi & Laba'),
        PosShortcutItem(keys: ['F1'], description: 'Tampilkan Panduan Tombol Keyboard ini'),
      ],
    ),
    PosShortcutCategory(
      title: 'Operasional Kasir & Keranjang',
      icon: Icons.point_of_sale_rounded,
      shortcuts: [
        PosShortcutItem(keys: ['F2'], description: 'Fokus Kolom Cari / Scan Barang (Select All)', note: 'Bisa juga tekan "/" saat tidak mengetik'),
        PosShortcutItem(keys: ['↑', '↓'], description: 'Pilih Baris Item di Keranjang Belanja'),
        PosShortcutItem(keys: ['+'], description: 'Tambah Jumlah Qty Item Terpilih (+1)'),
        PosShortcutItem(keys: ['-'], description: 'Kurangi Jumlah Qty Item Terpilih (-1)'),
        PosShortcutItem(keys: ['*'], description: 'Ubah Jumlah Qty Cepat Secara Langsung'),
        PosShortcutItem(keys: ['Del'], description: 'Hapus Item Terpilih dari Keranjang', note: 'Bisa juga tombol Backspace'),
        PosShortcutItem(keys: ['F3'], description: 'Pilih Pelanggan / Member Aktif Kasir'),
        PosShortcutItem(keys: ['F4'], description: 'Tahan Transaksi / Antrean Pesanan (Hold Cart)'),
        PosShortcutItem(keys: ['Shift', 'F4'], description: 'Buka & Pulihkan Transaksi yang Ditahan'),
      ],
    ),
    PosShortcutCategory(
      title: 'Pembayaran & Checkout',
      icon: Icons.payments_rounded,
      shortcuts: [
        PosShortcutItem(keys: ['F5'], description: 'Buka Dialog Pembayaran & Checkout', note: 'Bisa juga tombol Space saat tidak mengetik'),
        PosShortcutItem(keys: ['T'], description: 'Pilih Metode Bayar TUNAI (Cash)'),
        PosShortcutItem(keys: ['Q'], description: 'Pilih Metode Bayar QRIS (Non-Tunai)'),
        PosShortcutItem(keys: ['K'], description: 'Pilih Metode Catat KASBON (Piutang)'),
        PosShortcutItem(keys: ['Home'], description: 'Isi Otomatis UANG PAS', note: 'Bisa juga tekan F6'),
        PosShortcutItem(keys: ['1..5'], description: 'Pilih Rekomendasi Pecahan Uang Cepat'),
        PosShortcutItem(keys: ['Enter'], description: 'Konfirmasi Bayar & Cetak Struk'),
        PosShortcutItem(keys: ['Esc'], description: 'Tutup Dialog Pembayaran / Batal'),
      ],
    ),
    PosShortcutCategory(
      title: 'Hardware & Shift Kasir',
      icon: Icons.print_rounded,
      shortcuts: [
        PosShortcutItem(keys: ['Ctrl', 'P'], description: 'Cetak Ulang Struk Transaksi Terakhir'),
        PosShortcutItem(keys: ['F8'], description: 'Buka Laci Kasir Elektronik (Kick Cash Drawer)'),
        PosShortcutItem(keys: ['F7'], description: 'Catat Arus Kas Masuk / Keluar Operasional'),
        PosShortcutItem(keys: ['F9'], description: 'Tutup Shift Kasir (Rekap & Cetak Kas)'),
      ],
    ),
  ];

  /// Menangani event key scanner hardware wedge
  /// Mengembalikan string barcode jika scanner selesai mengirim data (diakhiri Enter), null jika belum
  String? processScannerKeystroke(KeyEvent event) {
    if (event is! KeyDownEvent) return null;

    final now = DateTime.now();
    final elapsedMs = now.difference(_lastCharTime).inMilliseconds;
    _lastCharTime = now;

    // Jika jeda antar karakter terlalu lama (> 60ms), anggap ketikan manual baru dan bersihkan buffer
    if (elapsedMs > scannerLatencyThresholdMs && _scannerBuffer.isNotEmpty) {
      _scannerBuffer.clear();
    }

    final key = event.logicalKey;

    // Akhir dari transmisi scanner (Enter)
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      final code = _scannerBuffer.toString().trim();
      _scannerBuffer.clear();
      if (code.length >= 3) {
        return code;
      }
      return null;
    }

    // Karakter yang dapat ditambahkan ke kode barcode
    final char = event.character;
    if (char != null && char.isNotEmpty && RegExp(r'^[a-zA-Z0-9\-_./#]$').hasMatch(char)) {
      _scannerBuffer.write(char);
    }

    return null;
  }

  /// Reset buffer pemindai
  void clearBuffer() {
    _scannerBuffer.clear();
  }

  /// Dialog modal panduan lengkap pintasan keyboard
  static void showShortcutGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            width: 600,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Dialog
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppConfig.primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.keyboard_rounded, color: AppConfig.primaryTeal, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pintasan Keyboard Kasir POS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Transaksi kilat tanpa perlu menyentuh mouse atau layar',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        tooltip: 'Tutup (Esc)',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Content List Kategori Shortcut
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, catIdx) {
                      final category = categories[catIdx];
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Judul Kategori
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                              child: Row(
                                children: [
                                  Icon(category.icon, size: 16, color: AppConfig.primaryTeal),
                                  const SizedBox(width: 6),
                                  Text(
                                    category.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),

                            // Baris-baris shortcut
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: category.shortcuts.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                indent: 14,
                                endIndent: 14,
                                color: Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (context, itemIdx) {
                                final item = category.shortcuts[itemIdx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  child: Row(
                                    children: [
                                      // Badge Tombol Keyboard
                                      Wrap(
                                        spacing: 4,
                                        children: item.keys.map((k) => _buildKeyBadge(k)).toList(),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.description,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            if (item.note != null) ...[
                                              const SizedBox(height: 1),
                                              Text(
                                                item.note!,
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  color: Color(0xFF94A3B8),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Footer Petunjuk
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Pintasan dapat digunakan dengan keyboard fisik USB, Bluetooth, atau scanner barcode kasir.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('Mengerti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Widget pembuat badge tombol visual seperti tombol fisik keyboard
  static Widget _buildKeyBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFCBD5E1),
            offset: Offset(0, 1.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w800,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }
}
