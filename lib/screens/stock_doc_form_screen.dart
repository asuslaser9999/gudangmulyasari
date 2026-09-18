import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/stock_notifier.dart';
import '../services/transfer_location_prefs.dart';
import '../utils/qty_format.dart';
import '../utils/table_filter_sort.dart';

class StockDocFormScreen extends StatefulWidget {
  const StockDocFormScreen({super.key, required this.docType});

  final String docType;

  @override
  State<StockDocFormScreen> createState() => _StockDocFormScreenState();
}

class _StockDocFormScreenState extends State<StockDocFormScreen> {
  final _note = TextEditingController();
  final _lines = <StockDraftLine>[];
  final _locationPrefs = TransferLocationPrefs();
  DateTime _docDate = DateTime.now();
  String? _fromId;
  String? _toId;
  String? _savedFromId;
  String? _savedToId;
  bool _didInitLocations = false;
  late bool _prefsReady;

  bool get _isReceipt => widget.docType == 'receipt';

  @override
  void initState() {
    super.initState();
    _prefsReady = _isReceipt;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isReceipt) {
        final saved = await _locationPrefs.load();
        if (!mounted) return;
        _savedFromId = saved.fromId;
        _savedToId = saved.toId;
        _prefsReady = true;
        setState(() {});
      }
      if (!mounted) return;
      await context.read<StockNotifier>().load();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String? _preferredId(List<StockLocation> locations, String? savedId) {
    if (savedId != null && locations.any((loc) => loc.id == savedId)) {
      return savedId;
    }
    return locations.firstOrNull?.id;
  }

  void _syncDefaultLocations(StockNotifier stock) {
    if (!_prefsReady || _didInitLocations || stock.locations.isEmpty) return;
    final auth = context.read<AuthNotifier>();
    final warehouses = auth.visibleLocations(stock.warehouses);
    final kitchens = auth.visibleLocations(stock.kitchens);
    final locations = auth.visibleLocations(stock.locations);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didInitLocations || locations.isEmpty) return;
      setState(() {
        _fromId ??= _preferredId(warehouses, _savedFromId);
        _toId ??= _isReceipt
            ? (warehouses.firstOrNull?.id ?? locations.firstOrNull?.id)
            : _preferredId(kitchens, _savedToId);
        _didInitLocations = true;
      });
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _docDate = picked);
  }

  Future<void> _addLine(StockNotifier stock) async {
    final items = stock.activeItems;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambah barang di Master Barang dulu.')),
      );
      return;
    }

    StockItem? selected = items.first;
    final qty = TextEditingController(text: '1');
    var query = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final filtered = items
                .where((item) => matchesSearch(query, [item.name, item.unit]))
                .toList();
            return AlertDialog(
              title: const Text('Tambah barang'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (value) => setModal(() => query = value),
                      decoration: const InputDecoration(
                        labelText: 'Cari barang',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Tidak ada barang yang cocok.'),
                      )
                    else
                      DropdownButtonFormField<StockItem>(
                        initialValue: filtered.contains(selected)
                            ? selected
                            : filtered.first,
                        decoration: const InputDecoration(labelText: 'Barang'),
                        items: [
                          for (final item in filtered)
                            DropdownMenuItem(
                              value: item,
                              child: Text('${item.name} (${item.unit})'),
                            ),
                        ],
                        onChanged: (value) => setModal(() => selected = value),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qty,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Qty'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Tambah'),
                ),
              ],
            );
          },
        );
      },
    );

    final parsed = parseQty(qty.text);
    if (ok == true && selected != null && parsed != null && parsed > 0) {
      setState(() {
        _lines.add(StockDraftLine(item: selected!, qty: parsed));
      });
    }
  }

  Future<void> _submit(StockNotifier stock) async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambah minimal 1 barang.')),
      );
      return;
    }
    if (_isReceipt && _toId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih lokasi tujuan.')),
      );
      return;
    }
    if (!_isReceipt && (_fromId == null || _toId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih gudang asal dan dapur tujuan.'),
        ),
      );
      return;
    }

    final ok = await stock.post(
      docType: widget.docType,
      docDate: _docDate,
      fromLocationId: _isReceipt ? null : _fromId,
      toLocationId: _toId,
      note: _note.text,
      lines: _lines,
    );
    if (!mounted) return;
    if (ok) {
      if (!_isReceipt && _fromId != null && _toId != null) {
        await _locationPrefs.save(
          fromLocationId: _fromId!,
          toLocationId: _toId!,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isReceipt ? 'Barang datang disimpan.' : 'Pengambilan disimpan.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(stock.errorMessage ?? 'Gagal menyimpan.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = context.watch<StockNotifier>();
    final auth = context.watch<AuthNotifier>();
    _syncDefaultLocations(stock);
    final dateLabel = DateFormat('d MMMM yyyy', 'id_ID').format(_docDate);
    final locations = auth.visibleLocations(stock.locations);
    final warehouses = auth.visibleLocations(stock.warehouses);
    final kitchens = auth.visibleLocations(stock.kitchens);
    final toChoices = _isReceipt ? locations : kitchens;
    final fromValue = warehouses.any((loc) => loc.id == _fromId)
        ? _fromId
        : null;
    final toValue = toChoices.any((loc) => loc.id == _toId) ? _toId : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isReceipt ? 'Barang Datang' : 'Pengambilan'),
      ),
      body: stock.isLoading && stock.locations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tanggal'),
                  subtitle: Text(dateLabel),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickDate,
                ),
                if (_isReceipt)
                  DropdownButtonFormField<String>(
                    initialValue: toValue,
                    decoration: const InputDecoration(
                      labelText: 'Masuk ke lokasi',
                    ),
                    items: [
                      for (final loc in locations)
                        DropdownMenuItem(
                          value: loc.id,
                          child: Text(
                            '${loc.name} · ${loc.kind.productionLabel}',
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() => _toId = value),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('from-$fromValue'),
                    initialValue: fromValue,
                    decoration: const InputDecoration(
                      labelText: 'Dari gudang',
                    ),
                    items: [
                      for (final loc in warehouses)
                        DropdownMenuItem(value: loc.id, child: Text(loc.name)),
                    ],
                    onChanged: (value) => setState(() => _fromId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('to-$toValue'),
                    initialValue: toValue,
                    decoration: const InputDecoration(
                      labelText: 'Ke dapur (produksi)',
                    ),
                    items: [
                      for (final loc in kitchens)
                        DropdownMenuItem(value: loc.id, child: Text(loc.name)),
                    ],
                    onChanged: (value) => setState(() => _toId = value),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Barang',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _addLine(stock),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah'),
                    ),
                  ],
                ),
                if (_lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Belum ada baris barang.')),
                  )
                else
                  for (var i = 0; i < _lines.length; i++)
                    Card(
                      child: ListTile(
                        title: Text(_lines[i].item.name),
                        subtitle: Text(
                          '${formatQty(_lines[i].qty)} ${_lines[i].item.unit}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => _lines.removeAt(i)),
                        ),
                      ),
                    ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: stock.isSaving ? null : () => _submit(stock),
                  child: stock.isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            ),
    );
  }
}
