import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stock.dart';
import '../services/location_service.dart';
import '../utils/table_filter_sort.dart';

class LocationNotifier extends ChangeNotifier {
  LocationNotifier({LocationService? service})
    : _service = service ?? LocationService();

  final LocationService _service;

  List<StockLocation> _locations = [];
  String _searchQuery = '';
  LocationFilter _filter = LocationFilter.all;
  NameSort _sort = NameSort.nameAsc;
  bool _isLoading = false;
  String? _errorMessage;

  List<StockLocation> get locations => _locations;
  List<StockLocation> get activeLocations =>
      _locations.where((loc) => loc.isActive).toList();
  List<StockLocation> get warehouses =>
      activeLocations.where((loc) => loc.isWarehouse).toList();
  List<StockLocation> get kitchens =>
      activeLocations.where((loc) => loc.isKitchen).toList();
  String get searchQuery => _searchQuery;
  LocationFilter get filter => _filter;
  NameSort get sort => _sort;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<StockLocation> get filtered {
    var result = _locations.where((loc) {
      final kindOk = switch (_filter) {
        LocationFilter.all => true,
        LocationFilter.warehouse => loc.isWarehouse,
        LocationFilter.kitchen => loc.isKitchen,
      };
      return kindOk && matchesSearch(_searchQuery, [loc.name, loc.code]);
    }).toList();
    result.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0 && _sort == NameSort.nameAsc) return byOrder;
      final cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return _sort == NameSort.nameAsc ? cmp : -cmp;
    });
    return result;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _locations = await _service.list();
    } catch (e) {
      _errorMessage = _mapError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setFilter(LocationFilter value) {
    _filter = value;
    notifyListeners();
  }

  void setSort(NameSort value) {
    _sort = value;
    notifyListeners();
  }

  Future<bool> save({
    String? id,
    required String name,
    required LocationKind kind,
    bool isActive = true,
  }) async {
    try {
      await _service.save(id: id, name: name, kind: kind, isActive: isActive);
      await load();
      return true;
    } catch (e) {
      _errorMessage = _mapError(e);
      notifyListeners();
      return false;
    }
  }

  String _mapError(Object error) {
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      if (message.contains('schema cache') ||
          message.contains('could not find the table') ||
          message.contains('could not find table')) {
        return 'Tabel lokasi belum ada di server. Jalankan '
            'supabase/migrations/002_gm_stock.sql di Supabase SQL Editor, '
            'lalu coba lagi.';
      }
      if (message.contains('duplicate') || message.contains('unique')) {
        return 'Kode atau nama lokasi sudah dipakai.';
      }
      return error.message;
    }
    return 'Gagal menyimpan lokasi.';
  }
}
