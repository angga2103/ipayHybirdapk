import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/pos_cart_item.dart';
import '../models/pos_product.dart';
import '../models/pos_transaction.dart';

class ConsignmentSummary {
  final String penitip;
  final int variantCount;
  final int totalStock;
  final int totalSoldQty;
  final double totalGross;
  final double totalDueToPenitip;
  final double storeFee;
  final double totalSettled;

  ConsignmentSummary({
    required this.penitip,
    required this.variantCount,
    required this.totalStock,
    required this.totalSoldQty,
    required this.totalGross,
    required this.totalDueToPenitip,
    required this.storeFee,
    this.totalSettled = 0.0,
  });

  double get remainingDue => totalDueToPenitip - totalSettled;
}

class PosDatabaseService {
  PosDatabaseService._internal();
  static final PosDatabaseService instance = PosDatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'garudatel_pos.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // 1. Tabel Produk
        await db.execute('''
          CREATE TABLE pos_products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kode TEXT UNIQUE NOT NULL,
            nama TEXT NOT NULL,
            unit TEXT NOT NULL DEFAULT 'pcs',
            harga_dasar REAL NOT NULL DEFAULT 0,
            harga_jual REAL NOT NULL DEFAULT 0,
            berat_gr REAL NOT NULL DEFAULT 0,
            stok INTEGER NOT NULL DEFAULT -1,
            kategori TEXT NOT NULL DEFAULT 'Umum',
            penitip TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');
        await db.execute('CREATE INDEX idx_products_kode ON pos_products(kode);');
        await db.execute('CREATE INDEX idx_products_nama ON pos_products(nama);');
        await db.execute('CREATE INDEX idx_products_kategori ON pos_products(kategori);');
        await db.execute('CREATE INDEX idx_products_penitip ON pos_products(penitip);');

        // 2. Tabel Transaksi
        await db.execute('''
          CREATE TABLE pos_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_no TEXT UNIQUE NOT NULL,
            date_time TEXT NOT NULL,
            total_amount REAL NOT NULL,
            normal_amount REAL NOT NULL DEFAULT 0,
            discount_amount REAL NOT NULL DEFAULT 0,
            profit_amount REAL NOT NULL DEFAULT 0,
            consignment_due_amount REAL NOT NULL DEFAULT 0,
            cash_paid REAL NOT NULL,
            change_due REAL NOT NULL,
            payment_method TEXT NOT NULL DEFAULT 'Tunai',
            cashier_name TEXT NOT NULL DEFAULT 'Kasir',
            note TEXT
          );
        ''');
        await db.execute('CREATE INDEX idx_trx_invoice ON pos_transactions(invoice_no);');
        await db.execute('CREATE INDEX idx_trx_date ON pos_transactions(date_time);');

        // 3. Tabel Detail Item Transaksi
        await db.execute('''
          CREATE TABLE pos_transaction_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER NOT NULL,
            product_kode TEXT NOT NULL,
            product_name TEXT NOT NULL,
            unit TEXT NOT NULL DEFAULT 'pcs',
            cost_price REAL NOT NULL,
            normal_price REAL NOT NULL,
            sold_price REAL NOT NULL,
            qty INTEGER NOT NULL,
            subtotal REAL NOT NULL,
            profit REAL NOT NULL,
            penitip TEXT,
            FOREIGN KEY (transaction_id) REFERENCES pos_transactions (id) ON DELETE CASCADE
          );
        ''');
        await db.execute('CREATE INDEX idx_items_trx ON pos_transaction_items(transaction_id);');
        await db.execute('CREATE INDEX idx_items_penitip ON pos_transaction_items(penitip);');

        // 4. Tabel Pelunasan / Setoran Konsinyasi
        await db.execute('''
          CREATE TABLE pos_consignment_settlements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            penitip TEXT NOT NULL,
            date_time TEXT NOT NULL,
            total_qty INTEGER NOT NULL,
            total_due REAL NOT NULL,
            store_fee REAL NOT NULL,
            note TEXT
          );
        ''');

        // Seeding Awal (Contoh Produk Default agar langsung bisa dicoba kasir)
        await _seedDefaultProducts(db);
      },
    );
  }

  Future<void> _seedDefaultProducts(Database db) async {
    final now = DateTime.now().toIso8601String();
    final defaults = [
      {
        'kode': 'MN-001',
        'nama': 'Kopi Susu Gula Aren',
        'unit': 'cup',
        'harga_dasar': 7000.0,
        'harga_jual': 15000.0,
        'berat_gr': 250.0,
        'stok': 50,
        'kategori': 'Minuman',
        'penitip': null,
        'created_at': now,
        'updated_at': now,
      },
      {
        'kode': 'MN-002',
        'nama': 'Es Teh Manis Jumbo',
        'unit': 'cup',
        'harga_dasar': 2000.0,
        'harga_jual': 5000.0,
        'berat_gr': 300.0,
        'stok': -1, // Unlimited
        'kategori': 'Minuman',
        'penitip': null,
        'created_at': now,
        'updated_at': now,
      },
      {
        'kode': 'MK-001',
        'nama': 'Mie Goreng Telur Spesial',
        'unit': 'porsi',
        'harga_dasar': 6000.0,
        'harga_jual': 12000.0,
        'berat_gr': 200.0,
        'stok': 30,
        'kategori': 'Makanan',
        'penitip': null,
        'created_at': now,
        'updated_at': now,
      },
      {
        'kode': 'RK-001',
        'nama': 'Rokok Sampoerna Mild 16',
        'unit': 'bks',
        'harga_dasar': 32000.0,
        'harga_jual': 35000.0,
        'berat_gr': 50.0,
        'stok': 20,
        'kategori': 'Rokok & Pulsa',
        'penitip': null,
        'created_at': now,
        'updated_at': now,
      },
      // KONSINYASI (TITIPAN)
      {
        'kode': 'KS-001',
        'nama': 'Keripik Pisang Coklat Bu Siti',
        'unit': 'bks',
        'harga_dasar': 8000.0,
        'harga_jual': 11000.0,
        'berat_gr': 150.0,
        'stok': 15,
        'kategori': 'Konsinyasi',
        'penitip': 'Bu Siti',
        'created_at': now,
        'updated_at': now,
      },
      {
        'kode': 'KS-002',
        'nama': 'Roti Bakar Coklat Keju Pak Joko',
        'unit': 'pcs',
        'harga_dasar': 5000.0,
        'harga_jual': 7000.0,
        'berat_gr': 120.0,
        'stok': 10,
        'kategori': 'Konsinyasi',
        'penitip': 'Pak Joko',
        'created_at': now,
        'updated_at': now,
      },
    ];

    for (final p in defaults) {
      await db.insert('pos_products', p);
    }
  }

  // ==========================================
  // MANAJEMEN PRODUK
  // ==========================================

  Future<List<PosProduct>> getAllProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('pos_products', orderBy: 'nama ASC');
    return maps.map((m) => PosProduct.fromMap(m)).toList();
  }

  Future<List<PosProduct>> searchProducts(String query, {String? category}) async {
    final db = await database;
    String where = '';
    List<dynamic> whereArgs = [];

    if (query.trim().isNotEmpty) {
      where = '(kode LIKE ? OR nama LIKE ?)';
      whereArgs.addAll(['%${query.trim()}%', '%${query.trim()}%']);
    }

    if (category != null && category.isNotEmpty && category != 'ALL') {
      if (category == 'Konsinyasi') {
        where += '${where.isEmpty ? '' : ' AND '}penitip IS NOT NULL AND penitip != ""';
      } else {
        where += '${where.isEmpty ? '' : ' AND '}kategori = ?';
        whereArgs.add(category);
      }
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'pos_products',
      where: where.isEmpty ? null : where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'nama ASC',
    );
    return maps.map((m) => PosProduct.fromMap(m)).toList();
  }

  Future<List<String>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT kategori FROM pos_products WHERE kategori IS NOT NULL AND kategori != "" ORDER BY kategori ASC',
    );
    return maps.map((m) => m['kategori'].toString()).toList();
  }

  Future<List<String>> getAllConsignors() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT penitip FROM pos_products WHERE penitip IS NOT NULL AND penitip != "" ORDER BY penitip ASC',
    );
    return maps.map((m) => m['penitip'].toString()).toList();
  }

  Future<int> insertOrUpdateProduct(PosProduct product) async {
    final db = await database;
    return await db.insert(
      'pos_products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> bulkInsertOrUpdateProducts(List<PosProduct> products) async {
    final db = await database;
    final batch = db.batch();
    for (final p in products) {
      batch.insert(
        'pos_products',
        p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final results = await batch.commit(noResult: false);
    return results.length;
  }

  Future<int> deleteProduct(String kode) async {
    final db = await database;
    return await db.delete('pos_products', where: 'kode = ?', whereArgs: [kode]);
  }

  Future<int> deleteAllProducts() async {
    final db = await database;
    return await db.delete('pos_products');
  }

  // ==========================================
  // TRANSAKSI KASIR (CHECKOUT ATOMIK)
  // ==========================================

  Future<PosTransaction> checkoutTransaction({
    required List<PosCartItem> cartItems,
    required double cashPaid,
    String paymentMethod = 'Tunai',
    String cashierName = 'Kasir',
    String? note,
  }) async {
    final db = await database;

    double totalAmount = 0.0;
    double normalAmount = 0.0;
    double profitAmount = 0.0;
    double consignmentDueAmount = 0.0;

    for (final item in cartItems) {
      totalAmount += item.subtotal;
      normalAmount += item.normalSubtotal;
      profitAmount += item.profitAmount;
      if (item.isConsignment) {
        consignmentDueAmount += item.costPrice * item.qty;
      }
    }

    final double discountAmount = normalAmount - totalAmount;
    final double changeDue = cashPaid - totalAmount;
    final now = DateTime.now();
    final invoiceNo = 'POS-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final trx = PosTransaction(
      invoiceNo: invoiceNo,
      dateTime: now,
      totalAmount: totalAmount,
      normalAmount: normalAmount,
      discountAmount: discountAmount,
      profitAmount: profitAmount,
      consignmentDueAmount: consignmentDueAmount,
      cashPaid: cashPaid,
      changeDue: changeDue < 0 ? 0 : changeDue,
      paymentMethod: paymentMethod,
      cashierName: cashierName,
      note: note,
    );

    await db.transaction((txn) async {
      // 1. Simpan Header Transaksi
      final trxId = await txn.insert('pos_transactions', trx.toMap());

      // 2. Simpan Setiap Item
      for (final item in cartItems) {
        final trxItem = PosTransactionItem(
          transactionId: trxId,
          productKode: item.product.kode,
          productName: item.product.nama,
          unit: item.product.unit,
          costPrice: item.costPrice,
          normalPrice: item.normalPrice,
          soldPrice: item.actualPrice,
          qty: item.qty,
          subtotal: item.subtotal,
          profit: item.profitAmount,
          penitip: item.penitip,
        );
        await txn.insert('pos_transaction_items', trxItem.toMap(trxId));

        // 3. Potong Stok Produk jika stok terbatas (stok >= 0)
        await txn.rawUpdate('''
          UPDATE pos_products 
          SET stok = CASE WHEN stok >= ? THEN stok - ? ELSE 0 END,
              updated_at = ?
          WHERE kode = ? AND stok >= 0
        ''', [item.qty, item.qty, now.toIso8601String(), item.product.kode]);
      }
    });

    final savedItems = cartItems.map((c) => PosTransactionItem(
      productKode: c.product.kode,
      productName: c.product.nama,
      unit: c.product.unit,
      costPrice: c.costPrice,
      normalPrice: c.normalPrice,
      soldPrice: c.actualPrice,
      qty: c.qty,
      subtotal: c.subtotal,
      profit: c.profitAmount,
      penitip: c.penitip,
    )).toList();

    return PosTransaction(
      invoiceNo: trx.invoiceNo,
      dateTime: trx.dateTime,
      totalAmount: trx.totalAmount,
      normalAmount: trx.normalAmount,
      discountAmount: trx.discountAmount,
      profitAmount: trx.profitAmount,
      consignmentDueAmount: trx.consignmentDueAmount,
      cashPaid: trx.cashPaid,
      changeDue: trx.changeDue,
      paymentMethod: trx.paymentMethod,
      cashierName: trx.cashierName,
      note: trx.note,
      items: savedItems,
    );
  }

  Future<List<PosTransaction>> getAllTransactions({int limit = 50}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pos_transactions',
      orderBy: 'date_time DESC',
      limit: limit,
    );

    List<PosTransaction> trxs = [];
    for (final m in maps) {
      final trxId = m['id'] as int;
      final itemMaps = await db.query(
        'pos_transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [trxId],
      );
      final items = itemMaps.map((it) => PosTransactionItem.fromMap(it)).toList();
      trxs.add(PosTransaction.fromMap(m, items));
    }
    return trxs;
  }

  // ==========================================
  // RINGKASAN STATISTIK & KONSINYASI
  // ==========================================

  Future<Map<String, double>> getTodaySalesStats() async {
    final db = await database;
    final todayPrefix = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD

    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_amount), 0) as total_omset,
        COALESCE(SUM(profit_amount), 0) as total_profit,
        COALESCE(SUM(discount_amount), 0) as total_discount,
        COALESCE(SUM(consignment_due_amount), 0) as total_consignment_due,
        COUNT(id) as total_trx
      FROM pos_transactions
      WHERE date_time LIKE ?
    ''', ['$todayPrefix%']);

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'total_omset': (row['total_omset'] as num).toDouble(),
        'total_profit': (row['total_profit'] as num).toDouble(),
        'total_discount': (row['total_discount'] as num).toDouble(),
        'total_consignment_due': (row['total_consignment_due'] as num).toDouble(),
        'total_trx': (row['total_trx'] as num).toDouble(),
      };
    }

    return {
      'total_omset': 0.0,
      'total_profit': 0.0,
      'total_discount': 0.0,
      'total_consignment_due': 0.0,
      'total_trx': 0.0,
    };
  }

  Future<List<ConsignmentSummary>> getConsignmentSummaries() async {
    final db = await database;
    final consignors = await getAllConsignors();

    List<ConsignmentSummary> summaries = [];
    for (final p in consignors) {
      // 1. Data varian & stok saat ini
      final prodResult = await db.rawQuery('''
        SELECT COUNT(id) as variant_count, COALESCE(SUM(CASE WHEN stok > 0 THEN stok ELSE 0 END), 0) as total_stock
        FROM pos_products
        WHERE penitip = ?
      ''', [p]);
      final variantCount = (prodResult.first['variant_count'] as num).toInt();
      final totalStock = (prodResult.first['total_stock'] as num).toInt();

      // 2. Data penjualan terakumulasi
      final salesResult = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(qty), 0) as total_sold,
          COALESCE(SUM(subtotal), 0) as total_gross,
          COALESCE(SUM(cost_price * qty), 0) as total_due,
          COALESCE(SUM(profit), 0) as store_fee
        FROM pos_transaction_items
        WHERE penitip = ?
      ''', [p]);
      final totalSold = (salesResult.first['total_sold'] as num).toInt();
      final totalGross = (salesResult.first['total_gross'] as num).toDouble();
      final totalDue = (salesResult.first['total_due'] as num).toDouble();
      final storeFee = (salesResult.first['store_fee'] as num).toDouble();

      // 3. Data pelunasan yang sudah disetorkan
      final settleResult = await db.rawQuery('''
        SELECT COALESCE(SUM(total_due), 0) as total_settled
        FROM pos_consignment_settlements
        WHERE penitip = ?
      ''', [p]);
      final totalSettled = (settleResult.first['total_settled'] as num).toDouble();

      summaries.add(ConsignmentSummary(
        penitip: p,
        variantCount: variantCount,
        totalStock: totalStock,
        totalSoldQty: totalSold,
        totalGross: totalGross,
        totalDueToPenitip: totalDue,
        storeFee: storeFee,
        totalSettled: totalSettled,
      ));
    }

    return summaries;
  }

  Future<void> settleConsignment({
    required String penitip,
    required int totalQty,
    required double totalDue,
    required double storeFee,
    String? note,
  }) async {
    final db = await database;
    await db.insert('pos_consignment_settlements', {
      'penitip': penitip,
      'date_time': DateTime.now().toIso8601String(),
      'total_qty': totalQty,
      'total_due': totalDue,
      'store_fee': storeFee,
      'note': note,
    });
  }
}
