import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_config.dart';
import '../../models/pos_product.dart';
import '../../providers/pos_provider.dart';
import '../../services/scanner_feedback_service.dart';

/// Modal Scanner Barcode Cepat untuk Kasir POS
/// Dilengkapi Audio Beep Retail, Haptic Feedback, Anti Double-Scan (1 Scan = 1 Qty),
/// serta Quick Quantity Adjustment langsung di layar scanner.
class PosScannerModal extends StatefulWidget {
  final PosProvider? pos;
  final bool isSingleCapture;

  const PosScannerModal({
    super.key,
    this.pos,
    this.isSingleCapture = false,
  });

  /// Mode 1: Pemindaian keranjang kasir (tambah ke keranjang dengan kontrol kuantitas)
  static Future<void> show(BuildContext context, PosProvider pos) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosScannerModal(pos: pos, isSingleCapture: false),
    );
  }

  /// Mode 2: Pemindaian tunggal untuk input form kode/SKU barang
  static Future<String?> scanSingle(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PosScannerModal(isSingleCapture: true),
    );
  }

  @override
  State<PosScannerModal> createState() => _PosScannerModalState();
}

class _PosScannerModalState extends State<PosScannerModal> {
  late final MobileScannerController _controller;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  /// Barcode yang saat ini terkunci di frame kamera agar tidak auto-increment liar
  String? _lockedBarcode;

  /// Produk yang baru saja berhasil di-scan
  PosProduct? _activeProduct;

  /// Status notifikasi / banner umpan balik
  String? _statusBanner;
  bool _isSuccessBanner = false;

  /// Animasi flash border hijau saat scan berhasil
  bool _successFlash = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _triggerSuccessFlash() {
    _flashTimer?.cancel();
    if (mounted) {
      setState(() => _successFlash = true);
      _flashTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) {
          setState(() => _successFlash = false);
        }
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawVal = barcodes.first.rawValue;
    if (rawVal == null || rawVal.trim().isEmpty) return;
    final code = rawVal.trim();

    // Mode 1: Single capture (input form master produk)
    if (widget.isSingleCapture) {
      ScannerFeedbackService.playScanSuccess();
      Navigator.pop(context, code);
      return;
    }

    // Mode 2: Kasir POS Checkout
    // ATURAN 1 SCAN = 1 JUMLAH:
    // Jika barcode masih sama dengan yang sedang terkunci di layar,
    // ABAIKAN auto-increment agar tidak bertambah berulang kali!
    if (_lockedBarcode == code) {
      return;
    }

    if (widget.pos == null) return;

    final product = widget.pos!.findProductByBarcode(code);

    if (product != null) {
      // Barcode produk ditemukan!
      _lockedBarcode = code;
      _activeProduct = product;
      _triggerSuccessFlash();
      ScannerFeedbackService.playScanSuccess();

      // Tambahkan tepat 1 pcs ke keranjang kasir
      final ok = widget.pos!.addToCart(product);

      setState(() {
        _isSuccessBanner = ok;
        _statusBanner = ok
            ? '✅ ${product.nama} masuk keranjang (1 pcs)'
            : (widget.pos!.errorMessage ?? '⚠️ Gagal menambah stok');
      });
    } else {
      // Barcode belum terdaftar di produk
      _lockedBarcode = code; // Kunci agar suara error tidak berulang-ulang tanpa henti
      _activeProduct = null;
      ScannerFeedbackService.playScanError();

      setState(() {
        _isSuccessBanner = false;
        _statusBanner = '❌ Barcode "$code" belum terdaftar di daftar produk';
      });
    }
  }

  /// Membuka kunci barcode aktif agar kasir bisa scan ulang barcode fisik yang sama
  void _unlockBarcodeForRescan() {
    setState(() {
      _lockedBarcode = null;
      _statusBanner = 'Kamera siap memindai ulang...';
      _isSuccessBanner = true;
    });
    HapticFeedback.lightImpact();
  }

  /// Tambah / Kurangi kuantitas produk yang sedang aktif
  void _updateActiveQty(int delta) {
    if (_activeProduct == null || widget.pos == null) return;

    if (delta > 0) {
      ScannerFeedbackService.playScanSuccess();
    } else {
      HapticFeedback.lightImpact();
    }

    final ok = widget.pos!.updateProductQty(_activeProduct!, delta);
    setState(() {
      if (!ok && widget.pos!.errorMessage != null) {
        _statusBanner = '⚠️ ${widget.pos!.errorMessage}';
        _isSuccessBanner = false;
      }
    });
  }

