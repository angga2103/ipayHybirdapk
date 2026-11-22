/// Model Satuan Bertingkat (Multi-Satuan / Grosir - Eceran)
class PosProductUnit {
  final int? id;
  final int? productId;
  final String unitName; // Contoh: 'Dus', 'Slop', 'Bungkus', 'Batang', 'Pcs'
  final int conversionFactor; // Pengali ke satuan dasar (misal: 1 Dus = 3456 Batang)
  final double hargaDasar; // Modal beli per satuan ini
  final double hargaJual; // Harga jual per satuan ini
  final String? barcode; // Barcode spesifik untuk kemasan ini (opsional)
  final bool isBaseUnit; // True jika ini merupakan satuan terkecil

  const PosProductUnit({
    this.id,
    this.productId,
    required this.unitName,
    required this.conversionFactor,
    required this.hargaDasar,
    required this.hargaJual,
    this.barcode,
    this.isBaseUnit = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'unit_name': unitName,
      'conversion_factor': conversionFactor,
      'harga_dasar': hargaDasar,
      'harga_jual': hargaJual,
      'barcode': barcode,
      'is_base_unit': isBaseUnit ? 1 : 0,
    };
  }

  factory PosProductUnit.fromMap(Map<String, dynamic> map) {
    return PosProductUnit(
      id: map['id'] as int?,
      productId: map['product_id'] as int?,
      unitName: (map['unit_name'] as String?)?.trim().isNotEmpty == true
          ? (map['unit_name'] as String).trim()
          : 'pcs',
      conversionFactor: (map['conversion_factor'] as num?)?.toInt() ?? 1,
      hargaDasar: (map['harga_dasar'] as num?)?.toDouble() ?? 0.0,
      hargaJual: (map['harga_jual'] as num?)?.toDouble() ?? 0.0,
      barcode: map['barcode'] as String?,
      isBaseUnit: (map['is_base_unit'] == 1 || map['is_base_unit'] == true),
    );
  }

  PosProductUnit copyWith({
    int? id,
    int? productId,
    String? unitName,
    int? conversionFactor,
    double? hargaDasar,
    double? hargaJual,
    String? barcode,
    bool? isBaseUnit,
  }) {
    return PosProductUnit(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitName: unitName ?? this.unitName,
      conversionFactor: conversionFactor ?? this.conversionFactor,
      hargaDasar: hargaDasar ?? this.hargaDasar,
      hargaJual: hargaJual ?? this.hargaJual,
      barcode: barcode ?? this.barcode,
      isBaseUnit: isBaseUnit ?? this.isBaseUnit,
    );
  }
}
