import 'package:flutter/material.dart';

import '../deal_logic.dart';

/// Постраничная таблица сделок, сгруппированных по дате оказания услуги.
class DealsGroupedTable extends StatelessWidget {
  const DealsGroupedTable({
    super.key,
    required this.headers,
    required this.entries,
    required this.page,
    required this.pageSize,
    required this.visibleColumns,
    required this.columnWidths,
    required this.defaultColumnWidth,
    required this.wrapText,
    required this.canEdit,
    required this.weekdayForDate,
    required this.onPageChanged,
    required this.onOpenDeal,
  });

  final List<String> headers;
  final Iterable<MapEntry<String, List<List<String>>>> entries;
  final int page;
  final int pageSize;
  final Set<int> visibleColumns;
  final Map<int, double> columnWidths;
  final double defaultColumnWidth;
  final bool wrapText;
  final bool canEdit;
  final String Function(String date) weekdayForDate;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<List<String>> onOpenDeal;

  double _sum(List<List<String>> rows, int column) => rows.fold<double>(
    0,
    (sum, row) =>
        sum + parseLocalizedNumber(column < row.length ? row[column] : ''),
  );

  String _cellText(List<String> row, int index) {
    final value = index < row.length ? row[index] : '';
    const moneyColumns = {5, 6, 7, 9, 11, 12, 13, 14, 15};
    return moneyColumns.contains(index)
        ? formatDealNumber(parseLocalizedNumber(value))
        : value;
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = entries.toList(growable: false);
    final pagination = paginateDeals(
      allEntries,
      requestedPage: page,
      pageSize: pageSize,
    );
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB2B8C2)
        : const Color(0xFF626975);
    return Column(
      children: [
        for (final entry in pagination.items)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ExpansionTile(
              title: Text(
                '${entry.key}  ${weekdayForDate(entry.key)}  •  Услуг: ${entry.value.length}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text(
                'Выручка: ${_sum(entry.value, 5).toStringAsFixed(0)} ₽  |  '
                'Бизнес-счёт: ${_sum(entry.value, 11).toStringAsFixed(0)} ₽  |  '
                'Работнику: ${_sum(entry.value, 9).toStringAsFixed(0)} ₽  |  '
                'Артём: ${_sum(entry.value, 14).toStringAsFixed(0)} ₽  |  '
                'Дмитрий: ${_sum(entry.value, 13).toStringAsFixed(0)} ₽',
                style: TextStyle(color: muted),
              ),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(color: scheme.outlineVariant),
                    columns: [
                      for (var index = 0; index < headers.length; index++)
                        if (visibleColumns.contains(index))
                          DataColumn(
                            label: SizedBox(
                              width: columnWidths[index] ?? defaultColumnWidth,
                              child: Text(
                                headers[index],
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                    ],
                    rows: [
                      for (final row in entry.value)
                        DataRow(
                          cells: [
                            for (var index = 0; index < headers.length; index++)
                              if (visibleColumns.contains(index))
                                DataCell(
                                  SizedBox(
                                    width:
                                        columnWidths[index] ??
                                        defaultColumnWidth,
                                    child: Text(
                                      _cellText(row, index),
                                      textAlign: TextAlign.center,
                                      softWrap: wrapText,
                                      maxLines: wrapText ? 4 : null,
                                    ),
                                  ),
                                  onTap: canEdit ? () => onOpenDeal(row) : null,
                                ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (allEntries.length > pageSize)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Предыдущая страница',
                onPressed: pagination.hasPrevious
                    ? () => onPageChanged(pagination.page - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${pagination.page + 1} из ${pagination.pageCount}'),
              IconButton(
                tooltip: 'Следующая страница',
                onPressed: pagination.hasNext
                    ? () => onPageChanged(pagination.page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}
