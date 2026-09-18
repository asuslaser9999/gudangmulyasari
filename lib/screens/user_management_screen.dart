import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/auth_config.dart';
import '../models/app_user.dart';
import '../models/stock.dart';
import '../notifiers/item_notifier.dart';
import '../notifiers/location_notifier.dart';
import '../notifiers/user_management_notifier.dart';
import '../utils/table_filter_sort.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserManagementNotifier>().load();
      context.read<LocationNotifier>().load();
      context.read<ItemNotifier>().load();
    });
  }

  Future<void> _openForm({AppUser? user}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserFormSheet(user: user),
    );
    if (result == true && mounted) {
      final notifier = context.read<UserManagementNotifier>();
      if (notifier.successMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(notifier.successMessage!)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<UserManagementNotifier>();
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola User')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: notifier.isSaving ? null : () => _openForm(),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Tambah User'),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.load,
        child: notifier.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (notifier.errorMessage != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(notifier.errorMessage!),
                      ),
                    ),
                  for (final user in notifier.users)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () => _openForm(user: user),
                        leading: CircleAvatar(
                          child: Icon(
                            user.role?.code == 'owner'
                                ? Icons.admin_panel_settings_outlined
                                : Icons.person_outline,
                          ),
                        ),
                        title: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName
                              : (user.username ?? '-'),
                        ),
                        subtitle: Text(
                          '@${user.username ?? '-'} · ${user.roleLabel} · '
                          '${user.statusLabel}'
                          '${user.locationIds.isEmpty ? '' : ' · ${user.locationIds.length} lokasi'}'
                          '${user.itemIds.isEmpty ? '' : ' · ${user.itemIds.length} barang datang'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }
}

class _UserFormSheet extends StatefulWidget {
  const _UserFormSheet({this.user});

