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
    final conversation = selected == null
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
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final sidebar = _Sidebar(
          compact: compact,
          conversations: widget.conversations,
          selected: selected,
          aiConfigured: widget.aiConfigured,
          muted: muted,
          onCreateConversation: widget.onCreateConversation,
          onEditKnowledgeBase: widget.onEditKnowledgeBase,
          onAnalyzeAvito: widget.onAnalyzeAvito,
          onSelectConversation: widget.onSelectConversation,
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [sidebar, const SizedBox(height: 18), conversation],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 260, child: sidebar),
            const SizedBox(width: 24),
            Expanded(child: conversation),
          ],
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.conversations,
    required this.selected,
    required this.aiConfigured,
    required this.muted,
    required this.onCreateConversation,
    required this.onEditKnowledgeBase,
    required this.onAnalyzeAvito,
    required this.onSelectConversation,
  });

  final bool compact;
  final List<BotConversation> conversations;
  final BotConversation? selected;
  final bool aiConfigured;
  final Color muted;
  final VoidCallback onCreateConversation;
  final VoidCallback onEditKnowledgeBase;
  final VoidCallback onAnalyzeAvito;
  final ValueChanged<String> onSelectConversation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: onCreateConversation,
        icon: const Icon(Icons.add),
        label: const Text('Новый диалог'),
      ),
      const SizedBox(height: 8),
      if (compact)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEditKnowledgeBase,
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('База знаний'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAnalyzeAvito,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('Анализ Avito'),
              ),
            ),
          ],
        )
      else ...[
        OutlinedButton.icon(
          onPressed: onEditKnowledgeBase,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('База знаний'),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onAnalyzeAvito,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Анализ Avito'),
        ),
      ],
      SizedBox(height: compact ? 12 : 18),
      Text('Тестовые диалоги', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      ...conversations.map(
        (conversation) => ListTile(
          selected: conversation.id == selected?.id,
          selectedTileColor: const Color(0x22F28C28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            conversation.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('${conversation.messages.length} сообщений'),
          onTap: () => onSelectConversation(conversation.id),
        ),
      ),
      if (!aiConfigured)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Работает безопасный mock-режим: бот отвечает только по базе знаний.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
    ],
  );
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
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 680;
    return Column(
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
        SizedBox(height: compact ? 6 : 8),
        Text(
          'Тестовый режим: ответы никогда не отправляются клиенту автоматически.',
          style: TextStyle(color: muted),
        ),
        SizedBox(height: compact ? 4 : 6),
        Semantics(
          label:
              'Отправка клиенту недоступна в тесте: сначала ответ проверяет сотрудник',
          child: Text(
            'Отправка клиенту недоступна в тесте',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        Container(
          height: compact ? 112 : 410,
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
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
        SizedBox(height: compact ? 8 : 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 440;
            final sendButton = compact
                ? Tooltip(
                    message: busy ? 'Бот формирует ответ' : 'Спросить',
                    child: FilledButton(
                      onPressed: busy ? null : onSend,
                      child: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: busy ? null : onSend,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(busy ? 'Думаю…' : 'Спросить'),
                  );
            return Row(
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
                      hintText:
                          'Например: Сколько стоит полировка для кроссовера?',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                sendButton,
              ],
            );
          },
        ),
      ],
    );
  }
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
              Wrap(
                spacing: 4,
                runSpacing: 2,
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
