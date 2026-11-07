import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../models/pos_cart_item.dart';
import '../../models/pos_product.dart';
import '../../models/pos_transaction.dart';
import '../../providers/pos_provider.dart';
import '../../providers/printer_provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/app_update_service.dart';
import '../../services/pos_database_service.dart';
import '../../services/pos_image_service.dart';
import '../../services/pos_product_helper.dart';
import '../../services/pos_whatsapp_service.dart';
import '../printer_settings_screen.dart';
import 'pos_scanner_modal.dart';

class PosMainScreen extends StatefulWidget {
  const PosMainScreen({super.key});

  @override
  State<PosMainScreen> createState() => _PosMainScreenState();
}

class _PosMainScreenState extends State<PosMainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosProvider>();
    final printer = context.watch<PrinterProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kembali ke PPOB Web',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Kasir POS Offline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppConfig.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppConfig.primaryTeal.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '100% NATIVE',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppConfig.primaryTeal),
                  ),
                ),
              ],
            ),
            Text(
              'Database Lokal HP • Bebas Gangguan Sinyal',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          // Tombol Cek Pembaruan APK
          IconButton(
            icon: const Icon(Icons.system_update_rounded, color: AppConfig.primaryTeal, size: 21),
            tooltip: 'Cek Pembaruan APK',
            onPressed: () => AppUpdateService().checkForUpdate(context, silent: false),
          ),
          // Indikator Status Printer
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: printer.isConnected ? const Color(0xFFECFDF5) : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: printer.isConnected ? const Color(0xFFA7F3D0) : Colors.orange.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.print,
                    size: 14,
                    color: printer.isConnected ? const Color(0xFF047857) : Colors.orange.shade800,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    printer.isConnected ? 'Printer Siap' : 'Printer Putus',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: printer.isConnected ? const Color(0xFF047857) : Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tombol Periksa Pembaruan Aplikasi
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined, size: 21, color: AppConfig.primaryTeal),
            tooltip: 'Periksa Pembaruan Versi Baru',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () {
              AppUpdateService().checkForUpdate(context, silent: false);
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConfig.primaryTeal,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppConfig.primaryTeal,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.point_of_sale, size: 20), text: 'Kasir'),
            Tab(icon: Icon(Icons.handshake_outlined, size: 20), text: 'Konsinyasi'),
            Tab(icon: Icon(Icons.table_view, size: 20), text: 'Produk/Excel'),
            Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'Riwayat/Laba'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCashierTab(pos),
          _buildConsignmentTab(pos),
          _buildProductExcelTab(pos),
          _buildHistoryReportTab(pos),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: KASIR POS (CATALOG & SPEED CHECKOUT)
  // =========================================================================
  Widget _buildCashierTab(PosProvider pos) {
    final filtered = pos.filteredProducts;

    return Stack(
      children: [
        Column(
          children: [
            // 1. Search Bar & Category Filter
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  // Search Box with View Mode Switcher
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (val) => pos.search(val),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Cari nama barang atau kode produk...',
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        pos.search('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tombol Scan Barcode Kamera Cepat
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: AppConfig.primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppConfig.primaryTeal.withValues(alpha: 0.25)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: AppConfig.primaryTeal, size: 22),
                          tooltip: 'Scan Barcode Kamera Cepat',
                          onPressed: () => PosScannerModal.show(context, pos),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tombol Ganti Mode Grid / List
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: IconButton(
                          icon: Icon(
                            pos.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                            color: AppConfig.primaryTeal,
                            size: 22,
                          ),
                          tooltip: pos.isGridView ? 'Ganti ke Tampilan List' : 'Ganti ke Tampilan Grid',
                          onPressed: () => pos.toggleViewMode(),
                        ),
                      ),
                    ],
                  ),

                  // Banner Antrean Pesanan Ditahan (Hold Cart)
                  if (pos.holdCartsCount > 0) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showHoldCartsSheet(context, pos),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.pause_circle_outline_rounded, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${pos.holdCartsCount} Transaksi Ditahan (Antrean)',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.amber.shade900),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade600,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Buka / Pulihkan',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Category Horizontal Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip(pos, 'ALL', 'Semua Barang'),
                        _buildCategoryChip(pos, 'Konsinyasi', '🤝 Titipan', isConsignment: true),
                        ...pos.categories.map((c) => _buildCategoryChip(pos, c, c)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Product List / Grid
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Tidak ada produk yang cocok',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : (pos.isGridView
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final product = filtered[idx];
                            return _buildProductCard(pos, product);
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
                          itemCount: filtered.length,
                          itemBuilder: (context, idx) {
                            final product = filtered[idx];
                            return _buildProductListItem(pos, product);
                          },
                        )),
            ),
          ],
        ),

        // 3. Floating Bottom Cart Bar
        if (pos.cart.isNotEmpty)
          Positioned(
            left: 14,
            right: 14,
            bottom: 16,
            child: _buildCartBottomBar(pos),
          ),
      ],
    );
  }

  Widget _buildCategoryChip(PosProvider pos, String catValue, String label, {bool isConsignment = false}) {
    final isSelected = pos.selectedCategory.toLowerCase() == catValue.toLowerCase();

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : (isConsignment ? Colors.amber.shade900 : const Color(0xFF475569)),
        ),
        backgroundColor: isConsignment ? Colors.amber.shade50 : const Color(0xFFF1F5F9),
        selectedColor: isConsignment ? Colors.amber.shade700 : AppConfig.primaryTeal,
        side: BorderSide(
          color: isConsignment ? Colors.amber.shade300 : Colors.transparent,
          width: 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        onSelected: (_) => pos.selectCategory(catValue),
      ),
    );
  }

  Widget _buildProductCard(PosProvider pos, PosProduct product) {
    final bool isOutOfStock = product.isStockManaged && product.stok <= 0;

    return InkWell(
      onTap: () {
        if (isOutOfStock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Stok "${product.nama}" sudah habis!'),
              backgroundColor: Colors.red.shade800,
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        final ok = pos.addToCart(product);
        if (!ok && pos.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(pos.errorMessage!),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isOutOfStock ? 0.65 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOutOfStock ? Colors.red.shade200 : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Foto Produk / Placeholder dengan Tombol Kamera Cepat
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 72,
                      width: double.infinity,
                      color: const Color(0xFFF1F5F9),
                      child: (product.imagePath != null && product.imagePath!.isNotEmpty && File(product.imagePath!).existsSync())
                          ? Image.file(
                              File(product.imagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildPlaceholderPhoto(product),
                            )
                          : _buildPlaceholderPhoto(product),
                    ),
                  ),
                  // Tombol Tambah / Edit Foto Cepat
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showPhotoSourcePicker(context, pos, product),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(4.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            (product.imagePath != null && product.imagePath!.isNotEmpty)
                                ? Icons.edit
                                : Icons.add_a_photo_outlined,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (product.isConsignment)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Titipan',
                          style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                  if (isOutOfStock)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HABIS',
                          style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),

              // 2. Kode & Nama Produk
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.kode,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                  ),
                  Text(
                    product.nama,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isOutOfStock ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                      height: 1.15,
                      decoration: isOutOfStock ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),

              // 3. Harga & Keterangan Stok
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _currencyFormat.format(product.hargaJual),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: isOutOfStock ? Colors.grey : AppConfig.primaryTeal,
                        ),
                      ),
                      Text(
                        '/${product.unit}',
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    product.isUnlimitedStock
                        ? 'Stok: Bebas (∞)'
                        : (isOutOfStock ? 'Stok: Habis' : 'Stok: ${product.stok} ${product.unit}'),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isOutOfStock
                          ? Colors.red.shade700
                          : (product.isUnlimitedStock ? Colors.blue.shade700 : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderPhoto(PosProduct product) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            product.isConsignment ? Icons.handshake_outlined : Icons.inventory_2_outlined,
            size: 26,
            color: product.isConsignment ? Colors.amber.shade700 : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 2),
          Text(
            product.kategori.isNotEmpty ? product.kategori : 'Produk',
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Tampilan Produk Model List yang Rapi Sesuai Web iPay
  Widget _buildProductListItem(PosProvider pos, PosProduct product) {
    final bool isOutOfStock = product.isStockManaged && product.stok <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOutOfStock ? Colors.red.shade100 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (isOutOfStock) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ Stok "${product.nama}" sudah habis!'),
                  backgroundColor: Colors.red.shade800,
                  duration: const Duration(seconds: 2),
                ),
              );
              return;
            }
            final ok = pos.addToCart(product);
            if (!ok && pos.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(pos.errorMessage!),
                  backgroundColor: Colors.orange.shade800,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Thumbnail / Inisial / Icon Box
                GestureDetector(
                  onTap: () => _showPhotoSourcePicker(context, pos, product),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? Colors.grey.shade100
                          : (product.isConsignment ? Colors.amber.shade50 : AppConfig.primaryTeal.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOutOfStock
                            ? Colors.grey.shade300
                            : (product.isConsignment ? Colors.amber.shade300 : AppConfig.primaryTeal.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: (product.imagePath != null && product.imagePath!.isNotEmpty && File(product.imagePath!).existsSync())
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.file(File(product.imagePath!), fit: BoxFit.cover, width: 44, height: 44),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                product.nama.isNotEmpty ? product.nama[0].toUpperCase() : 'P',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isOutOfStock
                                      ? Colors.grey
                                      : (product.isConsignment ? Colors.amber.shade900 : AppConfig.primaryTeal),
                                ),
                              ),
                              Positioned(
                                right: 1,
                                bottom: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(1.5),
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                                  child: const Icon(Icons.add_a_photo, size: 9, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Informasi Produk
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            product.kode,
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(width: 6),
                          if (product.isConsignment)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Text(
                                'Titipan ${product.penitip ?? ""}'.trim(),
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.amber.shade900),
                              ),
                            ),
                          if (isOutOfStock)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Text(
                                'HABIS',
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.red.shade800),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isOutOfStock ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                          decoration: isOutOfStock ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.isUnlimitedStock
                            ? 'Stok: Bebas (∞)'
                            : (isOutOfStock ? 'Stok: Habis' : 'Sisa: ${product.stok} ${product.unit}'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isOutOfStock
                              ? Colors.red.shade700
                              : (product.isUnlimitedStock ? Colors.blue.shade700 : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Harga & Tombol Beli Cepat
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(product.hargaJual),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isOutOfStock ? Colors.grey : AppConfig.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? Colors.grey.shade200 : AppConfig.primaryTeal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOutOfStock ? Icons.block : Icons.add_shopping_cart,
                            size: 13,
                            color: isOutOfStock ? Colors.grey.shade600 : Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOutOfStock ? 'Habis' : 'Beli',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isOutOfStock ? Colors.grey.shade600 : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartBottomBar(PosProvider pos) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConfig.primaryTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${pos.cartTotalQty} Item • Total Belanja',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
                Text(
                  _currencyFormat.format(pos.cartTotal),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _openCartDetailSheet(context, pos),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Periksa & Bayar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bottom Sheet Keranjang & Fitur Ubah Harga Jual Dinamis
  void _openCartDetailSheet(BuildContext context, PosProvider pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cartItems = pos.cart;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Sheet Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Keranjang Kasir',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Sentuh harga untuk ubah harga jual / diskon',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _promptHoldCart(context, pos, ctx),
                              icon: const Icon(Icons.pause_circle_outline, size: 15, color: Color(0xFFB45309)),
                              label: const Text('Tahan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                side: BorderSide(color: Colors.amber.shade400),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                backgroundColor: Colors.amber.shade50,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Cart Item List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: cartItems.length,
                      separatorBuilder: (c, i) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final item = cartItems[idx];
                        return _buildCartRow(context, pos, idx, item, setModalState);
                      },
                    ),
                  ),

                  // Footer Summary & Checkout Button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pos.cartDiscount.abs() > 0.001)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: pos.cartDiscount > 0 ? const Color(0xFFECFDF5) : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  pos.cartDiscount > 0 ? 'Total Potongan Diskon Dinamis:' : 'Penyesuaian Harga Tambahan:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: pos.cartDiscount > 0 ? const Color(0xFF047857) : Colors.red.shade800,
                                  ),
                                ),
                                Text(
                                  '${pos.cartDiscount > 0 ? '-' : '+'} ${_currencyFormat.format(pos.cartDiscount.abs())}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: pos.cartDiscount > 0 ? const Color(0xFF047857) : Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL BAYAR',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                            Text(
                              _currencyFormat.format(pos.cartTotal),
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppConfig.primaryTeal),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openPaymentModal(context, pos);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConfig.primaryTeal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Lanjut Pembayaran (F8)',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartRow(BuildContext context, PosProvider pos, int idx, PosCartItem item, StateSetter setModalState) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.nama,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),

              // Tombol Ubah Harga Jual Dinamis
              InkWell(
                onTap: () => _showDynamicPriceDialog(context, pos, idx, item),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.isBelowCost
                        ? Colors.red.shade50
                        : (item.isPriceModified ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.isBelowCost
                          ? Colors.red.shade300
                          : (item.isPriceModified ? const Color(0xFF6EE7B7) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currencyFormat.format(item.actualPrice),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: item.isBelowCost
                              ? Colors.red.shade800
                              : (item.isPriceModified ? const Color(0xFF047857) : const Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_note,
                        size: 14,
                        color: item.isBelowCost ? Colors.red.shade800 : const Color(0xFF64748B),
                      ),
                      if (item.isBelowCost) ...[
                        const SizedBox(width: 4),
                        const Text(
                          '⚠️ Bawah Modal',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Counter Qty dengan proteksi batas stok
        Builder(
          builder: (ctx) {
            final bool canAddMore = !item.isStockManaged || item.qty < item.product.stok;

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 14),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      pos.updateCartQty(idx, -1);
                      setModalState(() {});
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${item.qty}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add,
                      size: 14,
                      color: canAddMore ? const Color(0xFF0F172A) : Colors.grey.shade400,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      if (canAddMore) {
                        pos.updateCartQty(idx, 1);
                        setModalState(() {});
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('⚠️ Maksimal stok "${item.product.nama}" tercapai (${item.product.stok} ${item.product.unit})'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(width: 12),

        // Subtotal
        SizedBox(
          width: 80,
          child: Text(
            _currencyFormat.format(item.subtotal),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  // Dialog Ubah Harga Jual Dinamis
  void _showDynamicPriceDialog(BuildContext context, PosProvider pos, int idx, PosCartItem item) {
    final priceCtrl = TextEditingController(text: item.actualPrice.toInt().toString());

    showDialog(
      context: context,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final enteredPrice = double.tryParse(priceCtrl.text) ?? 0.0;
            final isBelowCost = enteredPrice < item.costPrice;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ubah Harga Jual Cepat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  Text(item.product.nama, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Harga Modal / Dasar:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            Text(_currencyFormat.format(item.costPrice), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Harga Jual Normal:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            Text(_currencyFormat.format(item.normalPrice), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Harga Jual Baru (Khusus Nota Ini):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  // Indikator Peringatan Bawah Modal
                  if (isBelowCost) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        '⚠️ PERINGATAN: Harga baru di bawah modal (Rugi ${_currencyFormat.format(item.costPrice - enteredPrice)}/item). Sistem mengizinkan, selisih tercatat di audit.',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    pos.resetCartItemPrice(idx);
                    Navigator.pop(dCtx);
                  },
                  child: const Text('Reset Normal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final val = double.tryParse(priceCtrl.text);
                    if (val != null && val >= 0) {
                      pos.updateCartItemPrice(idx, val);
                    }
                    Navigator.pop(dCtx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Modal Pembayaran & Cetak Struk
  void _openPaymentModal(BuildContext context, PosProvider pos) {
    final total = pos.cartTotal;
    final cashCtrl = TextEditingController(text: total.toInt().toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pCtx) {
        return StatefulBuilder(
          builder: (context, setPaymentState) {
            final cashPaid = double.tryParse(cashCtrl.text) ?? total;
            final change = cashPaid - total;

            // Tombol Uang Pas Cepat
            final quickOptions = [
              total,
              (total / 10000).ceil() * 10000.0,
              (total / 50000).ceil() * 50000.0,
              50000.0,
              100000.0,
              200000.0
            ].where((n) => n >= total).toSet().toList();

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pembayaran Tunai', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(pCtx)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Total Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppConfig.primaryTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppConfig.primaryTeal.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        const Text('TOTAL HARUS DIBAYAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        Text(
                          _currencyFormat.format(total),
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppConfig.primaryTeal),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Text('Uang Diterima dari Pelanggan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: cashCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    onChanged: (_) => setPaymentState(() {}),
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Quick cash chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: quickOptions.map((opt) {
                      final isExact = (opt - total).abs() < 0.001;
                      return ActionChip(
                        label: Text(isExact ? 'Uang Pas' : _currencyFormat.format(opt)),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isExact ? Colors.white : const Color(0xFF0F172A),
                        ),
                        backgroundColor: isExact ? AppConfig.primaryTeal : const Color(0xFFF1F5F9),
                        onPressed: () {
                          cashCtrl.text = opt.toInt().toString();
                          setPaymentState(() {});
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Kembalian Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('KEMBALIAN:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        Text(
                          change < 0 ? 'Kurang ${_currencyFormat.format(change.abs())}' : _currencyFormat.format(change),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: change < 0 ? Colors.red.shade700 : const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tombol Selesaikan Transaksi
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Bayar & Cetak Struk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConfig.primaryTeal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: change < 0
                                ? null
                                : () async {
                                    Navigator.pop(pCtx);
                                    final trx = await pos.checkout(
                                      cashPaid: cashPaid,
                                      autoPrint: true,
                                    );
                                    if (trx != null && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✅ Nota ${trx.invoiceNo} tersimpan dan dicetak!'),
                                          backgroundColor: AppConfig.primaryTeal,
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: change < 0
                              ? null
                              : () async {
                                  Navigator.pop(pCtx);
                                  final trx = await pos.checkout(
                                    cashPaid: cashPaid,
                                    autoPrint: false,
                                  );
                                  if (trx != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('✅ Transaksi ${trx.invoiceNo} disimpan!'),
                                        backgroundColor: const Color(0xFF0F172A),
                                      ),
                                    );
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Simpan Saja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // TAB 2: KONSINYASI (MANAJEMEN BARANG TITIPAN)
  // =========================================================================
  Widget _buildConsignmentTab(PosProvider pos) {
    final consignments = pos.consignments;

    return RefreshIndicator(
      onRefresh: () => pos.refreshAll(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Penjelasan
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.handshake, color: Colors.amber.shade900, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konsinyasi & Barang Titipan',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.amber.shade900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hitung otomatis hak setor penitip dan komisi toko. Cetak nota rekap langsung ke printer kasir.',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (consignments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    Text(
                      'Belum ada data barang konsinyasi.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Isi kolom "PENITIP" di file Excel untuk mencatat barang titipan.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            )
          else
            ...consignments.map((c) => _buildConsignmentCard(context, pos, c)),
        ],
      ),
    );
  }

  Widget _buildConsignmentCard(BuildContext context, PosProvider pos, ConsignmentSummary summary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.amber.shade100,
                    child: Text(
                      summary.penitip.isNotEmpty ? summary.penitip[0].toUpperCase() : '?',
                      style: TextStyle(fontWeight: FontWeight.w900, color: Colors.amber.shade900, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.penitip,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${summary.variantCount} Varian Produk • Sisa Stok: ${summary.totalStock} pcs',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: summary.totalSoldQty > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Terjual: ${summary.totalSoldQty} pcs',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: summary.totalSoldQty > 0 ? const Color(0xFF047857) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Detail Perhitungan Bagi Hasil
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Omset Penjualan:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(_currencyFormat.format(summary.totalGross), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Komisi Keuntungan Toko:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(_currencyFormat.format(summary.storeFee), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                  ],
                ),
                const Divider(height: 12, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('HAK WAJIB DISETOR:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    Text(
                      _currencyFormat.format(summary.totalDueToPenitip),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.amber.shade900),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tombol Cetak Rekap Setoran
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Cetak Rekap Setoran (RPP02N)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final ok = await pos.printConsignmentReport(summary);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? '✅ Rekap ${summary.penitip} berhasil dicetak!' : '⚠️ Gagal mencetak. Cek koneksi printer.'),
                          backgroundColor: ok ? AppConfig.primaryTeal : Colors.orange,
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await pos.settleConsignment(summary: summary, andPrint: false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Setoran ${summary.penitip} ditandai lunas!')),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Tandai Lunas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: KELOLA PRODUK & SINKRONISASI EXCEL (8 KOLOM STANDAR)
  // =========================================================================
  Widget _buildProductExcelTab(PosProvider pos) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Action Bar Excel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sinkronisasi Produk Excel',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                'Mendukung 8 Kolom Standar: KODE, NAMA PRODUK, UNIT/SATUAN, HARGA DASAR, HARGA JUAL, BERAT (gr), STOK, KATEGORI + PENITIP.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('Import File Excel', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final count = await pos.importFromExcel();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(count > 0 ? '✅ Berhasil mengimpor $count produk dari Excel!' : 'Tidak ada produk baru yang diimpor.'),
                          backgroundColor: count > 0 ? AppConfig.primaryTeal : Colors.orange,
                        ),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download Template Excel', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await pos.exportTemplate();
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Export Katalog', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      await pos.exportCatalog();
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Tambah Manual', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openAddEditProductDialog(context, pos),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Daftar Tabel Produk
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Daftar Produk (${pos.products.length} Barang Tersimpan)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pos.products.length,
                separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, idx) {
                  final p = pos.products[idx];
                  return ListTile(
                    dense: true,
                    title: Text(p.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    subtitle: Text(
                      '${p.kode} • Modal: ${_currencyFormat.format(p.hargaDasar)} • ${p.kategori} ${p.isConsignment ? "(Titipan: ${p.penitip})" : ""}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currencyFormat.format(p.hargaJual),
                          style: TextStyle(fontWeight: FontWeight.w900, color: AppConfig.primaryTeal, fontSize: 13),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16, color: Color(0xFF64748B)),
                          onPressed: () => _openAddEditProductDialog(context, pos, product: p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                title: const Text('Hapus Produk?'),
                                content: Text('Hapus ${p.nama} (${p.kode})?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                                  TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (ok == true) {
                              final wasHard = await pos.deleteOrArchiveProduct(p.kode);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(wasHard
                                        ? '✅ Produk ${p.nama} dihapus permanen.'
                                        : '📦 Produk ${p.nama} memiliki riwayat transaksi, berhasil diarsipkan dengan aman.'),
                                    backgroundColor: wasHard ? Colors.green : Colors.orange.shade800,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Dialog Tambah/Edit Produk Manual (POS 2.0: Stok Opsional & Model Komisi)
  void _openAddEditProductDialog(BuildContext context, PosProvider pos, {PosProduct? product}) {
    final kodeCtrl = TextEditingController(text: product?.kode ?? '');
    final namaCtrl = TextEditingController(text: product?.nama ?? '');
    final unitCtrl = TextEditingController(text: product?.unit ?? 'pcs');
    final dasarCtrl = TextEditingController(text: product != null ? product.hargaDasar.toInt().toString() : '');
    final jualCtrl = TextEditingController(text: product != null ? product.hargaJual.toInt().toString() : '');
    final beratCtrl = TextEditingController(text: product != null ? product.beratGr.toInt().toString() : '0');
    final stokCtrl = TextEditingController(text: (product != null && product.isStockManaged && product.stok >= 0) ? product.stok.toString() : '10');
    final kategoriCtrl = TextEditingController(text: product?.kategori ?? 'Umum');
    final penitipCtrl = TextEditingController(text: product?.penitip ?? '');
    final commValCtrl = TextEditingController(text: product != null && product.commissionValue > 0 ? product.commissionValue.toInt().toString() : '0');

    bool isStockManaged = product?.isStockManaged ?? (product != null ? product.stok >= 0 : true);
    String productType = product?.productType ?? ((product?.penitip != null && product!.penitip!.trim().isNotEmpty) ? 'consignment' : 'shop');
    String commType = product?.commissionType ?? 'markup';
    String? currentImagePath = product?.imagePath;

    showDialog(
      context: context,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final isConsignment = productType == 'consignment';

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                product == null ? 'Tambah Produk POS 2.0' : 'Edit Produk POS 2.0',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto Produk Box
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: (currentImagePath != null && currentImagePath!.isNotEmpty && File(currentImagePath!).existsSync())
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(13),
                                    child: Image.file(File(currentImagePath!), fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined, size: 30, color: Colors.grey.shade500),
                                      const SizedBox(height: 4),
                                      Text('Foto Produk', style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  final path = await PosImageService.instance.pickAndCompressImage(source: ImageSource.camera);
                                  if (path != null) {
                                    setDlgState(() => currentImagePath = path);
                                  }
                                },
                                icon: const Icon(Icons.camera_alt, size: 14),
                                label: const Text('Kamera', style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final path = await PosImageService.instance.pickAndCompressImage(source: ImageSource.gallery);
                                  if (path != null) {
                                    setDlgState(() => currentImagePath = path);
                                  }
                                },
                                icon: const Icon(Icons.photo_library, size: 14),
                                label: const Text('Galeri', style: TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              ),
                              if (currentImagePath != null)
                                IconButton(
                                  onPressed: () => setDlgState(() => currentImagePath = null),
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  tooltip: 'Hapus Foto',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: kodeCtrl,
                      decoration: InputDecoration(
                        labelText: 'Kode / SKU Produk (Opsional)',
                        hintText: 'Scan kemasan / generate otomatis',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppConfig.primaryTeal),
                              tooltip: 'Scan Barcode Kemasan Barang',
                              onPressed: () async {
                                final scanned = await PosScannerModal.scanSingle(context);
                                if (scanned != null && scanned.isNotEmpty) {
                                  kodeCtrl.text = scanned;
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.orange),
                              tooltip: 'Generate Kode Angka Anti-Bentrok',
                              onPressed: () {
                                final existing = pos.products.map((p) => p.kode).toSet();
                                final code = PosProductHelper.generateNumericCode(existingCodes: existing);
                                kodeCtrl.text = code;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: 'Nama Produk *')),
                    const SizedBox(height: 10),

                    // Jenis Produk (Toko, Konsinyasi, Jasa)
                    const Text('Jenis Produk:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: productType,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'shop', child: Text('Barang Toko Sendiri')),
                        DropdownMenuItem(value: 'consignment', child: Text('Titipan / Konsinyasi')),
                        DropdownMenuItem(value: 'service', child: Text('Jasa / Layanan (Bebas Stok)')),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setDlgState(() {
                          productType = val;
                          if (val == 'service') {
                            isStockManaged = false;
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    // Switch Kelola Stok
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kelola Stok Produk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(
                                isStockManaged ? 'Stok dihitung & berkurang saat terjual' : 'Bebas stok (tanpa batas / makanan & jasa)',
                                style: TextStyle(fontSize: 10, color: isStockManaged ? AppConfig.primaryTeal : Colors.orange.shade800),
                              ),
                            ],
                          ),
                          Switch(
                            value: isStockManaged,
                            activeTrackColor: AppConfig.primaryTeal.withValues(alpha: 0.5),
                            activeThumbColor: AppConfig.primaryTeal,
                            onChanged: (val) {
                              setDlgState(() {
                                isStockManaged = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Satuan (pcs/cup/bks)'))),
                        const SizedBox(width: 8),
                        if (isStockManaged)
                          Expanded(child: TextField(controller: stokCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah Stok')))
                        else
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 14),
                              child: Text('Stok: Bebas (∞)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            ),
                          ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: dasarCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga Dasar (Modal)'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: jualCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga Jual'))),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(child: TextField(controller: beratCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Berat (gram)'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: kategoriCtrl, decoration: const InputDecoration(labelText: 'Kategori'))),
                      ],
                    ),

                    // Pengaturan Konsinyasi Khusus
                    if (isConsignment) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pengaturan Mitra Titipan (Konsinyasi)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF78350F))),
                            TextField(
                              controller: penitipCtrl,
                              decoration: const InputDecoration(labelText: 'Nama Penitip / Vendor'),
                            ),
                            const SizedBox(height: 6),
                            const Text('Model Pembagian Komisi Toko:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF78350F))),
                            DropdownButtonFormField<String>(
                              initialValue: commType,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                              items: const [
                                DropdownMenuItem(value: 'markup', child: Text('Markup (Selisih Harga Jual - Modal)', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'nominal', child: Text('Komisi Nominal Tetap (Rp per pcs)', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'percent', child: Text('Komisi Persentase (% dari Penjualan)', style: TextStyle(fontSize: 11))),
                              ],
                              onChanged: (v) {
                                if (v != null) setDlgState(() => commType = v);
                              },
                            ),
                            if (commType != 'markup')
                              TextField(
                                controller: commValCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: commType == 'nominal' ? 'Nominal Komisi Toko (Rp)' : 'Persentase Komisi Toko (%)',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () async {
                    if (namaCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Nama produk wajib diisi!')),
                      );
                      return;
                    }
                    String effectiveKode = kodeCtrl.text.trim();
                    if (effectiveKode.isEmpty) {
                      final existing = pos.products.map((p) => p.kode).toSet();
                      effectiveKode = PosProductHelper.generateNumericCode(existingCodes: existing);
                    }
                    final parsedStok = isStockManaged ? (int.tryParse(stokCtrl.text) ?? 0) : -1;
                    final newP = PosProduct(
                      id: product?.id,
                      kode: effectiveKode,
                      nama: namaCtrl.text.trim(),
                      unit: unitCtrl.text.trim().isEmpty ? 'pcs' : unitCtrl.text.trim(),
                      hargaDasar: double.tryParse(dasarCtrl.text) ?? 0.0,
                      hargaJual: double.tryParse(jualCtrl.text) ?? 0.0,
                      beratGr: double.tryParse(beratCtrl.text) ?? 0.0,
                      stok: parsedStok,
                      isStockManaged: isStockManaged,
                      kategori: kategoriCtrl.text.trim().isEmpty ? 'Umum' : kategoriCtrl.text.trim(),
                      penitip: isConsignment && penitipCtrl.text.trim().isNotEmpty ? penitipCtrl.text.trim() : null,
                      productType: productType,
                      commissionType: commType,
                      commissionValue: double.tryParse(commValCtrl.text) ?? 0.0,
                      imagePath: currentImagePath,
                    );
                    await pos.saveProduct(newP);
                    if (dCtx.mounted) Navigator.pop(dCtx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppConfig.primaryTeal, foregroundColor: Colors.white),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // TAB 4: RIWAYAT PENJUALAN, TUTUP KAS HARIAN & BACKUP
  // =========================================================================
  Widget _buildHistoryReportTab(PosProvider pos) {
    final stats = pos.todayStats;
    final trxs = pos.transactions;

    return RefreshIndicator(
      onRefresh: () => pos.refreshAll(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Grid 4 Kartu Statistik
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildStatCard('Omset Hari Ini', stats['total_omset'] ?? 0.0, const Color(0xFF0F172A)),
              _buildStatCard('Estimasi Laba Bersih', stats['total_profit'] ?? 0.0, const Color(0xFF047857)),
              _buildStatCard('Hak Konsinyasi', stats['total_consignment_due'] ?? 0.0, Colors.amber.shade900),
              _buildStatCard('Kas Masuk (Tunai)', stats['cash_omset'] ?? 0.0, Colors.blue.shade800),
            ],
          ),

          const SizedBox(height: 14),

          // Tombol Tindakan Utama: Cetak Rekap Kas Harian (Laporan Z)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Cetak Rekap Kas Harian (Laporan Z)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final closing = await pos.closeDailyCash(andPrint: true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(closing != null
                              ? '✅ Struk Rekap Kas Harian berhasil dicetak ke printer!'
                              : '⚠️ Gagal mencetak rekap kas harian.'),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Card Cadangan & Pemulihan Data (Backup & Restore)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: AppConfig.primaryTeal),
                    const SizedBox(width: 6),
                    const Text('Cadangan & Pemulihan Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '100% Offline • Simpan cadangan database ke memori HP atau bagikan via WhatsApp / Google Drive',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Cadangkan Data', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final ok = await pos.shareBackupDatabase();
                          if (mounted && !ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('⚠️ Gagal membuat file cadangan database.')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('Pulihkan Data', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              title: const Text('Pulihkan Database?'),
                              content: const Text(
                                  'Memulihkan database akan menimpa data kasir saat ini dengan file cadangan yang Anda pilih. Pastikan Anda memilih file yang benar.\n\nLanjutkan?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                                TextButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  child: const Text('Pilih File Cadangan', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final err = await pos.restoreDatabase();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err == null ? '✅ Database kasir berhasil dipulihkan!' : '⚠️ $err'),
                                  backgroundColor: err == null ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Card Informasi & Cek Pembaruan APK
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppConfig.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.system_update_rounded, size: 20, color: AppConfig.primaryTeal),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Aplikasi IPAY Android',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppConfig.primaryTeal.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'v${AppConfig.appVersion}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppConfig.primaryTeal),
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Kasir POS Offline • Bluetooth ESC/POS Native',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Cek Pembaruan APK', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => AppUpdateService().checkForUpdate(context, silent: false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.auto_awesome, size: 15, color: AppConfig.primaryTeal),
                      label: const Text('Fitur Baru', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConfig.primaryTeal)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onPressed: () => AppUpdateService().showWhatsNewDialog(context, force: true),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Riwayat Transaksi Terakhir',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),

          if (trxs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('Belum ada transaksi hari ini', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            )
          else
            ...trxs.map((t) => _buildTransactionCard(pos, t)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double amount, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: valueColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(PosProvider pos, PosTransaction trx) {
    final isCancelled = trx.isCancelled;
    final isPartialReturn = trx.isPartiallyReturned;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCancelled
              ? Colors.red.shade200
              : (isPartialReturn ? Colors.amber.shade300 : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTransactionDetailSheet(context, pos, trx),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              trx.invoiceNo,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: isCancelled ? Colors.red.shade700 : const Color(0xFF0F172A),
                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isCancelled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Text('BATAL', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                            )
                          else if (isPartialReturn)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.shade400),
                              ),
                              child: Text('RETUR', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                            ),
                          // Indikator Audit Perubahan Harga Kasir (Beda Warna)
                          if (!isCancelled) ...[
                            if (trx.items.any((it) => it.isBelowCost)) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Text('⚠️ BAWAH MODAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                              ),
                            ],
                            if (trx.items.any((it) => it.soldPrice < it.normalPrice - 0.001)) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFF59E0B)),
                                ),
                                child: const Text('🏷️ DISKON', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                              ),
                            ],
                            if (trx.items.any((it) => it.soldPrice > it.normalPrice + 0.001)) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF38BDF8)),
                                ),
                                child: const Text('🏷️ HARGA NAIK', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                              ),
                            ],
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${trx.dateTime.hour.toString().padLeft(2, '0')}:${trx.dateTime.minute.toString().padLeft(2, '0')} • ${trx.totalActiveItemsQty} Item Aktif • Laba: ${_currencyFormat.format(trx.profitAmount)}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currencyFormat.format(trx.totalAmount),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isCancelled ? Colors.grey : AppConfig.primaryTeal,
                          ),
                        ),
                        Text(
                          trx.paymentMethod,
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: Color(0xFF25D366)),
                      tooltip: 'Kirim Struk via WhatsApp',
                      onPressed: () => _showWhatsAppReceiptDialog(context, trx),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_outlined, size: 20, color: Color(0xFF475569)),
                      tooltip: 'Cetak Ulang Struk',
                      onPressed: () async {
                        final ok = await pos.printReceipt(trx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? '✅ Struk ${trx.invoiceNo} dicetak ulang!' : '⚠️ Gagal mencetak.')),
                          );
                        }
                      },
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DETAIL TRANSAKSI & DIALOG RETUR SEBAGIAN
  // ==========================================

  void _showTransactionDetailSheet(BuildContext context, PosProvider pos, PosTransaction trx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setSheetState) {
            // Ambil data transaksi terbaru dari state provider
            final currentTrx = pos.transactions.firstWhere(
              (t) => t.invoiceNo == trx.invoiceNo,
              orElse: () => trx,
            );

            final isCancelled = currentTrx.isCancelled;
            final isPartial = currentTrx.isPartiallyReturned;

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle Bar
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header Nota
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  currentTrx.invoiceNo,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCancelled
                                        ? Colors.red.shade50
                                        : (isPartial ? Colors.amber.shade50 : Colors.green.shade50),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isCancelled
                                          ? Colors.red.shade300
                                          : (isPartial ? Colors.amber.shade300 : Colors.green.shade300),
                                    ),
                                  ),
                                  child: Text(
                                    isCancelled ? 'BATAL' : (isPartial ? 'RETUR SEBAGIAN' : 'SELESAI'),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isCancelled
                                          ? Colors.red.shade800
                                          : (isPartial ? Colors.amber.shade900 : Colors.green.shade800),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${currentTrx.dateTime.day}/${currentTrx.dateTime.month}/${currentTrx.dateTime.year} ${currentTrx.dateTime.hour.toString().padLeft(2, '0')}:${currentTrx.dateTime.minute.toString().padLeft(2, '0')} • Kasir: ${currentTrx.cashierName ?? "Kasir"}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 22, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Konten Scrollable
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 1. DAFTAR BARANG YANG DIBELI
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Rincian Barang Belanjaan',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '${currentTrx.totalActiveItemsQty} Item Aktif',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        ...currentTrx.items.map((item) {
                          final isPriceDecreased = item.soldPrice < item.normalPrice - 0.001;
                          final isPriceIncreased = item.soldPrice > item.normalPrice + 0.001;
                          final double priceDiff = (item.soldPrice - item.normalPrice).abs();
                          final bool canReturnItem = !isCancelled && item.activeQty > 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: item.isFullyReturned ? Colors.red.shade200 : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  item.productName,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: item.isFullyReturned ? Colors.grey : const Color(0xFF0F172A),
                                                    decoration: item.isFullyReturned ? TextDecoration.lineThrough : null,
                                                  ),
                                                ),
                                              ),
                                              if (item.isConsignment) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.amber.shade300),
                                                  ),
                                                  child: Text(
                                                    'Titipan: ${item.penitip ?? ""}',
                                                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.amber.shade900),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.productKode} • Harga Jual: ${_currencyFormat.format(item.soldPrice)}/${item.unit}',
                                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                          ),
                                          if (isPriceDecreased) ...[
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFF59E0B)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.arrow_downward_rounded, size: 12, color: Color(0xFFB45309)),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'Didiskon Kasir: -${_currencyFormat.format(priceDiff)} (Normal: ${_currencyFormat.format(item.normalPrice)})',
                                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                                                  ),
                                                  if (item.isBelowCost) ...[
                                                    const SizedBox(width: 4),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.shade700,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text('Bawah Modal', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ] else if (isPriceIncreased) ...[
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE0F2FE),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFF0284C7)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.arrow_upward_rounded, size: 12, color: Color(0xFF0369A1)),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    'Dinaikkan Kasir: +${_currencyFormat.format(priceDiff)} (Normal: ${_currencyFormat.format(item.normalPrice)})',
                                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF0369A1)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _currencyFormat.format(item.activeSubtotal),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w900,
                                            color: item.isFullyReturned ? Colors.grey : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          'Qty: ${item.activeQty} ${item.unit}',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // Status Retur pada Item
                                if (item.returnedQty > 0) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '⚠️ Diretur: ${item.returnedQty} ${item.unit}',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                        ),
                                        Text(
                                          'Pengembalian: ${_currencyFormat.format(item.returnedQty * item.soldPrice)}',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Tombol Aksi Retur Item Ini
                                if (canReturnItem) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        _showReturnItemDialog(context, pos, currentTrx, item, onCompleted: () {
                                          setSheetState(() {});
                                        });
                                      },
                                      icon: const Icon(Icons.replay_rounded, size: 14, color: Colors.orange),
                                      label: const Text('Retur Produk Ini', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        side: const BorderSide(color: Colors.orange),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 12),

                        // 2. RINGKASAN FINANSIAL
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ringkasan Pembayaran', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 10),
                              _buildDetailRow('Metode Pembayaran', currentTrx.paymentMethod),
                              _buildDetailRow('Total Normal', _currencyFormat.format(currentTrx.normalAmount)),
                              if (currentTrx.discountAmount > 0)
                                _buildDetailRow('Potongan Diskon', '- ${_currencyFormat.format(currentTrx.discountAmount)}', color: Colors.green.shade700),
                              const Divider(height: 16),
                              _buildDetailRow(
                                'TOTAL TAGIHAN AKHIR',
                                _currencyFormat.format(currentTrx.totalAmount),
                                isBold: true,
                                color: AppConfig.primaryTeal,
                              ),
                              _buildDetailRow('Uang Diterima', _currencyFormat.format(currentTrx.cashPaid)),
                              _buildDetailRow('Kembalian', _currencyFormat.format(currentTrx.changeDue)),
                              const Divider(height: 16),
                              _buildDetailRow('Keuntungan Bersih Toko', _currencyFormat.format(currentTrx.profitAmount), color: Colors.blue.shade800),
                              if (currentTrx.consignmentDueAmount > 0)
                                _buildDetailRow('Hak Bagi Hasil Penitip', _currencyFormat.format(currentTrx.consignmentDueAmount), color: Colors.amber.shade900),
                              if (currentTrx.note != null && currentTrx.note!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('Catatan: ${currentTrx.note!}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                              ],
                            ],
                          ),
                        ),

                        // 3. RIWAYAT RETUR / REFUND (JIKA ADA)
                        if (currentTrx.returns.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.history_rounded, size: 16, color: Colors.deepOrange),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Riwayat Retur & Pengembalian Dana (${currentTrx.returns.length})',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.deepOrange.shade900),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...currentTrx.returns.map((ret) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${ret.qtyReturned}x ${ret.productName}',
                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                              ),
                                              Text(
                                                'Alasan: ${ret.reason ?? "-"} • ${ret.createdAt.hour.toString().padLeft(2, '0')}:${ret.createdAt.minute.toString().padLeft(2, '0')}',
                                                style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '- ${_currencyFormat.format(ret.refundAmount)}',
                                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.red),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.print_outlined, size: 16, color: Colors.deepOrange),
                                              tooltip: 'Cetak Bukti Retur',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () async {
                                                final ok = await pos.printReturnReceipt(currentTrx, ret);
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(this.context).showSnackBar(
                                                  SnackBar(content: Text(ok ? '✅ Struk retur dicetak!' : '⚠️ Gagal mencetak struk retur.')),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Bottom Action Buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final ok = await pos.printReceipt(currentTrx);
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(content: Text(ok ? '✅ Struk transaksi dicetak ulang!' : '⚠️ Gagal mencetak struk.')),
                              );
                            },
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Cetak Struk'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConfig.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showWhatsAppReceiptDialog(context, currentTrx),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                            label: const Text('Kirim WA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        if (!isCancelled && currentTrx.totalActiveItemsQty > 0) ...[
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: this.context,
                                builder: (d) => AlertDialog(
                                  title: const Text('Batalkan Seluruh Nota?'),
                                  content: Text('Batalkan transaksi ${currentTrx.invoiceNo}?\nSemua sisa stok barang akan dikembalikan ke etalase dan transaksi dinyatakan batal penuh.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, true),
                                      child: const Text('Ya, Batalkan Semua', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                final ok = await pos.cancelTransaction(currentTrx.invoiceNo, reason: 'Pembatalan Kasir (Penuh)');
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(content: Text(ok ? '✅ Transaksi ${currentTrx.invoiceNo} telah dibatalkan penuh.' : '⚠️ Gagal membatalkan.')),
                                );
                                setSheetState(() {});
                              }
                            },
                            icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                            label: const Text('Batal Semua', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog Retur Item Spesifik
  void _showReturnItemDialog(
    BuildContext context,
    PosProvider pos,
    PosTransaction trx,
    PosTransactionItem item, {
    VoidCallback? onCompleted,
  }) {
    int returnQty = 1;
    final reasonCtrl = TextEditingController(text: 'Pelanggan berubah pikiran / barang rusak');
    bool autoPrint = true;

    showDialog(
      context: context,
      builder: (dCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final double refundTotal = returnQty * item.soldPrice;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.replay_rounded, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Retur Produk', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Harga Satuan: ${_currencyFormat.format(item.soldPrice)} • Tersedia untuk Diretur: ${item.activeQty} ${item.unit}',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),

                  // Counter Jumlah Unit yang Diretur
                  const Text('Jumlah Unit yang Dikembalikan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: returnQty > 1 ? () => setDialogState(() => returnQty--) : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                '$returnQty',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: returnQty < item.activeQty ? () => setDialogState(() => returnQty++) : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'dari total ${item.activeQty} ${item.unit}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Alasan Retur
                  const Text('Alasan Pengembalian:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Kemasan cacat, salah varian...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Total Refund Uang
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Uang Dikembalikan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                        Text(
                          _currencyFormat.format(refundTotal),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.red),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Opsi Auto Print
                  Row(
                    children: [
                      Checkbox(
                        value: autoPrint,
                        activeColor: AppConfig.primaryTeal,
                        onChanged: (v) => setDialogState(() => autoPrint = v ?? true),
                      ),
                      const Expanded(
                        child: Text(
                          'Cetak struk bukti retur ke printer thermal',
                          style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dCtx);

                    final returnRecord = await pos.returnTransactionItem(
                      invoiceNo: trx.invoiceNo,
                      productKode: item.productKode,
                      qtyToReturn: returnQty,
                      reason: reasonCtrl.text.trim(),
                      autoPrint: autoPrint,
                    );

                    if (!mounted) return;
                    if (returnRecord != null) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Retur $returnQty unit ${item.productName} berhasil diproses.'),
                          backgroundColor: Colors.green.shade800,
                        ),
                      );
                      if (onCompleted != null) onCompleted();
                    } else {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text('⚠️ ${pos.errorMessage ?? "Gagal memproses retur."}'),
                          backgroundColor: Colors.red.shade800,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Proses Retur'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // HELPER METODE: FOTO PRODUK, HOLD CART & STRUK WHATSAPP
  // =========================================================================

  void _showPhotoSourcePicker(BuildContext context, PosProvider pos, PosProduct product) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foto Produk: ${product.nama}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Text(
                'Foto otomatis dikompresi agar hemat memori HP & rendering tetap lancar.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppConfig.primaryTeal.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, color: AppConfig.primaryTeal),
                ),
                title: const Text('Ambil Foto Kamera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Foto fisik barang langsung di kasir', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(bCtx);
                  final path = await PosImageService.instance.pickAndCompressImage(source: ImageSource.camera);
                  if (path != null) {
                    await pos.updateProductPhoto(product, path);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ Foto "${product.nama}" berhasil disimpan!')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library, color: Colors.blue),
                ),
                title: const Text('Pilih dari Galeri HP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Pilih gambar dari album foto HP Anda', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(bCtx);
                  final path = await PosImageService.instance.pickAndCompressImage(source: ImageSource.gallery);
                  if (path != null) {
                    await pos.updateProductPhoto(product, path);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ Foto "${product.nama}" berhasil disimpan!')),
                      );
                    }
                  }
                },
              ),
              if (product.imagePath != null && product.imagePath!.isNotEmpty)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text('Hapus Foto Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(bCtx);
                    await pos.updateProductPhoto(product, null);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('🗑️ Foto "${product.nama}" telah dihapus.')),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptHoldCart(BuildContext context, PosProvider pos, BuildContext sheetCtx) {
    final noteCtrl = TextEditingController(text: 'Antrean #${pos.holdCartsCount + 1}');
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tahan Keranjang Belanja', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keranjang belanja aktif saat ini akan disimpan sementara, sehingga kasir dapat melayani pelanggan berikutnya.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Catatan / Nama Pelanggan',
                hintText: 'Contoh: Ibu kerudung merah / Meja 2',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(d);
              Navigator.pop(sheetCtx);
              final ok = await pos.holdCurrentCart(note: noteCtrl.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? '⏸️ Antrean berhasil ditahan. Silakan layani pelanggan berikutnya.' : '⚠️ Gagal menahan antrean.'),
                    backgroundColor: Colors.amber.shade800,
                  ),
                );
              }
            },
            child: const Text('Tahan Sekarang'),
          ),
        ],
      ),
    );
  }

  void _showHoldCartsSheet(BuildContext context, PosProvider pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final holdList = pos.holdCarts;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pause_circle_outline, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Text(
                              'Antrean Ditahan (${holdList.length})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: holdList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade400),
                                const SizedBox(height: 8),
                                const Text('Tidak ada antrean yang ditahan.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: holdList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final item = holdList[idx];
                              final cartId = item['cart_id'] as String;
                              final note = item['customer_note'] as String? ?? 'Antrean #${idx + 1}';
                              final total = (item['total_amount'] as num?)?.toDouble() ?? 0.0;
                              final holdAt = item['hold_at'] as String? ?? '';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.amber.shade100, shape: BoxShape.circle),
                                      child: Icon(Icons.shopping_bag_outlined, size: 20, color: Colors.amber.shade900),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(note, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Waktu: $holdAt • Total: ${_currencyFormat.format(total)}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppConfig.primaryTeal,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      onPressed: () async {
                                        if (pos.cart.isNotEmpty) {
                                          final overwrite = await showDialog<bool>(
                                            context: context,
                                            builder: (d) => AlertDialog(
                                              title: const Text('Keranjang Aktif Terisi'),
                                              content: const Text('Keranjang kasir saat ini masih berisi barang. Apakah Anda ingin menahan transaksi saat ini lalu memulihkan antrean yang dipilih?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(d, true),
                                                  child: const Text('Tahan Aktif & Pulihkan Ini'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (overwrite != true) return;
                                          await pos.holdCurrentCart(note: 'Otomatis Ditahan #${DateTime.now().minute}');
                                        }

                                        final ok = await pos.restoreHoldCart(cartId);
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(ok ? '✅ Antrean "$note" berhasil dipulihkan!' : '⚠️ Gagal memulihkan antrean.')),
                                          );
                                        }
                                      },
                                      child: const Text('Pulihkan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      tooltip: 'Hapus Antrean',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (d) => AlertDialog(
                                            title: const Text('Hapus Antrean?'),
                                            content: Text('Hapus antrean "$note"?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                                              TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await pos.deleteHoldCart(cartId);
                                          setModalState(() {});
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWhatsAppReceiptDialog(BuildContext context, PosTransaction trx) {
    final phoneCtrl = TextEditingController();
    final receiptPreview = PosWhatsappService.instance.generateReceiptText(trx: trx);

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('Kirim Struk via WhatsApp', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan nomor WhatsApp pembeli (opsional) atau langsung bagikan struk:',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor WhatsApp Pembeli',
                  hintText: '0812xxxxxxx atau 62812xxxxxxx',
                  prefixIcon: Icon(Icons.phone_android, size: 20),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Pratinjau Format Struk:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Text(
                    receiptPreview,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Color(0xFF1E293B)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(d);
              final ok = await PosWhatsappService.instance.sendReceiptViaWhatsApp(
                trx: trx,
                customerPhone: phoneCtrl.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? '✅ Struk nota dikirim ke WhatsApp!' : '⚠️ Gagal membuka WhatsApp.'),
                    backgroundColor: const Color(0xFF25D366),
                  ),
                );
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Kirim WhatsApp'),
          ),
        ],
      ),
    );
  }
}