  final AppUser? user;

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _password;
  String? _roleId;
  late bool _isActive;
  late Set<String> _locationIds;
  late Set<String> _itemIds;
  bool _obscurePassword = true;
  var _didPrefillLocations = false;
  var _didPrefillItems = false;
  String _itemQuery = '';

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user?.displayName ?? '');
    _username = TextEditingController(text: widget.user?.username ?? '');
    _password = TextEditingController();
    _roleId = widget.user?.role?.id;
    _isActive = widget.user?.isActive ?? true;
    _locationIds = {...widget.user?.locationIds ?? const <String>[]};
    _itemIds = {...widget.user?.itemIds ?? const <String>[]};
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roleId == null) return;
    final notifier = context.read<UserManagementNotifier>();
    notifier.clearMessages();
    final success = _isEditing
        ? await notifier.updateUser(
            userId: widget.user!.id,
            displayName: _name.text.trim(),
            roleId: _roleId!,
            isActive: _isActive,
            locationIds: _locationIds.toList(),
            itemIds: _itemIds.toList(),
            password: _password.text,
          )
        : await notifier.createUser(
            displayName: _name.text.trim(),
            username: _username.text.trim(),
            password: _password.text,
            roleId: _roleId!,
            locationIds: _locationIds.toList(),
            itemIds: _itemIds.toList(),
          );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else if (notifier.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notifier.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<UserManagementNotifier>();
    final locations = context.watch<LocationNotifier>().activeLocations;
    final items = [...context.watch<ItemNotifier>().items]
      ..sort(compareItemOrder);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final selectedRole = notifier.roles
        .where((role) => role.id == _roleId)
        .firstOrNull;
    final isOwnerRole = selectedRole?.code == 'owner';

    if (!_isEditing && _roleId == null && notifier.roles.isNotEmpty) {
      final staff = notifier.roles.where((role) => role.code == 'staff').firstOrNull;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _roleId != null) return;
        setState(() {
          _roleId = staff?.id ?? notifier.roles.first.id;
        });
      });
    }

    if (!_isEditing &&
        !_didPrefillLocations &&
        !isOwnerRole &&
        locations.isNotEmpty &&
        _locationIds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didPrefillLocations) return;
        setState(() {
          _didPrefillLocations = true;
          _locationIds.addAll(locations.map((loc) => loc.id));
        });
      });
    }

    if (!_isEditing &&
        !_didPrefillItems &&
        !isOwnerRole &&
        items.isNotEmpty &&
        _itemIds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didPrefillItems) return;
        setState(() {
          _didPrefillItems = true;
          _itemIds.addAll(items.map((item) => item.id));
        });
      });
    }

    final visibleItems = items
        .where((item) => matchesSearch(_itemQuery, [item.name, item.unit]))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit User' : 'Tambah User Baru',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nama Tampilan'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Wajib' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                enabled: !_isEditing,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                  helperText: _isEditing
                      ? 'Username tidak bisa diubah'
                      : 'Login pakai username ini',
                ),
                validator: (value) {
                  if (_isEditing) return null;
                  if (value == null || !isValidUsername(value)) {
                    return '3–32 karakter: huruf kecil, angka, underscore';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_roleId),
                initialValue: _roleId,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final role in notifier.roles)
                    DropdownMenuItem(value: role.id, child: Text(role.name)),
                ],
                onChanged: (value) => setState(() => _roleId = value),
                validator: (value) => value == null ? 'Pilih role' : null,
              ),
              if (_isEditing)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Status Aktif'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              const SizedBox(height: 8),
              Text(
                'Stok yang bisa dilihat',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                isOwnerRole
                    ? 'Owner selalu melihat stok di semua gudang dan dapur.'
                    : 'Centang gudang/dapur yang boleh dilihat user ini. '
                        'Kosong = tidak bisa lihat stok lokasi manapun.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!isOwnerRole) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: locations.isEmpty
                        ? null
                        : () {
                            setState(() {
                              if (_locationIds.length == locations.length) {
                                _locationIds.clear();
                              } else {
                                _locationIds
                                  ..clear()
                                  ..addAll(locations.map((loc) => loc.id));
                              }
                            });
                          },
                    child: Text(
                      _locationIds.length == locations.length &&
                              locations.isNotEmpty
                          ? 'Hapus semua'
                          : 'Pilih semua',
                    ),
                  ),
                ),
                for (final location in locations)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(location.name),
                    subtitle: Text(location.kind.productionLabel),
                    value: _locationIds.contains(location.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _locationIds.add(location.id);
                        } else {
                          _locationIds.remove(location.id);
                        }
                      });
                    },
                  ),
              ],
              const SizedBox(height: 16),
              Text(
                'Barang datang yang boleh diinput',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                isOwnerRole
                    ? 'Owner selalu bisa input semua barang datang.'
                    : 'Centang barang yang boleh diinput datang. '
                        'Kosong = tidak bisa input barang datang.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!isOwnerRole) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: items.isEmpty
                        ? null
                        : () {
                            setState(() {
                              if (_itemIds.length == items.length) {
                                _itemIds.clear();
                              } else {
                                _itemIds
                                  ..clear()
                                  ..addAll(items.map((item) => item.id));
                              }
                            });
                          },
                    child: Text(
                      _itemIds.length == items.length && items.isNotEmpty
                          ? 'Hapus semua'
                          : 'Pilih semua',
                    ),
                  ),
                ),
                TextField(
                  onChanged: (value) => setState(() => _itemQuery = value),
                  decoration: const InputDecoration(
                    labelText: 'Cari barang',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                for (final item in visibleItems)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text('Satuan ${item.unit}'),
                    value: _itemIds.contains(item.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _itemIds.add(item.id);
                        } else {
                          _itemIds.remove(item.id);
                        }
                      });
                    },
                  ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: _isEditing
                      ? 'Password Baru (opsional)'
                      : 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (!_isEditing && (value == null || value.isEmpty)) {
                    return 'Password wajib';
                  }
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return 'Minimal 6 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: notifier.isSaving ? null : _submit,
                child: Text(_isEditing ? 'Simpan Perubahan' : 'Tambah User'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
