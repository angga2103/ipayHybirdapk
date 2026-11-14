import '../models/pos_customer.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/pos_cart_item.dart';
import '../models/pos_product.dart';
import '../models/pos_transaction.dart';
import '../models/pos_shift.dart';
import '../models/pos_cash_flow.dart';
import '../models/pos_debt.dart';
import '../models/pos_consignment_payment.dart';
import '../models/pos_stock_movement.dart';
import '../services/pos_backup_service.dart';
import '../services/pos_database_service.dart';
import '../services/pos_excel_service.dart';
import '../services/pos_image_service.dart';
import '../services/pos_product_helper.dart';
import '../services/printer_service.dart';

class PosProvider extends ChangeNotifier {
  List<PosProduct> _products = [];
  List<String> _categories = [];
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  final List<PosCartItem> _cart = [];
  List<ConsignmentSummary> _consignments = [];
  List<PosConsignmentPayment> _consignmentPayments = [];
  List<PosStockMovement> _stockMovements = [];
  List<PosTransaction> _transactions = [];
  DateTime? _historyDate = DateTime.now();
  bool _historyAllDates = false;
  String _historyInvoiceQuery = '';
  List<Map<String, dynamic>> _holdCarts = [];
  Map<String, double> _todayStats = {
    'total_omset': 0.0,
    'total_profit': 0.0,
    'total_discount': 0.0,
    'total_consignment_due': 0.0,
    'cash_omset': 0.0,
    'non_cash_omset': 0.0,
    'total_trx': 0.0,
  };
  bool _isLoading = false;
  String? _errorMessage;
  String _cashierName = 'Kasir';
  String _storeName = 'IPAY';
  bool _isGridView = false; // Default List view (bisa diubah ke Grid)
  PosShift? _activeShift;
  List<PosCashFlow> _activeCashFlows = [];
  List<PosCashFlow> _lastClosedShiftCashFlows = [];
  List<PosCustomerDebt> _debts = [];
  List<PosCustomer> _customers = [];
  PosCustomer? _selectedCustomer;
  Map<String, dynamic> _debtSummary = {
    'active_count': 0,
    'total_unpaid': 0.0,
    'total_paid': 0.0,
  };

  List<PosProduct> get products => _products;
  List<String> get categories => _categories;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  List<PosCartItem> get cart => List.unmodifiable(_cart);
  List<ConsignmentSummary> get consignments => _consignments;
  List<PosConsignmentPayment> get consignmentPayments => _consignmentPayments;
  List<PosStockMovement> get stockMovements => _stockMovements;
  List<PosTransaction> get transactions => _transactions;
  DateTime? get historyDate => _historyDate;
  bool get historyAllDates => _historyAllDates;
  String get historyInvoiceQuery => _historyInvoiceQuery;
  List<Map<String, dynamic>> get holdCarts => _holdCarts;
  int get holdCartsCount => _holdCarts.length;
  Map<String, double> get todayStats => _todayStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get cashierName => _cashierName;
  String get storeName => _storeName;
  bool get isGridView => _isGridView;
  PosShift? get activeShift => _activeShift;
  bool get hasActiveShift => _activeShift != null && _activeShift!.isOpen;
  List<PosCashFlow> get activeCashFlows => _activeCashFlows;
  List<PosCashFlow> get lastClosedShiftCashFlows => _lastClosedShiftCashFlows;
  List<PosCustomerDebt> get debts => _debts;
  Map<String, dynamic> get debtSummary => _debtSummary;
  List<PosCustomer> get customers => _customers;
  PosCustomer? get selectedCustomer => _selectedCustomer;
  String get effectiveCustomerName => _selectedCustomer?.displayName ?? 'Umum';

  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  void setGridView(bool val) {
    _isGridView = val;
    notifyListeners();
  }

  void setCashierName(String name) {
    _cashierName = name;
    notifyListeners();
  }

  void setStoreName(String name) {
    _storeName = name;
    notifyListeners();
  }

