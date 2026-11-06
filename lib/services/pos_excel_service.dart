import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pos_product.dart';
import 'pos_database_service.dart';
import 'pos_product_helper.dart';

class PosExcelService {
  PosExcelService._internal();
  static final PosExcelService instance = PosExcelService._internal();

  static const List<String> headers = [
    'KODE',
    'NAMA PRODUK',
    'UNIT/SATUAN',
    'HARGA DASAR',
    'HARGA JUAL',
    'BERAT (gr)',
    'STOK',
    'KATEGORI',
    'PENITIP', // Opsional untuk konsinyasi (kosongkan jika milik sendiri)
  ];

  /// Menghasilkan file Excel (.xlsx) template kosong berformat standar 8 kolom + penitip
  Uint8List generateTemplateBytes() {
    final excel = Excel.createExcel();
    const sheetName = 'DATA PRODUK';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // 1. Tulis Header
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // 2. Tulis Contoh Data
    final sampleRows = [
      [
        TextCellValue('MN-001'),
        TextCellValue('Kopi Susu Gula Aren'),
        TextCellValue('cup'),
        DoubleCellValue(7000),
        DoubleCellValue(15000),
        DoubleCellValue(250),
        IntCellValue(50),
        TextCellValue('Minuman'),
        TextCellValue(''), // Milik Sendiri
      ],
      [
        TextCellValue('MK-001'),
        TextCellValue('Mie Goreng Telur'),
        TextCellValue('porsi'),
        DoubleCellValue(6000),
        DoubleCellValue(12000),
        DoubleCellValue(200),
        IntCellValue(30),
        TextCellValue('Makanan'),
        TextCellValue(''), // Milik Sendiri
      ],
      [
        TextCellValue('KS-001'),
        TextCellValue('Keripik Pisang Coklat Bu Siti'),
        TextCellValue('bks'),
        DoubleCellValue(8000),
        DoubleCellValue(11000),
        DoubleCellValue(150),
        IntCellValue(20),
        TextCellValue('Konsinyasi'),
        TextCellValue('Bu Siti'), // Konsinyasi
      ],
    ];

    for (final row in sampleRows) {
      sheet.appendRow(row);
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? []);
  }

