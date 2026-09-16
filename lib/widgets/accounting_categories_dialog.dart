import 'dart:async';

import 'package:flutter/material.dart';

/// Черновой редактор категорий финансовых операций.
///
/// Данные сохраняются одной операцией после подтверждения, поэтому отмена
/// диалога не приводит к частично изменённым настройкам бухгалтерии.
class AccountingCategoriesDialog extends StatefulWidget {
  const AccountingCategoriesDialog({
    super.key,
    required this.categories,
    required this.onSave,
  });

  final List<String> categories;
  final Future<void> Function(List<String> categories) onSave;

  @override
  State<AccountingCategoriesDialog> createState() =>
      _AccountingCategoriesDialogState();
}

class _AccountingCategoriesDialogState
    extends State<AccountingCategoriesDialog> {
  late final List<String> _categories = List<String>.from(widget.categories);
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty || _categories.contains(value)) return;
    setState(() {
      _categories.add(value);
      _controller.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.onSave(List<String>.unmodifiable(_categories));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Категории операций'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._categories.asMap().entries.map(
            (entry) => ListTile(
              title: Text(entry.value),
              trailing: IconButton(
                tooltip: 'Удалить категорию',
                icon: const Icon(Icons.delete_outline),
                onPressed: _saving
                    ? null
                    : () => setState(() => _categories.removeAt(entry.key)),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_saving,
                  onSubmitted: (_) => _add(),
                  decoration: const InputDecoration(
                    labelText: 'Новая категория',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Добавить категорию',
                icon: const Icon(Icons.add),
                onPressed: _saving ? null : _add,
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
        child: const Text('Отмена'),
      ),
      TextButton(
        onPressed: _saving ? null : () => unawaited(_save()),
        child: Text(_saving ? 'Сохранение…' : 'Готово'),
      ),
    ],
  );
}
