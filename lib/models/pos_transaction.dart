class PosTransactionReturn {
  final int? id;
  final int transactionId;
  final String invoiceNo;
  final String productKode;
  final String productName;
  final int qtyReturned;
  final double refundAmount;
  final String? reason;
  final DateTime createdAt;

  PosTransactionReturn({
    this.id,
    required this.transactionId,
    required this.invoiceNo,
    required this.productKode,
    required this.productName,
    required this.qtyReturned,
    required this.refundAmount,
    this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toMap([int? trxId]) {
    return {
      if (id != null) 'id': id,
      'transaction_id': trxId ?? transactionId,
      'invoice_no': invoiceNo,
      'product_kode': productKode,
      'product_name': productName,
      'qty_returned': qtyReturned,
      'refund_amount': refundAmount,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PosTransactionReturn.fromMap(Map<String, dynamic> map) {
    return PosTransactionReturn(
      id: map['id'] as int?,
      transactionId: (map['transaction_id'] is num) ? (map['transaction_id'] as num).toInt() : 0,
      invoiceNo: map['invoice_no']?.toString() ?? '',
      productKode: map['product_kode']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      qtyReturned: (map['qty_returned'] is num) ? (map['qty_returned'] as num).toInt() : 0,
      refundAmount: (map['refund_amount'] is num) ? (map['refund_amount'] as num).toDouble() : 0.0,
      reason: map['reason']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class PosTransactionItem {
  final int? id;
  final int? transactionId;
  final String productKode;
  final String productName;
  final String unit;
  final double costPrice;
  final double normalPrice;
  final double soldPrice;
  final int qty;
  final int returnedQty;
  final double subtotal;
  final double profit;
  final String? penitip;
  final bool isStockManaged;
  final double dueToPenitip;

  PosTransactionItem({
    this.id,
    this.transactionId,
    required this.productKode,
    required this.productName,
    this.unit = 'pcs',
    required this.costPrice,
    required this.normalPrice,
    required this.soldPrice,
    required this.qty,
    this.returnedQty = 0,
    required this.subtotal,
    required this.profit,
    this.penitip,
    this.isStockManaged = true,
    this.dueToPenitip = 0.0,
  });

  bool get isConsignment => penitip != null && penitip!.trim().isNotEmpty;
  bool get isBelowCost => soldPrice < costPrice;
  double get discountPerUnit => normalPrice - soldPrice;

  // Nilai aktif setelah dikurangi barang yang diretur
  int get activeQty => qty - returnedQty > 0 ? (qty - returnedQty) : 0;
  bool get isFullyReturned => activeQty <= 0;
  bool get isPartiallyReturned => returnedQty > 0 && activeQty > 0;
  double get activeSubtotal => activeQty * soldPrice;
  double get unitCost => costPrice;
  double get unitProfit => soldPrice - costPrice;
  double get activeProfit => activeQty * unitProfit;
  double get unitDueToPenitip => qty > 0 ? (dueToPenitip / qty) : 0.0;
  double get activeDueToPenitip => activeQty * unitDueToPenitip;

  Map<String, dynamic> toMap(int trxId) {
    return {
      if (id != null) 'id': id,
      'transaction_id': trxId,
      'product_kode': productKode,
      'product_name': productName,
      'unit': unit,
      'cost_price': costPrice,
      'normal_price': normalPrice,
      'sold_price': soldPrice,
      'qty': qty,
      'returned_qty': returnedQty,
      'subtotal': subtotal,
      'profit': profit,
      'penitip': penitip,
      'is_stock_managed': isStockManaged ? 1 : 0,
      'due_to_penitip': dueToPenitip,
    };
  }

  factory PosTransactionItem.fromMap(Map<String, dynamic> map) {
    return PosTransactionItem(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int?,
      productKode: map['product_kode']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      unit: map['unit']?.toString() ?? 'pcs',
      costPrice: (map['cost_price'] is num) ? (map['cost_price'] as num).toDouble() : 0.0,
      normalPrice: (map['normal_price'] is num) ? (map['normal_price'] as num).toDouble() : 0.0,
      soldPrice: (map['sold_price'] is num) ? (map['sold_price'] as num).toDouble() : 0.0,
      qty: (map['qty'] is num) ? (map['qty'] as num).toInt() : 1,
      returnedQty: (map['returned_qty'] is num) ? (map['returned_qty'] as num).toInt() : 0,
      subtotal: (map['subtotal'] is num) ? (map['subtotal'] as num).toDouble() : 0.0,
      profit: (map['profit'] is num) ? (map['profit'] as num).toDouble() : 0.0,
      penitip: map['penitip']?.toString(),
      isStockManaged: map['is_stock_managed'] == null ? true : (map['is_stock_managed'] == 1 || map['is_stock_managed'] == true),
      dueToPenitip: (map['due_to_penitip'] is num) ? (map['due_to_penitip'] as num).toDouble() : 0.0,
    );
  }
}

class PosTransaction {
  final int? id;
  final String invoiceNo;
  final DateTime dateTime;
  final double totalAmount;
  final double normalAmount;
  final double discountAmount;
  final double profitAmount;
  final double consignmentDueAmount;
  final double cashPaid;
  final double changeDue;
  final String paymentMethod;
  final String? cashierName;
  final String? note;
  final String status; // 'COMPLETED', 'PARTIAL_RETURN', 'CANCELLED'
  final List<PosTransactionItem> items;
  final List<PosTransactionReturn> returns;

  PosTransaction({
    this.id,
    required this.invoiceNo,
    required this.dateTime,
    required this.totalAmount,
    this.normalAmount = 0.0,
    this.discountAmount = 0.0,
    this.profitAmount = 0.0,
    this.consignmentDueAmount = 0.0,
    required this.cashPaid,
    required this.changeDue,
    this.paymentMethod = 'Tunai',
    this.cashierName = 'Kasir',
    this.note,
    this.status = 'COMPLETED',
    this.items = const [],
    this.returns = const [],
  });

  bool get isCancelled => status == 'CANCELLED';
  bool get isPartiallyReturned => status == 'PARTIAL_RETURN' || (items.any((it) => it.returnedQty > 0) && !isCancelled);
  int get totalActiveItemsQty => items.fold(0, (sum, it) => sum + it.activeQty);
  int get totalOriginalQty => items.fold(0, (sum, it) => sum + it.qty);
  int get totalReturnedQty => items.fold(0, (sum, it) => sum + it.returnedQty);
  double get totalRefundedAmount => returns.fold(0.0, (sum, r) => sum + r.refundAmount);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_no': invoiceNo,
      'date_time': dateTime.toIso8601String(),
      'total_amount': totalAmount,
      'normal_amount': normalAmount,
      'discount_amount': discountAmount,
      'profit_amount': profitAmount,
      'consignment_due_amount': consignmentDueAmount,
      'cash_paid': cashPaid,
      'change_due': changeDue,
      'payment_method': paymentMethod,
      'cashier_name': cashierName ?? 'Kasir',
      'note': note,
      'status': status,
    };
  }

  factory PosTransaction.fromMap(
    Map<String, dynamic> map, [
    List<PosTransactionItem> items = const [],
    List<PosTransactionReturn> returns = const [],
  ]) {
    return PosTransaction(
      id: map['id'] as int?,
      invoiceNo: map['invoice_no']?.toString() ?? '',
      dateTime: DateTime.tryParse(map['date_time']?.toString() ?? '') ?? DateTime.now(),
      totalAmount: (map['total_amount'] is num) ? (map['total_amount'] as num).toDouble() : 0.0,
      normalAmount: (map['normal_amount'] is num) ? (map['normal_amount'] as num).toDouble() : 0.0,
      discountAmount: (map['discount_amount'] is num) ? (map['discount_amount'] as num).toDouble() : 0.0,
      profitAmount: (map['profit_amount'] is num) ? (map['profit_amount'] as num).toDouble() : 0.0,
      consignmentDueAmount: (map['consignment_due_amount'] is num) ? (map['consignment_due_amount'] as num).toDouble() : 0.0,
      cashPaid: (map['cash_paid'] is num) ? (map['cash_paid'] as num).toDouble() : 0.0,
      changeDue: (map['change_due'] is num) ? (map['change_due'] as num).toDouble() : 0.0,
      paymentMethod: map['payment_method']?.toString() ?? 'Tunai',
      cashierName: map['cashier_name']?.toString() ?? 'Kasir',
      note: map['note']?.toString(),
      status: map['status']?.toString() ?? 'COMPLETED',
      items: items,
      returns: returns,
    );
  }
}

class PosDailyClosing {
  final int? id;
  final String closingDate; // YYYY-MM-DD
  final int totalTransactions;
  final double totalRevenue;
  final double totalProfit;
  final double cashRevenue;
  final double nonCashRevenue;
  final double consignmentDue;
  final DateTime closedAt;
  final String? notes;

  PosDailyClosing({
    this.id,
    required this.closingDate,
    required this.totalTransactions,
    required this.totalRevenue,
    required this.totalProfit,
    required this.cashRevenue,
    required this.nonCashRevenue,
    required this.consignmentDue,
    required this.closedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'closing_date': closingDate,
      'total_transactions': totalTransactions,
      'total_revenue': totalRevenue,
      'total_profit': totalProfit,
      'cash_revenue': cashRevenue,
      'non_cash_revenue': nonCashRevenue,
      'consignment_due': consignmentDue,
      'closed_at': closedAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory PosDailyClosing.fromMap(Map<String, dynamic> map) {
    return PosDailyClosing(
      id: map['id'] as int?,
      closingDate: map['closing_date']?.toString() ?? '',
      totalTransactions: (map['total_transactions'] is num) ? (map['total_transactions'] as num).toInt() : 0,
      totalRevenue: (map['total_revenue'] is num) ? (map['total_revenue'] as num).toDouble() : 0.0,
      totalProfit: (map['total_profit'] is num) ? (map['total_profit'] as num).toDouble() : 0.0,
      cashRevenue: (map['cash_revenue'] is num) ? (map['cash_revenue'] as num).toDouble() : 0.0,
      nonCashRevenue: (map['non_cash_revenue'] is num) ? (map['non_cash_revenue'] as num).toDouble() : 0.0,
      consignmentDue: (map['consignment_due'] is num) ? (map['consignment_due'] as num).toDouble() : 0.0,
      closedAt: DateTime.tryParse(map['closed_at']?.toString() ?? '') ?? DateTime.now(),
      notes: map['notes']?.toString(),
    );
  }
}
