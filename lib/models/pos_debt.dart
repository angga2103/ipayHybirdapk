/// Model Kasbon / Catatan Hutang Pelanggan (Piutang Warung)
class PosCustomerDebt {
  final int? id;
  final int? transactionId;
  final String invoiceNo;
  final String customerName;
  final String? customerPhone;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final DateTime? dueDate;
  final String status; // 'UNPAID', 'PARTIAL', 'PAID'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PosDebtPayment> payments;

  PosCustomerDebt({
    this.id,
    this.transactionId,
    required this.invoiceNo,
    required this.customerName,
    this.customerPhone,
    required this.totalAmount,
    this.paidAmount = 0.0,
    required this.remainingAmount,
    this.dueDate,
    this.status = 'UNPAID',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.payments = const [],
  });

  bool get isPaid => status == 'PAID' || remainingAmount <= 0.0;
  bool get isPartial => status == 'PARTIAL';
  bool get isUnpaid => status == 'UNPAID';

  bool get isOverdue {
    if (isPaid || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transaction_id': transactionId,
      'invoice_no': invoiceNo,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'due_date': dueDate?.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PosCustomerDebt.fromMap(Map<String, dynamic> map, {List<PosDebtPayment> payments = const []}) {
    return PosCustomerDebt(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int?,
      invoiceNo: (map['invoice_no'] as String?) ?? '',
      customerName: (map['customer_name'] as String?) ?? 'Pelanggan',
      customerPhone: map['customer_phone'] as String?,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (map['remaining_amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: map['due_date'] != null ? DateTime.tryParse(map['due_date'].toString()) : null,
      status: (map['status'] as String?) ?? 'UNPAID',
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      payments: payments,
    );
  }
}

/// Model Riwayat Pembayaran Cicilan / Pelunasan Kasbon
class PosDebtPayment {
  final int? id;
  final int debtId;
  final double amountPaid;
  final DateTime paymentDate;
  final String cashierName;
  final String? note;

  PosDebtPayment({
    this.id,
    required this.debtId,
    required this.amountPaid,
    required this.paymentDate,
    this.cashierName = 'Kasir',
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'debt_id': debtId,
      'amount_paid': amountPaid,
      'payment_date': paymentDate.toIso8601String(),
      'cashier_name': cashierName,
      'note': note,
    };
  }

  factory PosDebtPayment.fromMap(Map<String, dynamic> map) {
    return PosDebtPayment(
      id: map['id'] as int?,
      debtId: (map['debt_id'] as int?) ?? 0,
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      paymentDate: DateTime.tryParse(map['payment_date']?.toString() ?? '') ?? DateTime.now(),
      cashierName: (map['cashier_name'] as String?) ?? 'Kasir',
      note: map['note'] as String?,
    );
  }
}
