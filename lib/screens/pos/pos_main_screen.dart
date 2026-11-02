import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../models/pos_cart_item.dart';
import '../../models/pos_product.dart';
import '../../models/pos_transaction.dart';
import '../../providers/pos_provider.dart';
import '../../providers/printer_provider.dart';
import '../../services/pos_database_service.dart';
import '../printer_settings_screen.dart';

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
                  // Search Box
                  Container(
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

            // 2. Product Grid
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
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.88,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final product = filtered[idx];
                        return _buildProductCard(pos, product);
                      },
                    ),
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
    return InkWell(
      onTap: () => pos.addToCart(product),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.kode,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                    ),
                    if (product.isConsignment)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Text(
                          'Titipan',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.amber.shade900),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.nama,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.2),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _currencyFormat.format(product.hargaJual),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppConfig.primaryTeal),
                    ),
                    Text(
                      '/${product.unit}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  product.isUnlimitedStock ? 'Stok: Bebas (∞)' : 'Stok: ${product.stok} ${product.unit}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: product.stok <= 0 && !product.isUnlimitedStock ? Colors.red.shade600 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
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
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
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

        // Counter Qty
        Container(
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
                icon: const Icon(Icons.add, size: 14),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: () {
                  pos.updateCartQty(idx, 1);
                  setModalState(() {});
                },
              ),
            ],
          ),
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
                    TextField(controller: kodeCtrl, decoration: const InputDecoration(labelText: 'Kode / SKU Produk')),
                    TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: 'Nama Produk')),
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
                    if (kodeCtrl.text.isEmpty || namaCtrl.text.isEmpty) return;
                    final parsedStok = isStockManaged ? (int.tryParse(stokCtrl.text) ?? 0) : -1;
                    final newP = PosProduct(
                      id: product?.id,
                      kode: kodeCtrl.text.trim(),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCancelled ? Colors.red.shade200 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    trx.invoiceNo,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: isCancelled ? Colors.red.shade700 : const Color(0xFF0F172A),
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (isCancelled) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text('BATAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${trx.dateTime.hour.toString().padLeft(2, '0')}:${trx.dateTime.minute.toString().padLeft(2, '0')} • ${trx.items.length} Item • Laba: ${_currencyFormat.format(trx.profitAmount)}',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                _currencyFormat.format(trx.totalAmount),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isCancelled ? Colors.grey : AppConfig.primaryTeal),
              ),
              const SizedBox(width: 4),
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
              if (!isCancelled)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                  tooltip: 'Batalkan / Retur Transaksi',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Batalkan Transaksi?'),
                        content: Text('Batalkan nota ${trx.invoiceNo}?\nStok produk yang dikelola akan otomatis dikembalikan ke etalase.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Tutup')),
                          TextButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final ok = await pos.cancelTransaction(trx.invoiceNo, reason: 'Pembatalan Kasir');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? '✅ Transaksi ${trx.invoiceNo} berhasil dibatalkan.' : '⚠️ Gagal membatalkan transaksi.')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
