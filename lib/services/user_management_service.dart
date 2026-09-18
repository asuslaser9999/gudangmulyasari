import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/table_names.dart';
import '../models/app_user.dart';

class UserManagementService {
  UserManagementService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AppRole>> listRoles() async {
    final rows = await _client.from(GmTables.roles).select('*').order('name');
    return (rows as List)
        .map((row) => AppRole.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AppPermission>> listPermissions() async {
    final rows = await _client
        .from(GmTables.permissions)
        .select('*')
        .order('name');
    return (rows as List)
        .map((row) => AppPermission.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Set<String>> permissionIdsForRole(String roleId) async {
    final rows = await _client
        .from(GmTables.rolePermissions)
        .select('permission_id')
        .eq('role_id', roleId);
    return {
      for (final row in rows as List)
        (row as Map)['permission_id'] as String,
    };
  }

  Future<void> setRolePermissions({
    required String roleId,
    required Iterable<String> permissionIds,
  }) async {
    await _client.from(GmTables.rolePermissions).delete().eq('role_id', roleId);
    if (permissionIds.isEmpty) return;
    await _client.from(GmTables.rolePermissions).insert([
      for (final id in permissionIds) {'role_id': roleId, 'permission_id': id},
    ]);
  }

  Future<List<AppUser>> listUsers() async {
    try {
      final response = await _client
          .from(GmTables.profiles)
          .select(
            '*, gm_roles(id, code, name, is_system), '
            '${GmTables.userLocationAccess}(location_id), '
            '${GmTables.userItemAccess}(item_id)',
          )
          .order('created_at');
      return (response as List)
          .map((row) => AppUser.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException {
      try {
        final response = await _client
            .from(GmTables.profiles)
            .select(
              '*, gm_roles(id, code, name, is_system), '
              '${GmTables.userLocationAccess}(location_id)',
            )
            .order('created_at');
        return (response as List)
            .map((row) => AppUser.fromJson(row as Map<String, dynamic>))
            .toList();
      } on PostgrestException {
        final response = await _client
            .from(GmTables.profiles)
            .select('*, gm_roles(id, code, name, is_system)')
            .order('created_at');
        return (response as List)
            .map((row) => AppUser.fromJson(row as Map<String, dynamic>))
            .toList();
      }
    }
  }

  Future<void> createUser({
    required String displayName,
    required String username,
    required String password,
    required String roleId,
    required List<String> locationIds,
    required List<String> itemIds,
  }) async {
    try {
      await _client.rpc(
        GmTables.adminCreateUser,
        params: {
          'p_display_name': displayName,
          'p_username': username.trim().toLowerCase(),
          'p_password': password,
          'p_role_id': roleId,
          'p_location_ids': locationIds,
          'p_item_ids': itemIds,
        },
      );
    } on PostgrestException catch (e) {
      throw _mapAdminError(e);
    }
  }

  Future<void> updateUser({
    required String userId,
    String? displayName,
    String? roleId,
    bool? isActive,
    String? password,
    List<String>? locationIds,
    List<String>? itemIds,
  }) async {
    try {
      await _client.rpc(
        GmTables.adminUpdateUser,
        params: {
          'p_user_id': userId,
          'p_display_name': displayName,
          'p_role_id': roleId,
          'p_is_active': isActive,
          'p_password': (password == null || password.isEmpty) ? null : password,
          'p_location_ids': locationIds,
          'p_item_ids': itemIds,
        },
      );
    } on PostgrestException catch (e) {
      throw _mapAdminError(e);
    }
  }

  String _mapAdminError(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('p_item_ids') ||
        message.contains('gm_user_item_access') ||
        message.contains('gm_can_receipt_item')) {
      return 'Jalankan supabase/migrations/007_gm_receipt_item_access.sql '
          'di Supabase SQL Editor, lalu coba lagi.';
    }
    if (message.contains('schema cache') ||
        message.contains('could not find the function') ||
        message.contains('function public.gm_admin_')) {
      return 'Jalankan supabase/migrations/005_gm_admin_users.sql '
          'lalu 007_gm_receipt_item_access.sql di Supabase SQL Editor.';
    }
    if (message.contains('duplicate') || message.contains('unique')) {
      return 'Username sudah digunakan.';
    }
    return error.message;
  }
}
