import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/permission_codes.dart';
import '../models/app_user.dart';
import '../models/stock.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthNotifier extends ChangeNotifier {
  AuthNotifier({AuthService? authService})
    : _authService = authService ?? AuthService() {
    _init();
  }

  final AuthService _authService;

  AuthStatus _status = AuthStatus.initial;
  AppUser? _user;
  final Set<String> _permissions = {};
  final Set<String> _locationIds = {};
  final Set<String> _itemIds = {};
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isOwner => _user?.role?.code == 'owner';
  String get roleLabel => _user?.role?.name ?? 'User';

  bool hasPermission(String code) {
    if (isOwner) return true;
    return _permissions.contains(code);
  }

  bool get canManageUsers => hasPermission(PermissionCodes.usersManage);
  bool get canManageRoles => hasPermission(PermissionCodes.rolesManage);
  bool get canViewStock => hasPermission(PermissionCodes.stockView);
  bool get canReceipt => hasPermission(PermissionCodes.stockReceipt);
  bool get canTransfer => hasPermission(PermissionCodes.stockTransfer);
  bool get canDeleteTransfer =>
      hasPermission(PermissionCodes.stockTransferDelete);
  bool get canManageItems =>
      hasPermission(PermissionCodes.itemsManage) ||
      hasPermission(PermissionCodes.masterManage);
  bool get canManageLocations =>
      hasPermission(PermissionCodes.locationsManage) ||
      hasPermission(PermissionCodes.masterManage);
  bool get canManageMaster => canManageItems || canManageLocations;

  bool canSeeLocation(String locationId) {
    if (isOwner) return true;
    if (_user?.hasLocationScope != true) return true;
    return _locationIds.contains(locationId);
  }

  List<StockLocation> visibleLocations(List<StockLocation> all) {
    if (isOwner || _user?.hasLocationScope != true) return all;
    return all.where((loc) => _locationIds.contains(loc.id)).toList();
  }

  bool canReceiptItem(String itemId) {
    if (isOwner) return true;
    if (_user?.hasItemScope != true) return true;
    return _itemIds.contains(itemId);
  }

  List<StockItem> receiptItems(List<StockItem> all) {
    if (isOwner || _user?.hasItemScope != true) return all;
    return all.where((item) => _itemIds.contains(item.id)).toList();
  }

  Future<void> _init() async {
    try {
      if (_authService.isAuthenticated) {
        final loaded = await _loadAccess();
        if (!loaded) {
          await _authService.signOut();
          _status = AuthStatus.unauthenticated;
        } else {
          _status = AuthStatus.authenticated;
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Auth init error: $e');
      try {
        await _authService.signOut();
      } catch (_) {}
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }

    _authService.authStateChanges.listen((data) async {
      try {
        if (data.session != null) {
          final loaded = await _loadAccess();
          _status = loaded
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated;
          if (!loaded) await _authService.signOut();
        } else {
          _clearUser();
          _status = AuthStatus.unauthenticated;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Auth state change error: $e');
        _clearUser();
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    });
  }

  Future<bool> _loadAccess() async {
    final user = await _authService.getCurrentAppUser();
    if (user == null || !user.isActive) {
      _clearUser();
      return false;
    }
    _user = user;
    _locationIds
      ..clear()
      ..addAll(user.locationIds);
    _itemIds
      ..clear()
      ..addAll(user.itemIds);
    if (user.role != null) {
      _permissions
        ..clear()
        ..addAll(await _authService.getCurrentPermissions(user.role!.id));
    }
    return true;
  }

  void _clearUser() {
    _user = null;
    _permissions.clear();
    _locationIds.clear();
    _itemIds.clear();
  }

  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signIn(username: username, password: password);
      final loaded = await _loadAccess();
      if (!loaded) {
        _errorMessage =
            'Akun belum didaftarkan di Gudang Mulyasari. Hubungi owner.';
        _status = AuthStatus.unauthenticated;
        return false;
      }
      _status = AuthStatus.authenticated;
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Gagal login. Periksa koneksi Anda.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _clearUser();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
