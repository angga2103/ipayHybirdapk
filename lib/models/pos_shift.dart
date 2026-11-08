/// Model Shift Kasir (Buka / Tutup Toko & Hitung Selisih Uang Laci)
class PosShift {
  final int? id;
  final String cashierName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double startingCash;
  final double expectedCash;
  final double actualCash;
  final double cashDifference;
  final double totalCashSales;
  final double totalQrisSales;
  final double totalDebtSales;
  final double totalNonCashSales;
  final double totalCashIn;
  final double totalCashOut;
  final int totalTransactions;
  final String status; // 'OPEN' atau 'CLOSED'
  final String? notes;

  PosShift({
    this.id,
    required this.cashierName,
    required this.openedAt,
    this.closedAt,
    this.startingCash = 0.0,
    this.expectedCash = 0.0,
    this.actualCash = 0.0,
    this.cashDifference = 0.0,
    this.totalCashSales = 0.0,
    this.totalQrisSales = 0.0,
    this.totalDebtSales = 0.0,
    this.totalNonCashSales = 0.0,
    this.totalCashIn = 0.0,
    this.totalCashOut = 0.0,
    this.totalTransactions = 0,
    this.status = 'OPEN',
    this.notes,
  });

  bool get isOpen => status == 'OPEN';

  /// Total seluruh penjualan (omset kotor) yang terjadi selama shift
  double get totalSales => totalCashSales + totalQrisSales + totalDebtSales + totalNonCashSales;

  /// Uang tunai laci kasir fisik yang seharusnya ada
  /// (HANYA menghitung Modal Awal + Penjualan Tunai + Kas Masuk - Kas Keluar)
  /// QRIS tidak masuk laci fisik karena langsung masuk rekening/e-wallet.
  /// Kasbon tidak masuk laci fisik karena belum dibayar (piutang).
  double get calculatedExpectedCash =>
      startingCash + totalCashSales + totalCashIn - totalCashOut;

  /// Durasi shift berjalan
  Duration get shiftDuration => (closedAt ?? DateTime.now()).difference(openedAt);

  String get formattedDuration {
    final d = shiftDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) {
      return '$h Jam $m Mnt';
    }
    return '$m Menit';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cashier_name': cashierName,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'starting_cash': startingCash,
      'expected_cash': expectedCash,
      'actual_cash': actualCash,
      'cash_difference': cashDifference,
      'total_cash_sales': totalCashSales,
      'total_qris_sales': totalQrisSales,
      'total_debt_sales': totalDebtSales,
      'total_non_cash_sales': totalNonCashSales,
      'total_cash_in': totalCashIn,
      'total_cash_out': totalCashOut,
      'total_transactions': totalTransactions,
      'status': status,
      'notes': notes,
    };
  }

  factory PosShift.fromMap(Map<String, dynamic> map) {
    return PosShift(
      id: map['id'] as int?,
      cashierName: (map['cashier_name'] as String?) ?? 'Kasir',
      openedAt: DateTime.tryParse(map['opened_at']?.toString() ?? '') ?? DateTime.now(),
      closedAt: map['closed_at'] != null ? DateTime.tryParse(map['closed_at'].toString()) : null,
      startingCash: (map['starting_cash'] as num?)?.toDouble() ?? 0.0,
      expectedCash: (map['expected_cash'] as num?)?.toDouble() ?? 0.0,
      actualCash: (map['actual_cash'] as num?)?.toDouble() ?? 0.0,
      cashDifference: (map['cash_difference'] as num?)?.toDouble() ?? 0.0,
      totalCashSales: (map['total_cash_sales'] as num?)?.toDouble() ?? 0.0,
      totalQrisSales: (map['total_qris_sales'] as num?)?.toDouble() ?? 0.0,
      totalDebtSales: (map['total_debt_sales'] as num?)?.toDouble() ?? 0.0,
      totalNonCashSales: (map['total_non_cash_sales'] as num?)?.toDouble() ?? 0.0,
      totalCashIn: (map['total_cash_in'] as num?)?.toDouble() ?? 0.0,
      totalCashOut: (map['total_cash_out'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: (map['total_transactions'] as int?) ?? 0,
      status: (map['status'] as String?) ?? 'OPEN',
      notes: map['notes'] as String?,
    );
  }

  PosShift copyWith({
    int? id,
    String? cashierName,
    DateTime? openedAt,
    DateTime? closedAt,
    double? startingCash,
    double? expectedCash,
    double? actualCash,
    double? cashDifference,
    double? totalCashSales,
    double? totalQrisSales,
    double? totalDebtSales,
    double? totalNonCashSales,
    double? totalCashIn,
    double? totalCashOut,
    int? totalTransactions,
    String? status,
    String? notes,
  }) {
    return PosShift(
      id: id ?? this.id,
      cashierName: cashierName ?? this.cashierName,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      startingCash: startingCash ?? this.startingCash,
      expectedCash: expectedCash ?? this.expectedCash,
      actualCash: actualCash ?? this.actualCash,
      cashDifference: cashDifference ?? this.cashDifference,
      totalCashSales: totalCashSales ?? this.totalCashSales,
      totalQrisSales: totalQrisSales ?? this.totalQrisSales,
      totalDebtSales: totalDebtSales ?? this.totalDebtSales,
      totalNonCashSales: totalNonCashSales ?? this.totalNonCashSales,
      totalCashIn: totalCashIn ?? this.totalCashIn,
      totalCashOut: totalCashOut ?? this.totalCashOut,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}
