import 'package:flutter/material.dart';

/// Kanban-доска сделок с фиксированной воронкой статусов.
class DealsKanbanBoard extends StatelessWidget {
  const DealsKanbanBoard({
    super.key,
    required this.rows,
    required this.canEdit,
    required this.onShowTable,
    required this.onAddDeal,
    required this.onOpenDeal,
  });

  static const statuses = [
    'Новый лид',
    'Написал',
    'Записан',
    'В работе',
    'Выполнен',
    'Отказался',
    'Не приехал',
  ];

  final Iterable<List<String>> rows;
  final bool canEdit;
  final VoidCallback onShowTable;
  final VoidCallback onAddDeal;
  final ValueChanged<List<String>> onOpenDeal;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<List<String>>>{
      for (final status in statuses) status: [],
    };
    for (final row in rows) {
      final status = row.length > 16 && statuses.contains(row[16])
          ? row[16]
          : statuses.first;
      grouped[status]!.add(row);
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Воронка сделок',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(onPressed: onShowTable, child: const Text('Таблица')),
            ElevatedButton.icon(
              onPressed: canEdit ? onAddDeal : null,
              icon: const Icon(Icons.add),
              label: const Text('Новая сделка'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 560,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final status in statuses)
                  Container(
                    width: 245,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$status (${grouped[status]!.length})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: [
                              for (final row in grouped[status]!)
                                Card(
                                  child: ListTile(
                                    dense: true,
                                    title: Text(
                                      row.length > 17 ? row[17] : 'Без имени',
                                    ),
                                    subtitle: Text(
                                      row.length > 5 ? '${row[5]} ₽' : '',
                                    ),
                                    onTap: canEdit
                                        ? () => onOpenDeal(row)
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
