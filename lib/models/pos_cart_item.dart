import 'pos_product.dart';

class PosCartItem {
  final PosProduct product;
  int qty;
  double actualPrice; // Harga jual dinamis yang bisa diubah kasir

  PosCartItem({
    required this.product,
    this.qty = 1,
    double? customPrice,
  }) : actualPrice = customPrice ?? product.hargaJual;

  double get normalPrice => product.hargaJual;
  double get costPrice => product.hargaDasar;

  double get subtotal => actualPrice * qty;
  double get normalSubtotal => normalPrice * qty;
  double get discountAmount => (normalPrice - actualPrice) * qty;

  Map<String, double> get commissionBreakdown => product.calculateUnitCommission(actualPrice);
  double get unitStoreFee => commissionBreakdown['store_fee'] ?? (actualPrice - costPrice);
  double get unitDueToPenitip => commissionBreakdown['due_to_penitip'] ?? 0.0;

  double get profitAmount => isConsignment ? (unitStoreFee * qty) : ((actualPrice - costPrice) * qty);
  double get dueToPenitipAmount => isConsignment ? (unitDueToPenitip * qty) : 0.0;

  bool get isBelowCost => actualPrice < costPrice;
  bool get isPriceModified => (actualPrice - normalPrice).abs() > 0.001;
  bool get isConsignment => product.isConsignment;
  String? get penitip => product.penitip;
  bool get isStockManaged => product.isStockManaged;

  PosCartItem copyWith({
    PosProduct? product,
    int? qty,
    double? actualPrice,
  }) {
    return PosCartItem(
      product: product ?? this.product,
      qty: qty ?? this.qty,
      customPrice: actualPrice ?? this.actualPrice,
    );
  }
}
