class PosConsignmentPayment {
  final int? id;
  final String paymentNo;
  final String penitip;
  final double totalDueBefore;
  final double amountPaid;
  final double remainingDue;
  final String paymentStatus; // 'LUNAS', 'DIBAYAR SEBAGIAN'
  final String paymentMethod; // 'Tunai', 'Transfer'
  final int? shiftId;
  final String cashierName;
  final String? note;
  final DateTime createdAt;

  PosConsignmentPayment({
    this.id,
    required this.paymentNo,
    required this.penitip,
    required this.totalDueBefore,
    required this.amountPaid,
    required this.remainingDue,
    required this.paymentStatus,
    this.paymentMethod = 'Tunai',
    this.shiftId,
    this.cashierName = 'Kasir',
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'payment_no': paymentNo,
      'penitip': penitip,
      'total_due_before': totalDueBefore,
      'amount_paid': amountPaid,
      'remaining_due': remainingDue,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'shift_id': shiftId,
      'cashier_name': cashierName,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PosConsignmentPayment.fromMap(Map<String, dynamic> map) {
    return PosConsignmentPayment(
      id: map['id'] as int?,
      paymentNo: map['payment_no'] as String? ?? '',
      penitip: map['penitip'] as String? ?? '',
      totalDueBefore: (map['total_due_before'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      remainingDue: (map['remaining_due'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: map['payment_status'] as String? ?? 'LUNAS',
      paymentMethod: map['payment_method'] as String? ?? 'Tunai',
      shiftId: map['shift_id'] as int?,
      cashierName: map['cashier_name'] as String? ?? 'Kasir',
      note: map['note'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }
}
