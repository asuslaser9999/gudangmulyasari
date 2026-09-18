import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stock.dart';
import '../services/item_service.dart';
import '../services/location_service.dart';
import '../services/stock_service.dart';
import '../utils/table_filter_sort.dart';

class StockNotifier extends ChangeNotifier {
  StockNotifier({
    ItemService? itemService,
    LocationService? locationService,
    StockService? stockService,
  }) : _itemService = itemService ?? ItemService(),
       _locationService = locationService ?? LocationService(),
       _stockService = stockService ?? StockService();

  final ItemService _itemService;
  final LocationService _locationService;
  final StockService _stockService;

  List<StockItem> _items = [];
  List<StockLocation> _locations = [];
  List<StockRow> _rows = [];
  List<StockMoveLine> _transfers = [];
  List<StockMoveLine> _receipts = [];
  String _searchQuery = '';
  StockSort _sort = StockSort.custom;
  RecapPeriod _period = RecapPeriod.days30;
  RecapPeriod _receiptPeriod = RecapPeriod.days30;
  String _recapQuery = '';
  String _receiptQuery = '';
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<StockItem> get items => _items;
  List<StockItem> get activeItems {
    final result = _items.where((item) => item.isActive).toList()
      ..sort(compareItemOrder);
    return result;
  }
  List<StockLocation> get locations =>
      _locations.where((loc) => loc.isActive).toList();
  List<StockLocation> get warehouses =>
      locations.where((loc) => loc.isWarehouse).toList();
  List<StockLocation> get kitchens =>
      locations.where((loc) => loc.isKitchen).toList();
  String get searchQuery => _searchQuery;
  StockSort get sort => _sort;
  RecapPeriod get period => _period;
  RecapPeriod get receiptPeriod => _receiptPeriod;
  String get recapQuery => _recapQuery;
  String get receiptQuery => _receiptQuery;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  List<StockRow> get filteredRows {
    var result = _rows.where((row) {
      return matchesSearch(_searchQuery, [row.item.name, row.item.unit]);
    }).toList();
    result.sort((a, b) {
      switch (_sort) {
        case StockSort.custom:
          return compareItemOrder(a.item, b.item);
        case StockSort.nameAsc:
          return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
        case StockSort.nameDesc:
          return b.item.name.toLowerCase().compareTo(a.item.name.toLowerCase());
        case StockSort.totalDesc:
          return b.qtyTotal.compareTo(a.qtyTotal);
        case StockSort.totalAsc:
          return a.qtyTotal.compareTo(b.qtyTotal);
      }
    });
    return result;
  }

  List<StockMoveLine> get filteredTransfers =>
      _filterMoves(_transfers, _period, _recapQuery);

  List<StockMoveLine> get filteredReceipts =>
      _filterMoves(_receipts, _receiptPeriod, _receiptQuery);

  List<StockMoveLine> _filterMoves(
    List<StockMoveLine> source,
    RecapPeriod period,
    String query,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return source.where((line) {
      final date = DateTime(
        line.docDate.year,
        line.docDate.month,
        line.docDate.day,
      );
      final inPeriod = switch (period) {
        RecapPeriod.all => true,
        RecapPeriod.today => !date.isBefore(today),
        RecapPeriod.days7 =>
          !date.isBefore(today.subtract(const Duration(days: 6))),
        RecapPeriod.days30 =>
          !date.isBefore(today.subtract(const Duration(days: 29))),
      };
      return inPeriod &&
          matchesSearch(query, [
            line.itemName,
            line.fromLocationName,
            line.toLocationName,
            line.note,
            line.createdByName,
          ]);
    }).toList();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _items = await _itemService.list();
      _locations = await _locationService.list();
      _rows = await _stockService.loadRows(items: _items);
      final itemMap = {for (final item in _items) item.id: item};
      final locMap = {for (final loc in _locations) loc.id: loc};
      _transfers = await _stockService.loadTransfers(
        locations: locMap,
        items: itemMap,
      );
      _receipts = await _stockService.loadReceipts(
        locations: locMap,
        items: itemMap,
      );
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

  void setSort(StockSort value) {
    _sort = value;
    notifyListeners();
  }

  void setPeriod(RecapPeriod value) {
    _period = value;
    notifyListeners();
  }

  void setReceiptPeriod(RecapPeriod value) {
    _receiptPeriod = value;
    notifyListeners();
  }

  void setRecapQuery(String value) {
    _recapQuery = value;
    notifyListeners();
  }

  void setReceiptQuery(String value) {
    _receiptQuery = value;
    notifyListeners();
  }

  Future<bool> saveItemOrder(List<String> ids) async {
    try {
      await _itemService.saveOrder(ids);
      await load();
      return true;
    } catch (e) {
      _errorMessage = _mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> post({
    required String docType,
    required DateTime docDate,
    String? fromLocationId,
    String? toLocationId,
    String note = '',
    required List<StockDraftLine> lines,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _stockService.post(
        docType: docType,
        docDate: docDate,
        fromLocationId: fromLocationId,
        toLocationId: toLocationId,
        note: note,
        lines: lines,
      );
      await load();
      return true;
    } catch (e) {
      _errorMessage = _mapError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> voidTransferLine(String lineId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _stockService.voidTransferLine(lineId);
      await load();
      return true;
    } catch (e) {
      _errorMessage = _mapError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> voidReceiptLine(String lineId) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _stockService.voidReceiptLine(lineId);
      await load();
      return true;
    } catch (e) {
      _errorMessage = _mapError(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  String _mapError(Object error) {
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      if (message.contains('sort_order') || message.contains('schema cache')) {
        return 'Jalankan supabase/migrations/003_gm_item_sort.sql '
            'di Supabase SQL Editor, lalu coba lagi.';
      }
      if (message.contains('gm_user_location_access') ||
          message.contains('gm_void_stock_transfer_line') ||
          message.contains('gm_can_see_location')) {
        return 'Jalankan supabase/migrations/004_gm_roles_access.sql '
            'di Supabase SQL Editor, lalu coba lagi.';
      }
      if (message.contains('gm_user_item_access') ||
          message.contains('gm_can_receipt_item')) {
        return 'Jalankan supabase/migrations/007_gm_receipt_item_access.sql '
            'di Supabase SQL Editor, lalu coba lagi.';
      }
      if (message.contains('gm_void_stock_receipt_line')) {
        return 'Jalankan supabase/migrations/008_gm_void_receipt.sql '
            'di Supabase SQL Editor, lalu coba lagi.';
      }
      return error.message;
    }
    return 'Gagal memuat atau menyimpan stok.';
  }
}
