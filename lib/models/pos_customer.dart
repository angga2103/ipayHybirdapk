/// Model Master Data Pelanggan Toko & Rekap Kasbon
class PosCustomer {
  final int? id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Metadata agregasi transaksi & kasbon
  final double totalDebt;
  final int activeDebtCount;
  final double totalSpent;
  final int transactionCount;

  PosCustomer({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.totalDebt = 0.0,
    this.activeDebtCount = 0,
    this.totalSpent = 0.0,
    this.transactionCount = 0,
  });

  bool get hasActiveDebt => totalDebt > 0;

  String get displayName => name.trim().isEmpty ? 'Umum' : name.trim();

  String get formattedPhone {
    if (phone == null || phone!.trim().isEmpty) return '-';
    return phone!.trim();
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name.trim(),
      'phone': phone?.trim(),
      'address': address?.trim(),
      'notes': notes?.trim(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PosCustomer.fromMap(Map<String, dynamic> map) {
    return PosCustomer(
      id: map['id'] as int?,
      name: (map['name'] as String?)?.trim() ?? 'Umum',
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      totalDebt: (map['total_debt'] as num?)?.toDouble() ?? 0.0,
      activeDebtCount: (map['active_debt_count'] as num?)?.toInt() ?? 0,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (map['transaction_count'] as num?)?.toInt() ?? 0,
    );
  }

  PosCustomer copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? totalDebt,
    int? activeDebtCount,
    double? totalSpent,
    int? transactionCount,
  }) {
    return PosCustomer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalDebt: totalDebt ?? this.totalDebt,
      activeDebtCount: activeDebtCount ?? this.activeDebtCount,
      totalSpent: totalSpent ?? this.totalSpent,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }
}
