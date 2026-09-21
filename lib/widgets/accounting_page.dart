import 'package:flutter/material.dart';

/// Экран финансовых данных. Бизнес-состояние передаёт dashboard, а этот
/// компонент отвечает только за адаптивную компоновку и выбор фильтров.
class AccountingPage extends StatelessWidget {
  const AccountingPage({
    super.key,
    required this.lastSheetsSync,
    required this.sheetsOfflineMode,
    required this.loading,
    required this.canEditFinance,
    required this.onSync,
    required this.onClosePeriod,
    required this.from,
    required this.to,
    required this.onPeriodChanged,
    required this.categoryFilter,
    required this.categories,
    required this.onCategoryChanged,
    required this.onManageCategories,
    required this.sheetError,
    required this.hasRows,
    required this.table,
    required this.localOperations,
    required this.reconciliationReport,
    required this.closedPeriodSummary,
  });

  final DateTime? lastSheetsSync;
  final bool sheetsOfflineMode;
  final bool loading;
  final bool canEditFinance;
  final Future<void> Function() onSync;
  final Future<void> Function() onClosePeriod;
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTimeRange?> onPeriodChanged;
  final String categoryFilter;
  final List<String> categories;
  final ValueChanged<String> onCategoryChanged;
  final Future<void> Function() onManageCategories;
  final String? sheetError;
  final bool hasRows;
  final Widget? table;
  final Widget localOperations;
  final Widget reconciliationReport;
  final String? closedPeriodSummary;

  String get _syncDescription {
    if (lastSheetsSync == null) return 'Данные загружаются из Google Таблицы';
    final time = lastSheetsSync!;
    return 'Данные загружаются из Google Таблицы • обновлено '
        '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB2B8C2)
        : const Color(0xFF626975);
    final showSheetError =
        sheetError != null &&
        !(sheetsOfflineMode &&
            sheetError!.startsWith('Google Sheets недоступна'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_syncDescription, style: TextStyle(color: muted, fontSize: 14)),
        const SizedBox(height: 20),
        if (sheetsOfflineMode)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Google Sheets недоступна. Показаны последние сохранённые финансовые данные; локальные операции не потеряны.',
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            Future<void> selectPeriod() async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDateRange: from == null || to == null
                    ? null
                    : DateTimeRange(start: from!, end: to!),
              );
              if (picked != null) onPeriodChanged(picked);
            }

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: loading ? null : () => onSync(),
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      loading ? 'Синхронизация…' : 'Синхронизировать',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: canEditFinance ? () => onClosePeriod() : null,
                    icon: const Icon(Icons.lock_clock_outlined),
                    label: const Text('Закрыть период'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: selectPeriod,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            from == null
                                ? 'Период'
                                : '${from!.day}.${from!.month} – ${to!.day}.${to!.month}',
                          ),
                        ),
                      ),
                      if (from != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Сбросить период',
                          onPressed: () => onPeriodChanged(null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: categoryFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Категория',
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'Все категории',
                              child: Text('Все категории'),
                            ),
                            ...categories.map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              onCategoryChanged(value ?? 'Все категории'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Категории',
                        onPressed: canEditFinance
                            ? () => onManageCategories()
                            : null,
                        icon: const Icon(Icons.category_outlined),
                      ),
                    ],
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: loading ? null : () => onSync(),
                      icon: const Icon(Icons.sync),
                      label: const Text('Синхронизировать'),
                    ),
                    OutlinedButton.icon(
                      onPressed: canEditFinance ? () => onClosePeriod() : null,
                      icon: const Icon(Icons.lock_clock_outlined),
                      label: const Text('Закрыть период'),
                    ),
                    if (loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: selectPeriod,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        from == null
                            ? 'Период'
                            : '${from!.day}.${from!.month} – ${to!.day}.${to!.month}',
                      ),
                    ),
                    if (from != null)
                      TextButton(
                        onPressed: () => onPeriodChanged(null),
                        child: const Text('Сбросить'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: categoryFilter,
                      items: [
                        const DropdownMenuItem(
                          value: 'Все категории',
                          child: Text('Все категории'),
                        ),
                        ...categories.map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          onCategoryChanged(value ?? 'Все категории'),
                    ),
                    OutlinedButton.icon(
                      onPressed: canEditFinance
                          ? () => onManageCategories()
                          : null,
                      icon: const Icon(Icons.category_outlined),
                      label: const Text('Категории'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        if (showSheetError)
          Text(
            sheetError!,
            style: TextStyle(
              color: sheetsOfflineMode ? Colors.orange : Colors.red,
            ),
          ),
        if (!loading && hasRows && table != null) table!,
        if (!loading && !hasRows)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Text('Нажмите «Синхронизировать», чтобы загрузить данные.'),
          ),
        localOperations,
        const SizedBox(height: 12),
        reconciliationReport,
        if (closedPeriodSummary != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              closedPeriodSummary!,
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
