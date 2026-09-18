import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/stock_notifier.dart';
import '../utils/table_filter_sort.dart';
import '../widgets/stock_qty_table.dart';
import '../widgets/table_filter_sort_bar.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockNotifier>().load();
    });
  }

  Future<void> _pickSort(StockNotifier notifier) async {
    final selected = await showTableSortSheet<StockSort>(
      context: context,
      title: 'Urutkan stok',
      current: notifier.sort,
      options: [
        for (final value in StockSort.values)
          SortOption(value: value, label: value.label),
      ],
    );
    if (selected != null) notifier.setSort(selected);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<StockNotifier>();
    final auth = context.watch<AuthNotifier>();
    final rows = notifier.filteredRows;
    final locations = auth.visibleLocations(notifier.locations);

    return Scaffold(
      appBar: AppBar(title: const Text('Stok')),
      body: notifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableFilterSortBar(
                  searchQuery: notifier.searchQuery,
                  onSearchChanged: notifier.setSearchQuery,
                  searchHint: 'Cari nama barang...',
                  sortLabel: notifier.sort.label,
                  onSortTap: () => _pickSort(notifier),
                  resultCount: rows.length,
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
                    child: rows.isEmpty || locations.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  locations.isEmpty
                                      ? 'Belum ada lokasi stok yang diizinkan. Hubungi owner.'
                                      : notifier.items.isEmpty
                                          ? 'Belum ada barang. Tambah di Master Barang.'
                                          : 'Tidak ada barang yang cocok.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              StockQtyTable(
                                rows: rows,
                                locations: locations,
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
