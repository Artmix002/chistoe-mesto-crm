import 'package:flutter/material.dart';

/// Представление диалогов Telegram. Получает данные и действия извне: сетевые
/// запросы и очередь повторной отправки остаются на уровне Dashboard.
class TelegramInbox extends StatelessWidget {
  const TelegramInbox({
    super.key,
    required this.chats,
    required this.selectedChat,
    required this.loading,
    required this.replyController,
    required this.canEdit,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
    required this.titleOf,
    required this.onOpenChat,
    required this.onSend,
  });

  final List<Map<String, dynamic>> chats;
  final Map<String, dynamic>? selectedChat;
  final bool loading;
  final TextEditingController replyController;
  final bool canEdit;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;
  final String Function(Map<String, dynamic> chat) titleOf;
  final ValueChanged<Map<String, dynamic>> onOpenChat;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 980),
    height: 420,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        if (compact) {
          return Column(
            children: [
              SizedBox(height: 112, child: _chatList()),
              Divider(height: 20, color: borderColor),
              Expanded(child: _conversation()),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 300, child: _chatList()),
            VerticalDivider(width: 24, color: borderColor),
            Expanded(child: _conversation()),
          ],
        );
      },
    ),
  );

  Widget _chatList() {
    if (chats.isEmpty) {
      return Center(
        child: Text(
          loading ? 'Загружаем…' : 'Чатов Telegram пока нет',
          style: TextStyle(color: mutedTextColor),
        ),
      );
    }
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final selected =
            chat['id']?.toString() == selectedChat?['id']?.toString();
        return ListTile(
          dense: true,
          selected: selected,
          selectedTileColor: const Color(0x22F28C28),
          title: Text(titleOf(chat)),
          onTap: () => onOpenChat(chat),
        );
      },
    );
  }

  Widget _conversation() {
    final chat = selectedChat;
    if (chat == null) {
      return Center(
        child: Text(
          'Выберите чат Telegram',
          style: TextStyle(color: mutedTextColor),
        ),
      );
    }
    final messages = (chat['messages'] as List? ?? const [])
        .whereType<Map>()
        .toList(growable: false);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            titleOf(chat),
            style: TextStyle(color: mainTextColor, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return Align(
                alignment: message['out'] == true
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(message['text']?.toString() ?? 'Вложение'),
                ),
              );
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: replyController,
                onSubmitted: (_) => onSend(),
                enabled: canEdit,
                decoration: const InputDecoration(
                  hintText: 'Ответить в Telegram',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Отправить в Telegram',
              onPressed: canEdit ? onSend : null,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}
