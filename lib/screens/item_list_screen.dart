import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/item_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/table_filter_sort.dart';
import '../widgets/table_filter_sort_bar.dart';
import 'item_form_screen.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ItemNotifier>().load();
    });
  }

  Future<void> _openForm([StockItem? item]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ItemFormScreen(item: item)),
    );
    if (saved == true && mounted) {
      context.read<ItemNotifier>().load();
    }
  }

  Future<void> _pickSort(ItemNotifier notifier) async {
    final selected = await showTableSortSheet<ItemSort>(
      context: context,
      title: 'Urutkan barang',
      current: notifier.sort,
      options: [
        for (final value in ItemSort.values)
          SortOption(value: value, label: value.label),
      ],
    );
    if (selected != null) notifier.setSort(selected);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ItemNotifier>();
    final auth = context.watch<AuthNotifier>();
    final items = notifier.filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Master Barang')),
      floatingActionButton: auth.canManageItems
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            )
          : null,
      body: notifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TableFilterSortBar(
                  searchQuery: notifier.searchQuery,
                  onSearchChanged: notifier.setSearchQuery,
                  searchHint: 'Cari nama / satuan...',
                  sortLabel: notifier.sort.label,
                  onSortTap: () => _pickSort(notifier),
                  resultCount: items.length,
                ),
                if (notifier.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    child: items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Text(
                                  notifier.items.isEmpty
                                      ? 'Belum ada barang.'
                                      : 'Tidak ada barang yang cocok.',
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Card(
                                child: ListTile(
                                  onTap: auth.canManageItems
                                      ? () => _openForm(item)
                                      : null,
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.chipActiveBg,
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      color: item.isActive
                                          ? AppColors.accentGreen
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                  title: Text(item.name),
                                  subtitle: Text('Satuan: ${item.unit}'),
                                  trailing: Chip(
                                    label: Text(
                                      item.isActive ? 'Aktif' : 'Nonaktif',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
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
