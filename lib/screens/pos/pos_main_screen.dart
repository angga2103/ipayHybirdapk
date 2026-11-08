import '../../models/pos_customer.dart';
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
import 'package:url_launcher/url_launcher.dart';
import '../../models/pos_debt.dart';
import '../../services/pos_backup_service.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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
          // Tombol Pintas Master Data Pelanggan
          IconButton(
            icon: const Icon(Icons.people_alt_rounded, color: AppConfig.primaryTeal, size: 22),
            tooltip: 'Data Pelanggan & Kasbon',
            onPressed: () => _tabController.animateTo(1),
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
            Tab(icon: Icon(Icons.people_alt_outlined, size: 20), text: 'Pelanggan'),
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
          _buildCustomersTab(pos),
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
            // Status Shift Kasir & Modal Awal
            _buildShiftStatusBar(pos),

            // Bar Pemilih Pelanggan Aktif Kasir
            _buildCustomerSelectorBar(pos),

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

  // Modal Pembayaran & Cetak Struk (Tunai, QRIS, & Kasbon)
  void _openPaymentModal(BuildContext context, PosProvider pos) {
    final total = pos.cartTotal;
    final cashCtrl = TextEditingController(text: total.toInt().toString());
    final customerNameCtrl = TextEditingController(
      text: pos.selectedCustomer != null ? pos.selectedCustomer!.name : '',
    );
    final customerPhoneCtrl = TextEditingController(
      text: pos.selectedCustomer != null ? (pos.selectedCustomer!.phone ?? '') : '',
    );
    final debtNoteCtrl = TextEditingController();
    String paymentMethod = 'Tunai';
    int dueDays = 7;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (pCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setPaymentState) {
            final cashPaid = double.tryParse(cashCtrl.text) ?? total;
            final change = cashPaid - total;

            // Tombol Uang Pas Cepat (khusus Tunai)
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
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          paymentMethod == 'Tunai'
                              ? 'Pembayaran Kasir (Tunai)'
                              : paymentMethod == 'QRIS'
                                  ? 'Pembayaran Non-Tunai (QRIS)'
                                  : 'Catat Kasbon / Piutang Warung',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(pCtx)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Segmented Button 3 Pilihan: Tunai, QRIS, Kasbon
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setPaymentState(() => paymentMethod = 'Tunai'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: paymentMethod == 'Tunai' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: paymentMethod == 'Tunai'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.payments_outlined,
                                        size: 15,
                                        color: paymentMethod == 'Tunai' ? AppConfig.primaryTeal : const Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tunai',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: paymentMethod == 'Tunai' ? AppConfig.primaryTeal : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setPaymentState(() => paymentMethod = 'QRIS'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: paymentMethod == 'QRIS' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: paymentMethod == 'QRIS'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.qr_code_2_rounded,
                                        size: 15,
                                        color: paymentMethod == 'QRIS' ? Colors.blue.shade700 : const Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'QRIS',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: paymentMethod == 'QRIS' ? Colors.blue.shade700 : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setPaymentState(() => paymentMethod = 'Kasbon'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: paymentMethod == 'Kasbon' ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: paymentMethod == 'Kasbon'
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.menu_book_rounded,
                                        size: 15,
                                        color: paymentMethod == 'Kasbon' ? Colors.purple : const Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Kasbon',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: paymentMethod == 'Kasbon' ? Colors.purple : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Total Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (paymentMethod == 'Tunai'
                                ? AppConfig.primaryTeal
                                : paymentMethod == 'QRIS'
                                    ? Colors.blue.shade700
                                    : Colors.purple)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (paymentMethod == 'Tunai'
                                  ? AppConfig.primaryTeal
                                  : paymentMethod == 'QRIS'
                                      ? Colors.blue.shade700
                                      : Colors.purple)
                              .withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            paymentMethod == 'Kasbon' ? 'TOTAL KASBON / PIUTANG' : 'TOTAL HARUS DIBAYAR',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                          Text(
                            _currencyFormat.format(total),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: paymentMethod == 'Tunai'
                                  ? AppConfig.primaryTeal
                                  : paymentMethod == 'QRIS'
                                      ? Colors.blue.shade700
                                      : Colors.purple.shade700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pelanggan: ${pos.effectiveCustomerName}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),

                    if (paymentMethod == 'Tunai') ...[
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
                    ] else if (paymentMethod == 'QRIS') ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.qr_code_2, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pembayaran Scan QRIS',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Minta pembeli scan barcode QRIS toko. Pembayaran uang pas langsung masuk ke saldo rekening/e-wallet.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // FORM KASBON
                      const SizedBox(height: 14),
                      const Text('Nama Pelanggan / Peminjam *:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: customerNameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Bu Ani Warung / Pak Budi',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Nomor WhatsApp (Opsional):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: customerPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Contoh: 081234567890 (untuk kirim tagihan WA)',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Jangka Waktu Jatuh Tempo:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('3 Hari'),
                            selected: dueDays == 3,
                            onSelected: (_) => setPaymentState(() => dueDays = 3),
                          ),
                          ChoiceChip(
                            label: const Text('7 Hari (1 Minggu)'),
                            selected: dueDays == 7,
                            onSelected: (_) => setPaymentState(() => dueDays = 7),
                          ),
                          ChoiceChip(
                            label: const Text('14 Hari (2 Minggu)'),
                            selected: dueDays == 14,
                            onSelected: (_) => setPaymentState(() => dueDays = 14),
                          ),
                          ChoiceChip(
                            label: const Text('30 Hari (1 Bulan)'),
                            selected: dueDays == 30,
                            onSelected: (_) => setPaymentState(() => dueDays = 30),
                          ),
                          ChoiceChip(
                            label: const Text('Tanpa Tempo'),
                            selected: dueDays == 0,
                            onSelected: (_) => setPaymentState(() => dueDays = 0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('Catatan Kasbon (Opsional):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: debtNoteCtrl,
                        decoration: InputDecoration(
                          hintText: 'Keterangan tambahan...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Tombol Selesaikan Transaksi
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.print, size: 18),
                              label: Text(
                                paymentMethod == 'Tunai'
                                    ? 'Bayar & Cetak Struk'
                                    : paymentMethod == 'QRIS'
                                        ? 'Simpan & Cetak QRIS'
                                        : 'Catat & Cetak Kasbon',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: paymentMethod == 'Tunai'
                                    ? AppConfig.primaryTeal
                                    : paymentMethod == 'QRIS'
                                        ? Colors.blue.shade700
                                        : Colors.purple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: (paymentMethod == 'Tunai' && change < 0)
                                  ? null
                                  : () async {
                                      final isDebt = paymentMethod == 'Kasbon';
                                      if (isDebt && customerNameCtrl.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(modalCtx).showSnackBar(
                                          const SnackBar(
                                            content: Text('⚠️ Nama pelanggan kasbon wajib diisi!'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }
                                      Navigator.pop(pCtx);
                                      final dueDate = (isDebt && dueDays > 0)
                                          ? DateTime.now().add(Duration(days: dueDays))
                                          : null;
                                      final trx = await pos.checkout(
                                        cashPaid: paymentMethod == 'Tunai' ? cashPaid : total,
                                        paymentMethod: paymentMethod,
                                        customerId: isDebt ? null : pos.selectedCustomer?.id,
                                        customerName: isDebt
                                            ? customerNameCtrl.text.trim()
                                            : pos.effectiveCustomerName,
                                        customerPhone: isDebt
                                            ? customerPhoneCtrl.text.trim()
                                            : pos.selectedCustomer?.phone,
                                        dueDate: dueDate,
                                        note: isDebt ? debtNoteCtrl.text.trim() : null,
                                        autoPrint: true,
                                      );
                                      if (trx != null && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(isDebt
                                                ? '✅ Kasbon atas nama ${customerNameCtrl.text.trim()} tercatat dan dicetak!'
                                                : '✅ Transaksi ${trx.invoiceNo} tersimpan dan dicetak!'),
                                            backgroundColor: isDebt
                                                ? Colors.purple
                                                : paymentMethod == 'QRIS'
                                                    ? Colors.blue.shade700
                                                    : AppConfig.primaryTeal,
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
                            onPressed: (paymentMethod == 'Tunai' && change < 0)
                                ? null
                                : () async {
                                    final isDebt = paymentMethod == 'Kasbon';
                                    if (isDebt && customerNameCtrl.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(modalCtx).showSnackBar(
                                        const SnackBar(
                                          content: Text('⚠️ Nama pelanggan kasbon wajib diisi!'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.pop(pCtx);
                                    final dueDate = (isDebt && dueDays > 0)
                                        ? DateTime.now().add(Duration(days: dueDays))
                                        : null;
                                    final trx = await pos.checkout(
                                      cashPaid: paymentMethod == 'Tunai' ? cashPaid : total,
                                      paymentMethod: paymentMethod,
                                      customerId: isDebt ? null : pos.selectedCustomer?.id,
                                      customerName: isDebt
                                          ? customerNameCtrl.text.trim()
                                          : pos.effectiveCustomerName,
                                      customerPhone: isDebt
                                          ? customerPhoneCtrl.text.trim()
                                          : pos.selectedCustomer?.phone,
                                      dueDate: dueDate,
                                      note: isDebt ? debtNoteCtrl.text.trim() : null,
                                      autoPrint: false,
                                    );
                                    if (trx != null && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isDebt
                                              ? '✅ Kasbon atas nama ${customerNameCtrl.text.trim()} berhasil disimpan!'
                                              : '✅ Transaksi ${trx.invoiceNo} disimpan!'),
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
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: Colors.indigo),
                          tooltip: 'Cetak Barcode / Label Stiker',
                          onPressed: () => _showPrintBarcodeDialog(context, pos, p),
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

          // Card Buku Kasbon / Piutang Warung
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.purple, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Buku Kasbon Pelanggan',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total Piutang: ${_currencyFormat.format(pos.debtSummary['total_unpaid'] ?? 0)} (${pos.debtSummary['active_count'] ?? 0} Orang)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple.shade700),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Buka', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: () => _showCustomerDebtsDialog(context, pos),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Card Cadangkan & Pulihkan Sistem (.ZIP)
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.archive_rounded, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cadangkan & Pulihkan Sistem',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Database POS v5 + Seluruh Foto Produk (.ZIP)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.file_upload_outlined, size: 16),
                        label: const Text('Ekspor ZIP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          side: BorderSide(color: Colors.blue.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await PosBackupService.instance.shareBackup(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.restore_page_outlined, size: 16),
                        label: const Text('Pulihkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _confirmAndRestoreBackup(context, pos),
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

  // ==========================================
  // FITUR 1: SHIFT KASIR & KAS OPERASIONAL UI
  // ==========================================

  Widget _buildShiftStatusBar(PosProvider pos) {
    final shift = pos.activeShift;
    final isOpen = shift != null && shift.isOpen;

    return Container(
      color: isOpen ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isOpen ? Colors.green.shade100 : Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOpen ? Icons.storefront_rounded : Icons.lock_clock_rounded,
                  size: 16,
                  color: isOpen ? Colors.green.shade800 : Colors.amber.shade900,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOpen ? 'Shift: ${shift.cashierName}' : 'Shift Belum Dibuka',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isOpen ? Colors.green.shade900 : Colors.amber.shade900,
                    ),
                  ),
                  Text(
                    isOpen
                        ? 'Modal: ${_currencyFormat.format(shift.startingCash)}'
                        : 'Ketuk untuk isi modal kasir',
                    style: TextStyle(
                      fontSize: 10,
                      color: isOpen ? Colors.green.shade700 : Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isOpen)
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_vert_rounded, size: 14),
                  label: const Text('Kas +/-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.green.shade800,
                    side: BorderSide(color: Colors.green.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _showAddCashFlowDialog(context, pos),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showCloseShiftDialog(context, pos),
                  child: const Text('Tutup Shift', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text('Buka Kasir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showOpenShiftDialog(context, pos),
            ),
        ],
      ),
    );
  }

  void _showOpenShiftDialog(BuildContext context, PosProvider pos) {
    final modalCtrl = TextEditingController(text: '100000');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: AppConfig.primaryTeal),
            SizedBox(width: 8),
            Text('Buka Shift Kasir Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan modal awal uang tunai (kembalian) di laci kasir sebelum memulai transaksi:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: modalCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Modal Awal Kasir (Uang Kembalian)',
                prefixText: 'Rp ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                labelText: 'Catatan Shift (Opsional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final modal = double.tryParse(modalCtrl.text) ?? 0.0;
              Navigator.pop(dCtx);
              await pos.openShift(startingCash: modal, notes: noteCtrl.text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Shift kasir berhasil dibuka!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Buka Shift Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddCashFlowDialog(BuildContext context, PosProvider pos) {
    String type = 'OUT';
    String category = 'Operasional';
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Catat Kas Operasional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('[-] Kas Keluar'),
                      selected: type == 'OUT',
                      selectedColor: Colors.red.shade100,
                      onSelected: (val) => setDlgState(() {
                        type = 'OUT';
                        category = 'Operasional';
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('[+] Kas Masuk'),
                      selected: type == 'IN',
                      selectedColor: Colors.green.shade100,
                      onSelected: (val) => setDlgState(() {
                        type = 'IN';
                        category = 'Modal Tambahan';
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(
                  labelText: 'Kategori Kas',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: (type == 'OUT'
                        ? ['Operasional', 'Beli Perlengkapan', 'Kebersihan/Sampah', 'Makan Karyawan', 'Setoran', 'Lain-lain']
                        : ['Modal Tambahan', 'Pendapatan Lain', 'Pelunasan Kasbon', 'Lain-lain'])
                    .map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) => setDlgState(() => category = val ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nominal Uang',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Keterangan (misal: Beli Plastik 2 pak)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: type == 'OUT' ? Colors.red.shade700 : Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amount <= 0) return;
                Navigator.pop(dCtx);
                await pos.addCashFlow(
                  type: type,
                  amount: amount,
                  category: category,
                  note: noteCtrl.text,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Kas $type Rp ${amount.toInt()} berhasil dicatat.'),
                      backgroundColor: type == 'OUT' ? Colors.red.shade800 : Colors.green.shade800,
                    ),
                  );
                }
              },
              child: const Text('Simpan Kas', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloseShiftDialog(BuildContext context, PosProvider pos) {
    final shift = pos.activeShift;
    if (shift == null) return;

    final actualCtrl = TextEditingController(text: shift.calculatedExpectedCash.toInt().toString());
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final actual = double.tryParse(actualCtrl.text) ?? 0.0;
          final expected = shift.calculatedExpectedCash;
          final diff = actual - expected;

          String diffLabel = 'PAS (Uang Laci Sesuai)';
          Color diffColor = Colors.green;
          if (diff > 0) {
            diffLabel = 'LEBIH +${_currencyFormat.format(diff)}';
            diffColor = Colors.blue;
          } else if (diff < 0) {
            diffLabel = 'KURANG -${_currencyFormat.format(diff.abs())}';
            diffColor = Colors.red;
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.point_of_sale_rounded, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Tutup Shift Kasir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(dCtx)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Shift Kasir & Jam Buka/Tutup
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_filled_rounded, color: Colors.green.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kasir: ${shift.cashierName}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade900),
                                ),
                                Text(
                                  'Buka: ${DateFormat("HH:mm").format(shift.openedAt)} WIB • Durasi: ${shift.formattedDuration}',
                                  style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 1. Arus Kas Laci Fisik (Tunai)
                    const Text('1. Arus Uang Kas Laci Fisik (Tunai):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildShiftDetailRow('Modal Awal Kasir', _currencyFormat.format(shift.startingCash)),
                          const SizedBox(height: 4),
                          _buildShiftDetailRow('Penjualan Tunai (+)', _currencyFormat.format(shift.totalCashSales),
                              color: const Color(0xFF047857)),
                          const SizedBox(height: 4),
                          _buildShiftDetailRow('Kas Masuk Operasional (+)', _currencyFormat.format(shift.totalCashIn),
                              color: Colors.green.shade700),
                          const SizedBox(height: 4),
                          _buildShiftDetailRow('Kas Keluar Operasional (-)', _currencyFormat.format(shift.totalCashOut),
                              color: Colors.red.shade700),
                          const Divider(height: 12),
                          _buildShiftDetailRow(
                            'Uang Laci Seharusnya:',
                            _currencyFormat.format(expected),
                            isBold: true,
                            color: Colors.green.shade900,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Arus Non-Tunai (Rekening / QRIS / Kasbon)
                    const Text('2. Arus Non-Tunai (Bank & Piutang):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildShiftDetailRow('Penjualan QRIS (Bank)', _currencyFormat.format(shift.totalQrisSales),
                              color: Colors.blue.shade700),
                          const SizedBox(height: 4),
                          _buildShiftDetailRow('Penjualan Kasbon (Piutang)', _currencyFormat.format(shift.totalDebtSales),
                              color: Colors.purple.shade700),
                          const Divider(height: 12),
                          _buildShiftDetailRow(
                            'Total Omset Penjualan:',
                            _currencyFormat.format(shift.totalSales),
                            isBold: true,
                            color: const Color(0xFF0F172A),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. Hitung Kas Fisik Laci
                    const Text('3. Masukkan Uang Tunai Fisik di Laci:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: actualCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      onChanged: (_) => setDlgState(() {}),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixIcon: TextButton(
                          onPressed: () {
                            actualCtrl.text = expected.toInt().toString();
                            setDlgState(() {});
                          },
                          child: const Text('Uang Pas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Badge Hasil Selisih
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: diffColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: diffColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Hasil Selisih Kas:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(
                            diffLabel,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: diffColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Catatan Kasir / Keterangan (Opsional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
              ElevatedButton.icon(
                icon: const Icon(Icons.print, size: 16),
                label: const Text('Tutup & Cetak Struk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(dCtx);
                  await pos.closeShift(actualCash: actual, notes: notesCtrl.text, andPrint: true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Shift ditutup dan struk dicetak!'), backgroundColor: Colors.green),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShiftDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // FITUR 2: CETAK BARCODE & QR CODE PRODUK
  // ==========================================

  void _showPrintBarcodeDialog(BuildContext context, PosProvider pos, PosProduct product) {
    int qty = 1;
    bool isQr = false;

    showDialog(
      context: context,
      builder: (bCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: AppConfig.primaryTeal),
              SizedBox(width: 8),
              Expanded(
                child: Text('Cetak Label Barcode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text('SKU: ${product.kode}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text('Harga: ${_currencyFormat.format(product.hargaJual)} / ${product.unit}',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: AppConfig.primaryTeal, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Format Label:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Barcode 1D'),
                      selected: !isQr,
                      onSelected: (val) => setDlgState(() => isQr = !val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('QR Code 2D'),
                      selected: isQr,
                      onSelected: (val) => setDlgState(() => isQr = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Jumlah Stiker Label:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: qty > 1 ? () => setDlgState(() => qty--) : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$qty Lembar', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: qty < 50 ? () => setDlgState(() => qty++) : null,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(bCtx), child: const Text('Batal')),
            ElevatedButton.icon(
              icon: const Icon(Icons.print, size: 16),
              label: Text('Cetak $qty Label'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(bCtx);
                final ok = await pos.printProductBarcode(product, qty: qty, isQr: isQr);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Pastikan printer Bluetooth thermal sudah terhubung.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // FITUR 3: BUKU KASBON / PIUTANG PELANGGAN UI
  // ==========================================

  void _showCustomerDebtsDialog(BuildContext context, PosProvider pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (mCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final debts = pos.debts;

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                            child: const Icon(Icons.menu_book_rounded, color: Colors.purple, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Buku Kasbon Pelanggan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(
                                'Total Piutang: ${_currencyFormat.format(pos.debtSummary['total_unpaid'] ?? 0)}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(mCtx)),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // List
                Expanded(
                  child: debts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade400),
                              const SizedBox(height: 8),
                              const Text('Semua Kasbon Lunas!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              const Text('Tidak ada piutang pelanggan yang tertunggak.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: debts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final d = debts[i];
                            final isPaid = d.isPaid;
                            final isOverdue = d.isOverdue;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isPaid ? const Color(0xFFF8FAFC) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isOverdue ? Colors.red.shade300 : const Color(0xFFE2E8F0)),
                                boxShadow: isPaid
                                    ? []
                                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(d.customerName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isPaid
                                              ? Colors.green.shade50
                                              : (isOverdue ? Colors.red.shade50 : Colors.amber.shade50),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isPaid ? 'LUNAS' : (isOverdue ? 'JATUH TEMPO' : 'BELUM LUNAS'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: isPaid
                                                ? Colors.green.shade800
                                                : (isOverdue ? Colors.red.shade800 : Colors.amber.shade900),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Nota: ${d.invoiceNo} • Tgl: ${DateFormat('dd/MM/yy').format(d.createdAt)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Total: ${_currencyFormat.format(d.totalAmount)}', style: const TextStyle(fontSize: 11)),
                                      Text(
                                        'Sisa: ${_currencyFormat.format(d.remainingAmount)}',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isPaid ? Colors.green : Colors.red.shade700),
                                      ),
                                    ],
                                  ),
                                  if (!isPaid) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.payments_rounded, size: 14),
                                            label: const Text('Bayar Cicilan / Lunasi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.purple,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                            onPressed: () => _showPayDebtDialog(context, pos, d, () => setSheetState(() {})),
                                          ),
                                        ),
                                        if (d.customerPhone != null && d.customerPhone!.trim().isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.share, color: Colors.green),
                                            tooltip: 'Kirim Tagihan via WA',
                                            onPressed: () => _sendDebtWhatsAppReminder(pos, d),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
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
      ),
    );
  }

  void _showPayDebtDialog(BuildContext context, PosProvider pos, PosCustomerDebt debt, VoidCallback onUpdated) {
    final payCtrl = TextEditingController(text: debt.remainingAmount.toInt().toString());

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Bayar Kasbon: ${debt.customerName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sisa Hutang: ${_currencyFormat.format(debt.remainingAmount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 12),
            TextField(
              controller: payCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah Pembayaran',
                prefixText: 'Rp ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final val = double.tryParse(payCtrl.text) ?? 0.0;
              if (val <= 0) return;
              Navigator.pop(dCtx);
              await pos.payDebt(debtId: debt.id!, amount: val);
              onUpdated();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Pembayaran kasbon Rp ${val.toInt()} berhasil dicatat.'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Simpan Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sendDebtWhatsAppReminder(PosProvider pos, PosCustomerDebt debt) {
    final phone = debt.customerPhone ?? '';
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final targetPhone = cleanPhone.startsWith('0') ? '62${cleanPhone.substring(1)}' : cleanPhone;

    final msg = '''
Halo Bpk/Ibu *${debt.customerName}*,
Ini pengingat catatan kasbon belanja dari *${pos.storeName}*:
- No. Nota : ${debt.invoiceNo}
- Total Belanja : ${_currencyFormat.format(debt.totalAmount)}
- Sisa Tagihan  : *${_currencyFormat.format(debt.remainingAmount)}*
${debt.dueDate != null ? "- Jatuh Tempo   : ${DateFormat('dd/MM/yyyy').format(debt.dueDate!)}\n" : ""}
Mohon konfirmasi jika sudah melakukan pembayaran. Terima kasih banyak atas kerjasamanya! 🙏
''';

    final uri = Uri.parse('whatsapp://send?phone=$targetPhone&text=${Uri.encodeComponent(msg)}');
    launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) {
      final webUri = Uri.parse('https://api.whatsapp.com/send?phone=$targetPhone&text=${Uri.encodeComponent(msg)}');
      return launchUrl(webUri, mode: LaunchMode.externalApplication);
    });
  }

  // ==========================================
  // FITUR 4: RESTORE BACKUP SYSTEM
  // ==========================================
  void _confirmAndRestoreBackup(BuildContext context, PosProvider pos) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Pulihkan Sistem (.ZIP)?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Seluruh database transaksi, produk offline, dan foto produk saat ini akan digantikan dengan data yang ada di dalam arsip ZIP cadangan.\n\nPastikan Anda telah membuat cadangan terbaru sebelum melanjutkan pemulihan.',
          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dCtx);
              final ok = await PosBackupService.instance.pickAndRestoreBackup(context);
              if (ok) {
                await pos.refreshAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Seluruh data POS & foto produk berhasil dipulihkan dari ZIP!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Pilih File & Pulihkan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FITUR 1: MASTER PELANGGAN & PEMILIH KASIR
  // ==========================================

  Widget _buildCustomerSelectorBar(PosProvider pos) {
    final customer = pos.selectedCustomer;
    final isUmum = customer == null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUmum ? const Color(0xFFF8FAFC) : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isUmum ? const Color(0xFFE2E8F0) : Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isUmum ? const Color(0xFFE2E8F0) : Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 16,
                color: isUmum ? const Color(0xFF64748B) : Colors.blue.shade800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Pelanggan: ',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isUmum ? 'Umum (Default)' : customer.name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: isUmum ? const Color(0xFF0F172A) : Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  if (!isUmum && customer.phone != null && customer.phone!.isNotEmpty)
                    Text(
                      'No. WA: ${customer.phone}',
                      style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                    ),
                  if (!isUmum && customer.hasActiveDebt)
                    Text(
                      'Ada Kasbon: ${_currencyFormat.format(customer.totalDebt)}',
                      style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
            if (!isUmum)
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                tooltip: 'Reset ke Umum',
                visualDensity: VisualDensity.compact,
                onPressed: () => pos.selectCustomer(null),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz_rounded, size: 14),
              label: Text(isUmum ? 'Pilih' : 'Ganti', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: isUmum ? const Color(0xFF0F172A) : Colors.blue.shade800,
                side: BorderSide(color: isUmum ? const Color(0xFFCBD5E1) : Colors.blue.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showCustomerPickerModal(context, pos),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerPickerModal(BuildContext context, PosProvider pos) {
    String search = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (mCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final allCustomers = pos.customers;
          final filtered = search.trim().isEmpty
              ? allCustomers
              : allCustomers.where((c) {
                  final q = search.trim().toLowerCase();
                  return c.name.toLowerCase().contains(q) || (c.phone ?? '').contains(q);
                }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.people_alt_rounded, color: AppConfig.primaryTeal, size: 22),
                          SizedBox(width: 8),
                          Text('Pilih Pelanggan Kasir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('+ Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () async {
                              final newCust = await _showAddEditCustomerDialog(context, pos);
                              if (newCust != null) {
                                pos.selectCustomer(newCust);
                                if (mCtx.mounted) Navigator.pop(mCtx);
                              }
                            },
                          ),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(mCtx)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Search Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau No. WhatsApp...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (val) => setModalState(() => search = val),
                  ),
                ),
                const Divider(height: 1),

                // Customer List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Opsi 1: Pelanggan Umum
                      InkWell(
                        onTap: () {
                          pos.selectCustomer(null);
                          Navigator.pop(mCtx);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: pos.selectedCustomer == null ? Colors.blue.shade50 : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: pos.selectedCustomer == null ? Colors.blue.shade300 : const Color(0xFFE2E8F0),
                              width: pos.selectedCustomer == null ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey.shade300,
                                child: const Icon(Icons.group, size: 18, color: Color(0xFF475569)),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Pelanggan Umum (Tanpa Data)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('Default untuk pembeli umum atau transaksi cepat',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              if (pos.selectedCustomer == null)
                                const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                            ],
                          ),
                        ),
                      ),

                      // Daftar Pelanggan Tersimpan
                      ...filtered.map((cust) {
                        final isSelected = pos.selectedCustomer?.id == cust.id;
                        return InkWell(
                          onTap: () {
                            pos.selectCustomer(cust);
                            Navigator.pop(mCtx);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.shade50 : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.blue.shade300 : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppConfig.primaryTeal.withValues(alpha: 0.15),
                                  child: Text(
                                    cust.name.isNotEmpty ? cust.name[0].toUpperCase() : 'P',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppConfig.primaryTeal, fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(cust.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (cust.phone != null && cust.phone!.isNotEmpty)
                                        Text('WA: ${cust.phone}',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                      if (cust.hasActiveDebt)
                                        Container(
                                          margin: const EdgeInsets.only(top: 3),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.red.shade200),
                                          ),
                                          child: Text(
                                            'Kasbon: ${_currencyFormat.format(cust.totalDebt)}',
                                            style: TextStyle(
                                                fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<PosCustomer?> _showAddEditCustomerDialog(BuildContext context, PosProvider pos, [PosCustomer? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    return showDialog<PosCustomer?>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(existing == null ? Icons.person_add_rounded : Icons.edit_note_rounded, color: AppConfig.primaryTeal),
            const SizedBox(width: 8),
            Text(existing == null ? 'Tambah Pelanggan Baru' : 'Edit Data Pelanggan',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Pelanggan *',
                  hintText: 'Contoh: Bu Ani Warung / Pak Budi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Nomor WhatsApp / HP',
                  hintText: 'Contoh: 08123456789',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: InputDecoration(
                  labelText: 'Alamat (Opsional)',
                  hintText: 'Contoh: Jl. Merdeka No. 12',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: 'Catatan Khusus (Opsional)',
                  hintText: 'Contoh: Langganan warung kopi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(dCtx).showSnackBar(
                  const SnackBar(content: Text('⚠️ Nama pelanggan wajib diisi!'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(dCtx);
              if (existing == null) {
                final created = await pos.addCustomer(
                  name: name,
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                );
                if (created != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Pelanggan "${created.name}" berhasil ditambahkan!'), backgroundColor: Colors.green),
                  );
                }
              } else {
                final updated = existing.copyWith(
                  name: name,
                  phone: phoneCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                  updatedAt: DateTime.now(),
                );
                await pos.updateCustomer(updated);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Data pelanggan "${updated.name}" diperbarui!'), backgroundColor: Colors.green),
                  );
                }
              }
            },
            child: const Text('Simpan Pelanggan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: HALAMAN KHUSUS MASTER PELANGGAN & KASBON
  // ==========================================

  Widget _buildCustomersTab(PosProvider pos) {
    final customers = pos.customers;
    final totalCustomers = customers.length;
    final totalDebt = pos.debtSummary['total_unpaid'] ?? 0.0;
    final activeDebtCount = pos.debtSummary['active_count'] ?? 0;

    return Column(
      children: [
        // Header Ringkasan Master Pelanggan
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Pelanggan',
                              style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('$totalCustomers Orang',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blue.shade900)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Piutang Kasbon',
                              style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(_currencyFormat.format(totalDebt),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.purple.shade900)),
                          Text('$activeDebtCount Pelanggan Nunggak',
                              style: TextStyle(fontSize: 10, color: Colors.purple.shade700, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tombol Tambah Pelanggan
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Tambah Pelanggan Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showAddEditCustomerDialog(context, pos),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('Buku Kasbon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showCustomerDebtsDialog(context, pos),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List Pelanggan
        Expanded(
          child: customers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('Belum ada data pelanggan tersimpan.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text('Tambah pelanggan untuk mencatat riwayat belanja & kasbon.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Pelanggan Pertama'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showAddEditCustomerDialog(context, pos),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: customers.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final cust = customers[i];
                    final hasDebt = cust.hasActiveDebt;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasDebt ? Colors.purple.shade200 : const Color(0xFFE2E8F0),
                          width: hasDebt ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: hasDebt ? Colors.purple.shade100 : Colors.teal.shade50,
                                child: Text(
                                  cust.name.isNotEmpty ? cust.name[0].toUpperCase() : 'P',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: hasDebt ? Colors.purple.shade800 : AppConfig.primaryTeal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cust.name,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                    ),
                                    if (cust.phone != null && cust.phone!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      InkWell(
                                        onTap: () {
                                          final phone = cust.phone!.replaceAll(RegExp(r'[^0-9]'), '');
                                          final target = phone.startsWith('0') ? '62${phone.substring(1)}' : phone;
                                          final uri = Uri.parse('whatsapp://send?phone=$target');
                                          launchUrl(uri, mode: LaunchMode.externalApplication);
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.chat, color: Color(0xFF25D366), size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              cust.phone!,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (cust.address != null && cust.address!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        cust.address!,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                                onSelected: (val) async {
                                  if (val == 'edit') {
                                    _showAddEditCustomerDialog(context, pos, cust);
                                  } else if (val == 'select_cashier') {
                                    pos.selectCustomer(cust);
                                    _tabController.animateTo(0);
                                  } else if (val == 'delete') {
                                    _confirmDeleteCustomer(context, pos, cust);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'select_cashier', child: Text('Layani di Kasir')),
                                  PopupMenuItem(value: 'edit', child: Text('Edit Data')),
                                  PopupMenuItem(value: 'delete', child: Text('Hapus Pelanggan', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Status Kasbon & Belanja
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: hasDebt ? Colors.purple.shade50 : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: hasDebt ? Colors.purple.shade200 : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hasDebt ? 'TAGIHAN KASBON BELUM LUNAS' : 'STATUS KASBON:',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: hasDebt ? Colors.purple.shade800 : const Color(0xFF64748B),
                                      ),
                                    ),
                                    Text(
                                      hasDebt
                                          ? _currencyFormat.format(cust.totalDebt)
                                          : 'Bersih (Tidak Ada Kasbon)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: hasDebt ? Colors.purple.shade900 : const Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                                if (hasDebt)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.payment, size: 13),
                                    label: const Text('Bayar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () => _showCustomerDebtsDialog(context, pos),
                                  )
                                else
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.point_of_sale, size: 13),
                                    label: const Text('Ke Kasir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppConfig.primaryTeal,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      pos.selectCustomer(cust);
                                      _tabController.animateTo(0);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmDeleteCustomer(BuildContext context, PosProvider pos, PosCustomer cust) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pelanggan?'),
        content: Text('Apakah Anda yakin ingin menghapus pelanggan "${cust.name}"? Data kasbon terkait akan tetap tersimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dCtx);
              await pos.deleteCustomer(cust.id!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Pelanggan "${cust.name}" dihapus!'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

}
