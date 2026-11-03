import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_flutter/config/app_config.dart';
import 'package:mobile_flutter/models/pos_cart_item.dart';
import 'package:mobile_flutter/models/pos_product.dart';
import 'package:mobile_flutter/models/pos_transaction.dart';
import 'package:mobile_flutter/providers/printer_provider.dart';
import 'package:mobile_flutter/services/pos_excel_service.dart';
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
}
