import 'pos_product.dart';
import 'pos_product_unit.dart';

class PosCartItem {
  final PosProduct product;
  int qty;
  double actualPrice; // Harga jual dinamis yang bisa diubah kasir
  PosProductUnit? selectedUnit; // Satuan bertingkat yang dipilih kasir (null = unit standar)

  PosCartItem({
    required this.product,
    this.qty = 1,
    double? customPrice,
    this.selectedUnit,
  }) : actualPrice = customPrice ?? (selectedUnit?.hargaJual ?? product.hargaJual);

  String get activeUnitName => selectedUnit?.unitName ?? product.unit;
  int get unitMultiplier => selectedUnit?.conversionFactor ?? 1;
  int get totalBaseQtyDeduction => qty * unitMultiplier;

  double get normalPrice => selectedUnit?.hargaJual ?? product.hargaJual;
  double get costPrice => selectedUnit?.hargaDasar ?? product.hargaDasar;

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
  bool get hasMultiUnit => product.hasMultiUnit;

  /// Beralih ke satuan tingkat berikutnya (Batang -> Bungkus -> Slop -> Dus)
  void cycleNextUnit() {
    if (!hasMultiUnit) return;
    final units = product.multiUnits;
    if (units.isEmpty) return;

    final currentUnitName = selectedUnit?.unitName ?? product.unit;
    final currentIndex = units.indexWhere((u) => u.unitName.toLowerCase() == currentUnitName.toLowerCase());

    final nextIndex = currentIndex == -1 ? 0 : ((currentIndex + 1) % units.length);
    selectedUnit = units[nextIndex];
    actualPrice = selectedUnit!.hargaJual;
  }

  void setUnit(PosProductUnit newUnit) {
    selectedUnit = newUnit;
    actualPrice = newUnit.hargaJual;
  }

  PosCartItem copyWith({
    PosProduct? product,
    int? qty,
    double? actualPrice,
    PosProductUnit? selectedUnit,
  }) {
    return PosCartItem(
      product: product ?? this.product,
      qty: qty ?? this.qty,
      customPrice: actualPrice ?? this.actualPrice,
      selectedUnit: selectedUnit ?? this.selectedUnit,
    );
  }
}
