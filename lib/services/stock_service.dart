import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/table_names.dart';
import '../models/stock.dart';
import '../utils/qty_format.dart';

class StockService {
  StockService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<StockRow>> loadRows({
    required List<StockItem> items,
  }) async {
    final rows = await _client.from(GmTables.stockBalances).select();
    final qty = <String, Map<String, double>>{};
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      final itemId = map['item_id'] as String;
      final locationId = map['location_id'] as String;
      final value = (map['qty'] as num?)?.toDouble() ?? 0;
      qty.putIfAbsent(itemId, () => {})[locationId] = value;
    }
    return items
        .map(
          (item) => StockRow(
            item: item,
            qtyByLocation: qty[item.id] ?? const {},
          ),
        )
        .toList();
  }

  Future<List<StockMoveLine>> loadTransfers({
    required Map<String, StockLocation> locations,
    required Map<String, StockItem> items,
  }) {
    return loadMoves(
      docType: 'transfer',
      locations: locations,
      items: items,
    );
  }

  Future<List<StockMoveLine>> loadReceipts({
    required Map<String, StockLocation> locations,
    required Map<String, StockItem> items,
  }) {
    return loadMoves(
      docType: 'receipt',
      locations: locations,
      items: items,
    );
  }

  Future<List<StockMoveLine>> loadMoves({
    required String docType,
    required Map<String, StockLocation> locations,
    required Map<String, StockItem> items,
  }) async {
    Object response;
    try {
      response = await _client
          .from(GmTables.stockDocs)
          .select(
            'id, doc_date, note, from_location_id, to_location_id, created_by, '
            '${GmTables.profiles}!created_by(display_name, username), '
            '${GmTables.stockDocLines}(id, qty, item_id)',
          )
          .eq('doc_type', docType)
          .order('doc_date', ascending: false)
          .order('created_at', ascending: false);
    } on PostgrestException {
      response = await _client
          .from(GmTables.stockDocs)
          .select(
            'id, doc_date, note, from_location_id, to_location_id, '
            '${GmTables.stockDocLines}(id, qty, item_id)',
          )
          .eq('doc_type', docType)
          .order('doc_date', ascending: false)
          .order('created_at', ascending: false);
    }
    final rows = response as List;

    final result = <StockMoveLine>[];
    for (final row in rows) {
      final doc = row as Map<String, dynamic>;
      final docId = doc['id'] as String;
      final docDate = parseIsoDate(doc['doc_date']);
      final note = doc['note'] as String? ?? '';
      final createdByName = _createdByName(doc[GmTables.profiles]);
      final fromName =
          locations[doc['from_location_id'] as String?]?.name ?? '-';
      final toName = locations[doc['to_location_id'] as String?]?.name ?? '-';
      final lines = doc[GmTables.stockDocLines];
      if (lines is! List) continue;
      for (final line in lines) {
        if (line is! Map<String, dynamic>) continue;
        final item = items[line['item_id'] as String?];
        result.add(
          StockMoveLine(
            lineId: line['id'] as String? ?? '',
            docId: docId,
            docDate: docDate,
            fromLocationId: doc['from_location_id'] as String?,
            toLocationId: doc['to_location_id'] as String?,
            fromLocationName: fromName,
            toLocationName: toName,
            itemName: item?.name ?? '-',
            unit: item?.unit ?? '',
            qty: (line['qty'] as num?)?.toDouble() ?? 0,
            note: note,
            createdByName: createdByName,
          ),
        );
      }
    }
    return result;
  }

  String _createdByName(dynamic profile) {
    Map<String, dynamic>? map;
    if (profile is Map<String, dynamic>) {
      map = profile;
    } else if (profile is List && profile.isNotEmpty && profile.first is Map) {
      map = Map<String, dynamic>.from(profile.first as Map);
    }
    if (map == null) return 'Tidak diketahui';
    final name = (map['display_name'] as String?)?.trim() ?? '';
    final username = (map['username'] as String?)?.trim() ?? '';
    if (name.isNotEmpty && username.isNotEmpty) {
      return '$name (@$username)';
    }
    if (name.isNotEmpty) return name;
    if (username.isNotEmpty) return '@$username';
    return 'Tidak diketahui';
  }

  Future<void> post({
    required String docType,
    required DateTime docDate,
    String? fromLocationId,
    String? toLocationId,
    String note = '',
    required List<StockDraftLine> lines,
  }) async {
    await _client.rpc(
      GmTables.postStockDoc,
      params: {
        'p_doc_type': docType,
        'p_doc_date': dateToIso(docDate),
        'p_from_location_id': fromLocationId,
        'p_to_location_id': toLocationId,
        'p_note': note,
        'p_lines': [
          for (final line in lines)
            {'item_id': line.item.id, 'qty': line.qty},
        ],
      },
    );
  }

  Future<void> voidTransferLine(String lineId) async {
    await _client.rpc(
      GmTables.voidStockTransferLine,
      params: {'p_line_id': lineId},
    );
  }

  Future<void> voidReceiptLine(String lineId) async {
    await _client.rpc(
      GmTables.voidStockReceiptLine,
      params: {'p_line_id': lineId},
    );
  }
}
