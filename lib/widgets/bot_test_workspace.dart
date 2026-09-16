import 'package:flutter/material.dart';

import '../workspace_models.dart';

class BotTestWorkspace extends StatefulWidget {
  const BotTestWorkspace({
    super.key,
    required this.conversations,
    required this.selectedConversationId,
    required this.knowledgeBase,
    required this.aiConfigured,
    required this.busy,
    required this.onCreateConversation,
    required this.onSelectConversation,
    required this.onRenameConversation,
    required this.onDeleteConversation,
    required this.onClearConversation,
    required this.onSend,
    required this.onMarkGood,
    required this.onMarkBad,
    required this.onRetryReply,
    required this.onEditKnowledgeBase,
    required this.onAnalyzeAvito,
  });

  final List<BotConversation> conversations;
  final String? selectedConversationId;
  final String knowledgeBase;
  final bool aiConfigured;
  final bool busy;
  final VoidCallback onCreateConversation;
  final ValueChanged<String> onSelectConversation;
  final ValueChanged<BotConversation> onRenameConversation;
  final ValueChanged<BotConversation> onDeleteConversation;
  final ValueChanged<BotConversation> onClearConversation;
  final Future<void> Function(String) onSend;
  final ValueChanged<BotMessage> onMarkGood;
  final Future<void> Function(BotMessage) onMarkBad;
  final Future<void> Function(BotMessage) onRetryReply;
  final VoidCallback onEditKnowledgeBase;
  final VoidCallback onAnalyzeAvito;

  @override
  State<BotTestWorkspace> createState() => _BotTestWorkspaceState();
}

class _BotTestWorkspaceState extends State<BotTestWorkspace> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.conversations.cast<BotConversation?>().firstWhere(
      (item) => item?.id == widget.selectedConversationId,
      orElse: () => null,
    );
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB7BDC7)
        : const Color(0xFF626975);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: widget.onCreateConversation,
                icon: const Icon(Icons.add),
                label: const Text('Новый диалог'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.onEditKnowledgeBase,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('База знаний'),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: widget.onAnalyzeAvito,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Анализ Avito'),
              ),
              const SizedBox(height: 18),
              Text(
                'Тестовые диалоги',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...widget.conversations.map(
                (conversation) => ListTile(
                  selected: conversation.id == selected?.id,
                  selectedTileColor: const Color(0x22F28C28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  title: Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${conversation.messages.length} сообщений'),
                  onTap: () => widget.onSelectConversation(conversation.id),
                ),
              ),
              if (!widget.aiConfigured)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Работает безопасный mock-режим: бот отвечает только по базе знаний.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: selected == null
              ? Center(
                  child: Text(
                    'Создайте тестовый диалог',
                    style: TextStyle(color: muted),
                  ),
                )
              : _ConversationPanel(
                  conversation: selected,
                  controller: _message,
                  busy: widget.busy,
                  muted: muted,
                  onRename: () => widget.onRenameConversation(selected),
                  onDelete: () => widget.onDeleteConversation(selected),
                  onClear: () => widget.onClearConversation(selected),
                  onSend: () async {
                    final text = _message.text.trim();
                    if (text.isEmpty) return;
                    _message.clear();
                    await widget.onSend(text);
                  },
                  onMarkGood: widget.onMarkGood,
                  onMarkBad: widget.onMarkBad,
                  onRetryReply: widget.onRetryReply,
                ),
        ),
      ],
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.conversation,
    required this.controller,
    required this.busy,
    required this.muted,
    required this.onRename,
    required this.onDelete,
    required this.onClear,
    required this.onSend,
    required this.onMarkGood,
    required this.onMarkBad,
    required this.onRetryReply,
  });
  final BotConversation conversation;
  final TextEditingController controller;
  final bool busy;
  final Color muted;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final Future<void> Function() onSend;
  final ValueChanged<BotMessage> onMarkGood;
  final Future<void> Function(BotMessage) onMarkBad;
  final Future<void> Function(BotMessage) onRetryReply;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              conversation.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Переименовать',
            onPressed: onRename,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Очистить контекст',
            onPressed: onClear,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
          IconButton(
            tooltip: 'Удалить диалог',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Тестовый режим: ответы никогда не отправляются клиенту автоматически.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 6),
      Tooltip(
        message:
            'Отправка доступна только из реального диалога после проверки сотрудником',
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.send_outlined, size: 16),
          label: const Text('Отправить клиенту (недоступно в тесте)'),
        ),
      ),
      const SizedBox(height: 14),
      Container(
        height: 410,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: conversation.messages.isEmpty
            ? Center(
                child: Text(
                  'Напишите тестовое объявление или вопрос клиента.',
                  style: TextStyle(color: muted),
                ),
              )
            : ListView(
                children: conversation.messages
                    .map(
                      (message) => _Bubble(
                        message: message,
                        onMarkGood: onMarkGood,
                        onMarkBad: onMarkBad,
                        onRetryReply: onRetryReply,
                      ),
                    )
                    .toList(),
              ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              enabled: !busy,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                labelText: 'Сообщение для теста',
                hintText: 'Например: Сколько стоит полировка для кроссовера?',
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: busy ? null : onSend,
            icon: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(busy ? 'Думаю…' : 'Спросить'),
          ),
        ],
      ),
    ],
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.onMarkGood,
    required this.onMarkBad,
    required this.onRetryReply,
  });
  final BotMessage message;
  final ValueChanged<BotMessage> onMarkGood;
  final Future<void> Function(BotMessage) onMarkBad;
  final Future<void> Function(BotMessage) onRetryReply;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isEscalation = message.needsHuman;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFFF28C28)
              : isEscalation
              ? const Color(0xFFFFE8C5)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUser
                  ? 'Вы'
                  : isEscalation
                  ? 'Нужно участие сотрудника'
                  : 'Тест-бот',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isUser ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.text,
              style: TextStyle(color: isUser ? Colors.white : null),
            ),
            if (!isUser && message.usedKnowledgeSections.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                'Использовано: ${message.usedKnowledgeSections.join(', ')}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
            if (!isUser && !isEscalation) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => onMarkGood(message),
                    icon: const Icon(Icons.thumb_up_outlined, size: 16),
                    label: const Text('Ответил хорошо'),
                  ),
                  TextButton.icon(
                    onPressed: () => onMarkBad(message),
                    icon: const Icon(Icons.thumb_down_outlined, size: 16),
                    label: const Text('Ответил плохо'),
                  ),
                  TextButton.icon(
                    onPressed: () => onRetryReply(message),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
