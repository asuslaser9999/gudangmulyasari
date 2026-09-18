import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../notifiers/location_notifier.dart';

class LocationFormScreen extends StatefulWidget {
  const LocationFormScreen({super.key, this.location});

  final StockLocation? location;

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late LocationKind _kind;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.location?.name ?? '');
    _kind = widget.location?.kind ?? LocationKind.warehouse;
    _isActive = widget.location?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<LocationNotifier>().save(
      id: widget.location?.id,
      name: _name.text,
      kind: _kind,
      isActive: _isActive,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      final error = context.read<LocationNotifier>().errorMessage;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? 'Gagal menyimpan.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location == null ? 'Tambah Lokasi' : 'Ubah Lokasi'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nama',
                hintText: 'Gudang 3, Dapur pastry, ...',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LocationKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Jenis'),
              items: [
                for (final kind in LocationKind.values)
                  DropdownMenuItem(
                    value: kind,
                    child: Text(kind.productionLabel),
                  ),
              ],
              onChanged: widget.location == null
                  ? (value) {
                      if (value != null) setState(() => _kind = value);
                    }
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktif'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Simpan')),
          ],
        ),
      ),
    );
  }
}
