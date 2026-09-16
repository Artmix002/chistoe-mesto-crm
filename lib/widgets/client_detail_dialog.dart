import 'package:flutter/material.dart';

import '../models.dart';

class ClientDetailDialog extends StatelessWidget {
  const ClientDetailDialog({
    super.key,
    required this.client,
    required this.relatedDeals,
    required this.relatedAppointments,
    required this.statuses,
    required this.appointmentTime,
    required this.canEditDeals,
    required this.canEditCalendar,
    required this.canEditClients,
    required this.canContact,
    this.onStatusChanged,
    this.onCall,
    this.onMessage,
    this.onCreateDeal,
    this.onCreateAppointment,
    this.onEdit,
  });

  final Client client;
  final List<List<String>> relatedDeals;
  final List<Map<String, dynamic>> relatedAppointments;
  final List<String> statuses;
  final String Function(Map<String, dynamic>) appointmentTime;
  final bool canEditDeals;
  final bool canEditCalendar;
  final bool canEditClients;
  final bool canContact;
  final Future<void> Function(String status)? onStatusChanged;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final VoidCallback? onCreateDeal;
  final VoidCallback? onCreateAppointment;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(client.name),
    content: SizedBox(
      width: 560,
      height: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Телефоны: ${client.phones.join(' • ')}'),
            Text('Автомобили: ${client.cars.join(' • ')}'),
            if (client.telegramChatId.isNotEmpty)
              Text('Telegram: ${client.telegramChatId}'),
            if (client.vkPeerId.isNotEmpty) Text('VK: ${client.vkPeerId}'),
            if (client.source.isNotEmpty) Text('Источник: ${client.source}'),
            Row(
              children: [
                const Text('Статус: '),
                DropdownButton<String>(
                  value: statuses.contains(client.status)
                      ? client.status
                      : statuses.first,
                  items: statuses
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: !canEditDeals || onStatusChanged == null
                      ? null
                      : (value) {
                          if (value != null) onStatusChanged!(value);
                        },
                ),
              ],
            ),
            if (client.note.isNotEmpty) Text('Комментарий: ${client.note}'),
            const Divider(),
            Text(
              'История сделок (${relatedDeals.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (relatedDeals.isEmpty) const Text('Сделок нет'),
            ...relatedDeals
                .take(10)
                .map(
                  (row) => ListTile(
                    dense: true,
                    title: Text(row.length > 3 ? row[3] : 'Услуга'),
                    subtitle: Text(
                      '${row.isNotEmpty ? row[0] : ''} • ${row.length > 5 ? row[5] : ''} ₽ • ${row.length > 16 ? row[16] : ''}',
                    ),
                  ),
                ),
            Text(
              'Записи (${relatedAppointments.length})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (relatedAppointments.isEmpty) const Text('Записей нет'),
            ...relatedAppointments
                .take(10)
                .map(
                  (event) => ListTile(
                    dense: true,
                    title: Text(event['summary']?.toString() ?? 'Запись'),
                    subtitle: Text(appointmentTime(event)),
                  ),
                ),
            const Divider(),
            const Text(
              'История автомобиля',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (client.carHistory.isEmpty) const Text('Нет изменений'),
            ...client.carHistory.map(Text.new),
            const SizedBox(height: 8),
            const Text(
              'История обращений',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (client.interactionHistory.isEmpty) const Text('Нет обращений'),
            ...client.interactionHistory.take(10).map(Text.new),
          ],
        ),
      ),
    ),
    actions: [
      OutlinedButton.icon(
        onPressed: !canContact || client.phone.trim().isEmpty ? null : onCall,
        icon: const Icon(Icons.call_outlined),
        label: const Text('Позвонить'),
      ),
      OutlinedButton.icon(
        onPressed: !canContact || client.phone.trim().isEmpty
            ? null
            : onMessage,
        icon: const Icon(Icons.sms_outlined),
        label: const Text('Написать'),
      ),
      OutlinedButton.icon(
        onPressed: canEditDeals ? onCreateDeal : null,
        icon: const Icon(Icons.handshake_outlined),
        label: const Text('Новая сделка'),
      ),
      OutlinedButton.icon(
        onPressed: canEditCalendar ? onCreateAppointment : null,
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Новая запись'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
      ElevatedButton(
        onPressed: canEditClients ? onEdit : null,
        child: const Text('Редактировать'),
      ),
    ],
  );
}
