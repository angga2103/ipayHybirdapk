class PosProduct {
  final int? id;
  final String kode;
  final String nama;
  final String unit;
  final double hargaDasar;
  final double hargaJual;
  final double beratGr;
  final int stok; // -1 jika unlimited/tanpa batas stok
  final String kategori;
  final String? penitip; // null jika milik sendiri, ada nama jika konsinyasi
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
    this.kategori = 'Umum',
    this.penitip,
    this.createdAt,
    this.updatedAt,
  });

  bool get isConsignment => penitip != null && penitip!.trim().isNotEmpty;
  bool get isUnlimitedStock => stok < 0;
  double get profitMargin => hargaJual - hargaDasar;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'kode': kode.trim(),
      'nama': nama.trim(),
      'unit': unit.trim().isEmpty ? 'pcs' : unit.trim(),
      'harga_dasar': hargaDasar,
      'harga_jual': hargaJual,
      'berat_gr': beratGr,
      'stok': stok,
      'kategori': kategori.trim().isEmpty ? 'Umum' : kategori.trim(),
      'penitip': (penitip != null && penitip!.trim().isNotEmpty) ? penitip!.trim() : null,
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory PosProduct.fromMap(Map<String, dynamic> map) {
    return PosProduct(
      id: map['id'] as int?,
      kode: map['kode']?.toString() ?? '',
      nama: map['nama']?.toString() ?? '',
      unit: map['unit']?.toString() ?? 'pcs',
      hargaDasar: (map['harga_dasar'] is num) ? (map['harga_dasar'] as num).toDouble() : 0.0,
      hargaJual: (map['harga_jual'] is num) ? (map['harga_jual'] as num).toDouble() : 0.0,
      beratGr: (map['berat_gr'] is num) ? (map['berat_gr'] as num).toDouble() : 0.0,
      stok: (map['stok'] is num) ? (map['stok'] as num).toInt() : -1,
      kategori: map['kategori']?.toString() ?? 'Umum',
      penitip: map['penitip']?.toString(),
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
    String? kategori,
    String? penitip,
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
      kategori: kategori ?? this.kategori,
      penitip: penitip ?? this.penitip,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
