import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stock.dart';
import '../services/item_service.dart';
import '../utils/table_filter_sort.dart';

class ItemNotifier extends ChangeNotifier {
  ItemNotifier({ItemService? service}) : _service = service ?? ItemService();

  final ItemService _service;

  List<StockItem> _items = [];
  String _searchQuery = '';
  ItemSort _sort = ItemSort.custom;
  bool _isLoading = false;
  String? _errorMessage;

  List<StockItem> get items => _items;
  String get searchQuery => _searchQuery;
  ItemSort get sort => _sort;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<StockItem> get filtered {
    var result = _items.where((item) {
      return matchesSearch(_searchQuery, [item.name, item.unit]);
    }).toList();
    result.sort((a, b) {
      switch (_sort) {
        case ItemSort.custom:
          return compareItemOrder(a, b);
        case ItemSort.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case ItemSort.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      }
    });
    return result;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _items = await _service.list();
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

  void setSort(ItemSort value) {
    _sort = value;
    notifyListeners();
  }

  Future<bool> saveOrder(List<String> ids) async {
    try {
      await _service.saveOrder(ids);
      await load();
      return true;
    } catch (e) {
      _errorMessage = _mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> save({
    String? id,
    required String name,
    required String unit,
    bool isActive = true,
  }) async {
    try {
      await _service.save(id: id, name: name, unit: unit, isActive: isActive);
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
          message.contains('could not find table') ||
          message.contains('sort_order')) {
        return 'Kolom urutan barang belum ada di server. Jalankan '
            'supabase/migrations/003_gm_item_sort.sql di Supabase SQL Editor, '
            'lalu coba lagi.';
      }
      if (message.contains('duplicate') || message.contains('unique')) {
        return 'Nama barang sudah dipakai.';
      }
      return error.message;
    }
    return 'Gagal menyimpan barang.';
  }
}
