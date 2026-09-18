import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/table_names.dart';
import '../models/stock.dart';

class ItemService {
  ItemService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<StockItem>> list() async {
    final rows = await _client
        .from(GmTables.items)
        .select()
        .order('sort_order')
        .order('name');
    return (rows as List)
        .map((row) => StockItem.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<StockItem> save({
    String? id,
    required String name,
    required String unit,
    bool isActive = true,
    int? sortOrder,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'unit': unit.trim().isEmpty ? 'pcs' : unit.trim(),
      'is_active': isActive,
    };
    if (id == null) {
      final existing = await list();
      payload['sort_order'] = sortOrder ??
          existing.fold<int>(0, (max, item) =>
              item.sortOrder > max ? item.sortOrder : max) +
              1;
    } else if (sortOrder != null) {
      payload['sort_order'] = sortOrder;
    }
    final row = id == null
        ? await _client.from(GmTables.items).insert(payload).select().single()
        : await _client
              .from(GmTables.items)
              .update(payload)
              .eq('id', id)
              .select()
              .single();
    return StockItem.fromJson(row);
  }

  Future<void> saveOrder(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      await _client
          .from(GmTables.items)
          .update({'sort_order': i + 1})
          .eq('id', ids[i]);
    }
  }

  Future<void> delete(String id) async {
    await _client.from(GmTables.items).delete().eq('id', id);
  }
}
