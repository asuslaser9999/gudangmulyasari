import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/auth_config.dart';
import '../config/table_names.dart';
import '../models/app_user.dart';

class AuthService {
  AuthService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  bool get isAuthenticated => currentUser != null;

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      return await _client
          .from(GmTables.profiles)
          .select(
            '*, gm_roles(id, code, name, is_system), '
            '${GmTables.userLocationAccess}(location_id), '
            '${GmTables.userItemAccess}(item_id)',
          )
          .eq('id', user.id)
          .maybeSingle();
    } on PostgrestException {
      try {
        return await _client
            .from(GmTables.profiles)
            .select(
              '*, gm_roles(id, code, name, is_system), '
              '${GmTables.userLocationAccess}(location_id)',
            )
            .eq('id', user.id)
            .maybeSingle();
      } on PostgrestException {
        return _client
            .from(GmTables.profiles)
            .select('*, gm_roles(id, code, name, is_system)')
            .eq('id', user.id)
            .maybeSingle();
      }
    }
  }

  Future<AppUser?> getCurrentAppUser() async {
    final json = await getCurrentProfile();
    if (json == null) return null;
    return AppUser.fromJson(json);
  }

  Future<Set<String>> getCurrentPermissions(String roleId) async {
    final rows = await _client
        .from(GmTables.rolePermissions)
        .select('gm_permissions(code)')
        .eq('role_id', roleId);

    final codes = <String>{};
    for (final row in rows as List) {
      final perm = (row as Map)['gm_permissions'];
      if (perm is Map && perm['code'] is String) {
        codes.add(perm['code'] as String);
      }
    }
    return codes;
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    final loginEmail = await _resolveLoginEmail(username);
    AuthException? lastError;

    for (final email in _loginEmailCandidates(username, loginEmail)) {
      try {
        await _client.auth.signInWithPassword(email: email, password: password);

        final profile = await getCurrentProfile();
        if (profile == null) {
          await signOut();
          throw AuthException(
            'Akun belum didaftarkan di Gudang Mulyasari. Hubungi owner.',
          );
        }
        if ((profile['is_active'] as bool? ?? true) == false) {
          await signOut();
          throw AuthException('Akun nonaktif. Hubungi owner.');
        }
        return;
      } on AuthException catch (e) {
        lastError = e;
      }
    }

    throw AuthException(_mapLoginError(lastError?.message));
  }

  Future<String> _resolveLoginEmail(String input) async {
    final trimmed = input.trim();
    if (trimmed.contains('@')) return trimmed.toLowerCase();

    try {
      final result = await _client.rpc(
        GmTables.resolveLoginEmail,
        params: {'p_username': trimmed},
      );
      if (result != null && result.toString().trim().isNotEmpty) {
        return result.toString().trim().toLowerCase();
      }
    } catch (_) {}

    return usernameToInternalEmail(trimmed);
  }

  List<String> _loginEmailCandidates(String input, String primaryEmail) {
    final trimmed = input.trim().toLowerCase();
    final candidates = <String>{primaryEmail.toLowerCase()};
    if (trimmed.contains('@')) {
      candidates.add(trimmed);
    } else {
      candidates.add(usernameToInternalEmail(trimmed));
    }
    return candidates.toList();
  }

  String _mapLoginError(String? message) {
    final lower = (message ?? '').toLowerCase();
    if (lower.contains('banned') || lower.contains('ban')) {
      return 'Akun diblokir/nonaktif. Hubungi owner atau cek di Supabase.';
    }
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return 'Username/email atau password salah.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Akun belum dikonfirmasi. Hubungi owner.';
    }
    return message ?? 'Gagal login.';
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
