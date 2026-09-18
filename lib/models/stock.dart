enum LocationKind {
  warehouse('warehouse', 'Gudang'),
  kitchen('kitchen', 'Dapur');

  const LocationKind(this.storageKey, this.label);

  final String storageKey;
  final String label;

  String get productionLabel =>
      this == LocationKind.kitchen ? 'Dapur (produksi)' : label;

  static LocationKind fromStorageKey(String? key) {
    return LocationKind.values.firstWhere(
      (value) => value.storageKey == key,
      orElse: () => LocationKind.warehouse,
    );
  }
}

class StockLocation {
  const StockLocation({
    required this.id,
    required this.code,
    required this.name,
    required this.kind,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String name;
  final LocationKind kind;
  final int sortOrder;
  final bool isActive;

  bool get isWarehouse => kind == LocationKind.warehouse;
  bool get isKitchen => kind == LocationKind.kitchen;

  factory StockLocation.fromJson(Map<String, dynamic> json) {
    return StockLocation(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      kind: LocationKind.fromStorageKey(json['kind'] as String?),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    this.unit = 'pcs',
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String unit;
  final int sortOrder;
  final bool isActive;

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? 'pcs',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  StockItem copyWith({int? sortOrder, bool? isActive}) {
    return StockItem(
      id: id,
      name: name,
      unit: unit,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}

int compareItemOrder(StockItem a, StockItem b) {
  final byOrder = a.sortOrder.compareTo(b.sortOrder);
  if (byOrder != 0) return byOrder;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

class StockRow {
  const StockRow({
    required this.item,
    required this.qtyByLocation,
  });

  final StockItem item;
  final Map<String, double> qtyByLocation;

  double qtyAt(String locationId) => qtyByLocation[locationId] ?? 0;

  double qtyTotalFor(Iterable<String> locationIds) {
    var sum = 0.0;
    for (final id in locationIds) {
      sum += qtyAt(id);
    }
    return sum;
  }

  double get qtyTotal =>
      qtyByLocation.values.fold(0, (sum, value) => sum + value);
}

class StockDraftLine {
  const StockDraftLine({
    required this.item,
    required this.qty,
  });

  final StockItem item;
  final double qty;
}

class StockMoveLine {
  const StockMoveLine({
    required this.lineId,
    required this.docId,
    required this.docDate,
    required this.fromLocationId,
    required this.toLocationId,
    required this.fromLocationName,
    required this.toLocationName,
    required this.itemName,
    required this.unit,
    required this.qty,
    this.note = '',
    this.createdByName = '',
  });

  final String lineId;
  final String docId;
  final DateTime docDate;
  final String? fromLocationId;
  final String? toLocationId;
  final String fromLocationName;
  final String toLocationName;
  final String itemName;
  final String unit;
  final double qty;
  final String note;
  final String createdByName;
}

enum RecapPeriod {
  today('Hari ini'),
  days7('7 hari'),
  days30('30 hari'),
  all('Semua');

  const RecapPeriod(this.label);
  final String label;
}

enum NameSort {
  nameAsc('Nama A-Z'),
  nameDesc('Nama Z-A');

  const NameSort(this.label);
  final String label;
}

enum ItemSort {
  custom('Urutan tersimpan'),
  nameAsc('Nama A-Z'),
  nameDesc('Nama Z-A');

  const ItemSort(this.label);
  final String label;
}

enum StockSort {
  custom('Urutan tersimpan'),
  nameAsc('Nama A-Z'),
  nameDesc('Nama Z-A'),
  totalDesc('Total terbanyak'),
  totalAsc('Total terendah');

  const StockSort(this.label);
  final String label;
}

enum LocationFilter {
  all('Semua'),
  warehouse('Gudang'),
  kitchen('Dapur');

  const LocationFilter(this.label);
  final String label;
}
