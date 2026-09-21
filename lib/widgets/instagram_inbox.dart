import 'package:flutter/material.dart';

class InstagramInbox extends StatelessWidget {
  const InstagramInbox({
    super.key,
    required this.conversations,
    required this.selectedConversation,
    required this.messages,
    required this.loading,
    required this.replyController,
    required this.canEdit,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
    required this.titleOf,
    required this.onOpenConversation,
    required this.onSend,
  });

  final List<Map<String, dynamic>> conversations;
  final Map<String, dynamic>? selectedConversation;
  final List<Map<String, dynamic>> messages;
  final bool loading;
  final TextEditingController replyController;
  final bool canEdit;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;
  final String Function(Map<String, dynamic>) titleOf;
  final ValueChanged<Map<String, dynamic>> onOpenConversation;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final selected = selectedConversation;
    return Container(
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
          final conversationList = conversations.isEmpty
              ? Center(
                  child: Text(
                    loading ? 'Загружаем…' : 'Диалогов Instagram пока нет',
                    style: TextStyle(color: mutedTextColor),
                  ),
                )
              : ListView(
                  children: conversations
                      .map(
                        (item) => ListTile(
                          title: Text(titleOf(item)),
                          onTap: () => onOpenConversation(item),
                        ),
                      )
                      .toList(growable: false),
                );
          final conversation = selected == null
              ? Center(
                  child: Text(
                    'Выберите диалог Instagram',
                    style: TextStyle(color: mutedTextColor),
                  ),
                )
              : Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        titleOf(selected),
                        style: TextStyle(
                          color: mainTextColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: messages.isEmpty
                          ? Center(
                              child: Text(
                                loading ? 'Загружаем…' : 'Сообщений пока нет',
                                style: TextStyle(color: mutedTextColor),
                              ),
                            )
                          : ListView(
                              children: messages
                                  .map(
                                    (message) => Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        message['message']?.toString() ??
                                            'Вложение',
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: replyController,
                            enabled: canEdit,
                            onSubmitted: canEdit ? (_) => onSend() : null,
                            decoration: const InputDecoration(
                              hintText: 'Ответить в Instagram',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: canEdit ? onSend : null,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                );
          if (compact) {
            return Column(
              children: [
                SizedBox(height: 112, child: conversationList),
                Divider(height: 20, color: borderColor),
                Expanded(child: conversation),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(width: 300, child: conversationList),
              VerticalDivider(width: 24, color: borderColor),
              Expanded(child: conversation),
            ],
          );
        },
      ),
    );
  }
}
