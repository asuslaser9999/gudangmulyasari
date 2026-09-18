import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/table_names.dart';
import '../models/app_settings.dart';
import '../models/staff_access_mode.dart';

/// Pengaturan akses staf yang disinkronkan ke Supabase (semua perangkat).
class RemoteAppSettingsService {
  RemoteAppSettingsService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _singletonId = 'default';

  bool get isAuthenticated => _client.auth.currentSession != null;

  Future<AppSettings?> fetchStaffPolicy() async {
    if (!isAuthenticated) return null;

    final response = await _client
        .from(GmTables.appSettings)
        .select('staff_access_mode, staff_access_start, staff_access_end')
        .eq('id', _singletonId)
        .maybeSingle();

    if (response == null) return null;

    return AppSettings(
      staffAccessMode: StaffAccessMode.fromStorageKey(
        response['staff_access_mode'] as String?,
      ),
      staffAccessStart: response['staff_access_start'] as String? ?? '05:30',
      staffAccessEnd: response['staff_access_end'] as String? ?? '16:30',
    );
  }

  Future<void> upsertStaffPolicy(AppSettings settings) async {
    if (!isAuthenticated) return;

    final userId = _client.auth.currentUser?.id;
    final payload = <String, dynamic>{
      'id': _singletonId,
      'staff_access_mode': settings.staffAccessMode.storageKey,
      'staff_access_start': settings.staffAccessStart,
      'staff_access_end': settings.staffAccessEnd,
    };
    if (userId != null) {
      payload['updated_by'] = userId;
    }

    await _client.from(GmTables.appSettings).upsert(payload);
  }
}
