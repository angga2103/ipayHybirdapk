import 'package:flutter/foundation.dart';
import '../models/pos_cart_item.dart';
import '../models/pos_product.dart';
import '../models/pos_transaction.dart';
import '../services/pos_backup_service.dart';
import '../services/pos_database_service.dart';
import '../services/pos_excel_service.dart';
import '../services/printer_service.dart';

class PosProvider extends ChangeNotifier {
  List<PosProduct> _products = [];
  List<String> _categories = [];
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  final List<PosCartItem> _cart = [];
  List<ConsignmentSummary> _consignments = [];
  List<PosTransaction> _transactions = [];
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

  List<PosProduct> get products => _products;
  List<String> get categories => _categories;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  List<PosCartItem> get cart => List.unmodifiable(_cart);
  List<ConsignmentSummary> get consignments => _consignments;
  List<PosTransaction> get transactions => _transactions;
  Map<String, double> get todayStats => _todayStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get cashierName => _cashierName;
  String get storeName => _storeName;

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
      // Sinkronisasi profil toko & logo otomatis dari backend admin web secara background
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
    _transactions = await PosDatabaseService.instance.getAllTransactions(limit: 50);
    _todayStats = await PosDatabaseService.instance.getTodaySalesStats();
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

  // --- Cart Operations ---
  void addToCart(PosProduct product) {
    final idx = _cart.indexWhere((it) => it.product.kode == product.kode);
    if (idx >= 0) {
      _cart[idx].qty += 1;
    } else {
      _cart.add(PosCartItem(product: product, qty: 1));
    }
    notifyListeners();
  }

  void updateCartQty(int index, int delta) {
    if (index < 0 || index >= _cart.length) return;
    _cart[index].qty += delta;
    if (_cart[index].qty <= 0) {
      _cart.removeAt(index);
    }
    notifyListeners();
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
  }) async {
    if (_cart.isEmpty) return null;

    try {
      final trx = await PosDatabaseService.instance.checkoutTransaction(
        cartItems: _cart,
        cashPaid: cashPaid,
        paymentMethod: paymentMethod,
        cashierName: _cashierName,
        note: note,
      );

      _cart.clear();
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
      await PosDatabaseService.instance.insertOrUpdateProduct(product);
      await refreshAll();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan produk: $e';
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

  // --- Retur / Pembatalan Transaksi ---
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

  // --- Excel Sync ---
  Future<int> importFromExcel() async {
    try {
      final count = await PosExcelService.instance.pickAndImportExcel();
      if (count > 0) {
        await refreshAll();
      }
      return count;
    } catch (e) {
      _errorMessage = 'Gagal import Excel: $e';
      notifyListeners();
      return 0;
    }
  }

  Future<bool> exportTemplate() async {
    return await PosExcelService.instance.shareTemplateExcel();
  }

  Future<bool> exportCatalog() async {
    return await PosExcelService.instance.shareProductCatalog(_products);
  }

  // --- Consignment Settlement ---
  Future<bool> settleConsignment({
    required ConsignmentSummary summary,
    bool andPrint = true,
  }) async {
    try {
      await PosDatabaseService.instance.settleConsignment(
        penitip: summary.penitip,
        totalQty: summary.totalSoldQty,
        totalDue: summary.totalDueToPenitip,
        storeFee: summary.storeFee,
      );

      if (andPrint) {
        await printConsignmentReport(summary);
      }

      await refreshAll();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memproses setoran konsinyasi: $e';
      notifyListeners();
      return false;
    }
  }
}