  /// Mengekspor daftar produk yang ada ke dalam file Excel
  Uint8List exportProductsToExcelBytes(List<PosProduct> products) {
    final excel = Excel.createExcel();
    const sheetName = 'KATALOG PRODUK';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final p in products) {
      sheet.appendRow([
        TextCellValue(p.kode),
        TextCellValue(p.nama),
        TextCellValue(p.unit),
        DoubleCellValue(p.hargaDasar),
        DoubleCellValue(p.hargaJual),
        DoubleCellValue(p.beratGr),
        IntCellValue(p.stok),
        TextCellValue(p.kategori),
        TextCellValue(p.penitip ?? ''),
      ]);
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? []);
  }

  /// Mem-parsing byte file Excel menjadi `List<PosProduct>`
  List<PosProduct> parseExcelBytes(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];

    // Gunakan sheet pertama yang memiliki data
    Sheet? targetSheet;
    for (final s in excel.tables.values) {
      if (s.maxRows > 1) {
        targetSheet = s;
        break;
      }
    }
    targetSheet ??= excel.tables.values.first;

    final List<PosProduct> result = [];
    final rows = targetSheet.rows;
    if (rows.length <= 1) return [];

    // Cari posisi index header secara cerdas (tidak case-sensitive)
    final headerRow = rows[0];
    int idxKode = -1;
    int idxNama = -1;
    int idxUnit = -1;
    int idxDasar = -1;
    int idxJual = -1;
    int idxBerat = -1;
    int idxStok = -1;
    int idxKategori = -1;
    int idxPenitip = -1;

    for (int col = 0; col < headerRow.length; col++) {
      final cellStr = _cellToString(headerRow[col]).toUpperCase();
      if (cellStr.contains('KODE') || cellStr.contains('SKU') || cellStr.contains('BARCODE')) idxKode = col;
      if (cellStr.contains('NAMA') || cellStr.contains('PRODUK') || cellStr.contains('BARANG')) idxNama = col;
      if (cellStr.contains('UNIT') || cellStr.contains('SATUAN')) idxUnit = col;
      if (cellStr.contains('DASAR') || cellStr.contains('MODAL') || cellStr.contains('BELI')) idxDasar = col;
      if (cellStr.contains('JUAL') || cellStr.contains('HARGA')) {
        if (!cellStr.contains('DASAR') && !cellStr.contains('MODAL')) idxJual = col;
      }
      if (cellStr.contains('BERAT') || cellStr.contains('GRAM')) idxBerat = col;
      if (cellStr.contains('STOK') || cellStr.contains('QTY') || cellStr.contains('JUMLAH')) idxStok = col;
      if (cellStr.contains('KATEGORI') || cellStr.contains('JENIS')) idxKategori = col;
      if (cellStr.contains('PENITIP') || cellStr.contains('KONSINYASI') || cellStr.contains('SUPPLIER')) idxPenitip = col;
    }

    // Jika header tidak terdeteksi via nama, gunakan posisi default 0-8
    if (idxKode == -1) idxKode = 0;
    if (idxNama == -1) idxNama = 1;
    if (idxUnit == -1) idxUnit = 2;
    if (idxDasar == -1) idxDasar = 3;
    if (idxJual == -1) idxJual = 4;
    if (idxBerat == -1) idxBerat = 5;
    if (idxStok == -1) idxStok = 6;
    if (idxKategori == -1) idxKategori = 7;
    if (idxPenitip == -1 && headerRow.length > 8) idxPenitip = 8;

    final Set<String> existingCodes = {};

    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      final kode = _getCellValue(row, idxKode).trim();
      final nama = _getCellValue(row, idxNama).trim();
      if (kode.isEmpty && nama.isEmpty) continue;

      final safeNama = nama.isNotEmpty ? nama : 'Produk Baris $r';
      final safeKode = kode.isNotEmpty
          ? kode
          : PosProductHelper.generateCodeFromName(safeNama, existingCodes: existingCodes);
      existingCodes.add(safeKode);
      final unit = _getCellValue(row, idxUnit).isNotEmpty ? _getCellValue(row, idxUnit) : 'pcs';
      final dasar = _cellToDouble(_getCell(row, idxDasar));
      final jual = _cellToDouble(_getCell(row, idxJual));
      final berat = _cellToDouble(_getCell(row, idxBerat));
      final stok = _cellToInt(_getCell(row, idxStok));
      final kategori = _getCellValue(row, idxKategori).isNotEmpty ? _getCellValue(row, idxKategori) : 'Umum';
      final penitipRaw = (idxPenitip >= 0) ? _getCellValue(row, idxPenitip) : '';
      final penitip = penitipRaw.trim().isNotEmpty ? penitipRaw.trim() : null;

      final isStockManaged = stok >= 0;
      final productType = penitip != null ? 'consignment' : 'shop';

      result.add(PosProduct(
        kode: safeKode,
        nama: safeNama,
        unit: unit,
        hargaDasar: dasar,
        hargaJual: jual > 0 ? jual : dasar,
        beratGr: berat,
        stok: isStockManaged ? stok : -1,
        isStockManaged: isStockManaged,
        kategori: kategori,
        penitip: penitip,
        productType: productType,
      ));
    }

    return result;
  }

  /// Membuka file picker untuk memilih file Excel dari memori HP dan menyimpannya ke database
  Future<int> pickAndImportExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return 0;
      final file = result.files.first;
      Uint8List? fileBytes = file.bytes;

      if (fileBytes == null && file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      }

      if (fileBytes == null || fileBytes.isEmpty) return 0;

      final products = parseExcelBytes(fileBytes);
      if (products.isEmpty) return 0;

      final count = await PosDatabaseService.instance.bulkInsertOrUpdateProducts(products);
      return count;
    } catch (e) {
      debugPrint('[PosExcelService] Error pickAndImportExcel: $e');
      rethrow;
    }
  }

  /// Mengekspor dan membagikan Template Excel via WhatsApp / Simpan File
  Future<bool> shareTemplateExcel() async {
    try {
      final bytes = generateTemplateBytes();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Template_Produk_POS_GarudaTel.xlsx');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Template Excel Produk POS GarudaTel (8 Kolom Standar + Penitip)',
        subject: 'Template Excel POS GarudaTel',
      );
      return true;
    } catch (e) {
      debugPrint('[PosExcelService] Error shareTemplateExcel: $e');
      return false;
    }
  }

  /// Mengekspor dan membagikan Katalog Produk via WhatsApp / File
  Future<bool> shareProductCatalog(List<PosProduct> products) async {
    try {
      final bytes = exportProductsToExcelBytes(products);
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${tempDir.path}/Katalog_Produk_POS_$dateStr.xlsx');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Katalog Produk POS GarudaTel - Total ${products.length} Barang',
        subject: 'Katalog Produk POS',
      );
      return true;
    } catch (e) {
      debugPrint('[PosExcelService] Error shareProductCatalog: $e');
      return false;
    }
  }

  // --- Helpers ---
  Data? _getCell(List<Data?> row, int index) {
    if (index >= 0 && index < row.length) return row[index];
    return null;
  }

  String _getCellValue(List<Data?> row, int index) {
    final cell = _getCell(row, index);
    return _cellToString(cell);
  }

  String _cellToString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    return cell.value.toString().trim();
  }

  double _cellToDouble(Data? cell) {
    if (cell == null || cell.value == null) return 0.0;
    final val = cell.value;
    if (val is DoubleCellValue) return val.value;
    if (val is IntCellValue) return val.value.toDouble();
    if (val is num) return (val as num).toDouble();
    final clean = val.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  int _cellToInt(Data? cell) {
    if (cell == null || cell.value == null) return -1;
    final val = cell.value;
    if (val is IntCellValue) return val.value;
    if (val is DoubleCellValue) return val.value.toInt();
    if (val is num) return (val as num).toInt();
    final clean = val.toString().replaceAll(RegExp(r'[^0-9-]'), '');
    return int.tryParse(clean) ?? -1;
  }

  static int dateNowMs() => DateTime.now().millisecondsSinceEpoch % 100000;
}
