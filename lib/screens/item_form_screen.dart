import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../notifiers/item_notifier.dart';

class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({super.key, this.item});

  final StockItem? item;

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _unit = TextEditingController(text: widget.item?.unit ?? 'pcs');
    _isActive = widget.item?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<ItemNotifier>().save(
      id: widget.item?.id,
      name: _name.text,
      unit: _unit.text,
      isActive: _isActive,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      final error = context.read<ItemNotifier>().errorMessage;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? 'Gagal menyimpan.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Tambah Barang' : 'Ubah Barang'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama barang'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unit,
              decoration: const InputDecoration(
                labelText: 'Satuan',
                hintText: 'pcs, kg, pack, ...',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Satuan wajib diisi';
                }
                return null;
              },
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
