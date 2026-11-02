class PosProduct {
  final int? id;
  final String kode;
  final String nama;
  final String unit;
  final double hargaDasar;
  final double hargaJual;
  final double beratGr;
  final int stok; // -1 jika unlimited/tanpa batas stok
  final bool isStockManaged; // true jika stok dihitung, false jika bebas/unlimited
  final String kategori;
  final String? penitip; // null jika milik sendiri, ada nama jika konsinyasi
  final String productType; // 'shop' (barang toko), 'consignment' (titipan), 'service' (jasa/tanpa stok)
  final String commissionType; // 'markup' (selisih harga), 'nominal' (komisi per pcs), 'percent' (persentase omset)
  final double commissionValue; // nominal komisi atau angka persentase (misal 10%)
  final bool isArchived; // true jika dihapus secara soft-delete
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PosProduct({
    this.id,
    required this.kode,
    required this.nama,
    this.unit = 'pcs',
    required this.hargaDasar,
    required this.hargaJual,
    this.beratGr = 0.0,
    this.stok = -1,
    bool? isStockManaged,
    this.kategori = 'Umum',
    this.penitip,
    this.productType = 'shop',
    this.commissionType = 'markup',
    this.commissionValue = 0.0,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  }) : isStockManaged = isStockManaged ?? (stok >= 0);

  bool get isConsignment => (penitip != null && penitip!.trim().isNotEmpty) || productType == 'consignment';
  bool get isService => productType == 'service';
  bool get isUnlimitedStock => !isStockManaged || stok < 0;
  double get profitMargin => hargaJual - hargaDasar;

  /// Menghitung komisi toko dan hak penitip untuk 1 unit produk
  Map<String, double> calculateUnitCommission(double actualSoldPrice) {
    if (!isConsignment) {
      return {
        'store_fee': actualSoldPrice - hargaDasar,
        'due_to_penitip': 0.0,
      };
    }

    double storeFee = 0.0;
    double dueToPenitip = 0.0;

    switch (commissionType) {
      case 'nominal':
        storeFee = commissionValue;
        dueToPenitip = actualSoldPrice - storeFee;
        break;
      case 'percent':
        storeFee = actualSoldPrice * (commissionValue / 100.0);
        dueToPenitip = actualSoldPrice - storeFee;
        break;
      case 'markup':
      default:
        dueToPenitip = hargaDasar;
        storeFee = actualSoldPrice - hargaDasar;
        break;
    }

    if (dueToPenitip < 0) dueToPenitip = 0;
    return {
      'store_fee': storeFee,
      'due_to_penitip': dueToPenitip,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'kode': kode.trim(),
      'nama': nama.trim(),
      'unit': unit.trim().isEmpty ? 'pcs' : unit.trim(),
      'harga_dasar': hargaDasar,
      'harga_jual': hargaJual,
      'berat_gr': beratGr,
      'stok': isStockManaged ? (stok < 0 ? 0 : stok) : -1,
      'is_stock_managed': isStockManaged ? 1 : 0,
      'kategori': kategori.trim().isEmpty ? 'Umum' : kategori.trim(),
      'penitip': (penitip != null && penitip!.trim().isNotEmpty) ? penitip!.trim() : null,
      'product_type': productType,
      'commission_type': commissionType,
      'commission_value': commissionValue,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory PosProduct.fromMap(Map<String, dynamic> map) {
    final rawStok = (map['stok'] is num) ? (map['stok'] as num).toInt() : -1;
    final stockManagedVal = map['is_stock_managed'];
    final bool isManaged = stockManagedVal != null ? (stockManagedVal == 1 || stockManagedVal == true) : (rawStok >= 0);

    return PosProduct(
      id: map['id'] as int?,
      kode: map['kode']?.toString() ?? '',
      nama: map['nama']?.toString() ?? '',
      unit: map['unit']?.toString() ?? 'pcs',
      hargaDasar: (map['harga_dasar'] is num) ? (map['harga_dasar'] as num).toDouble() : 0.0,
      hargaJual: (map['harga_jual'] is num) ? (map['harga_jual'] as num).toDouble() : 0.0,
      beratGr: (map['berat_gr'] is num) ? (map['berat_gr'] as num).toDouble() : 0.0,
      stok: rawStok,
      isStockManaged: isManaged,
      kategori: map['kategori']?.toString() ?? 'Umum',
      penitip: map['penitip']?.toString(),
      productType: map['product_type']?.toString() ?? ((map['penitip'] != null && map['penitip'].toString().trim().isNotEmpty) ? 'consignment' : 'shop'),
      commissionType: map['commission_type']?.toString() ?? 'markup',
      commissionValue: (map['commission_value'] is num) ? (map['commission_value'] as num).toDouble() : 0.0,
      isArchived: (map['is_archived'] == 1 || map['is_archived'] == true),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  PosProduct copyWith({
    int? id,
    String? kode,
    String? nama,
    String? unit,
    double? hargaDasar,
    double? hargaJual,
    double? beratGr,
    int? stok,
    bool? isStockManaged,
    String? kategori,
    String? penitip,
    String? productType,
    String? commissionType,
    double? commissionValue,
    bool? isArchived,
  }) {
    return PosProduct(
      id: id ?? this.id,
      kode: kode ?? this.kode,
      nama: nama ?? this.nama,
      unit: unit ?? this.unit,
      hargaDasar: hargaDasar ?? this.hargaDasar,
      hargaJual: hargaJual ?? this.hargaJual,
      beratGr: beratGr ?? this.beratGr,
      stok: stok ?? this.stok,
      isStockManaged: isStockManaged ?? this.isStockManaged,
      kategori: kategori ?? this.kategori,
      penitip: penitip ?? this.penitip,
      productType: productType ?? this.productType,
      commissionType: commissionType ?? this.commissionType,
      commissionValue: commissionValue ?? this.commissionValue,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
