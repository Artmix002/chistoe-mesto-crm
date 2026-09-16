import 'dart:async';

import 'package:flutter/material.dart';

import '../deal_logic.dart';
import '../models.dart';

/// Витрина склада: поиск, страницы и быстрые действия над товаром.
///
/// Операции изменения передаются через callbacks, поэтому UI не меняет
/// остатки самостоятельно и не дублирует логику списаний.
class StockPage extends StatelessWidget {
  const StockPage({
    super.key,
    required this.items,
    required this.movementCount,
    required this.query,
    required this.page,
    required this.pageSize,
    required this.canEdit,
    required this.onAdd,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onEdit,
    required this.onMovement,
    required this.onShowMovements,
    required this.onDelete,
    this.categories = const [],
    this.categoryFilter = '',
    this.onCategoryChanged,
    this.totalValue = 0,
    this.lowStockCount = 0,
  });

  final List<StockItem> items;
  final int Function(StockItem item) movementCount;
  final String query;
  final int page;
  final int pageSize;
  final bool canEdit;
  final VoidCallback onAdd;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<StockItem> onEdit;
  final ValueChanged<StockItem> onMovement;
  final ValueChanged<StockItem> onShowMovements;
  final Future<void> Function(StockItem) onDelete;
  final List<String> categories;
  final String categoryFilter;
  final ValueChanged<String>? onCategoryChanged;
  final double totalValue;
  final int lowStockCount;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final filtered =
        items
            .where(
              (item) =>
                  normalizedQuery.isEmpty ||
                  item.name.toLowerCase().contains(normalizedQuery) ||
                  item.supplier.toLowerCase().contains(normalizedQuery),
            )
            .where(
              (item) =>
                  categoryFilter.isEmpty || item.category == categoryFilter,
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    final pagination = paginateDeals(
      filtered,
      requestedPage: page,
      pageSize: pageSize,
    );
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB2B8C2)
        : const Color(0xFF626975);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Склад', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: canEdit ? onAdd : null,
              icon: const Icon(Icons.add),
              label: const Text('Добавить товар'),
            ),
            Text('Позиций: ${items.length}', style: TextStyle(color: muted)),
            Text(
              'Ниже минимума: $lowStockCount',
              style: TextStyle(color: muted),
            ),
            Text(
              'Стоимость остатков: ${totalValue.toStringAsFixed(0)} ₽',
              style: TextStyle(color: muted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (categories.isNotEmpty && onCategoryChanged != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DropdownButtonFormField<String>(
              initialValue: categoryFilter.isEmpty ? '' : categoryFilter,
              decoration: const InputDecoration(labelText: 'Категория'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Все категории')),
                ...categories.map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                ),
              ],
              onChanged: (value) => onCategoryChanged!(value ?? ''),
            ),
          ),
        if (categories.isNotEmpty && onCategoryChanged != null)
          const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: TextField(
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Поиск по товару или поставщику',
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Text(
            items.isEmpty
                ? 'Склад пуст. Добавьте первый товар.'
                : 'По вашему запросу товаров нет.',
          ),
        ...pagination.items.map(
          (item) => Card(
            child: ListTile(
              title: Text(item.name),
              subtitle: Text(
                '${item.category} • Остаток: ${item.quantity} ${item.unit} • минимум: ${item.minQuantity} • цена: ${item.purchasePrice.toStringAsFixed(0)} ₽ • движений: ${movementCount(item)}',
              ),
              onTap: canEdit ? () => onEdit(item) : null,
              onLongPress: () => onShowMovements(item),
              trailing: Wrap(
                spacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (item.quantity <= item.minQuantity)
                    const Chip(label: Text('Пополнить')),
                  IconButton(
                    icon: const Icon(Icons.swap_vert),
                    tooltip: 'Движение',
                    onPressed: canEdit ? () => onMovement(item) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.history),
                    tooltip: 'История движений',
                    onPressed: () => onShowMovements(item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Удалить товар',
                    onPressed: canEdit ? () => unawaited(onDelete(item)) : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (filtered.length > pageSize)
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