  /// Dialog input angka kuantitas langsung (misal beli 10 atau 24 pcs)
  void _showDirectQtyDialog(int currentQty) {
    if (_activeProduct == null || widget.pos == null) return;

    final ctrl = TextEditingController(text: currentQty.toString());
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Atur Jumlah ${_activeProduct!.nama}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan jumlah barang yang dibeli pelanggan:',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Jumlah (${_activeProduct!.unit})',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.numbers_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.primaryTeal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newQty = int.tryParse(ctrl.text.trim()) ?? currentQty;
              Navigator.pop(dCtx);
              widget.pos!.setProductCartQty(_activeProduct!, newQty);
              setState(() {});
              HapticFeedback.mediumImpact();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSingle = widget.isSingleCapture;
    final pos = widget.pos;
    final activeQty = (_activeProduct != null && pos != null)
        ? pos.getProductCartQty(_activeProduct!)
        : 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded, color: AppConfig.primaryTeal, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSingle ? 'Pindai Barcode Kemasan' : 'Pindai Barcode Produk',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isSingle
                            ? 'Arahkan kamera ke barcode kemasan untuk input otomatis'
                            : '1 Scan = 1 Qty • Anti duplikat scan aktif',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Flashlight Toggle
                IconButton(
                  icon: ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, state, child) {
                      final isTorchOn = state.torchState == TorchState.on;
                      return Icon(
                        isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: isTorchOn ? Colors.amber : Colors.white70,
                      );
                    },
                  ),
                  onPressed: () => _controller.toggleTorch(),
                ),
                // Close Button
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Camera Viewfinder Box
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),

                // Viewfinder Frame Overlay dengan Flash Animasi saat Sukses
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _successFlash
                          ? Colors.greenAccent
                          : AppConfig.primaryTeal,
                      width: _successFlash ? 4.5 : 2.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _successFlash
                        ? [
                            BoxShadow(
                              color: Colors.greenAccent.withValues(alpha: 0.6),
                              blurRadius: 20,
                              spreadRadius: 4,
                            )
                          ]
                        : null,
                  ),
                ),

                // Red Laser Line Accent
                Positioned(
                  child: Container(
                    width: 240,
                    height: 2,
                    color: Colors.redAccent.withValues(alpha: 0.8),
                  ),
                ),

                // Panduan di bawah frame
                Positioned(
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _lockedBarcode != null && !isSingle
                          ? 'Barcode terkunci • Ganti produk atau tap tombol di bawah'
                          : 'Arahkan barcode produk ke kotak tengah',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status Feedback Banner (Jika ada pesan)
          if (!isSingle && _statusBanner != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _isSuccessBanner ? const Color(0xFF047857) : const Color(0xFFDC2626),
              child: Row(
                children: [
                  Icon(
                    _isSuccessBanner ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusBanner!,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Quick Quantity Adjustment Card (Muncul saat ada produk aktif terpindai)
          if (!isSingle && _activeProduct != null && pos != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppConfig.primaryTeal.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Info Produk
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _activeProduct!.nama,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              _currencyFormat.format(_activeProduct!.hargaJual),
                              style: const TextStyle(color: AppConfig.primaryTeal, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            if (_activeProduct!.kode.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _activeProduct!.kode,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_activeProduct!.isStockManaged)
                          Text(
                            'Sisa Stok: ${_activeProduct!.stok} ${_activeProduct!.unit}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                          ),
                      ],
                    ),
                  ),

                  // Stepper Quick Counter
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tombol Kurang (-)
                      IconButton.filledTonal(
                        onPressed: () => _updateActiveQty(-1),
                        icon: const Icon(Icons.remove_rounded, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Kotak Qty (Bisa di-tap untuk ketik jumlah langsung)
                      InkWell(
                        onTap: () => _showDirectQtyDialog(activeQty),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '$activeQty',
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_rounded, color: Colors.white70, size: 12),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Tombol Tambah (+)
                      IconButton.filled(
                        onPressed: () => _updateActiveQty(1),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: AppConfig.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Tombol Scan Ulang Fisik
                      IconButton(
                        tooltip: 'Scan item fisik berikutnya',
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                        onPressed: _unlockBarcodeForRescan,
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Footer Keranjang & Selesai Scan
          if (!isSingle && pos != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              color: const Color(0xFF0B132B),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total Keranjang Kasir:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Text(
                        '${pos.cartTotalQty} Item • ${_currencyFormat.format(pos.cartTotal)}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                    label: const Text('Selesai Scan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E293B),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Posisikan barcode di dalam kotak hijau',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
