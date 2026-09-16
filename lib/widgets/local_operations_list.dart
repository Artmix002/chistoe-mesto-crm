import 'package:flutter/material.dart';

/// Краткий список локальных финансовых операций за выбранный период.
class LocalOperationsList extends StatelessWidget {
  const LocalOperationsList({super.key, required this.operations});

  final List<Map<String, dynamic>> operations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB2B8C2)
        : const Color(0xFF626975);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Локальные операции',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          if (operations.isEmpty)
            Text(
              'Операций за выбранный период нет.',
              style: TextStyle(color: muted),
            )
          else
            ...operations.take(50).map((operation) {
              final amount = (operation['amount'] as num?)?.toDouble() ?? 0;
              final source = operation['source'] == 'google_sheets'
                  ? 'Google Sheets'
                  : 'Локально';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(operation['comment']?.toString() ?? 'Операция'),
                subtitle: Text('${operation['date'] ?? ''} • $source'),
                trailing: Text(
                  '${amount >= 0 ? '+' : ''}${amount.toStringAsFixed(0)} ₽',
                ),
              );
            }),
        ],
      ),
    );
  }
}
