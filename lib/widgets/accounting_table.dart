import 'package:flutter/material.dart';

import '../deal_logic.dart';

/// Постраничная таблица строк, загруженных из Google Sheets.
///
/// Таблица получает только значения и текущую страницу, поэтому не зависит от
/// состояния синхронизации или финансовой логики dashboard.
class AccountingTable extends StatelessWidget {
  const AccountingTable({
    super.key,
    required this.rows,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
  });

  final List<List<String>> rows;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final values = rows
        .skip(1)
        .where((row) => row.any((value) => value.trim().isNotEmpty))
        .toList(growable: false);
    final pagination = paginateDeals(
      values,
      requestedPage: page,
      pageSize: pageSize,
    );
    final firstRow = values.isEmpty ? 0 : pagination.page * pageSize + 1;
    final lastRow = values.isEmpty ? 0 : firstRow + pagination.items.length - 1;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB2B8C2)
        : const Color(0xFF626975);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (values.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Строки $firstRow–$lastRow из ${values.length}',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: rows.first
                  .map(
                    (header) => DataColumn(
                      label: Text(
                        header,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .toList(),
              rows: pagination.items
                  .map<DataRow>(
                    (row) => DataRow(
                      cells: List.generate(
                        rows.first.length,
                        (index) => DataCell(
                          Text(index < row.length ? row[index] : ''),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (pagination.pageCount > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
            ),
        ],
      ),
    );
  }
}
