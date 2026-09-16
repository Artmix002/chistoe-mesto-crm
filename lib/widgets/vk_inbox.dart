import 'package:flutter/material.dart';

class VkInbox extends StatelessWidget {
  const VkInbox({
    super.key,
    required this.conversations,
    required this.selectedConversation,
    required this.messages,
    required this.loading,
    required this.darkMode,
    required this.canEdit,
    required this.canConfigure,
    required this.replyController,
    required this.quickReplyTemplates,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
    required this.titleOf,
    required this.textOf,
    required this.onRefresh,
    required this.onOpenConversation,
    required this.isNotificationChat,
    required this.onSelectNotificationChat,
    required this.onSendTest,
    required this.onSend,
  });

  final List<Map<String, dynamic>> conversations;
  final Map<String, dynamic>? selectedConversation;
  final List<Map<String, dynamic>> messages;
  final bool loading;
  final bool darkMode;
  final bool canEdit;
  final bool canConfigure;
  final TextEditingController replyController;
  final List<String> quickReplyTemplates;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>) textOf;
  final VoidCallback onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpenConversation;
  final bool isNotificationChat;
  final ValueChanged<String> onSelectNotificationChat;
  final Future<String?> Function() onSendTest;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    width: 980,
    height: 520,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.alternate_email, color: Color(0xFFF28C28)),
            const SizedBox(width: 8),
            Text(
              'Диалоги ВКонтакте',
              style: TextStyle(
                color: mainTextColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Обновить'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 310,
                child: conversations.isEmpty
                    ? Center(
                        child: Text(
                          loading ? 'Загружаем…' : 'Диалогов пока нет',
                          style: TextStyle(color: mutedTextColor),
                        ),
                      )
                    : ListView.separated(
                        itemCount: conversations.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: borderColor),
                        itemBuilder: (_, index) {
                          final item = conversations[index];
                          final last = item['last_message'] is Map
                              ? Map<String, dynamic>.from(item['last_message'])
                              : <String, dynamic>{};
                          final selected =
                              selectedConversation?['conversation']?['peer']?['id'] ==
                              item['conversation']?['peer']?['id'];
                          return InkWell(
                            onTap: () => onOpenConversation(item),
                            child: Container(
                              color: selected
                                  ? const Color(
                                      0xFFF28C28,
                                    ).withValues(alpha: darkMode ? .18 : .1)
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    titleOf(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: mainTextColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    textOf(last),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: mutedTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              VerticalDivider(width: 26, color: borderColor),
              Expanded(child: _conversationView(context)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _conversationView(BuildContext context) {
    final selected = selectedConversation;
    if (selected == null) {
      return Center(
        child: Text(
          'Выберите диалог слева',
          style: TextStyle(color: mutedTextColor),
        ),
      );
    }
    final peerId = selected['conversation']?['peer']?['id']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Text(
              titleOf(selected),
              style: TextStyle(
                color: mainTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            );
            final actions = Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: peerId == null || !canConfigure
                      ? null
                      : () => onSelectNotificationChat(peerId),
                  icon: Icon(
                    isNotificationChat
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                  ),
                  label: Text(
                    isNotificationChat
                        ? 'Уведомления включены'
                        : 'Отправлять новые записи сюда',
                  ),
                ),
                if (isNotificationChat)
                  IconButton(
                    tooltip: 'Отправить тест уведомлений',
                    icon: const Icon(Icons.send_outlined),
                    onPressed: canEdit
                        ? () async {
                            final error = await onSendTest();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  error ??
                                      'Тестовое уведомление отправлено в чат.',
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
              ],
            );
            if (constraints.maxWidth < 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, actions],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                actions,
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (_, index) {
              final message = messages[index];
              final outgoing = message['out'] == 1 || message['out'] == true;
              return Align(
                alignment: outgoing
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: outgoing
                        ? const Color(0xFFF28C28)
                        : (darkMode
                              ? const Color(0xFF30343B)
                              : const Color(0xFFF0F2F5)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    textOf(message),
                    style: TextStyle(
                      color: outgoing ? Colors.white : mainTextColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            PopupMenuButton<String>(
              tooltip: 'Быстрый ответ',
              icon: const Icon(Icons.flash_on_outlined),
              onSelected: (value) => replyController.text = value,
              itemBuilder: (_) => quickReplyTemplates
                  .map(
                    (template) => PopupMenuItem(
                      value: template,
                      child: SizedBox(
                        width: 320,
                        child: Text(
                          template,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            Expanded(
              child: TextField(
                controller: replyController,
                enabled: canEdit,
                onSubmitted: canEdit ? (_) => onSend() : null,
                decoration: const InputDecoration(
                  hintText: 'Ответить клиенту ВКонтакте…',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: canEdit ? onSend : null,
              color: const Color(0xFFF28C28),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}
