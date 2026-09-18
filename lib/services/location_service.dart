import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/table_names.dart';
import '../models/stock.dart';

class LocationService {
  LocationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<StockLocation>> list() async {
    final rows = await _client
        .from(GmTables.locations)
        .select()
        .order('sort_order')
        .order('name');
    return (rows as List)
        .map((row) => StockLocation.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  String suggestCode(LocationKind kind, String name) {
    final prefix = kind == LocationKind.warehouse ? 'GUDANG' : 'DAPUR';
    final slug = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) return '$prefix-${DateTime.now().millisecondsSinceEpoch}';
    if (slug.startsWith(prefix)) return slug;
    return '$prefix-$slug';
  }

  Future<StockLocation> save({
    String? id,
    required String name,
    required LocationKind kind,
    String? code,
    int? sortOrder,
    bool isActive = true,
  }) async {
    final payload = {
      'name': name.trim(),
      'kind': kind.storageKey,
      'code': (code == null || code.trim().isEmpty)
          ? suggestCode(kind, name)
          : code.trim().toUpperCase(),
      'is_active': isActive,
      'sort_order': ?sortOrder,
    };

    if (id == null && sortOrder == null) {
      final existing = await list();
      final maxOrder = existing.fold<int>(
        0,
        (max, loc) => loc.sortOrder > max ? loc.sortOrder : max,
      );
      payload['sort_order'] = maxOrder + 1;
    }

    final row = id == null
        ? await _client
              .from(GmTables.locations)
              .insert(payload)
              .select()
              .single()
        : await _client
              .from(GmTables.locations)
              .update(payload)
              .eq('id', id)
              .select()
              .single();
    return StockLocation.fromJson(row);
  }
}
