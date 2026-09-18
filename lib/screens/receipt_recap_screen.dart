import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/stock_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/qty_format.dart';
import '../widgets/table_filter_sort_bar.dart';

class ReceiptRecapScreen extends StatefulWidget {
  const ReceiptRecapScreen({super.key});

  @override
  State<ReceiptRecapScreen> createState() => _ReceiptRecapScreenState();
}

class _ReceiptRecapScreenState extends State<ReceiptRecapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockNotifier>().load();
    });
  }

  Future<void> _delete(StockMoveLine line) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus barang datang?'),
        content: Text(
          '${line.itemName} ${formatQty(line.qty)} ${line.unit}\n'
          'Masuk ke ${line.toLocationName}\n\n'
          'Stok di lokasi itu akan dikurangi. Jika stok sudah terpakai, hapus gagal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final notifier = context.read<StockNotifier>();
    final ok = await notifier.voidReceiptLine(line.lineId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Barang datang dihapus.'
              : (notifier.errorMessage ?? 'Gagal menghapus.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<StockNotifier>();
    final auth = context.watch<AuthNotifier>();
    final lines = notifier.filteredReceipts.where((line) {
      return line.toLocationId == null ||
          auth.canSeeLocation(line.toLocationId!);
    }).toList();
    final dateFormat = DateFormat('d MMM yyyy', 'id_ID');

    return Scaffold(
      appBar: AppBar(title: const Text('Rekap Barang Datang')),
      body: notifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableFilterSortBar(
                  searchQuery: notifier.receiptQuery,
                  onSearchChanged: notifier.setReceiptQuery,
                  searchHint: 'Cari barang / lokasi / user...',
                  sortLabel: 'Terbaru',
                  onSortTap: () {},
                  resultCount: lines.length,
                  filterChips: [
                    for (final period in RecapPeriod.values)
                      buildFilterChip(
                        label: period.label,
                        selected: notifier.receiptPeriod == period,
                        onTap: () => notifier.setReceiptPeriod(period),
                      ),
                  ],
                ),
                if (notifier.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      notifier.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: notifier.load,
                    child: lines.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(
                                child: Text('Belum ada barang datang.'),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: lines.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final line = lines[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.chipActiveBg,
                                    child: Icon(
                                      Icons.move_to_inbox_outlined,
                                      color: AppColors.accentGreen,
                                    ),
                                  ),
                                  title: Text(
                                    '${line.itemName} · ${formatQty(line.qty)} ${line.unit}',
                                  ),
                                  subtitle: Text(
                                    '${dateFormat.format(line.docDate)} · '
                                    'Masuk ke ${line.toLocationName}\n'
                                    'Oleh ${line.createdByName.isEmpty ? 'Tidak diketahui' : line.createdByName}'
                                    '${line.note.trim().isEmpty ? '' : '\n${line.note}'}',
                                  ),
                                  isThreeLine: true,
                                  trailing:
                                      auth.isOwner && line.lineId.isNotEmpty
                                      ? IconButton(
                                          tooltip: 'Hapus barang datang',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: notifier.isSaving
                                              ? null
                                              : () => _delete(line),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
