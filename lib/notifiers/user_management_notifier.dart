import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/user_management_service.dart';

class UserManagementNotifier extends ChangeNotifier {
  UserManagementNotifier({UserManagementService? service})
    : _service = service ?? UserManagementService();

  final UserManagementService _service;

  List<AppUser> users = [];
  List<AppRole> roles = [];
  List<AppPermission> permissions = [];
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  String? successMessage;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      roles = await _service.listRoles();
      permissions = await _service.listPermissions();
      users = await _service.listUsers();
    } catch (_) {
      errorMessage = 'Gagal memuat data user.';
      users = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUser({
    required String displayName,
    required String username,
    required String password,
    required String roleId,
    required List<String> locationIds,
    required List<String> itemIds,
  }) async {
    isSaving = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();
    try {
      await _service.createUser(
        displayName: displayName,
        username: username,
        password: password,
        roleId: roleId,
        locationIds: locationIds,
        itemIds: itemIds,
      );
      successMessage = 'User berhasil ditambahkan.';
      await load();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateUser({
    required String userId,
    required String displayName,
    required String roleId,
    required bool isActive,
    required List<String> locationIds,
    required List<String> itemIds,
    String? password,
  }) async {
    isSaving = true;
    errorMessage = null;
    successMessage = null;
    notifyListeners();
    try {
      await _service.updateUser(
        userId: userId,
        displayName: displayName,
        roleId: roleId,
        isActive: isActive,
        password: password,
        locationIds: locationIds,
        itemIds: itemIds,
      );
      successMessage = 'User berhasil diperbarui.';
      await load();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<Set<String>> permissionIdsForRole(String roleId) {
    return _service.permissionIdsForRole(roleId);
  }

  Future<bool> saveRolePermissions({
    required String roleId,
    required Iterable<String> permissionIds,
  }) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _service.setRolePermissions(
        roleId: roleId,
        permissionIds: permissionIds,
      );
      successMessage = 'Hak akses role disimpan.';
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }
}
