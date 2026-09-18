import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/stock.dart';
import '../theme/app_theme.dart';
import '../utils/qty_format.dart';

class StockQtyTable extends StatefulWidget {
  const StockQtyTable({
    super.key,
    required this.rows,
    required this.locations,
  });

  final List<StockRow> rows;
  final List<StockLocation> locations;

  @override
  State<StockQtyTable> createState() => _StockQtyTableState();
}

class _StockQtyTableState extends State<StockQtyTable> {
  static const _rowHeight = 52.0;
  static const _colName = 148.0;
  static const _colLoc = 96.0;
  static const _colTotal = 72.0;

  final _horizontalScrollController = ScrollController();

  double get _scrollableWidth =>
      widget.locations.length * _colLoc + _colTotal;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderSide = BorderSide(color: theme.colorScheme.outlineVariant);
    final rows = widget.rows;
    final locations = widget.locations;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.swipe_left,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Nama barang tetap terlihat · geser untuk qty lokasi',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: borderSide.color),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FrozenNameColumn(
                  rows: rows,
                  theme: theme,
                  rowHeight: _rowHeight,
                  colWidth: _colName,
                  borderSide: borderSide,
                ),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true,
                      notificationPredicate: (notification) =>
                          notification.metrics.axis == Axis.horizontal,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _scrollableWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
              _ScrollableHeaderRow(
                locations: locations,
                rowHeight: _rowHeight,
                colLoc: _colLoc,
                colTotal: _colTotal,
                borderSide: borderSide,
              ),
                              for (var i = 0; i < rows.length; i++)
                                _ScrollableDataRow(
                                  row: rows[i],
                                  locations: locations,
                                  theme: theme,
                                  rowHeight: _rowHeight,
                                  colLoc: _colLoc,
                                  colTotal: _colTotal,
                                  borderSide: borderSide,
                                  striped: i.isOdd,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FrozenNameColumn extends StatelessWidget {
  const _FrozenNameColumn({
    required this.rows,
    required this.theme,
    required this.rowHeight,
    required this.colWidth,
    required this.borderSide,
  });

  final List<StockRow> rows;
  final ThemeData theme;
  final double rowHeight;
  final double colWidth;
  final BorderSide borderSide;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: Colors.black26,
      color: theme.colorScheme.surface,
      child: SizedBox(
        width: colWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NameCell(
              name: 'Barang',
              unit: '',
              isHeader: true,
              height: rowHeight,
              borderSide: borderSide,
              backgroundColor: context.palette.tableHeaderBg,
            ),
            for (var i = 0; i < rows.length; i++)
              _NameCell(
                name: rows[i].item.name,
                unit: rows[i].item.unit,
                height: rowHeight,
                borderSide: borderSide,
                backgroundColor: i.isOdd
                    ? theme.colorScheme.surfaceContainerLowest.withValues(
                        alpha: 0.55,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({
    required this.name,
    required this.unit,
    required this.height,
    required this.borderSide,
    this.isHeader = false,
    this.backgroundColor,
  });

  final String name;
  final String unit;
  final bool isHeader;
  final double height;
  final BorderSide borderSide;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: borderSide, right: borderSide),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: isHeader
          ? Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
                if (unit.isNotEmpty)
                  Text(
                    unit,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ScrollableHeaderRow extends StatelessWidget {
  const _ScrollableHeaderRow({
    required this.locations,
    required this.rowHeight,
    required this.colLoc,
    required this.colTotal,
    required this.borderSide,
  });

  final List<StockLocation> locations;
  final double rowHeight;
  final double colLoc;
  final double colTotal;
  final BorderSide borderSide;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        color: context.palette.tableHeaderBg,
        border: Border(bottom: borderSide),
      ),
      child: Row(
        children: [
          for (final loc in locations)
            _HeaderCell(
              label: loc.name,
              width: colLoc,
              borderSide: borderSide,
              color: loc.isWarehouse
                  ? context.palette.accentBlue
                  : context.palette.accentOrange,
            ),
          _HeaderCell(
            label: 'Total',
            width: colTotal,
            borderSide: borderSide,
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.width,
    required this.borderSide,
    this.color,
  });

  final String label;
  final double width;
  final BorderSide borderSide;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border(right: borderSide),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          height: 1.15,
          color: color,
        ),
      ),
    );
  }
}

class _ScrollableDataRow extends StatelessWidget {
  const _ScrollableDataRow({
    required this.row,
    required this.locations,
    required this.theme,
    required this.rowHeight,
    required this.colLoc,
    required this.colTotal,
    required this.borderSide,
    required this.striped,
  });

  final StockRow row;
  final List<StockLocation> locations;
  final ThemeData theme;
  final double rowHeight;
  final double colLoc;
  final double colTotal;
  final BorderSide borderSide;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    final total = row.qtyTotalFor(locations.map((loc) => loc.id));
    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        color: striped
            ? theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.55)
            : null,
        border: Border(bottom: borderSide),
      ),
      child: Row(
        children: [
          for (final loc in locations)
            _QtyCell(
              qty: row.qtyAt(loc.id),
              width: colLoc,
              borderSide: borderSide,
              color: loc.isWarehouse
                  ? context.palette.accentBlue
                  : context.palette.accentOrange,
            ),
          _QtyCell(
            qty: total,
            width: colTotal,
            borderSide: borderSide,
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _QtyCell extends StatelessWidget {
  const _QtyCell({
    required this.qty,
    required this.width,
    required this.borderSide,
    this.color,
    this.emphasize = false,
  });

  final double qty;
  final double width;
  final BorderSide borderSide;
  final Color? color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final muted = qty == 0;
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(right: borderSide),
      ),
      child: Text(
        formatQty(qty),
        style: TextStyle(
          fontWeight: emphasize || !muted ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
          color: muted
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : color,
        ),
      ),
    );
  }
}
