import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../config/app_config.dart';
import '../../providers/pos_provider.dart';

/// Modal Scanner Barcode Kamera Cepat untuk Kasir POS
class PosScannerModal extends StatefulWidget {
  final PosProvider pos;

  const PosScannerModal({super.key, required this.pos});

  static Future<void> show(BuildContext context, PosProvider pos) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosScannerModal(pos: pos),
    );
  }

  @override
  State<PosScannerModal> createState() => _PosScannerModalState();
}

class _PosScannerModalState extends State<PosScannerModal> {
  late final MobileScannerController _controller;
  String? _lastScannedCode;
  DateTime _lastScanTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _statusBanner;
  bool _isSuccessBanner = false;

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
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawVal = barcodes.first.rawValue;
    if (rawVal == null || rawVal.trim().isEmpty) return;
    final code = rawVal.trim();

    // Debounce agar tidak scan berulang kali dalam 1.2 detik untuk barcode yang sama
    final now = DateTime.now();
    if (_lastScannedCode == code && now.difference(_lastScanTime).inMilliseconds < 1200) {
      return;
    }
    _lastScannedCode = code;
    _lastScanTime = now;

    HapticFeedback.mediumImpact();

    final product = widget.pos.findProductByBarcode(code);
    if (product != null) {
      final ok = widget.pos.addToCart(product);
      setState(() {
        _isSuccessBanner = ok;
        _statusBanner = ok
            ? '✅ ${product.nama} masuk keranjang'
            : widget.pos.errorMessage ?? '⚠️ Gagal menambah stok';
      });
    } else {
      setState(() {
        _isSuccessBanner = false;
        _statusBanner = '❌ Barcode "$code" belum terdaftar';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded, color: AppConfig.primaryTeal, size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pindai Barcode Produk',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Arahkan kamera ke barcode kemasan barang',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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
                        isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: isTorchOn ? Colors.amber : Colors.white,
                      );
                    },
                  ),
                  onPressed: () => _controller.toggleTorch(),
                ),
                // Close Button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
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

                // Viewfinder Frame Overlay
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppConfig.primaryTeal, width: 2.5),
                    borderRadius: BorderRadius.circular(16),
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

                // Petunjuk di bawah frame
                Positioned(
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Mendukung Barcode EAN-13, QR Code & Kode Produk',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status Feedback Banner
          if (_statusBanner != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: _isSuccessBanner ? const Color(0xFF047857) : const Color(0xFFDC2626),
              child: Row(
                children: [
                  Icon(
                    _isSuccessBanner ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusBanner!,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Footer Info Kasir
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Keranjang Aktif:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    Text(
                      '${widget.pos.cartTotalQty} Item • Rp ${widget.pos.cartTotal.toInt()}',
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
                  ),
                  icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                  label: const Text('Selesai Scan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
