import 'package:flutter/material.dart';

class CalendarConnectionPanel extends StatelessWidget {
  const CalendarConnectionPanel({
    super.key,
    required this.status,
    required this.loading,
    required this.canConfigure,
    required this.surfaceColor,
    required this.borderColor,
    required this.onConnect,
    this.hasClientSecret = false,
    this.onConfigureSecret,
  });

  final String? status;
  final bool loading;
  final bool canConfigure;
  final Color surfaceColor;
  final Color borderColor;
  final VoidCallback onConnect;
  final bool hasClientSecret;
  final VoidCallback? onConfigureSecret;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 460,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, color: Color(0xFFF28C28), size: 46),
          const SizedBox(height: 14),
          const Text(
            'Подключите Google Календарь',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            status ?? 'После подключения здесь появится календарь записей.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: loading || !canConfigure ? null : onConnect,
            icon: const Icon(Icons.link),
            label: const Text('Подключить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF28C28),
              foregroundColor: Colors.white,
            ),
          ),
          if (onConfigureSecret != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: loading || !canConfigure ? null : onConfigureSecret,
              icon: Icon(hasClientSecret ? Icons.key : Icons.key_outlined),
              label: Text(
                hasClientSecret
                    ? 'Изменить client secret'
                    : 'Добавить client secret',
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

enum CalendarSettingsAction { choose, refresh, reconnect, configureSecret }

class CalendarSettingsDialog extends StatelessWidget {
  const CalendarSettingsDialog({
    super.key,
    required this.calendarName,
    required this.status,
    required this.canConfigure,
    this.hasClientSecret = false,
  });

  final String calendarName;
  final String? status;
  final bool canConfigure;
  final bool hasClientSecret;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Row(
      children: [
        Icon(Icons.settings, color: Color(0xFFF28C28)),
        SizedBox(width: 10),
        Text('Настройки календаря'),
      ],
    ),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Подключённый календарь',
            style: TextStyle(color: Color(0xFF737984), fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            calendarName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: canConfigure
                ? () => Navigator.pop(context, CalendarSettingsAction.choose)
                : null,
            icon: const Icon(Icons.calendar_today),
            label: const Text('Выбрать календарь'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pop(context, CalendarSettingsAction.refresh),
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить записи'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: canConfigure
                ? () => Navigator.pop(context, CalendarSettingsAction.reconnect)
                : null,
            icon: const Icon(Icons.link),
            label: const Text('Подключить заново'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: canConfigure
                ? () => Navigator.pop(
                    context,
                    CalendarSettingsAction.configureSecret,
                  )
                : null,
            icon: Icon(hasClientSecret ? Icons.key : Icons.key_outlined),
            label: Text(
              hasClientSecret
                  ? 'Изменить client secret'
                  : 'Добавить client secret',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            status ?? '',
            style: const TextStyle(color: Color(0xFF737984), fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Готово'),
      ),
    ],
  );
}
