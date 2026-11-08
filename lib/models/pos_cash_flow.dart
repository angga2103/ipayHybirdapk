/// Model Kas Masuk / Kas Keluar (Petty Cash Operasional Toko)
class PosCashFlow {
  final int? id;
  final int? shiftId;
  final String type; // 'IN' (Kas Masuk) atau 'OUT' (Kas Keluar)
  final double amount;
  final String category; // 'Operasional', 'Beli Perlengkapan', 'Modal Tambahan', 'Setoran', 'Lain-lain'
  final String? note;
  final String cashierName;
  final DateTime createdAt;

  PosCashFlow({
    this.id,
    this.shiftId,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    this.cashierName = 'Kasir',
    required this.createdAt,
  });

  bool get isCashIn => type.toUpperCase() == 'IN';
  bool get isCashOut => type.toUpperCase() == 'OUT';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'shift_id': shiftId,
      'type': type.toUpperCase(),
      'amount': amount,
      'category': category,
      'note': note,
      'cashier_name': cashierName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PosCashFlow.fromMap(Map<String, dynamic> map) {
    return PosCashFlow(
      id: map['id'] as int?,
      shiftId: map['shift_id'] as int?,
      type: (map['type'] as String?)?.toUpperCase() ?? 'OUT',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: (map['category'] as String?) ?? 'Operasional',
      note: map['note'] as String?,
      cashierName: (map['cashier_name'] as String?) ?? 'Kasir',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
