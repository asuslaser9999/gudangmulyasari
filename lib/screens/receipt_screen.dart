import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/stock_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/qty_format.dart';
import '../utils/table_filter_sort.dart';
import '../widgets/table_filter_sort_bar.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _note = TextEditingController();
  final _qtyCtrls = <String, TextEditingController>{};
  final _ordered = <StockItem>[];
  DateTime _docDate = DateTime.now();
  String? _toId;
  String _searchQuery = '';
  var _didInit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<StockNotifier>().load();
      if (!mounted) return;
      _syncItems(context.read<StockNotifier>());
    });
  }

  @override
  void dispose() {
    _note.dispose();
    for (final ctrl in _qtyCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _syncItems(StockNotifier stock) {
    final allowed = context.read<AuthNotifier>().receiptItems(stock.activeItems)
      ..sort(compareItemOrder);
    final ids = allowed.map((item) => item.id).toSet();
    for (final id in _qtyCtrls.keys.toList()) {
      if (!ids.contains(id)) {
        _qtyCtrls.remove(id)?.dispose();
      }
    }
    for (final item in allowed) {
      _qtyCtrls.putIfAbsent(item.id, TextEditingController.new);
    }
    final visible = context.read<AuthNotifier>().visibleLocations(
      stock.locations,
    );
    setState(() {
      _ordered
        ..clear()
        ..addAll(allowed);
      if (_toId == null || !visible.any((loc) => loc.id == _toId)) {
        _toId = visible.firstOrNull?.id;
      }
      _didInit = true;
    });
  }

  List<StockItem> get _visible {
    return _ordered
        .where((item) => matchesSearch(_searchQuery, [item.name, item.unit]))
        .toList();
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

  void _onReorder(int oldIndex, int newIndex) {
    if (_searchQuery.trim().isNotEmpty) return;
    setState(() {
      final item = _ordered.removeAt(oldIndex);
      _ordered.insert(newIndex, item);
    });
  }

  Future<void> _submit(StockNotifier stock) async {
    final auth = context.read<AuthNotifier>();
    if (_toId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih lokasi tujuan.')),
      );
      return;
    }

    final lines = <StockDraftLine>[];
    for (final item in _ordered) {
      final qty = parseQty(_qtyCtrls[item.id]?.text ?? '') ?? 0;
      if (qty > 0) {
        lines.add(StockDraftLine(item: item, qty: qty));
      }
    }

    final canSaveOrder =
        auth.canManageItems && _ordered.length == stock.activeItems.length;
    final orderOk = canSaveOrder
        ? await stock.saveItemOrder(
            _ordered.map((item) => item.id).toList(),
          )
        : true;
    if (!mounted) return;
    if (!orderOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(stock.errorMessage ?? 'Gagal simpan urutan.')),
      );
      return;
    }

    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.canManageItems &&
                    _ordered.length == stock.activeItems.length
                ? 'Urutan barang disimpan.'
                : 'Isi qty datang dulu.',
          ),
        ),
      );
      return;
    }

    final ok = await stock.post(
      docType: 'receipt',
      docDate: _docDate,
      toLocationId: _toId,
      note: _note.text,
      lines: lines,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barang datang disimpan.')),
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
    if (_didInit && !stock.isLoading) {
      final allowed = auth.receiptItems(stock.activeItems);
      if (allowed.length != _ordered.length ||
          !_ordered.every((item) => allowed.any((next) => next.id == item.id))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _syncItems(stock);
        });
      }
    }

    final scheme = Theme.of(context).colorScheme;
    final dateLabel = DateFormat('d MMMM yyyy', 'id_ID').format(_docDate);
    final locations = auth.visibleLocations(stock.locations);
    final toValue = locations.any((loc) => loc.id == _toId) ? _toId : null;
    final canReorder =
        auth.canManageItems && _ordered.length == stock.activeItems.length;
    final visible = _visible;
    final searching = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Barang Datang')),
      body: stock.isLoading && !_didInit
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tanggal'),
                        subtitle: Text(dateLabel),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: _pickDate,
                      ),
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
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _note,
                        decoration: const InputDecoration(
                          labelText: 'Catatan (opsional)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TableFilterSortBar(
                  searchQuery: _searchQuery,
                  onSearchChanged: (value) =>
                      setState(() => _searchQuery = value),
                  searchHint: 'Cari barang...',
                  sortLabel: 'Urutan tersimpan',
                  onSortTap: () {},
                  showSort: false,
                  resultCount: visible.length,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    !canReorder
                        ? 'Hanya barang yang diizinkan untuk user ini.'
                        : searching
                            ? 'Kosongkan pencarian untuk mengubah urutan.'
                            : 'Tahan ikon garis lalu geser untuk mengubah urutan.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: _ordered.isEmpty
                      ? Center(
                          child: Text(
                            stock.activeItems.isEmpty
                                ? 'Belum ada barang aktif. Tambah di Master Barang.'
                                : 'Tidak ada barang yang diizinkan untuk input datang.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Column(
                          children: [
                            Container(
                              color: context.palette.tableHeaderBg,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 36),
                                  const Expanded(
                                    child: Text(
                                      'Barang',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 56,
                                    child: Text(
                                      'Satuan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 88,
                                    child: Text(
                                      'Qty datang',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ReorderableListView.builder(
                                buildDefaultDragHandles: false,
                                padding: const EdgeInsets.only(bottom: 88),
                                itemCount: visible.length,
                                onReorderItem: searching || !canReorder
                                    ? (oldIndex, newIndex) {}
                                    : _onReorder,
                                itemBuilder: (context, index) {
                                  final item = visible[index];
                                  return Material(
                                    key: ValueKey(item.id),
                                    color: scheme.surface,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: scheme.outlineVariant,
                                          ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          if (searching || !canReorder)
                                            const SizedBox(width: 36)
                                          else
                                            ReorderableDragStartListener(
                                              index: index,
                                              child: const Padding(
                                                padding: EdgeInsets.all(8),
                                                child: Icon(Icons.drag_handle),
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 56,
                                            child: Text(
                                              item.unit,
                                              style: TextStyle(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 88,
                                            child: TextField(
                                              controller: _qtyCtrls[item.id],
                                              textAlign: TextAlign.end,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r'[0-9.,]'),
                                                ),
                                              ],
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                hintText: '0',
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: stock.isSaving ? null : () => _submit(stock),
                        child: stock.isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Simpan'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
