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

  double get remainingDue {
    final diff = totalDueToPenitip - totalSettled;
    return diff < 0 ? 0.0 : diff;
  }
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

  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'garudatel_pos.db');
  }

  Future<void> closeDatabase() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  Future<Database> _initDatabase() async {
    final path = await getDatabaseFilePath();

    return await openDatabase(
      path,
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // 1. Tabel Produk POS
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
            is_stock_managed INTEGER NOT NULL DEFAULT 1,
            kategori TEXT NOT NULL DEFAULT 'Umum',
            penitip TEXT,
            product_type TEXT NOT NULL DEFAULT 'shop',
            commission_type TEXT NOT NULL DEFAULT 'markup',
            commission_value REAL NOT NULL DEFAULT 0,
            image_path TEXT,
            is_archived INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');
        await db.execute('CREATE INDEX idx_products_kode ON pos_products(kode);');
        await db.execute('CREATE INDEX idx_products_nama ON pos_products(nama);');
        await db.execute('CREATE INDEX idx_products_kategori ON pos_products(kategori);');
        await db.execute('CREATE INDEX idx_products_penitip ON pos_products(penitip);');
        await db.execute('CREATE INDEX idx_products_archived ON pos_products(is_archived);');

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
            note TEXT,
            status TEXT NOT NULL DEFAULT 'COMPLETED'
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
            returned_qty INTEGER NOT NULL DEFAULT 0,
            subtotal REAL NOT NULL,
            profit REAL NOT NULL,
            penitip TEXT,
            is_stock_managed INTEGER NOT NULL DEFAULT 1,
            due_to_penitip REAL NOT NULL DEFAULT 0,
            FOREIGN KEY (transaction_id) REFERENCES pos_transactions (id) ON DELETE CASCADE
          );
        ''');
        await db.execute('CREATE INDEX idx_items_trx ON pos_transaction_items(transaction_id);');
        await db.execute('CREATE INDEX idx_items_penitip ON pos_transaction_items(penitip);');

        // 4. Tabel Riwayat Retur / Pengembalian Item
        await db.execute('''
          CREATE TABLE pos_transaction_returns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER NOT NULL,
            invoice_no TEXT NOT NULL,
            product_kode TEXT NOT NULL,
            product_name TEXT NOT NULL,
            qty_returned INTEGER NOT NULL,
            refund_amount REAL NOT NULL,
            reason TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (transaction_id) REFERENCES pos_transactions (id) ON DELETE CASCADE
          );
        ''');
        await db.execute('CREATE INDEX idx_returns_trx ON pos_transaction_returns(transaction_id);');
        await db.execute('CREATE INDEX idx_returns_invoice ON pos_transaction_returns(invoice_no);');

        // 5. Tabel Pelunasan / Setoran Konsinyasi
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

        // 6. Tabel Rekap Penutupan Kas Harian (Laporan Z)
        await db.execute('''
          CREATE TABLE pos_daily_closings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            closing_date TEXT UNIQUE NOT NULL,
            total_transactions INTEGER NOT NULL DEFAULT 0,
            total_revenue REAL NOT NULL DEFAULT 0,
            total_profit REAL NOT NULL DEFAULT 0,
            cash_revenue REAL NOT NULL DEFAULT 0,
            non_cash_revenue REAL NOT NULL DEFAULT 0,
            consignment_due REAL NOT NULL DEFAULT 0,
            closed_at TEXT NOT NULL,
            notes TEXT
          );
        ''');
        await db.execute('CREATE INDEX idx_closing_date ON pos_daily_closings(closing_date);');

        // 7. Tabel Antrean / Keranjang Belanja Tertahan (Hold Carts)
        await db.execute('''
          CREATE TABLE pos_hold_carts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cart_id TEXT UNIQUE NOT NULL,
            customer_note TEXT,
            hold_at TEXT NOT NULL,
            total_amount REAL NOT NULL DEFAULT 0,
            items_json TEXT NOT NULL
          );
        ''');
        await db.execute('CREATE INDEX idx_hold_carts_id ON pos_hold_carts(cart_id);');

        // Seeding Awal Default Produk
        await _seedDefaultProducts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE pos_products ADD COLUMN is_stock_managed INTEGER NOT NULL DEFAULT 1;');
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE pos_products ADD COLUMN product_type TEXT NOT NULL DEFAULT 'shop';");
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE pos_products ADD COLUMN commission_type TEXT NOT NULL DEFAULT 'markup';");
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE pos_products ADD COLUMN commission_value REAL NOT NULL DEFAULT 0;');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE pos_products ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0;');
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE pos_transactions ADD COLUMN status TEXT NOT NULL DEFAULT 'COMPLETED';");
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE pos_transaction_items ADD COLUMN is_stock_managed INTEGER NOT NULL DEFAULT 1;');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE pos_transaction_items ADD COLUMN due_to_penitip REAL NOT NULL DEFAULT 0;');
          } catch (_) {}
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS pos_daily_closings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                closing_date TEXT UNIQUE NOT NULL,
                total_transactions INTEGER NOT NULL DEFAULT 0,
                total_revenue REAL NOT NULL DEFAULT 0,
                total_profit REAL NOT NULL DEFAULT 0,
                cash_revenue REAL NOT NULL DEFAULT 0,
                non_cash_revenue REAL NOT NULL DEFAULT 0,
                consignment_due REAL NOT NULL DEFAULT 0,
                closed_at TEXT NOT NULL,
                notes TEXT
              );
            ''');
          } catch (_) {}
        }

        if (oldVersion < 3) {
          // Migrasi Skema v2 -> v3 (Dukungan Retur Parsial & Riwayat Retur)
          try {
            await db.execute('ALTER TABLE pos_transaction_items ADD COLUMN returned_qty INTEGER NOT NULL DEFAULT 0;');
          } catch (_) {}
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS pos_transaction_returns (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                transaction_id INTEGER NOT NULL,
                invoice_no TEXT NOT NULL,
                product_kode TEXT NOT NULL,
                product_name TEXT NOT NULL,
                qty_returned INTEGER NOT NULL,
                refund_amount REAL NOT NULL,
                reason TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY (transaction_id) REFERENCES pos_transactions (id) ON DELETE CASCADE
              );
            ''');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_returns_trx ON pos_transaction_returns(transaction_id);');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_returns_invoice ON pos_transaction_returns(invoice_no);');
          } catch (_) {}
        }

        if (oldVersion < 4) {
          // Migrasi Skema v3 -> v4 (Foto Produk & Hold Carts)
          try {
            await db.execute('ALTER TABLE pos_products ADD COLUMN image_path TEXT;');
          } catch (_) {}
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS pos_hold_carts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cart_id TEXT UNIQUE NOT NULL,
                customer_note TEXT,
                hold_at TEXT NOT NULL,
                total_amount REAL NOT NULL DEFAULT 0,
                items_json TEXT NOT NULL
              );
            ''');
            await db.execute('CREATE INDEX IF NOT EXISTS idx_hold_carts_id ON pos_hold_carts(cart_id);');
          } catch (_) {}
        }
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
        'is_stock_managed': 1,
        'kategori': 'Minuman',
        'penitip': null,
        'product_type': 'shop',
        'commission_type': 'markup',
        'commission_value': 0.0,
        'is_archived': 0,
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
        'stok': -1,
        'is_stock_managed': 0, // Bebas stok / unlimited
        'kategori': 'Minuman',
        'penitip': null,
        'product_type': 'shop',
        'commission_type': 'markup',
        'commission_value': 0.0,
        'is_archived': 0,
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
        'is_stock_managed': 1,
        'kategori': 'Makanan',
        'penitip': null,
        'product_type': 'shop',
        'commission_type': 'markup',
        'commission_value': 0.0,
        'is_archived': 0,
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
        'is_stock_managed': 1,
        'kategori': 'Rokok & Pulsa',
        'penitip': null,
        'product_type': 'shop',
        'commission_type': 'markup',
        'commission_value': 0.0,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      },
      // KONSINYASI (TITIP JUAL)
      {
        'kode': 'KS-001',
        'nama': 'Keripik Pisang Coklat Bu Siti',
        'unit': 'bks',
        'harga_dasar': 8000.0,
        'harga_jual': 11000.0,
        'berat_gr': 150.0,
        'stok': 15,
        'is_stock_managed': 1,
        'kategori': 'Konsinyasi',
        'penitip': 'Bu Siti',
        'product_type': 'consignment',
        'commission_type': 'markup', // Selisih 3.000 untuk toko
        'commission_value': 0.0,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      },
      {
        'kode': 'KS-002',
        'nama': 'Roti Bakar Keju Pak Joko',
        'unit': 'pcs',
        'harga_dasar': 5000.0,
        'harga_jual': 7000.0,
        'berat_gr': 120.0,
        'stok': 10,
        'is_stock_managed': 1,
        'kategori': 'Konsinyasi',
        'penitip': 'Pak Joko',
        'product_type': 'consignment',
        'commission_type': 'nominal',
        'commission_value': 1500.0, // Komisi 1.500 per pcs
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      },
    ];

    for (final p in defaults) {
      await db.insert('pos_products', p, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ==========================================
  // MANAJEMEN PRODUK
  // ==========================================

  Future<List<PosProduct>> getAllProducts({bool includeArchived = false}) async {
    final db = await database;
    final where = includeArchived ? null : 'is_archived = 0';
    final List<Map<String, dynamic>> maps = await db.query(
      'pos_products',
      where: where,
      orderBy: 'nama ASC',
    );
    return maps.map((m) => PosProduct.fromMap(m)).toList();
  }

  Future<List<PosProduct>> searchProducts(String query, {String? category, bool includeArchived = false}) async {
    final db = await database;
    List<String> conditions = [];
    List<dynamic> whereArgs = [];

    if (!includeArchived) {
      conditions.add('is_archived = 0');
    }

    if (query.trim().isNotEmpty) {
      conditions.add('(kode LIKE ? OR nama LIKE ?)');
      whereArgs.addAll(['%${query.trim()}%', '%${query.trim()}%']);
    }

    if (category != null && category.isNotEmpty && category != 'ALL') {
      if (category == 'Konsinyasi') {
        conditions.add('(penitip IS NOT NULL AND penitip != "" OR product_type = "consignment")');
      } else {
        conditions.add('kategori = ?');
        whereArgs.add(category);
      }
    }

    final whereClause = conditions.isEmpty ? null : conditions.join(' AND ');

    final List<Map<String, dynamic>> maps = await db.query(
      'pos_products',
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'nama ASC',
    );
    return maps.map((m) => PosProduct.fromMap(m)).toList();
  }

  Future<List<String>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT kategori FROM pos_products WHERE is_archived = 0 AND kategori IS NOT NULL AND kategori != "" ORDER BY kategori ASC',
    );
    return maps.map((m) => m['kategori'].toString()).toList();
  }

  Future<List<String>> getAllConsignors() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT penitip FROM pos_products WHERE is_archived = 0 AND penitip IS NOT NULL AND penitip != "" ORDER BY penitip ASC',
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

  /// Menghapus produk secara aman (Soft delete jika sudah ada transaksi, hard delete jika belum)
  Future<bool> deleteOrArchiveProduct(String kode) async {
    final db = await database;
    final check = await db.rawQuery(
      'SELECT COUNT(id) as cnt FROM pos_transaction_items WHERE product_kode = ?',
      [kode],
    );
    final count = (check.first['cnt'] as num).toInt();

    if (count > 0) {
      await db.update(
        'pos_products',
        {'is_archived': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'kode = ?',
        whereArgs: [kode],
      );
      return false; // Diarsipkan (bukan dihapus permanen)
    } else {
      await db.delete('pos_products', where: 'kode = ?', whereArgs: [kode]);
      return true; // Dihapus permanen
    }
  }

  Future<void> restoreProduct(String kode) async {
    final db = await database;
    await db.update(
      'pos_products',
      {'is_archived': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'kode = ?',
      whereArgs: [kode],
    );
  }

  // ==========================================
  // TRANSAKSI KASIR (CHECKOUT ATOMIK DENGAN VALIDASI STOK KETAT)
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
        consignmentDueAmount += item.dueToPenitipAmount;
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
      status: 'COMPLETED',
    );

    int trxId = 0;

    await db.transaction((txn) async {
      // 1. Verifikasi Ketersediaan Stok Terlebih Dahulu (Strict Stock Validation)
      for (final item in cartItems) {
        if (item.isStockManaged) {
          final pQuery = await txn.rawQuery(
            'SELECT nama, stok FROM pos_products WHERE kode = ? AND is_stock_managed = 1',
            [item.product.kode],
          );
          if (pQuery.isNotEmpty) {
            final curStock = (pQuery.first['stok'] as num).toInt();
            if (curStock < item.qty) {
              final prodName = pQuery.first['nama'] ?? item.product.nama;
              throw Exception('Stok "$prodName" tidak mencukupi (Tersedia: $curStock, Diminta: ${item.qty}). Transaksi dibatalkan.');
            }
          } else {
            throw Exception('Produk "${item.product.nama}" (${item.product.kode}) tidak ditemukan di etalase.');
          }
        }
      }

      // 2. Simpan Header Transaksi
      trxId = await txn.insert('pos_transactions', trx.toMap());

      // 3. Simpan Setiap Item Transaksi dan Potong Stok
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
          returnedQty: 0,
          subtotal: item.subtotal,
          profit: item.profitAmount,
          penitip: item.penitip,
          isStockManaged: item.isStockManaged,
          dueToPenitip: item.dueToPenitipAmount,
        );
        await txn.insert('pos_transaction_items', trxItem.toMap(trxId));

        // Potong Stok Produk HANYA jika kelola stok aktif
        if (item.isStockManaged) {
          await txn.rawUpdate('''
            UPDATE pos_products 
            SET stok = CASE WHEN stok >= ? THEN stok - ? ELSE 0 END,
                updated_at = ?
            WHERE kode = ? AND is_stock_managed = 1 AND stok >= 0
          ''', [item.qty, item.qty, now.toIso8601String(), item.product.kode]);
        }
      }
    });

    final savedItems = cartItems.map((c) => PosTransactionItem(
      transactionId: trxId,
      productKode: c.product.kode,
      productName: c.product.nama,
      unit: c.product.unit,
      costPrice: c.costPrice,
      normalPrice: c.normalPrice,
      soldPrice: c.actualPrice,
      qty: c.qty,
      returnedQty: 0,
      subtotal: c.subtotal,
      profit: c.profitAmount,
      penitip: c.penitip,
      isStockManaged: c.isStockManaged,
      dueToPenitip: c.dueToPenitipAmount,
    )).toList();

    return PosTransaction(
      id: trxId,
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
      status: 'COMPLETED',
      items: savedItems,
      returns: [],
    );
  }

  // ==========================================
  // RETUR BARANG (PARSIAL / PER ITEM)
  // ==========================================

  /// Melakukan retur untuk sebagian atau seluruh unit dari 1 item produk tertentu
  Future<PosTransactionReturn> returnTransactionItem({
    required String invoiceNo,
    required String productKode,
    required int qtyToReturn,
    String? reason,
  }) async {
    if (qtyToReturn <= 0) {
      throw Exception('Jumlah unit yang diretur harus lebih dari 0.');
    }

    final db = await database;

    // 1. Ambil transaksi
    final trxs = await db.query('pos_transactions', where: 'invoice_no = ?', whereArgs: [invoiceNo]);
    if (trxs.isEmpty) {
      throw Exception('Faktur $invoiceNo tidak ditemukan.');
    }
    final trxData = trxs.first;
    final trxId = (trxData['id'] as num).toInt();

    // 2. Ambil item bersangkutan
    final items = await db.query(
      'pos_transaction_items',
      where: 'transaction_id = ? AND product_kode = ?',
      whereArgs: [trxId, productKode],
    );
    if (items.isEmpty) {
      throw Exception('Produk $productKode tidak terdapat pada transaksi $invoiceNo.');
    }

    final item = PosTransactionItem.fromMap(items.first);
    if (qtyToReturn > item.activeQty) {
      throw Exception('Jumlah retur ($qtyToReturn) melebihi sisa barang aktif (${item.activeQty}).');
    }

    final now = DateTime.now();
    final refundAmount = qtyToReturn * item.soldPrice;
    final profitRefund = qtyToReturn * item.unitProfit;
    final consignmentDueRefund = qtyToReturn * item.unitDueToPenitip;

    final returnRecord = PosTransactionReturn(
      transactionId: trxId,
      invoiceNo: invoiceNo,
      productKode: item.productKode,
      productName: item.productName,
      qtyReturned: qtyToReturn,
      refundAmount: refundAmount,
      reason: reason ?? 'Retur Kasir',
      createdAt: now,
    );

    await db.transaction((txn) async {
      // A. Catat riwayat retur
      await txn.insert('pos_transaction_returns', returnRecord.toMap(trxId));

      // B. Update returned_qty pada pos_transaction_items
      await txn.rawUpdate('''
        UPDATE pos_transaction_items 
        SET returned_qty = returned_qty + ?
        WHERE id = ?
      ''', [qtyToReturn, item.id]);

      // C. Kembalikan stok fisik jika produk dikelola stoknya
      if (item.isStockManaged) {
        await txn.rawUpdate('''
          UPDATE pos_products 
          SET stok = stok + ?,
              updated_at = ?
          WHERE kode = ? AND is_stock_managed = 1 AND stok >= 0
        ''', [qtyToReturn, now.toIso8601String(), item.productKode]);
      }

      // D. Cek apakah setelah retur ini, seluruh item transaksi habis (semua unit aktif = 0)
      final allItemsQuery = await txn.query('pos_transaction_items', where: 'transaction_id = ?', whereArgs: [trxId]);
      int totalRemainingActiveQty = 0;
      for (final m in allItemsQuery) {
        final q = (m['qty'] as num).toInt();
        final r = (m['returned_qty'] as num).toInt();
        totalRemainingActiveQty += (q - r > 0 ? q - r : 0);
      }

      final newStatus = totalRemainingActiveQty <= 0 ? 'CANCELLED' : 'PARTIAL_RETURN';
      final existingNote = trxData['note']?.toString() ?? '';
      final returnNoteTag = '[Retur ${qtyToReturn}x ${item.productName}: ${_formatRupiah(refundAmount)}]';
      final updatedNote = existingNote.contains(returnNoteTag)
          ? existingNote
          : (existingNote.isEmpty ? returnNoteTag : '$existingNote | $returnNoteTag');

      // E. Update total di header transaksi
      await txn.rawUpdate('''
        UPDATE pos_transactions 
        SET total_amount = MAX(0, total_amount - ?),
            profit_amount = profit_amount - ?,
            consignment_due_amount = MAX(0, consignment_due_amount - ?),
            status = ?,
            note = ?
        WHERE id = ?
      ''', [refundAmount, profitRefund, consignmentDueRefund, newStatus, updatedNote, trxId]);
    });

    return returnRecord;
  }

  static String _formatRupiah(double val) {
    return 'Rp ${val.toInt()}';
  }

  // ==========================================
  // PEMBATALAN PENUH TRANSAKSI (CANCEL ALL)
  // ==========================================

  /// Membatalkan seluruh sisa item yang belum diretur pada transaksi
  Future<bool> cancelTransaction(String invoiceNo, {String? reason}) async {
    final db = await database;
    final trxs = await db.query('pos_transactions', where: 'invoice_no = ?', whereArgs: [invoiceNo]);
    if (trxs.isEmpty) return false;

    final trxData = trxs.first;
    final trxId = trxData['id'] as int;
    final itemMaps = await db.query('pos_transaction_items', where: 'transaction_id = ?', whereArgs: [trxId]);
    final now = DateTime.now();

    await db.transaction((txn) async {
      double totalRefund = 0.0;

      for (final im in itemMaps) {
        final item = PosTransactionItem.fromMap(im);
        final remainingActive = item.activeQty;

        if (remainingActive > 0) {
          final itemRefund = remainingActive * item.soldPrice;
          totalRefund += itemRefund;

          // Catat ke pos_transaction_returns
          await txn.insert('pos_transaction_returns', {
            'transaction_id': trxId,
            'invoice_no': invoiceNo,
            'product_kode': item.productKode,
            'product_name': item.productName,
            'qty_returned': remainingActive,
            'refund_amount': itemRefund,
            'reason': reason ?? 'Pembatalan Penuh Nota',
            'created_at': now.toIso8601String(),
          });

          // Set returned_qty = qty (semua diretur)
          await txn.update(
            'pos_transaction_items',
            {'returned_qty': item.qty},
            where: 'id = ?',
            whereArgs: [item.id],
          );

          // Kembalikan stok fisik jika dikelola
          if (item.isStockManaged) {
            await txn.rawUpdate('''
              UPDATE pos_products 
              SET stok = stok + ?,
                  updated_at = ?
              WHERE kode = ? AND is_stock_managed = 1 AND stok >= 0
            ''', [remainingActive, now.toIso8601String(), item.productKode]);
          }
        }
      }

      // Tandai transaksi sebagai CANCELLED
      final existingNote = trxData['note']?.toString() ?? '';
      final updatedNote = '$existingNote [DIBATALKAN PENUH: ${reason ?? "Pembatalan Kasir"} (Total Refund: ${_formatRupiah(totalRefund)})]'.trim();

      await txn.update(
        'pos_transactions',
        {
          'status': 'CANCELLED',
          'total_amount': 0.0,
          'profit_amount': 0.0,
          'consignment_due_amount': 0.0,
          'note': updatedNote,
        },
        where: 'id = ?',
        whereArgs: [trxId],
      );
    });

    return true;
  }

  // ==========================================
  // QUERY RIWAYAT LENGKAP TRANSAKSI
  // ==========================================

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

      // Ambil items
      final itemMaps = await db.query(
        'pos_transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [trxId],
      );
      final items = itemMaps.map((it) => PosTransactionItem.fromMap(it)).toList();

      // Ambil riwayat returns
      final returnMaps = await db.query(
        'pos_transaction_returns',
        where: 'transaction_id = ?',
        whereArgs: [trxId],
        orderBy: 'created_at ASC',
      );
      final returns = returnMaps.map((r) => PosTransactionReturn.fromMap(r)).toList();

      trxs.add(PosTransaction.fromMap(m, items, returns));
    }
    return trxs;
  }

  Future<PosTransaction?> getTransactionByInvoice(String invoiceNo) async {
    final db = await database;
    final maps = await db.query('pos_transactions', where: 'invoice_no = ?', whereArgs: [invoiceNo]);
    if (maps.isEmpty) return null;

    final trxId = maps.first['id'] as int;
    final itemMaps = await db.query('pos_transaction_items', where: 'transaction_id = ?', whereArgs: [trxId]);
    final items = itemMaps.map((it) => PosTransactionItem.fromMap(it)).toList();

    final returnMaps = await db.query(
      'pos_transaction_returns',
      where: 'transaction_id = ?',
      whereArgs: [trxId],
      orderBy: 'created_at ASC',
    );
    final returns = returnMaps.map((r) => PosTransactionReturn.fromMap(r)).toList();

    return PosTransaction.fromMap(maps.first, items, returns);
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
        COALESCE(SUM(CASE WHEN payment_method = 'Tunai' THEN total_amount ELSE 0 END), 0) as cash_omset,
        COALESCE(SUM(CASE WHEN payment_method != 'Tunai' THEN total_amount ELSE 0 END), 0) as non_cash_omset,
        COUNT(id) as total_trx
      FROM pos_transactions
      WHERE date_time LIKE ? AND status != 'CANCELLED'
    ''', ['$todayPrefix%']);

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'total_omset': (row['total_omset'] as num).toDouble(),
        'total_profit': (row['total_profit'] as num).toDouble(),
        'total_discount': (row['total_discount'] as num).toDouble(),
        'total_consignment_due': (row['total_consignment_due'] as num).toDouble(),
        'cash_omset': (row['cash_omset'] as num).toDouble(),
        'non_cash_omset': (row['non_cash_omset'] as num).toDouble(),
        'total_trx': (row['total_trx'] as num).toDouble(),
      };
    }

    return {
      'total_omset': 0.0,
      'total_profit': 0.0,
      'total_discount': 0.0,
      'total_consignment_due': 0.0,
      'cash_omset': 0.0,
      'non_cash_omset': 0.0,
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
        WHERE penitip = ? AND is_archived = 0
      ''', [p]);
      final variantCount = (prodResult.first['variant_count'] as num).toInt();
      final totalStock = (prodResult.first['total_stock'] as num).toInt();

      // 2. Data penjualan terakumulasi (hanya unit aktif yang TIDAK diretur dan dari transaksi yang tidak dibatalkan)
      final salesResult = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(i.qty - COALESCE(i.returned_qty, 0)), 0) as total_sold,
          COALESCE(SUM((i.qty - COALESCE(i.returned_qty, 0)) * i.sold_price), 0) as total_gross,
          COALESCE(SUM((i.qty - COALESCE(i.returned_qty, 0)) * (CASE WHEN i.due_to_penitip > 0 THEN (i.due_to_penitip / i.qty) ELSE i.cost_price END)), 0) as total_due,
          COALESCE(SUM((i.qty - COALESCE(i.returned_qty, 0)) * (i.profit / i.qty)), 0) as store_fee
        FROM pos_transaction_items i
        JOIN pos_transactions t ON i.transaction_id = t.id
        WHERE i.penitip = ? AND t.status != 'CANCELLED' AND (i.qty - COALESCE(i.returned_qty, 0)) > 0
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

  // ==========================================
  // TUTUP KAS HARIAN (LAPORAN Z)
  // ==========================================

  Future<PosDailyClosing> saveDailyClosing({String? notes}) async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final stats = await getTodaySalesStats();

    final closing = PosDailyClosing(
      closingDate: today,
      totalTransactions: stats['total_trx']?.toInt() ?? 0,
      totalRevenue: stats['total_omset'] ?? 0.0,
      totalProfit: stats['total_profit'] ?? 0.0,
      cashRevenue: stats['cash_omset'] ?? 0.0,
      nonCashRevenue: stats['non_cash_omset'] ?? 0.0,
      consignmentDue: stats['total_consignment_due'] ?? 0.0,
      closedAt: DateTime.now(),
      notes: notes,
    );

    await db.insert(
      'pos_daily_closings',
      closing.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return closing;
  }

  Future<List<PosDailyClosing>> getAllDailyClosings({int limit = 30}) async {
    final db = await database;
    final maps = await db.query(
      'pos_daily_closings',
      orderBy: 'closing_date DESC',
      limit: limit,
    );
    return maps.map((m) => PosDailyClosing.fromMap(m)).toList();
  }

  // ==========================================
  // ANTREAN / KERANJANG TERTAHAN (HOLD CARTS)
  // ==========================================

  Future<int> saveHoldCart({
    required String cartId,
    String? customerNote,
    required double totalAmount,
    required String itemsJson,
  }) async {
    final db = await database;
    return await db.insert(
      'pos_hold_carts',
      {
        'cart_id': cartId,
        'customer_note': customerNote,
        'hold_at': DateTime.now().toIso8601String(),
        'total_amount': totalAmount,
        'items_json': itemsJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllHoldCarts() async {
    final db = await database;
    return await db.query('pos_hold_carts', orderBy: 'hold_at DESC');
  }

  Future<int> deleteHoldCart(String cartId) async {
    final db = await database;
    return await db.delete('pos_hold_carts', where: 'cart_id = ?', whereArgs: [cartId]);
  }

  Future<int> getHoldCartsCount() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pos_hold_carts')) ?? 0;
  }

  /// Mengecek apakah kode produk sudah terpakai di database
  Future<bool> isProductCodeExists(String kode) async {
    final db = await database;
    final res = await db.query(
      'pos_products',
      columns: ['id'],
      where: 'LOWER(kode) = ?',
      whereArgs: [kode.trim().toLowerCase()],
      limit: 1,
    );
    return res.isNotEmpty;
  }
}
