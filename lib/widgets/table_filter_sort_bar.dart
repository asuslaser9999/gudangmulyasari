import 'package:flutter/material.dart';

import '../utils/table_filter_sort.dart';

class TableFilterSortBar extends StatefulWidget {
  const TableFilterSortBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.sortLabel,
    required this.onSortTap,
    this.searchHint = 'Cari...',
    this.filterChips = const [],
    this.resultCount,
    this.showSort = true,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String sortLabel;
  final VoidCallback onSortTap;
  final String searchHint;
  final List<Widget> filterChips;
  final int? resultCount;
  final bool showSort;
  final EdgeInsets padding;

  @override
  State<TableFilterSortBar> createState() => _TableFilterSortBarState();
}

class _TableFilterSortBarState extends State<TableFilterSortBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(TableFilterSortBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            onChanged: widget.onSearchChanged,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _controller.clear();
                        widget.onSearchChanged('');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          if (widget.filterChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: widget.filterChips),
            ),
          ],
          const SizedBox(height: 8),
          if (widget.showSort)
            InkWell(
              onTap: widget.onSortTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.sort, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Urutkan: ${widget.sortLabel}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          if (widget.resultCount != null) ...[
            const SizedBox(height: 4),
            Text(
              '${widget.resultCount} baris ditampilkan',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

Future<T?> showTableSortSheet<T>({
  required BuildContext context,
  required String title,
  required List<SortOption<T>> options,
  required T current,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final option in options)
            ListTile(
              title: Text(option.label),
              trailing: current == option.value
                  ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, option.value),
            ),
        ],
      ),
    ),
  );
}

Widget buildFilterChip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}
