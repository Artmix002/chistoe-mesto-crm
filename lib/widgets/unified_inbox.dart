import 'package:flutter/material.dart';

class UnifiedDialog {
  const UnifiedDialog({
    required this.platform,
    required this.id,
    required this.name,
    required this.preview,
    required this.unread,
    required this.onTap,
    this.onLongPress,
    this.assignee,
    this.tags = const [],
  });

  final String platform;
  final String id;
  final String name;
  final String preview;
  final bool unread;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? assignee;
  final List<String> tags;
}

class UnifiedInboxList extends StatelessWidget {
  const UnifiedInboxList({
    super.key,
    required this.dialogs,
    required this.mainTextColor,
    required this.mutedTextColor,
    required this.cardBorderColor,
  });

  final List<UnifiedDialog> dialogs;
  final Color mainTextColor;
  final Color mutedTextColor;
  final Color cardBorderColor;

  @override
  Widget build(BuildContext context) {
    if (dialogs.isEmpty) {
      return Center(
        child: Text(
          'Диалогов пока нет. Подключите канал или обновите данные.',
          style: TextStyle(color: mutedTextColor),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: dialogs.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: cardBorderColor),
      itemBuilder: (_, index) {
        final dialog = dialogs[index];
        return ListTile(
          dense: true,
          leading: Stack(
            alignment: Alignment.topRight,
            children: [
              CircleAvatar(radius: 17, child: Text(dialog.platform[0])),
              const Icon(Icons.circle, size: 9, color: Color(0xFFF28C28)),
            ],
          ),
          title: Text(
            dialog.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: mainTextColor, fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${dialog.platform} • ${dialog.preview}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: mutedTextColor, fontSize: 11),
              ),
              if ((dialog.assignee ?? '').isNotEmpty || dialog.tags.isNotEmpty)
                Text(
                  [
                    if ((dialog.assignee ?? '').isNotEmpty)
                      '↳ ${dialog.assignee}',
                    if (dialog.tags.isNotEmpty) '#${dialog.tags.join(' #')}',
                  ].join('  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: mutedTextColor, fontSize: 10),
                ),
            ],
          ),
          onTap: dialog.onTap,
          onLongPress: dialog.onLongPress,
          trailing: Text(
            dialog.unread ? '●' : '',
            style: TextStyle(color: mutedTextColor, fontSize: 10),
          ),
        );
      },
    );
  }
}