  List<PosProduct> get filteredProducts {
    return _products.where((p) {
      if (p.isArchived) return false;

      final matchesCategory = (_selectedCategory == 'ALL') ||
          (_selectedCategory == 'Konsinyasi' ? p.isConsignment : p.kategori.toLowerCase() == _selectedCategory.toLowerCase());

      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          p.nama.toLowerCase().contains(q) ||
          p.kode.toLowerCase().contains(q);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  double get cartTotal => _cart.fold(0.0, (sum, it) => sum + it.subtotal);
  double get cartNormalTotal => _cart.fold(0.0, (sum, it) => sum + it.normalSubtotal);
  double get cartDiscount => cartNormalTotal - cartTotal;
  int get cartTotalQty => _cart.fold(0, (sum, it) => sum + it.qty);

  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      PrinterService.instance.syncStoreSettingsFromBackend().then((_) async {
        final profile = await PrinterService.instance.getStoreProfile();
        if (profile['name'] != null && profile['name'].toString().isNotEmpty) {
          _storeName = profile['name'].toString();
          notifyListeners();
        }
      });

      await refreshAll();
    } catch (e) {
      _errorMessage = 'Gagal memuat database POS: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAll() async {
    _products = await PosDatabaseService.instance.getAllProducts(includeArchived: false);
    _categories = await PosDatabaseService.instance.getAllCategories();
    _consignments = await PosDatabaseService.instance.getConsignmentSummaries();
    _consignmentPayments = await PosDatabaseService.instance.getConsignmentPayments();
    _stockMovements = await PosDatabaseService.instance.getStockMovements();
    _transactions = await PosDatabaseService.instance.getTransactions(
      date: _historyAllDates ? null : _historyDate,
      searchQuery: _historyInvoiceQuery.isNotEmpty ? _historyInvoiceQuery : null,
      limit: 150,
    );
    _holdCarts = await PosDatabaseService.instance.getAllHoldCarts();
    _todayStats = await PosDatabaseService.instance.getTodaySalesStats();
    _activeShift = await PosDatabaseService.instance.getActiveShift();
    if (_activeShift != null) {
      _cashierName = _activeShift!.cashierName;
      _activeCashFlows = await PosDatabaseService.instance.getCashFlows(shiftId: _activeShift!.id);
    } else {
      _activeCashFlows = await PosDatabaseService.instance.getCashFlows(limit: 20);
    }
    _debts = await PosDatabaseService.instance.getAllDebts();
    _debtSummary = await PosDatabaseService.instance.getDebtSummary();
    _customers = await PosDatabaseService.instance.getCustomers();
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  // --- Cart Operations dengan Proteksi Stok Ketat ---
  bool addToCart(PosProduct product) {
    if (product.isStockManaged && product.stok <= 0) {
      _errorMessage = 'Stok "${product.nama}" sudah habis!';
      notifyListeners();
      return false;
    }

    final idx = _cart.indexWhere((it) => it.product.kode == product.kode);
    if (idx >= 0) {
      if (product.isStockManaged && (_cart[idx].qty + 1) > product.stok) {
        _errorMessage = 'Sisa stok "${product.nama}" hanya ${product.stok} ${product.unit}.';
        notifyListeners();
        return false;
      }
      _cart[idx].qty += 1;
    } else {
      _cart.add(PosCartItem(product: product, qty: 1));
    }
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  int getProductCartQty(PosProduct product) {
    final idx = _cart.indexWhere((i) => i.product.id == product.id);
    return idx >= 0 ? _cart[idx].qty : 0;
  }

  bool updateProductQty(PosProduct product, int delta) {
    final idx = _cart.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      return updateCartQty(idx, delta);
    } else if (delta > 0) {
      return addToCart(product);
    }
    return false;
  }

  bool setProductCartQty(PosProduct product, int targetQty) {
    final idx = _cart.indexWhere((i) => i.product.id == product.id);
    if (targetQty <= 0) {
      if (idx >= 0) {
        removeCartItem(idx);
      }
      return true;
    }
    if (idx >= 0) {
      final item = _cart[idx];
      if (item.isStockManaged && targetQty > item.product.stok) {
        _errorMessage = 'Maksimal stok "${item.product.nama}" tercapai (${item.product.stok} ${item.product.unit}).';
        notifyListeners();
        return false;
      }
      item.qty = targetQty;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      if (product.isStockManaged && targetQty > product.stok) {
        _errorMessage = 'Maksimal stok "${product.nama}" tercapai (${product.stok} ${product.unit}).';
        notifyListeners();
        return false;
      }
      _cart.add(PosCartItem(product: product, qty: targetQty));
      _errorMessage = null;
      notifyListeners();
      return true;
    }
  }

  bool updateCartQty(int index, int delta) {
    if (index < 0 || index >= _cart.length) return false;
    final item = _cart[index];

    if (delta > 0 && item.isStockManaged) {
      if (item.qty + delta > item.product.stok) {
        _errorMessage = 'Maksimal stok "${item.product.nama}" tercapai (${item.product.stok} ${item.product.unit}).';
        notifyListeners();
        return false;
      }
    }

    item.qty += delta;
    if (item.qty <= 0) {
      _cart.removeAt(index);
    }
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  void updateCartItemPrice(int index, double newPrice) {
    if (index < 0 || index >= _cart.length) return;
    _cart[index].actualPrice = newPrice;
    notifyListeners();
  }

  void resetCartItemPrice(int index) {
    if (index < 0 || index >= _cart.length) return;
    _cart[index].actualPrice = _cart[index].normalPrice;
    notifyListeners();
  }

  void removeCartItem(int index) {
    if (index < 0 || index >= _cart.length) return;
    _cart.removeAt(index);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  // --- Checkout ---
  Future<PosTransaction?> checkout({
    required double cashPaid,
    String paymentMethod = 'Tunai',
    String? note,
    bool autoPrint = true,
    int? customerId,
    String? customerName,
    String? customerPhone,
    DateTime? dueDate,
  }) async {
    if (_cart.isEmpty) return null;

    // Proteksi Keamanan: Shift Kasir Wajib Aktif
    if (_activeShift == null || !_activeShift!.isOpen) {
      _activeShift = await PosDatabaseService.instance.getActiveShift();
    }
    if (_activeShift == null || !_activeShift!.isOpen) {
      _errorMessage = 'Shift kasir belum dibuka! Silakan buka shift kasir dan isi modal awal terlebih dahulu.';
      notifyListeners();
      return null;
    }

    final effectiveCName = customerName?.trim().isNotEmpty == true 
        ? customerName!.trim() 
        : (_selectedCustomer?.displayName ?? 'Umum');
    final effectiveCId = customerId ?? _selectedCustomer?.id;
    final effectiveCPhone = customerPhone?.trim().isNotEmpty == true 
        ? customerPhone!.trim() 
        : _selectedCustomer?.phone;

    try {
      final trx = await PosDatabaseService.instance.checkoutTransaction(
        cartItems: _cart,
        cashPaid: cashPaid,
        paymentMethod: paymentMethod,
        cashierName: _activeShift?.cashierName ?? _cashierName,
        note: note,
        customerId: effectiveCId,
        customerName: effectiveCName,
        customerPhone: effectiveCPhone,
        shiftId: _activeShift?.id,
      );

      // Jika metode pembayaran Kasbon, catat ke pos_customer_debts
      if (paymentMethod.toLowerCase() == 'kasbon' && effectiveCName.isNotEmpty) {
        await PosDatabaseService.instance.recordCustomerDebt(
          transactionId: trx.id,
          customerId: effectiveCId,
          invoiceNo: trx.invoiceNo,
          customerName: effectiveCName,
          customerPhone: effectiveCPhone,
          totalAmount: trx.totalAmount,
          dueDate: dueDate,
          notes: note,
        );
      }

      _cart.clear();
      _selectedCustomer = null; // Reset ke 'Umum' untuk transaksi berikutnya
      await refreshAll();

      if (autoPrint) {
        await printReceipt(trx);
      }

      return trx;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan transaksi: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> printReceipt(PosTransaction trx) async {
    try {
      return await PrinterService.instance.printPosTransaction(
        trx,
        storeName: _storeName,
      );
    } catch (e) {
      debugPrint('[PosProvider] Error printReceipt: $e');
      return false;
    }
  }

  /// Ambil transaksi terakhir yang tersimpan untuk cetak ulang cepat (Ctrl+P)
  Future<PosTransaction?> getLastTransaction() async {
    if (_transactions.isNotEmpty) return _transactions.first;
    final list = await PosDatabaseService.instance.getTransactions(limit: 1);
    return list.isNotEmpty ? list.first : null;
  }

  /// Cetak ulang struk transaksi terakhir (Pintasan Keyboard Ctrl+P)
  Future<bool> reprintLastTransaction() async {
    final lastTrx = await getLastTransaction();
    if (lastTrx == null) {
      _errorMessage = 'Belum ada transaksi untuk dicetak ulang';
      notifyListeners();
      return false;
    }
    return await printReceipt(lastTrx);
  }

  Future<bool> printConsignmentReport(ConsignmentSummary summary) async {
    try {
      return await PrinterService.instance.printConsignmentReport(
        summary,
        storeName: _storeName,
      );
    } catch (e) {
      debugPrint('[PosProvider] Error printConsignmentReport: $e');
      return false;
    }
  }

  // --- Product Management ---
  Future<bool> saveProduct(PosProduct product) async {
    try {
      // Jika kode produk kosong, buatkan otomatis menggunakan rumus
      if (product.kode.trim().isEmpty) {
        final existingCodes = _products.map((p) => p.kode).toSet();
        final autoCode = PosProductHelper.generateNumericCode(existingCodes: existingCodes);
        product = product.copyWith(kode: autoCode);
      }
      await PosDatabaseService.instance.insertOrUpdateProduct(product);
      await refreshAll();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan produk: $e';
      notifyListeners();
      return false;
    }
  }

  /// Memperbarui atau menambahkan foto pada produk yang sudah tersimpan
  Future<bool> updateProductPhoto(PosProduct product, String? newImagePath) async {
    try {
      if (product.imagePath != null && product.imagePath != newImagePath) {
        await PosImageService.instance.deleteImageFile(product.imagePath);
      }
      final updated = product.copyWith(imagePath: newImagePath);
      await PosDatabaseService.instance.insertOrUpdateProduct(updated);
      await refreshAll();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui foto produk: $e';
      notifyListeners();
      return false;
    }
  }

  // --- Barcode Scanner Helper ---
  PosProduct? findProductByBarcode(String barcode) {
    final clean = barcode.trim().toLowerCase();
    try {
      return _products.firstWhere(
        (p) => !p.isArchived && p.kode.trim().toLowerCase() == clean,
      );
    } catch (_) {
      return null;
    }
  }

  bool addProductByBarcode(String barcode) {
    final product = findProductByBarcode(barcode);
    if (product != null) {
      return addToCart(product);
    }
    _errorMessage = 'Produk dengan kode/barcode "$barcode" tidak ditemukan!';
    notifyListeners();
    return false;
  }

  // --- Hold Cart Operations (Tahan & Pulihkan Keranjang) ---
  Future<bool> holdCurrentCart({String? note}) async {
    if (_cart.isEmpty) return false;
    try {
      final cartId = 'HOLD-${DateTime.now().millisecondsSinceEpoch}';
      final itemsList = _cart.map((it) => {
        'product': it.product.toMap(),
        'qty': it.qty,
        'custom_price': it.actualPrice,
      }).toList();
      final itemsJson = jsonEncode(itemsList);
      final total = cartTotal;

      await PosDatabaseService.instance.saveHoldCart(
        cartId: cartId,
        customerNote: note ?? 'Pelanggan #${_holdCarts.length + 1}',
        totalAmount: total,
        itemsJson: itemsJson,
      );

      _cart.clear();
      _holdCarts = await PosDatabaseService.instance.getAllHoldCarts();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menahan pesanan: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreHoldCart(String cartId) async {
    try {
      final cartRecord = _holdCarts.firstWhere((c) => c['cart_id'] == cartId, orElse: () => {});
      if (cartRecord.isEmpty) return false;

      final itemsJson = cartRecord['items_json'] as String?;
      if (itemsJson == null || itemsJson.isEmpty) return false;

      final decoded = jsonDecode(itemsJson) as List<dynamic>;
      _cart.clear();

      for (final raw in decoded) {
        final pMap = raw['product'] as Map<String, dynamic>;
        final currentProduct = _products.firstWhere(
          (p) => p.kode == pMap['kode'],
          orElse: () => PosProduct.fromMap(pMap),
        );
        final item = PosCartItem(
          product: currentProduct,
          qty: (raw['qty'] as num?)?.toInt() ?? 1,
          customPrice: (raw['custom_price'] as num?)?.toDouble() ?? currentProduct.hargaJual,
        );
        _cart.add(item);
      }

      await PosDatabaseService.instance.deleteHoldCart(cartId);
      _holdCarts = await PosDatabaseService.instance.getAllHoldCarts();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memuat pesanan tertahan: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteHoldCart(String cartId) async {
    try {
      await PosDatabaseService.instance.deleteHoldCart(cartId);
      _holdCarts = await PosDatabaseService.instance.getAllHoldCarts();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus pesanan tertahan: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteOrArchiveProduct(String kode) async {
    try {
      final isHardDeleted = await PosDatabaseService.instance.deleteOrArchiveProduct(kode);
      await refreshAll();
      return isHardDeleted;
    } catch (e) {
      _errorMessage = 'Gagal menghapus produk: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> restoreProduct(String kode) async {
    try {
      await PosDatabaseService.instance.restoreProduct(kode);
      await refreshAll();
    } catch (e) {
      _errorMessage = 'Gagal memulihkan produk: $e';
      notifyListeners();
    }
  }

  // --- Retur / Pembatalan Transaksi Parsial & Penuh ---
  Future<PosTransactionReturn?> returnTransactionItem({
    required String invoiceNo,
    required String productKode,
    required int qtyToReturn,
    String? reason,
    bool autoPrint = true,
  }) async {
    try {
      final returnRecord = await PosDatabaseService.instance.returnTransactionItem(
        invoiceNo: invoiceNo,
        productKode: productKode,
        qtyToReturn: qtyToReturn,
        reason: reason,
      );
      await refreshAll();

      if (autoPrint) {
        final updatedTrx = await PosDatabaseService.instance.getTransactionByInvoice(invoiceNo);
        if (updatedTrx != null) {
          await PrinterService.instance.printReturnReceipt(
            updatedTrx,
            returnRecord,
            storeName: _storeName,
          );
        }
      }

      return returnRecord;
    } catch (e) {
      _errorMessage = 'Gagal retur barang: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> printReturnReceipt(PosTransaction trx, PosTransactionReturn returnRecord) async {
    try {
      return await PrinterService.instance.printReturnReceipt(
        trx,
        returnRecord,
        storeName: _storeName,
      );
    } catch (e) {
      debugPrint('[PosProvider] Error printReturnReceipt: $e');
      return false;
    }
  }

  Future<bool> cancelTransaction(String invoiceNo, {String? reason}) async {
    try {
      final ok = await PosDatabaseService.instance.cancelTransaction(invoiceNo, reason: reason);
      if (ok) {
        await refreshAll();
      }
      return ok;
    } catch (e) {
      _errorMessage = 'Gagal membatalkan transaksi: $e';
      notifyListeners();
      return false;
    }
  }

  // --- Tutup Kas Harian (Laporan Z) ---
  Future<PosDailyClosing?> closeDailyCash({String? notes, bool andPrint = true}) async {
    try {
      final closing = await PosDatabaseService.instance.saveDailyClosing(notes: notes);
      if (andPrint) {
        await PrinterService.instance.printDailyClosingReport(closing);
      }
      await refreshAll();
      return closing;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan tutup kas harian: $e';
      notifyListeners();
      return null;
    }
  }

  // --- Backup & Restore Database ---
  Future<bool> shareBackupDatabase() async {
    try {
      return await PosBackupService.instance.shareBackupDatabase();
    } catch (e) {
      _errorMessage = 'Gagal membuat backup database: $e';
      notifyListeners();
      return false;
    }
  }

  Future<String?> restoreDatabase() async {
    try {
      final error = await PosBackupService.instance.restoreDatabaseFromFile();
      if (error == null) {
        await refreshAll();
      }
      return error;
    } catch (e) {
      _errorMessage = 'Gagal memulihkan database: $e';
      notifyListeners();
      return e.toString();
    }
  }

  // --- Konsinyasi Settlement & Stock Movements ---
  Future<PosConsignmentPayment?> settleConsignmentPayment({
    required String penitip,
    required double amountPaid,
    String paymentMethod = 'Tunai',
    String? note,
    String? cashierName,
    bool andPrint = false,
  }) async {
    try {
      final payment = await PosDatabaseService.instance.recordConsignmentPayment(
        penitip: penitip,
        amountPaid: amountPaid,
        paymentMethod: paymentMethod,
        note: note,
        cashierName: cashierName ?? _activeShift?.cashierName ?? _cashierName,
        shiftId: _activeShift?.id,
      );

      if (andPrint) {
        await PrinterService.instance.printConsignmentPaymentReceipt(payment, storeName: _storeName);
      }

      await refreshAll();
      return payment;
    } catch (e) {
      _errorMessage = 'Gagal mencatat pembayaran konsinyasi: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> settleConsignment({required ConsignmentSummary summary, bool andPrint = true}) async {
    try {
      await settleConsignmentPayment(
        penitip: summary.penitip,
        amountPaid: summary.remainingDue,
        paymentMethod: 'Tunai',
        note: 'Pelunasan konsinyasi otomatis',
        andPrint: andPrint,
      );
    } catch (e) {
      _errorMessage = 'Gagal mencatat pelunasan konsinyasi: $e';
      notifyListeners();
    }
  }

  Future<PosStockMovement?> addConsignmentStock({
    required int productId,
    required int qty,
    String? refNumber,
    String? operatorName,
    String? note,
  }) async {
    try {
      final movement = await PosDatabaseService.instance.recordStockMovement(
        productId: productId,
        movementType: 'IN_CONSIGNMENT',
        qty: qty,
        refNumber: refNumber,
        operatorName: operatorName ?? _activeShift?.cashierName ?? _cashierName,
        note: note,
      );
      await refreshAll();
      return movement;
    } catch (e) {
      _errorMessage = 'Gagal mencatat penambahan stok titipan: $e';
      notifyListeners();
      return null;
    }
  }

  Future<List<PosConsignmentPayment>> getPaymentsForPenitip(String penitip) async {
    return await PosDatabaseService.instance.getConsignmentPayments(penitip: penitip);
  }

  Future<List<PosStockMovement>> getMovementsForPenitip(String penitip) async {
    return await PosDatabaseService.instance.getStockMovements(penitip: penitip);
  }

  Future<List<PosProduct>> getProductsForPenitip(String penitip) async {
    return await PosDatabaseService.instance.getConsignmentProducts(penitip);
  }

  // --- Excel Import & Export ---
  Future<int> importFromExcel() async {
    try {
      final count = await PosExcelService.instance.pickAndImportExcel();
      if (count > 0) {
        await refreshAll();
      }
      return count;
    } catch (e) {
      _errorMessage = 'Gagal mengimpor file: $e';
      notifyListeners();
      return 0;
    }
  }

  Future<bool> exportTemplate() async {
    try {
      return await PosExcelService.instance.shareTemplateExcel();
    } catch (e) {
      _errorMessage = 'Gagal mengunduh template: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> exportCatalog() async {
    try {
      final allProducts = await PosDatabaseService.instance.getAllProducts(includeArchived: false);
      return await PosExcelService.instance.shareProductCatalog(allProducts);
    } catch (e) {
      _errorMessage = 'Gagal mengekspor katalog: $e';
      notifyListeners();
      return false;
    }
  }

  // --- Shift Kasir (Buka / Tutup Toko) ---
  Future<PosShift?> refreshActiveShift() async {
    try {
      _activeShift = await PosDatabaseService.instance.getActiveShift();
      if (_activeShift != null) {
        _activeCashFlows = await PosDatabaseService.instance.getCashFlows(shiftId: _activeShift!.id);
      }
      notifyListeners();
      return _activeShift;
    } catch (e) {
      debugPrint('[PosProvider] Error refreshActiveShift: $e');
      return _activeShift;
    }
  }

  Future<PosShift?> openShift({
    required double startingCash,
    String? cashierName,
    String? notes,
  }) async {
    try {
      if (cashierName != null && cashierName.trim().isNotEmpty) {
        _cashierName = cashierName.trim();
      }
      final shift = await PosDatabaseService.instance.openShift(
        cashierName: _cashierName,
        startingCash: startingCash,
        notes: notes,
      );
      _activeShift = shift;
      _activeCashFlows = [];
      notifyListeners();
      return shift;
    } catch (e) {
      _errorMessage = 'Gagal membuka shift kasir: $e';
      notifyListeners();
      return null;
    }
  }

  Future<PosShift?> closeShift({required double actualCash, String? notes, bool andPrint = true}) async {
    if (_activeShift == null || _activeShift!.id == null) return null;
    try {
      final flowsToPrint = await PosDatabaseService.instance.getCashFlows(shiftId: _activeShift!.id!);
      final closed = await PosDatabaseService.instance.closeShift(
        shiftId: _activeShift!.id!,
        actualCash: actualCash,
        notes: notes,
      );
      _lastClosedShiftCashFlows = flowsToPrint;
      if (andPrint) {
        await PrinterService.instance.printShiftReceipt(closed, flowsToPrint, storeName: _storeName);
      }
      await refreshAll();
      return closed;
    } catch (e) {
      _errorMessage = 'Gagal menutup shift kasir: $e';
      notifyListeners();
      return null;
    }
  }

  // --- Kas Masuk / Kas Keluar Operasional ---
  Future<bool> addCashFlow({
    required String type,
    required double amount,
    required String category,
    String? note,
  }) async {
    // Proteksi Keamanan: Shift Kasir Wajib Aktif
    if (_activeShift == null || !_activeShift!.isOpen) {
      _activeShift = await PosDatabaseService.instance.getActiveShift();
    }
    if (_activeShift == null || !_activeShift!.isOpen) {
      _errorMessage = 'Shift kasir belum dibuka! Buka shift kasir terlebih dahulu untuk mencatat kas operasional.';
      notifyListeners();
      return false;
    }

    try {
      await PosDatabaseService.instance.recordCashFlow(
        shiftId: _activeShift?.id,
        type: type,
        amount: amount,
        category: category,
        note: note,
        cashierName: _activeShift?.cashierName ?? _cashierName,
      );
      await refreshAll();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mencatat kas operasional: $e';
      notifyListeners();
      return false;
    }
  }

  // --- Kasbon & Piutang Pelanggan ---
  Future<bool> payDebt({
    required int debtId,
    required double amount,
    String? note,
  }) async {
    // Proteksi Keamanan: Shift Kasir Wajib Aktif
    if (_activeShift == null || !_activeShift!.isOpen) {
      _activeShift = await PosDatabaseService.instance.getActiveShift();
    }
    if (_activeShift == null || !_activeShift!.isOpen) {
      _errorMessage = 'Shift kasir belum dibuka! Buka shift kasir terlebih dahulu untuk mencatat pelunasan kasbon.';
      notifyListeners();
      return false;
    }

    try {
      await PosDatabaseService.instance.payCustomerDebt(
        debtId: debtId,
        amount: amount,
        cashierName: _activeShift?.cashierName ?? _cashierName,
        note: note,
      );
      await refreshAll();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal mencatat pembayaran kasbon: $e';
      notifyListeners();
      return false;
    }
  }

  // --- Filter & Riwayat Transaksi Kasir ---
  Future<void> setHistoryDate(DateTime date) async {
    _historyDate = date;
    _historyAllDates = false;
    await _reloadHistoryTransactions();
  }

  Future<void> setHistoryToday() async {
    _historyDate = DateTime.now();
    _historyAllDates = false;
    await _reloadHistoryTransactions();
  }

  Future<void> setHistoryYesterday() async {
    _historyDate = DateTime.now().subtract(const Duration(days: 1));
    _historyAllDates = false;
    await _reloadHistoryTransactions();
  }

  Future<void> setHistoryAllDates() async {
    _historyAllDates = true;
    _historyDate = null;
    await _reloadHistoryTransactions();
  }

  Future<void> setHistoryInvoiceQuery(String query) async {
    _historyInvoiceQuery = query.trim();
    await _reloadHistoryTransactions();
  }

  Future<void> resetHistoryFilters() async {
    _historyDate = DateTime.now();
    _historyAllDates = false;
    _historyInvoiceQuery = '';
    await _reloadHistoryTransactions();
  }

  Future<void> _reloadHistoryTransactions() async {
    _transactions = await PosDatabaseService.instance.getTransactions(
      date: _historyAllDates ? null : _historyDate,
      searchQuery: _historyInvoiceQuery.isNotEmpty ? _historyInvoiceQuery : null,
      limit: 150,
    );
    notifyListeners();
  }

  // --- Cetak Barcode & QR Code Label ---
  Future<bool> printProductBarcode(
    PosProduct product, {
    int qty = 1,
    bool isQr = false,
  }) async {
    try {
      return await PrinterService.instance.printBarcodeLabels(
        product,
        qty: qty,
        isQr: isQr,
        storeName: _storeName,
      );
    } catch (e) {
      debugPrint('[PosProvider] Error printProductBarcode: $e');
      return false;
    }
  }

  // --- Master Pelanggan Methods ---
  void selectCustomer(PosCustomer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  Future<void> loadCustomers({String? query}) async {
    _customers = await PosDatabaseService.instance.getCustomers(searchQuery: query);
    notifyListeners();
  }

  Future<PosCustomer?> addCustomer({
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final cust = PosCustomer(
        name: name.trim(),
        phone: phone?.trim(),
        address: address?.trim(),
        notes: notes?.trim(),
        createdAt: now,
        updatedAt: now,
      );
      final id = await PosDatabaseService.instance.insertCustomer(cust);
      final created = cust.copyWith(id: id);
      await loadCustomers();
      return created;
    } catch (e) {
      _errorMessage = 'Gagal menambahkan pelanggan: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateCustomer(PosCustomer customer) async {
    try {
      await PosDatabaseService.instance.updateCustomer(customer);
      await loadCustomers();
      if (_selectedCustomer?.id == customer.id) {
        _selectedCustomer = customer;
      }
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui pelanggan: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCustomer(int id) async {
    try {
      await PosDatabaseService.instance.deleteCustomer(id);
      if (_selectedCustomer?.id == id) {
        _selectedCustomer = null;
      }
      await loadCustomers();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus pelanggan: $e';
      notifyListeners();
      return false;
    }
  }
}
