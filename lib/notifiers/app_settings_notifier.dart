import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_appearance.dart';
import '../models/app_settings.dart';
import '../services/app_settings_service.dart';
import '../services/remote_app_settings_service.dart';

class AppSettingsNotifier extends ChangeNotifier {
  AppSettingsNotifier({
    AppSettingsService? service,
    RemoteAppSettingsService? remoteService,
  }) : _service = service ?? AppSettingsService(),
       _remoteService = remoteService ?? RemoteAppSettingsService() {
    load();
  }

  final AppSettingsService _service;
  final RemoteAppSettingsService _remoteService;

  AppSettings _settings = AppSettings.defaults;
  bool _isSaving = false;
  bool _isSyncingRemote = false;
  String? _errorMessage;

  AppSettings get settings => _settings;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _settings = await _service.load();
    notifyListeners();
  }

  Future<void> updateAppearance(AppAppearance appearance) async {
    final next = _settings.copyWith(appearance: appearance);
    await _service.save(next);
    _settings = next;
    notifyListeners();
  }

  Future<bool> save(AppSettings settings, {bool syncAccess = false}) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.save(settings);
      _settings = settings;
      if (syncAccess) {
        try {
          await _remoteService.upsertStaffPolicy(settings);
        } catch (error) {
          _errorMessage = _mapRemoteError(error);
        }
      }
      return true;
    } catch (error) {
      _errorMessage = 'Gagal menyimpan: $error';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Tarik pengaturan akses staf dari Supabase (semua perangkat).
  Future<void> syncFromRemote() async {
    if (_isSyncingRemote || !_remoteService.isAuthenticated) return;

    _isSyncingRemote = true;
    try {
      final remote = await _remoteService.fetchStaffPolicy();
      if (remote == null) return;

      final merged = _settings.copyWith(
        staffAccessMode: remote.staffAccessMode,
        staffAccessStart: remote.staffAccessStart,
        staffAccessEnd: remote.staffAccessEnd,
      );
      if (!_staffPolicyEquals(_settings, merged)) {
        await _service.save(merged);
        _settings = merged;
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Remote settings sync failed: $error');
      }
    } finally {
      _isSyncingRemote = false;
    }
  }

  bool _staffPolicyEquals(AppSettings a, AppSettings b) {
    return a.staffAccessMode == b.staffAccessMode &&
        a.staffAccessStart == b.staffAccessStart &&
        a.staffAccessEnd == b.staffAccessEnd;
  }

  String? _mapRemoteError(Object error) {
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      if (message.contains('gm_app_settings') ||
          message.contains('staff_access_mode') ||
          message.contains('schema cache')) {
        return 'Jalankan supabase/migrations/009_gm_app_settings.sql '
            'di Supabase SQL Editor, lalu coba lagi.';
      }
      return error.message;
    }
    return 'Gagal sinkron ke server — perangkat staf mungkin belum terupdate.';
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
