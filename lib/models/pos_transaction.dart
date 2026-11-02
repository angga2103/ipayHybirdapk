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
  final double subtotal;
  final double profit;
  final String? penitip;

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
    required this.subtotal,
    required this.profit,
    this.penitip,
  });

  bool get isConsignment => penitip != null && penitip!.trim().isNotEmpty;
  bool get isBelowCost => soldPrice < costPrice;
  double get discountPerUnit => normalPrice - soldPrice;

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
      'subtotal': subtotal,
      'profit': profit,
      'penitip': penitip,
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
      subtotal: (map['subtotal'] is num) ? (map['subtotal'] as num).toDouble() : 0.0,
      profit: (map['profit'] is num) ? (map['profit'] as num).toDouble() : 0.0,
      penitip: map['penitip']?.toString(),
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
  final List<PosTransactionItem> items;

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
    this.items = const [],
  });

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
    };
  }

  factory PosTransaction.fromMap(Map<String, dynamic> map, [List<PosTransactionItem> items = const []]) {
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
      items: items,
    );
  }
}
