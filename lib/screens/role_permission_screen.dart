import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/permission_codes.dart';
import '../models/app_user.dart';
import '../notifiers/user_management_notifier.dart';

class RolePermissionScreen extends StatefulWidget {
  const RolePermissionScreen({super.key});

  @override
  State<RolePermissionScreen> createState() => _RolePermissionScreenState();
}

class _RolePermissionScreenState extends State<RolePermissionScreen> {
  static const _paramOrder = [
    PermissionCodes.stockView,
    PermissionCodes.stockReceipt,
    PermissionCodes.stockTransfer,
    PermissionCodes.stockTransferDelete,
    PermissionCodes.itemsManage,
    PermissionCodes.locationsManage,
    PermissionCodes.usersManage,
    PermissionCodes.rolesManage,
  ];

  static const _labels = {
    PermissionCodes.stockView: 'Lihat stok',
    PermissionCodes.stockReceipt: 'Input barang datang',
    PermissionCodes.stockTransfer: 'Pengambilan barang',
    PermissionCodes.stockTransferDelete: 'Hapus pengambilan',
    PermissionCodes.itemsManage: 'Tambah barang baru',
    PermissionCodes.locationsManage: 'Tambah gudang/dapur baru',
    PermissionCodes.usersManage: 'Kelola user',
    PermissionCodes.rolesManage: 'Ubah hak akses role',
  };

  static const _hints = {
    PermissionCodes.stockView:
        'Buka menu Cek stok. Kolom lokasi tetap mengikuti lokasi yang diizinkan per user.',
    PermissionCodes.stockReceipt: 'Bisa menyimpan barang datang.',
    PermissionCodes.stockTransfer: 'Bisa input pengambilan gudang ke dapur.',
    PermissionCodes.stockTransferDelete:
        'Bisa menghapus riwayat pengambilan dan mengembalikan stok.',
    PermissionCodes.itemsManage: 'Bisa menambah dan mengubah master barang.',
    PermissionCodes.locationsManage: 'Bisa menambah gudang atau dapur baru.',
    PermissionCodes.usersManage: 'Bisa menambah/ubah akun Gudang Mulyasari.',
    PermissionCodes.rolesManage: 'Bisa mengubah centang hak akses role.',
  };

  String? _roleId;
  Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = context.read<UserManagementNotifier>();
      await notifier.load();
      if (!mounted || notifier.roles.isEmpty) return;
      final staff = notifier.roles.where((r) => r.code == 'staff').firstOrNull;
      await _selectRole(staff?.id ?? notifier.roles.first.id);
    });
  }

  Future<void> _selectRole(String roleId) async {
    final ids = await context
        .read<UserManagementNotifier>()
        .permissionIdsForRole(roleId);
    if (!mounted) return;
    setState(() {
      _roleId = roleId;
      _selected = {...ids};
    });
  }

  List<AppPermission> _ordered(List<AppPermission> all) {
    final byCode = {for (final p in all) p.code: p};
    final result = <AppPermission>[];
    for (final code in _paramOrder) {
      final permission = byCode.remove(code);
      if (permission != null) result.add(permission);
    }
    for (final leftover in byCode.values) {
      if (leftover.code == PermissionCodes.masterManage) continue;
      result.add(leftover);
    }
    return result;
  }

  Iterable<String> _idsToSave(UserManagementNotifier notifier) {
    final hasGranular = notifier.permissions.any(
      (p) => p.code == PermissionCodes.itemsManage,
    );
    return _selected.where((id) {
      final permission = notifier.permissions
          .where((item) => item.id == id)
          .firstOrNull;
      if (permission == null) return true;
      if (permission.code == PermissionCodes.masterManage) {
        return !hasGranular;
      }
      return true;
    });
  }

  Future<void> _save() async {
    if (_roleId == null) return;
    final notifier = context.read<UserManagementNotifier>();
    final role = notifier.roles.where((r) => r.id == _roleId).firstOrNull;
    if (role?.code == 'owner') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role owner selalu punya semua hak.')),
      );
      return;
    }
    final ok = await notifier.saveRolePermissions(
      roleId: _roleId!,
      permissionIds: _idsToSave(notifier),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Hak akses disimpan.'
              : (notifier.errorMessage ?? 'Gagal menyimpan'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<UserManagementNotifier>();
    final role = notifier.roles.where((r) => r.id == _roleId).firstOrNull;
    final locked = role?.code == 'owner';
    final permissions = _ordered(notifier.permissions);

    return Scaffold(
      appBar: AppBar(title: const Text('Hak Akses Role')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(_roleId),
            initialValue: _roleId,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [
              for (final item in notifier.roles)
                DropdownMenuItem(value: item.id, child: Text(item.name)),
            ],
            onChanged: (value) {
              if (value != null) _selectRole(value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Lokasi stok yang terlihat diatur per user di Kelola User. '
            'Centang di bawah adalah kemampuan role.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!notifier.permissions.any(
            (p) => p.code == PermissionCodes.itemsManage,
          ))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Jalankan supabase/migrations/004_gm_roles_access.sql '
                'di Supabase SQL Editor supaya parameter role lengkap.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          for (final permission in permissions)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_labels[permission.code] ?? permission.name),
              subtitle: Text(_hints[permission.code] ?? permission.code),
              value: locked || _selected.contains(permission.id),
              onChanged: locked
                  ? null
                  : (value) {
                      setState(() {
                        if (value == true) {
                          _selected.add(permission.id);
                        } else {
                          _selected.remove(permission.id);
                        }
                      });
                    },
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: notifier.isSaving ? null : _save,
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
