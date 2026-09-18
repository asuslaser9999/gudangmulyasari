import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/stock_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/qty_format.dart';
import '../widgets/table_filter_sort_bar.dart';

class TransferRecapScreen extends StatefulWidget {
  const TransferRecapScreen({super.key});

  @override
  State<TransferRecapScreen> createState() => _TransferRecapScreenState();
}

class _TransferRecapScreenState extends State<TransferRecapScreen> {
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
        title: const Text('Hapus pengambilan?'),
        content: Text(
          '${line.itemName} ${formatQty(line.qty)} ${line.unit}\n'
          '${line.fromLocationName} → ${line.toLocationName}\n\n'
          'Stok akan dikembalikan ke gudang asal.',
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
    final ok = await notifier.voidTransferLine(line.lineId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Pengambilan dihapus.'
              : (notifier.errorMessage ?? 'Gagal menghapus.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<StockNotifier>();
    final auth = context.watch<AuthNotifier>();
    final lines = notifier.filteredTransfers.where((line) {
      final fromOk =
          line.fromLocationId == null ||
          auth.canSeeLocation(line.fromLocationId!);
      final toOk =
          line.toLocationId == null || auth.canSeeLocation(line.toLocationId!);
      return fromOk || toOk;
    }).toList();
    final dateFormat = DateFormat('d MMM yyyy', 'id_ID');

    return Scaffold(
      appBar: AppBar(title: const Text('Rekap Pengambilan')),
      body: notifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableFilterSortBar(
                  searchQuery: notifier.recapQuery,
                  onSearchChanged: notifier.setRecapQuery,
                  searchHint: 'Cari barang / lokasi / user...',
                  sortLabel: 'Terbaru',
                  onSortTap: () {},
                  resultCount: lines.length,
                  filterChips: [
                    for (final period in RecapPeriod.values)
                      buildFilterChip(
                        label: period.label,
                        selected: notifier.period == period,
                        onTap: () => notifier.setPeriod(period),
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
                                child: Text('Belum ada pengambilan.'),
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
                                    backgroundColor: AppColors.consignmentRowBg,
                                    child: Icon(
                                      Icons.swap_horiz_rounded,
                                      color: AppColors.accentOrange,
                                    ),
                                  ),
                                  title: Text(
                                    '${line.itemName} · ${formatQty(line.qty)} ${line.unit}',
                                  ),
                                  subtitle: Text(
                                    '${dateFormat.format(line.docDate)} · '
                                    '${line.fromLocationName} → ${line.toLocationName}\n'
                                    'Oleh ${line.createdByName.isEmpty ? 'Tidak diketahui' : line.createdByName}'
                                    '${line.note.trim().isEmpty ? '' : '\n${line.note}'}',
                                  ),
                                  isThreeLine: true,
                                  trailing:
                                      auth.canDeleteTransfer &&
                                          line.lineId.isNotEmpty
                                      ? IconButton(
                                          tooltip: 'Hapus pengambilan',
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
