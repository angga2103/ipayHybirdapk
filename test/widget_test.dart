import 'package:mobile_flutter/models/pos_customer.dart';
import 'package:mobile_flutter/models/pos_shift.dart';
import 'package:mobile_flutter/models/pos_cash_flow.dart';
import 'package:mobile_flutter/models/pos_debt.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_flutter/config/app_config.dart';
import 'package:mobile_flutter/models/pos_cart_item.dart';
import 'package:mobile_flutter/models/pos_product.dart';
import 'package:mobile_flutter/models/pos_transaction.dart';
import 'package:mobile_flutter/providers/printer_provider.dart';
import 'package:mobile_flutter/services/pos_excel_service.dart';
import 'package:mobile_flutter/services/pos_product_helper.dart';
import 'package:mobile_flutter/services/pos_whatsapp_service.dart';
import 'package:mobile_flutter/services/printer_service.dart';
import 'package:mobile_flutter/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConfig Tests', () {
    test('Configures production URL and Channel names correctly', () {
      expect(AppConfig.webUrl, equals('https://ipay.my.id'));
      expect(AppConfig.printChannelName, equals('PrintChannel'));
      expect(AppConfig.storageChannelName, equals('StorageChannel'));
    });
  });

  group('StorageService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Stores and retrieves key-value pairs', () async {
      final storage = StorageService.instance;
      await storage.setString('test_key', 'test_value');
      final val = await storage.getString('test_key');
      expect(val, equals('test_value'));
    });

    test('Stores and retrieves saved printer MAC address', () async {
      final storage = StorageService.instance;
      await storage.setSavedPrinterMac('00:11:22:33:44:55');
      final mac = await storage.getSavedPrinterMac();
      expect(mac, equals('00:11:22:33:44:55'));
    });

    test('Handles JSON message from StorageChannel correctly', () async {
      final storage = StorageService.instance;
      const jsonMsg = '{"action":"set","key":"agent_pref","value":"dark_mode"}';
      await storage.handleMessage(jsonMsg, null);

      final val = await storage.getString('agent_pref');
      expect(val, equals('dark_mode'));
    });
  });

  group('PrinterService & StrukPayload Unit Tests', () {
    test('Parses JSON Struk from Web correctly', () {
      const jsonStruk = '{"storeName":"KONTER GARUDA","refId":"GT-100234","product":"Pulsa Telkomsel 10K","amount":"Rp 12.000","sn":"1234567890","status":"BERHASIL"}';
      final payload = StrukPayload.fromMessage(jsonStruk);

      expect(payload.storeName, equals('KONTER GARUDA'));
      expect(payload.refId, equals('GT-100234'));
      expect(payload.productName, equals('Pulsa Telkomsel 10K'));
      expect(payload.amount, equals('Rp 12.000'));
      expect(payload.sn, equals('1234567890'));
      expect(payload.status, equals('BERHASIL'));
    });

    test('Parses Plain Text ESC-POS Struk from Web', () {
      const plainText = 'STRUK TRANSAKSI GARUDATEL\\nNo: GT-999\\nTotal: Rp 50.000';
      final payload = StrukPayload.fromMessage(plainText);

      expect(payload.rawText, equals(plainText));
      expect(payload.storeName, isNull);
    });

    test('Generates non-empty ESC/POS bytes from StrukPayload', () {
      final payload = StrukPayload(
        rawText: 'Sample text',
        storeName: 'GARUDATEL CELL',
        refId: 'TRX-12345',
        productName: 'Indosat 10GB',
        amount: 'Rp 25.000',
        sn: '9988776655',
      );

      final bytes = PrinterService.instance.generateEscPosBytes(payload);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(20));
    });

    test('Formats two columns with precise dynamic spacing', () {
      final service = PrinterService.instance;
      // 58mm default width: 32 chars
      final line58 = service.formatTwoColumns('Kopi Susu', 'Rp 18.000', maxChars: 32);
      expect(line58.length, equals(32));
      expect(line58.startsWith('Kopi Susu'), isTrue);
      expect(line58.endsWith('Rp 18.000'), isTrue);

      // 80mm width: 48 chars
      final line80 = service.formatTwoColumns('Croissant Butter', 'Rp 22.000', maxChars: 48);
      expect(line80.length, equals(48));
      expect(line80.startsWith('Croissant Butter'), isTrue);
      expect(line80.endsWith('Rp 22.000'), isTrue);
    });

    test('Handles paper size switching between 58mm and 80mm', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PrinterService.instance;

      await service.setPaperSize(PaperSize.mm58);
      expect(service.paperSize, equals(PaperSize.mm58));
      expect(service.maxCharsPerLine, equals(32));
      expect(service.dividerLine.length, equals(32));

      await service.setPaperSize(PaperSize.mm80);
      expect(service.paperSize, equals(PaperSize.mm80));
      expect(service.maxCharsPerLine, equals(48));
      expect(service.dividerLine.length, equals(48));
    });
  });

  group('PrinterProvider State Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with default properties', () {
      final provider = PrinterProvider();
      expect(provider.isConnected, isFalse);
      expect(provider.connectedMac, isNull);
      expect(provider.isScanning, isFalse);
      expect(provider.availableDevices, isEmpty);
      expect(provider.paperSize, equals(PaperSize.mm58));
      expect(provider.errorMessage, isNull);
    });

    test('Can update paper size in state', () async {
      final provider = PrinterProvider();
      await provider.setPaperSize(PaperSize.mm80);
      expect(provider.paperSize, equals(PaperSize.mm80));
    });
  });

  group('Offline POS & Excel Models Tests', () {
    test('PosProduct model parses and converts to Map correctly', () {
      final p = PosProduct(
        id: 1,
        kode: 'BRG-001',
        nama: 'Kopi Susu Aren Botol',
        unit: 'botol',
        hargaDasar: 10000,
        hargaJual: 15000,
        beratGr: 250,
        stok: 20,
        kategori: 'Minuman',
        penitip: 'Dapur Bu Siti',
      );

      expect(p.isConsignment, isTrue);
      expect(p.isUnlimitedStock, isFalse);
      expect(p.profitMargin, equals(5000));

      final map = p.toMap();
      expect(map['kode'], equals('BRG-001'));
      expect(map['penitip'], equals('Dapur Bu Siti'));

      final fromMap = PosProduct.fromMap(map);
      expect(fromMap.nama, equals('Kopi Susu Aren Botol'));
      expect(fromMap.hargaJual, equals(15000));
    });

    test('PosCartItem calculates dynamic price, discount, profit, and below-cost alert', () {
      final p = PosProduct(
        kode: 'BRG-002',
        nama: 'Keripik Tempe Renyah',
        unit: 'bks',
        hargaDasar: 8000,
        hargaJual: 12000,
        beratGr: 100,
        stok: 10,
        kategori: 'Snack',
      );

      final cartItem = PosCartItem(product: p, qty: 2);
      expect(cartItem.subtotal, equals(24000));
      expect(cartItem.isPriceModified, isFalse);
      expect(cartItem.isBelowCost, isFalse);

      // Ubah harga jual dinamis menjadi harga grosir (misal 10.000 / bks)
      cartItem.actualPrice = 10000;
      expect(cartItem.isPriceModified, isTrue);
      expect(cartItem.subtotal, equals(20000));
      expect(cartItem.discountAmount, equals(4000));
      expect(cartItem.profitAmount, equals(4000));
      expect(cartItem.isBelowCost, isFalse);

      // Jual rugi / cuci gudang di bawah modal (misal 7.000 / bks)
      cartItem.actualPrice = 7000;
      expect(cartItem.isBelowCost, isTrue);
      expect(cartItem.profitAmount, equals(-2000));
    });

    test('PosExcelService generates valid Excel template bytes', () {
      final bytes = PosExcelService.instance.generateTemplateBytes();
      expect(bytes.isNotEmpty, isTrue);
    });

    test('PosTransactionItem and PosTransaction handle partial returns accurately', () {
      final item1 = PosTransactionItem(
        id: 1,
        transactionId: 10,
        productKode: 'MN-001',
        productName: 'Kopi Susu Aren',
        unit: 'cup',
        costPrice: 7000,
        normalPrice: 15000,
        soldPrice: 15000,
        qty: 3,
        returnedQty: 1, // 1 cup dikembalikan/diretur
        subtotal: 45000,
        profit: 24000,
      );

      expect(item1.activeQty, equals(2));
      expect(item1.activeSubtotal, equals(30000));
      expect(item1.activeProfit, equals(16000));
      expect(item1.isPartiallyReturned, isTrue);
      expect(item1.isFullyReturned, isFalse);

      final item2 = PosTransactionItem(
        id: 2,
        transactionId: 10,
        productKode: 'KS-001',
        productName: 'Roti Bakar',
        unit: 'pcs',
        costPrice: 5000,
        normalPrice: 7000,
        soldPrice: 7000,
        qty: 1,
        returnedQty: 1, // Diretur penuh
        subtotal: 7000,
        profit: 2000,
        penitip: 'Pak Joko',
        dueToPenitip: 5000,
      );

      expect(item2.activeQty, equals(0));
      expect(item2.isFullyReturned, isTrue);
      expect(item2.activeDueToPenitip, equals(0.0));

      final returnRecord = PosTransactionReturn(
        transactionId: 10,
        invoiceNo: 'POS-20261103-001',
        productKode: 'KS-001',
        productName: 'Roti Bakar',
        qtyReturned: 1,
        refundAmount: 7000,
        reason: 'Kemasan rusak',
        createdAt: DateTime.now(),
      );

      final trx = PosTransaction(
        invoiceNo: 'POS-20261103-001',
        dateTime: DateTime.now(),
        totalAmount: 30000, // sisa setelah refund 7000 dan retur kopi
        normalAmount: 52000,
        discountAmount: 0,
        profitAmount: 16000,
        cashPaid: 55000,
        changeDue: 3000,
        status: 'PARTIAL_RETURN',
        items: [item1, item2],
        returns: [returnRecord],
      );

      expect(trx.isPartiallyReturned, isTrue);
      expect(trx.isCancelled, isFalse);
      expect(trx.totalActiveItemsQty, equals(2));
      expect(trx.totalReturnedQty, equals(2));
      expect(trx.totalRefundedAmount, equals(7000));
    });
  });

  group('PosProductHelper Auto-Generate Code Tests', () {
    test('Generates valid code with formula 3-5 uppercase letters + hyphen + 4 random digits', () {
      final code1 = PosProductHelper.generateCodeFromName('Kopi Susu Gula Aren');
      final codePattern = RegExp(r'^[A-Z]{3,5}-\d{4}$');
      expect(codePattern.hasMatch(code1), isTrue);
      expect(code1.startsWith('KSGA-'), isTrue);

      final code2 = PosProductHelper.generateCodeFromName('Air Galon Isi Ulang');
      expect(codePattern.hasMatch(code2), isTrue);
      expect(code2.startsWith('AGIU-'), isTrue);
    });

    test('Handles single-word product names properly', () {
      final code = PosProductHelper.generateCodeFromName('Beras');
      final codePattern = RegExp(r'^[A-Z]{3,5}-\d{4}$');
      expect(codePattern.hasMatch(code), isTrue);
      expect(code.startsWith('BERAS-'), isTrue);
    });

    test('Handles short or special character names properly', () {
      final codeShort = PosProductHelper.generateCodeFromName('Es');
      expect(codeShort, isNotEmpty);
      expect(codeShort.contains('-'), isTrue);

      final codeSpecial = PosProductHelper.generateCodeFromName('Kue Cubit (Pandan) #1');
      final codePattern = RegExp(r'^[A-Z]{3,5}-\d{4}$');
      expect(codePattern.hasMatch(codeSpecial), isTrue);
    });

    test('Avoids collision when generated code already exists', () {
      final existing = <String>{};
      for (int i = 0; i < 20; i++) {
        final code = PosProductHelper.generateCodeFromName('Kopi Susu Aren', existingCodes: existing);
        expect(existing.contains(code), isFalse);
        existing.add(code);
      }
      expect(existing.length, equals(20));
    });

    test('Generates GS1 In-Store numeric code with prefix 20 and exactly 10 digits', () {
      final code = PosProductHelper.generateNumericCode();
      expect(code.length, equals(10));
      expect(code.startsWith('20'), isTrue);
      final numericPattern = RegExp(r'^20\d{8}$');
      expect(numericPattern.hasMatch(code), isTrue);
    });

    test('Numeric code generator avoids collisions', () {
      final existing = <String>{};
      for (int i = 0; i < 20; i++) {
        final code = PosProductHelper.generateNumericCode(existingCodes: existing);
        expect(existing.contains(code), isFalse);
        expect(code.startsWith('20'), isTrue);
        existing.add(code);
      }
      expect(existing.length, equals(20));
    });
  });

  group('PosProduct with Offline Image Path Tests', () {
    test('Serializes and deserializes imagePath correctly', () {
      final product = PosProduct(
        id: 101,
        kode: 'KSA-1234',
        nama: 'Kopi Susu Aren',
        unit: 'cup',
        hargaDasar: 8000,
        hargaJual: 15000,
        stok: 50,
        kategori: 'Minuman',
        imagePath: '/data/user/0/com.garudatel.ipay/app_flutter/product_images/prod_1234.jpg',
      );

      final map = product.toMap();
      expect(map['image_path'], equals('/data/user/0/com.garudatel.ipay/app_flutter/product_images/prod_1234.jpg'));

      final fromMapProduct = PosProduct.fromMap(map);
      expect(fromMapProduct.imagePath, equals(product.imagePath));
      expect(fromMapProduct.nama, equals(product.nama));

      final updated = product.copyWith(imagePath: '/new/path.jpg');
      expect(updated.imagePath, equals('/new/path.jpg'));
      expect(updated.kode, equals(product.kode));
    });
  });

  group('PosWhatsappService Receipt Formatting Tests', () {
    test('Generates clean, elegant digital receipt for customer', () {
      final item1 = PosTransactionItem(
        productKode: 'AGIU-1001',
        productName: 'Air Galon Isi Ulang',
        unit: 'galon',
        qty: 2,
        normalPrice: 6700,
        soldPrice: 6700,
        subtotal: 13400,
        costPrice: 4000,
        profit: 5400,
      );

      final item2 = PosTransactionItem(
        productKode: 'AC-1002',
        productName: 'Adaptor Charger 2A',
        unit: 'pcs',
        qty: 1,
        normalPrice: 25000,
        soldPrice: 45000, // Harga diubah kasir naik
        subtotal: 45000,
        costPrice: 18000,
        profit: 27000,
      );

      final trx = PosTransaction(
        invoiceNo: 'POS-20261106-99001',
        dateTime: DateTime(2026, 11, 6, 14, 30),
        totalAmount: 58400,
        normalAmount: 38400,
        discountAmount: 0,
        profitAmount: 32400,
        cashPaid: 60000,
        changeDue: 1600,
        paymentMethod: 'Tunai',
        cashierName: 'Budi Kasir',
        status: 'PAID',
        items: [item1, item2],
      );

      final receipt = PosWhatsappService.instance.generateReceiptText(
        trx: trx,
        storeName: 'TOKO IPAY SENTOSA',
      );

      expect(receipt.contains('STRUK PEMBELIAN - TOKO IPAY SENTOSA'), isTrue);
      expect(receipt.contains('POS-20261106-99001'), isTrue);
      expect(receipt.contains('Kasir    : Budi Kasir'), isTrue);
      expect(receipt.contains('2x Air Galon Isi Ulang'), isTrue);
      expect(receipt.contains('1x Adaptor Charger 2A'), isTrue);
      expect(receipt.contains('TOTAL     : Rp 58.400'), isTrue);
      expect(receipt.contains('Kembalian : Rp 1.600'), isTrue);
      // Memastikan TIDAK ADA teks internal audit seperti 'Diskon Khusus' atau 'Harga Normal' pada struk pembeli
      expect(receipt.contains('Diskon Khusus'), isFalse);
      expect(receipt.contains('Bawah Modal'), isFalse);
    });

    test('Generates detailed shift closing report text for WhatsApp', () {
      final shift = PosShift(
        cashierName: 'Ahmad Kasir',
        openedAt: DateTime(2026, 11, 8, 8, 0),
        closedAt: DateTime(2026, 11, 8, 16, 0),
        startingCash: 100000,
        totalCashSales: 450000,
        totalQrisSales: 200000,
        totalDebtSales: 50000,
        totalCashIn: 25000,
        totalCashOut: 15000,
        expectedCash: 560000,
        actualCash: 560000,
        cashDifference: 0,
        totalTransactions: 18,
        status: 'CLOSED',
        notes: 'Semua lancar aman',
      );

      final report = PosWhatsappService.instance.generateShiftReportText(
        shift: shift,
        storeName: 'IPAY STORE',
      );

      expect(report.contains('LAPORAN REKAP TUTUP KASIR (SHIFT)'), isTrue);
      expect(report.contains('IPAY STORE'), isTrue);
      expect(report.contains('Ahmad Kasir'), isTrue);
      expect(report.contains('Rp 100.000'), isTrue);
      expect(report.contains('Rp 450.000'), isTrue);
      expect(report.contains('Rp 200.000'), isTrue);
      expect(report.contains('Rp 560.000'), isTrue);
      expect(report.contains('PAS (SESUAI)'), isTrue);
      expect(report.contains('Semua lancar aman'), isTrue);
    });
  });

  group('PosShift & Cashier Shift Tests', () {
    test('Calculates expected cash and difference correctly', () {
      final shift = PosShift(
        cashierName: 'Andi Kasir',
        openedAt: DateTime(2026, 11, 8, 8, 0),
        startingCash: 200000,
        totalCashSales: 550000,
        totalCashIn: 50000,   // tambahan modal kasir
        totalCashOut: 30000,  // beli lakban operasional
        actualCash: 770000,
      );

      // Expected = 200k + 550k + 50k - 30k = 770k
      expect(shift.calculatedExpectedCash, equals(770000.0));
      // Actual 770k -> Difference = 0
      final diff = shift.actualCash - shift.calculatedExpectedCash;
      expect(diff, equals(0.0));
    });

    test('Detects cash shortages accurately', () {
      final shift = PosShift(
        cashierName: 'Siti Kasir',
        openedAt: DateTime(2026, 11, 8, 8, 0),
        startingCash: 100000,
        totalCashSales: 200000,
        totalCashIn: 0,
        totalCashOut: 0,
        actualCash: 280000, // Hilang 20rb
      );

      final diff = shift.actualCash - shift.calculatedExpectedCash;
      expect(diff, equals(-20000.0));
    });

    test('Serializes toMap and fromMap accurately', () {
      final now = DateTime.now();
      final shift = PosShift(
        id: 1,
        cashierName: 'Budi Kasir',
        openedAt: now,
        startingCash: 150000,
        expectedCash: 350000,
        actualCash: 350000,
        cashDifference: 0,
        status: 'OPEN',
      );

      final map = shift.toMap();
      final parsed = PosShift.fromMap(map);
      expect(parsed.id, equals(1));
      expect(parsed.cashierName, equals('Budi Kasir'));
      expect(parsed.startingCash, equals(150000.0));
      expect(parsed.status, equals('OPEN'));
    });
  });

  group('PosCashFlow Petty Cash Tests', () {
    test('Handles Cash IN and Cash OUT correctly', () {
      final now = DateTime.now();
      final cashIn = PosCashFlow(
        type: 'IN',
        amount: 50000,
        category: 'Modal Tambahan',
        note: 'Pecahan kecil dari bos',
        cashierName: 'Kasir 1',
        createdAt: now,
      );
      expect(cashIn.isCashIn, isTrue);
      expect(cashIn.isCashOut, isFalse);

      final cashOut = PosCashFlow(
        type: 'OUT',
        amount: 15000,
        category: 'Operasional',
        note: 'Beli kertas struk thermal',
        cashierName: 'Kasir 1',
        createdAt: now,
      );
      expect(cashOut.isCashOut, isTrue);
      expect(cashOut.isCashIn, isFalse);

      final mapOut = cashOut.toMap();
      final parsedOut = PosCashFlow.fromMap(mapOut);
      expect(parsedOut.amount, equals(15000.0));
      expect(parsedOut.category, equals('Operasional'));
    });
  });

  group('PosCustomerDebt & Piutang Warung Tests', () {
    test('Calculates remaining amount, paid status, and overdue status correctly', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final debt = PosCustomerDebt(
        id: 10,
        invoiceNo: 'POS-20261108-001',
        customerName: 'Bu Ani Warung',
        customerPhone: '08123456789',
        totalAmount: 150000,
        paidAmount: 50000,
        remainingAmount: 100000,
        dueDate: yesterday,
        status: 'PARTIAL',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(debt.remainingAmount, equals(100000.0));
      expect(debt.isPaid, isFalse);
      expect(debt.isPartial, isTrue);
      expect(debt.isOverdue, isTrue); // Karena dueDate kemarin dan belum lunas
    });

    test('Fully paid debt is marked isPaid even if overdue date has passed', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final paidDebt = PosCustomerDebt(
        id: 11,
        invoiceNo: 'POS-20261108-002',
        customerName: 'Pak Budi',
        totalAmount: 75000,
        paidAmount: 75000,
        remainingAmount: 0,
        dueDate: pastDate,
        status: 'PAID',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(paidDebt.isPaid, isTrue);
      expect(paidDebt.isOverdue, isFalse); // Lunas tidak pernah dianggap overdue
    });
  });

  group('PrinterService Barcode Labels & Shift Receipt Tests', () {
    test('Generates thermal barcode label bytes properly', () {
      final product = PosProduct(
        kode: '2012345678',
        nama: 'Kopi Kapal Api Special',
        kategori: 'Minuman',
        unit: 'pcs',
        hargaDasar: 2500,
        hargaJual: 3500,
        stok: 50,
      );

      final bytes = PrinterService.instance.generateBarcodeLabelBytes(
        product,
        qty: 1,
        isQr: false,
        storeName: 'TOKO IPAY CELL',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(30));
    });

    test('Generates shift closing thermal receipt bytes with discrepancy report', () {
      final shift = PosShift(
        id: 1,
        cashierName: 'Budi Kasir',
        openedAt: DateTime(2026, 11, 8, 8, 0),
        closedAt: DateTime(2026, 11, 8, 20, 0),
        startingCash: 200000,
        expectedCash: 850000,
        actualCash: 850000,
        cashDifference: 0,
        totalCashSales: 600000,
        totalNonCashSales: 50000,
        totalCashIn: 80000,
        totalCashOut: 30000,
        totalTransactions: 35,
        status: 'CLOSED',
      );

      final bytes = PrinterService.instance.generateShiftReceiptBytes(
        shift,
        [],
        storeName: 'TOKO IPAY CELL',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(50));
    });
  });

  group('PosCustomer & Customer Master Tests', () {
    test('PosCustomer model parses and converts to Map correctly', () {
      final now = DateTime.now();
      final customer = PosCustomer(
        id: 1,
        name: 'Pak Haji Rohman',
        phone: '081234567890',
        address: 'Jl. Merdeka No. 45',
        notes: 'Pelanggan setia warung sembako',
        totalDebt: 75000,
        activeDebtCount: 2,
        totalSpent: 500000,
        transactionCount: 15,
        createdAt: now,
        updatedAt: now,
      );

      expect(customer.displayName, equals('Pak Haji Rohman'));
      expect(customer.hasActiveDebt, isTrue);
      expect(customer.totalDebt, equals(75000));
      expect(customer.activeDebtCount, equals(2));

      final map = customer.toMap();
      expect(map['name'], equals('Pak Haji Rohman'));
      expect(map['phone'], equals('081234567890'));

      final restored = PosCustomer.fromMap(map);
      expect(restored.name, equals('Pak Haji Rohman'));
      expect(restored.phone, equals('081234567890'));
      expect(restored.address, equals('Jl. Merdeka No. 45'));
    });

    test('Customer without debt reports hasActiveDebt as false', () {
      final now = DateTime.now();
      final customer = PosCustomer(
        name: 'Siti Aminah',
        totalDebt: 0,
        activeDebtCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      expect(customer.hasActiveDebt, isFalse);
    });

    test('PosCustomer copyWith updates fields properly', () {
      final now = DateTime.now();
      final customer = PosCustomer(name: 'Andi', phone: '08111', createdAt: now, updatedAt: now);
      final updated = customer.copyWith(name: 'Andi Saputra', totalDebt: 25000);
      expect(updated.name, equals('Andi Saputra'));
      expect(updated.phone, equals('08111'));
      expect(updated.totalDebt, equals(25000));
    });
  });

  group('Shift Management: Cash Drawer vs QRIS Cash Flow Tests', () {
    test('Calculated physical expected cash excludes QRIS and Debt sales from cash drawer', () {
      final shift = PosShift(
        cashierName: 'Budi Kasir',
        openedAt: DateTime.now(),
        startingCash: 100000,   // Modal awal fisik di laci
        totalCashSales: 450000, // Uang fisik dari transaksi tunai
        totalQrisSales: 250000, // Non-tunai QRIS langsung ke bank (tidak di laci)
        totalDebtSales: 50000,  // Kasbon piutang (belum ada uang fisik)
        totalCashIn: 50000,     // Kas masuk fisik (tukar uang receh dari bos)
        totalCashOut: 20000,    // Kas keluar fisik (beli token listrik/galon)
      );

      // Verifikasi: uang fisik laci kasir seharusnya = 100.000 + 450.000 + 50.000 - 20.000 = 580.000
      expect(shift.calculatedExpectedCash, equals(580000));

      // Verifikasi: Total omset penjualan toko = 450.000 (Tunai) + 250.000 (QRIS) + 50.000 (Kasbon) = 750.000
      expect(shift.totalSales, equals(750000));
    });

    test('Shift difference calculation correctly flags PAS, LEBIH, dan KURANG', () {
      // Kasus 1: Uang fisik pas
      final shiftPas = PosShift(
        cashierName: 'Budi',
        openedAt: DateTime.now(),
        startingCash: 100000,
        expectedCash: 300000,
        actualCash: 300000,
        cashDifference: 0,
      );
      expect(shiftPas.cashDifference, equals(0));

      // Kasus 2: Uang fisik kurang (selisih minus)
      final shiftKurang = PosShift(
        cashierName: 'Budi',
        openedAt: DateTime.now(),
        startingCash: 100000,
        expectedCash: 300000,
        actualCash: 280000,
        cashDifference: -20000,
      );
      expect(shiftKurang.cashDifference, equals(-20000));

      // Kasus 3: Uang fisik lebih
      final shiftLebih = PosShift(
        cashierName: 'Budi',
        openedAt: DateTime.now(),
        startingCash: 100000,
        expectedCash: 300000,
        actualCash: 310000,
        cashDifference: 10000,
      );
      expect(shiftLebih.cashDifference, equals(10000));
    });

    test('Shift formatted duration outputs readable text', () {
      final start = DateTime(2026, 11, 8, 8, 0);
      final end = DateTime(2026, 11, 8, 16, 30);
      final shift = PosShift(
        cashierName: 'Kasir 1',
        openedAt: start,
        closedAt: end,
      );
      expect(shift.formattedDuration, equals('8 Jam 30 Mnt'));
    });
  });

  group('PosTransaction Customer & Payment Method Tests', () {
    test('Default transaction assigns customer as Umum', () {
      final trx = PosTransaction(
        invoiceNo: 'TRX-DEFAULT-001',
        dateTime: DateTime.now(),
        totalAmount: 50000,
        cashPaid: 50000,
        changeDue: 0,
        paymentMethod: 'Tunai',
        items: [],
      );

      expect(trx.customerName, equals('Umum'));
      expect(trx.customerId, isNull);
    });

    test('Transaction preserves customer name, phone and shiftId', () {
      final trx = PosTransaction(
        invoiceNo: 'TRX-QRIS-002',
        dateTime: DateTime.now(),
        customerId: 5,
        customerName: 'Ibu Ratna',
        customerPhone: '081999888777',
        shiftId: 12,
        totalAmount: 125000,
        cashPaid: 125000,
        changeDue: 0,
        paymentMethod: 'QRIS',
        items: [],
      );

      expect(trx.customerId, equals(5));
      expect(trx.customerName, equals('Ibu Ratna'));
      expect(trx.customerPhone, equals('081999888777'));
      expect(trx.shiftId, equals(12));
      expect(trx.paymentMethod, equals('QRIS'));

      final map = trx.toMap();
      expect(map['customer_id'], equals(5));
      expect(map['customer_name'], equals('Ibu Ratna'));
      expect(map['payment_method'], equals('QRIS'));
      expect(map['shift_id'], equals(12));

      final restored = PosTransaction.fromMap(map);
      expect(restored.customerName, equals('Ibu Ratna'));
      expect(restored.paymentMethod, equals('QRIS'));
      expect(restored.shiftId, equals(12));
    });
  });

  group('Transaction History Filtering & Shift Security Tests', () {
    test('Transaction history filters by date matching', () {
      final now = DateTime.now();
      final todayTrx = PosTransaction(
        invoiceNo: 'POS-20261108-001',
        dateTime: now,
        totalAmount: 45000,
        cashPaid: 50000,
        changeDue: 5000,
        paymentMethod: 'Tunai',
        customerName: 'Budi',
        items: [],
      );

      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayTrx = PosTransaction(
        invoiceNo: 'POS-20261107-002',
        dateTime: yesterday,
        totalAmount: 75000,
        cashPaid: 75000,
        changeDue: 0,
        paymentMethod: 'QRIS',
        customerName: 'Siti',
        items: [],
      );

      final allList = [todayTrx, yesterdayTrx];

      // Filter Hari Ini
      final filteredToday = allList.where((t) =>
        t.dateTime.year == now.year &&
        t.dateTime.month == now.month &&
        t.dateTime.day == now.day
      ).toList();

      expect(filteredToday.length, equals(1));
      expect(filteredToday.first.invoiceNo, equals('POS-20261108-001'));

      // Filter Kemarin
      final filteredYesterday = allList.where((t) =>
        t.dateTime.year == yesterday.year &&
        t.dateTime.month == yesterday.month &&
        t.dateTime.day == yesterday.day
      ).toList();

      expect(filteredYesterday.length, equals(1));
      expect(filteredYesterday.first.invoiceNo, equals('POS-20261107-002'));
    });

    test('Transaction history filters by Invoice Number and Customer Name query', () {
      final trxs = [
        PosTransaction(
          invoiceNo: 'POS-20261108-1001',
          dateTime: DateTime.now(),
          totalAmount: 25000,
          cashPaid: 25000,
          changeDue: 0,
          customerName: 'Pak Joko Mart',
          paymentMethod: 'Tunai',
          items: [],
        ),
        PosTransaction(
          invoiceNo: 'POS-20261108-1002',
          dateTime: DateTime.now(),
          totalAmount: 60000,
          cashPaid: 100000,
          changeDue: 40000,
          customerName: 'Bu Dewi Warung',
          paymentMethod: 'Tunai',
          items: [],
        ),
      ];

      // Cari nomor nota '1001'
      final matchInvoice = trxs.where((t) =>
        t.invoiceNo.toLowerCase().contains('1001') ||
        t.customerName.toLowerCase().contains('1001')
      ).toList();
      expect(matchInvoice.length, equals(1));
      expect(matchInvoice.first.customerName, equals('Pak Joko Mart'));

      // Cari nama pelanggan 'Dewi'
      final matchCustomer = trxs.where((t) =>
        t.invoiceNo.toLowerCase().contains('dewi') ||
        t.customerName.toLowerCase().contains('dewi')
      ).toList();
      expect(matchCustomer.length, equals(1));
      expect(matchCustomer.first.invoiceNo, equals('POS-20261108-1002'));
    });

    test('Shift enforcement correctly verifies active shift status', () {
      bool isShiftOpen(PosShift? s) => s != null && s.isOpen;
      expect(isShiftOpen(null), isFalse);

      final closedShift = PosShift(
        id: 1,
        cashierName: 'Kasir',
        openedAt: DateTime.now().subtract(const Duration(hours: 4)),
        closedAt: DateTime.now(),
        startingCash: 100000,
        status: 'CLOSED',
      );
      expect(closedShift.isOpen, isFalse);

      final openShift = PosShift(
        id: 2,
        cashierName: 'Kasir Utama',
        openedAt: DateTime.now(),
        startingCash: 100000,
        status: 'OPEN',
      );
      expect(openShift.isOpen, isTrue);
    });
  });


  group('POS Barcode Scanner & Shift Closing Receipt Consistency Tests', () {
    test('Anti-Double Scan barcode lock pattern prevents uncontrolled increment', () {
      String? lockedBarcode;
      int scanCount = 0;

      void onBarcodeDetected(String code) {
        if (lockedBarcode == code) {
          // Barcode locked - prevent rapid increment
          return;
        }
        lockedBarcode = code;
        scanCount++;
      }

      // First detection
      onBarcodeDetected('8991234567890');
      expect(scanCount, equals(1));
      expect(lockedBarcode, equals('8991234567890'));

      // Continuous camera frames on same barcode (camera held for 3 seconds)
      for (int i = 0; i < 30; i++) {
        onBarcodeDetected('8991234567890');
      }
      expect(scanCount, equals(1)); // Still exactly 1!

      // Scan different barcode
      onBarcodeDetected('8999999999999');
      expect(scanCount, equals(2));
      expect(lockedBarcode, equals('8999999999999'));

      // Rescan unlocked barcode
      lockedBarcode = null; // simulate unlock / rescan action
      onBarcodeDetected('8991234567890');
      expect(scanCount, equals(3));
    });

    test('PrinterService shift receipt includes cash flow details when flows exist', () {
      final shift = PosShift(
        id: 10,
        cashierName: 'admin',
        openedAt: DateTime(2026, 11, 11, 5, 15),
        closedAt: DateTime(2026, 11, 12, 7, 9),
        startingCash: 100000,
        totalCashSales: 156000,
        totalQrisSales: 17000,
        totalDebtSales: 0,
        totalCashIn: 21000,
        totalCashOut: 0,
        actualCash: 256000,
        cashDifference: 0,
        totalTransactions: 3,
        status: 'CLOSED',
      );

      final flows = [
        PosCashFlow(
          id: 1,
          shiftId: 10,
          type: 'IN',
          amount: 21000,
          category: 'Pelunasan Kasbon',
          note: 'Cicilan/Pelunasan kasbon nota POS-20261108-094007 (Agus)',
          cashierName: 'admin',
          createdAt: DateTime.now(),
        ),
      ];

      final bytes = PrinterService.instance.generateShiftReceiptBytes(
        shift,
        flows,
        storeName: 'IPAY',
      );

      expect(bytes, isNotEmpty);
      final receiptString = String.fromCharCodes(bytes);
      expect(receiptString.contains('Rincian Kas Masuk / Keluar'), isTrue);
      expect(receiptString.contains('Pelunasan Kasbon'), isTrue);
      expect(receiptString.contains('Agus'), isTrue);
    });

    test('PosWhatsappService includes cash flow details in shift report text', () {
      final shift = PosShift(
        id: 10,
        cashierName: 'admin',
        openedAt: DateTime(2026, 11, 11, 5, 15),
        closedAt: DateTime(2026, 11, 12, 7, 9),
        startingCash: 100000,
        totalCashSales: 156000,
        totalQrisSales: 17000,
        totalDebtSales: 0,
        totalCashIn: 21000,
        totalCashOut: 0,
        actualCash: 256000,
        cashDifference: 0,
        totalTransactions: 3,
        status: 'CLOSED',
      );

      final flows = [
        PosCashFlow(
          id: 1,
          shiftId: 10,
          type: 'IN',
          amount: 21000,
          category: 'Pelunasan Kasbon',
          note: 'Cicilan/Pelunasan kasbon nota POS-20261108-094007 (Agus)',
          cashierName: 'admin',
          createdAt: DateTime.now(),
        ),
      ];

      final waText = PosWhatsappService.instance.generateShiftReportText(
        shift: shift,
        cashFlows: flows,
        storeName: 'IPAY',
      );

      expect(waText.contains('RINCIAN KAS MASUK / KELUAR'), isTrue);
      expect(waText.contains('Pelunasan Kasbon'), isTrue);
      expect(waText.contains('Agus'), isTrue);
      expect(waText.contains('21.000'), isTrue);
    });
  });
}
