class PosStockMovement {
  final int? id;
  final int productId;
  final String? productName;
  final String? penitip;
  final String movementType; // 'IN_CONSIGNMENT', 'SALE', 'RETURN', 'ADJUSTMENT'
  final int qty;
  final int beforeStock;
  final int afterStock;
  final String? refNumber;
  final String operatorName;
  final String? note;
  final DateTime createdAt;

  PosStockMovement({
    this.id,
    required this.productId,
    this.productName,
    this.penitip,
    required this.movementType,
    required this.qty,
    required this.beforeStock,
    required this.afterStock,
    this.refNumber,
    this.operatorName = 'Admin',
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'penitip': penitip,
      'movement_type': movementType,
      'qty': qty,
      'before_stock': beforeStock,
      'after_stock': afterStock,
      'ref_number': refNumber,
      'operator_name': operatorName,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PosStockMovement.fromMap(Map<String, dynamic> map) {
    return PosStockMovement(
      id: map['id'] as int?,
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      productName: map['product_name'] as String?,
      penitip: map['penitip'] as String?,
      movementType: map['movement_type'] as String? ?? 'IN_CONSIGNMENT',
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      beforeStock: (map['before_stock'] as num?)?.toInt() ?? 0,
      afterStock: (map['after_stock'] as num?)?.toInt() ?? 0,
      refNumber: map['ref_number'] as String?,
      operatorName: map['operator_name'] as String? ?? 'Admin',
      note: map['note'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
    );
  }
}
