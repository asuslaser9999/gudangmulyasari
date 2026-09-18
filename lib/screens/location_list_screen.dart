import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/location_notifier.dart';
import '../theme/app_theme.dart';
import '../utils/table_filter_sort.dart';
import '../widgets/table_filter_sort_bar.dart';
import 'location_form_screen.dart';

class LocationListScreen extends StatefulWidget {
  const LocationListScreen({super.key});

  @override
  State<LocationListScreen> createState() => _LocationListScreenState();
}

class _LocationListScreenState extends State<LocationListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationNotifier>().load();
    });
  }

  Future<void> _openForm([StockLocation? location]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LocationFormScreen(location: location),
      ),
    );
    if (saved == true && mounted) {
      context.read<LocationNotifier>().load();
    }
  }

  Future<void> _pickSort(LocationNotifier notifier) async {
    final selected = await showTableSortSheet<NameSort>(
      context: context,
      title: 'Urutkan lokasi',
      current: notifier.sort,
      options: [
        for (final value in NameSort.values)
          SortOption(value: value, label: value.label),
      ],
    );
    if (selected != null) notifier.setSort(selected);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<LocationNotifier>();
    final auth = context.watch<AuthNotifier>();
    final locations = notifier.filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Gudang & Dapur')),
      floatingActionButton: auth.canManageLocations
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            )
          : null,
      body: notifier.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableFilterSortBar(
                  searchQuery: notifier.searchQuery,
                  onSearchChanged: notifier.setSearchQuery,
                  searchHint: 'Cari nama lokasi...',
                  sortLabel: notifier.sort.label,
                  onSortTap: () => _pickSort(notifier),
                  resultCount: locations.length,
                  filterChips: [
                    for (final option in LocationFilter.values)
                      buildFilterChip(
                        label: option.label,
                        selected: notifier.filter == option,
                        onTap: () => notifier.setFilter(option),
                      ),
                  ],
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: notifier.load,
                    child: locations.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('Belum ada lokasi.')),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                            itemCount: locations.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final loc = locations[index];
                              return Card(
                                child: ListTile(
                                  onTap: auth.canManageLocations
                                      ? () => _openForm(loc)
                                      : null,
                                  leading: CircleAvatar(
                                    backgroundColor: loc.isWarehouse
                                        ? AppColors.chipActiveBg
                                        : AppColors.consignmentRowBg,
                                    child: Icon(
                                      loc.isWarehouse
                                          ? Icons.warehouse_outlined
                                          : Icons.soup_kitchen_outlined,
                                      color: loc.isWarehouse
                                          ? AppColors.accentBlue
                                          : AppColors.accentOrange,
                                    ),
                                  ),
                                  title: Text(loc.name),
                                  subtitle: Text(loc.kind.productionLabel),
                                  trailing: Chip(
                                    label: Text(
                                      loc.isActive ? 'Aktif' : 'Nonaktif',
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
