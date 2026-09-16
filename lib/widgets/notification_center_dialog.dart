import 'package:flutter/material.dart';

import '../app_notification.dart';

/// Диалог центра уведомлений. Хранение и отметка прочтения остаются у
/// владельца состояния, поэтому виджет пригоден для любого экрана CRM.
class NotificationCenterDialog extends StatelessWidget {
  const NotificationCenterDialog({
    super.key,
    required this.notifications,
    this.onClear,
  });

  final List<CrmNotification> notifications;
  final Future<void> Function()? onClear;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Уведомления'),
    content: SizedBox(
      width: 560,
      height: 420,
      child: notifications.isEmpty
          ? const Center(child: Text('Новых уведомлений нет'))
          : ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final item = notifications[index];
                final color = switch (item.level) {
                  CrmNotificationLevel.success => Colors.green,
                  CrmNotificationLevel.warning => Colors.orange,
                  CrmNotificationLevel.error => Colors.red,
                  CrmNotificationLevel.info => const Color(0xFFF28C28),
                };
                final icon = switch (item.level) {
                  CrmNotificationLevel.success => Icons.check_circle_outline,
                  CrmNotificationLevel.warning => Icons.warning_amber_outlined,
                  CrmNotificationLevel.error => Icons.error_outline,
                  CrmNotificationLevel.info => Icons.info_outline,
                };
                return ListTile(
                  leading: Icon(icon, color: color),
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.message}\n${item.createdAt.replaceFirst('T', ' ').split('.').first}',
                  ),
                  isThreeLine: true,
                );
              },
            ),
    ),
    actions: [
      if (notifications.isNotEmpty && onClear != null)
        TextButton(
          onPressed: () async {
            await onClear!();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Очистить'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
    ],
  );
}
