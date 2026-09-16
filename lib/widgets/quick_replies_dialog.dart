import 'dart:async';

import 'package:flutter/material.dart';

/// Редактор быстрых ответов с отдельным черновиком.
///
/// Изменения передаются наружу только после явного подтверждения, поэтому
/// случайное закрытие окна не меняет сохранённые настройки сообщений.
class QuickRepliesDialog extends StatefulWidget {
  const QuickRepliesDialog({
    super.key,
    required this.templates,
    required this.onSave,
  });

  final List<String> templates;
  final Future<void> Function(List<String> templates) onSave;

  @override
  State<QuickRepliesDialog> createState() => _QuickRepliesDialogState();
}

class _QuickRepliesDialogState extends State<QuickRepliesDialog> {
  late final List<String> _templates = List<String>.from(widget.templates);
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTemplate() {
    final value = _controller.text.trim();
    if (value.isEmpty || _templates.contains(value)) return;
    setState(() {
      _templates.add(value);
      _controller.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.onSave(List<String>.unmodifiable(_templates));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Шаблоны ответов'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._templates.asMap().entries.map(
            (entry) => ListTile(
              title: Text(entry.value),
              trailing: IconButton(
                tooltip: 'Удалить шаблон',
                icon: const Icon(Icons.delete_outline),
                onPressed: _saving
                    ? null
                    : () => setState(() => _templates.removeAt(entry.key)),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_saving,
                  maxLines: 2,
                  onSubmitted: (_) => _addTemplate(),
                  decoration: const InputDecoration(labelText: 'Новый шаблон'),
                ),
              ),
              IconButton(
                tooltip: 'Добавить шаблон',
                icon: const Icon(Icons.add),
                onPressed: _saving ? null : _addTemplate,
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
