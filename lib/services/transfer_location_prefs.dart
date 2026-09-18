import 'package:shared_preferences/shared_preferences.dart';

/// Pilihan gudang/dapur terakhir di menu pengambilan — per perangkat saja.
class TransferLocationPrefs {
  TransferLocationPrefs({this._prefs});

  static const _fromKey = 'gm_last_transfer_from_location_id';
  static const _toKey = 'gm_last_transfer_to_location_id';

  final SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ?? SharedPreferences.getInstance();
  }

  Future<({String? fromId, String? toId})> load() async {
    final prefs = await _instance();
    return (
      fromId: prefs.getString(_fromKey),
      toId: prefs.getString(_toKey),
    );
  }

  Future<void> save({
    required String fromLocationId,
    required String toLocationId,
  }) async {
    final prefs = await _instance();
    await prefs.setString(_fromKey, fromLocationId);
    await prefs.setString(_toKey, toLocationId);
  }
}
