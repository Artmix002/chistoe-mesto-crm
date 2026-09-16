import 'package:flutter/material.dart';

import 'calendar_components.dart';

enum CalendarAppointmentAction { move, arrived, missed }

class CalendarAppointmentDialog extends StatelessWidget {
  const CalendarAppointmentDialog({
    super.key,
    required this.event,
    required this.timeLabel,
    required this.canEdit,
    required this.mainTextColor,
    required this.mutedTextColor,
  });

  final Map<String, dynamic> event;
  final String Function(Map<String, dynamic> event) timeLabel;
  final bool canEdit;
  final Color mainTextColor;
  final Color mutedTextColor;

  String _field(String key, String fallback) {
    final private =
        ((event['extendedProperties'] as Map?)?['private'] as Map?) ?? const {};
    final value = private[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        const Icon(Icons.event_note, color: Color(0xFFF28C28)),
        const SizedBox(width: 10),
        Expanded(child: Text(event['summary']?.toString() ?? 'Запись')),
      ],
    ),
    content: SizedBox(
      width: 470,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(Icons.schedule, 'Дата и время', timeLabel(event)),
            _row(Icons.person_outline, 'Клиент', _field('name', 'Не указан')),
            _row(Icons.phone_outlined, 'Телефон', _field('phone', 'Не указан')),
            _row(
              Icons.directions_car_outlined,
              'Автомобиль',
              _field('car', 'Не указан'),
            ),
            _row(
              Icons.engineering_outlined,
              'Исполнитель',
              _field('performer', 'Не указан'),
            ),
            _row(
              Icons.design_services_outlined,
              'Услуга',
              _field('service', event['summary']?.toString() ?? 'Не указана'),
            ),
            _row(
              Icons.payments_outlined,
              'Стоимость',
              _field('cost', 'Не указана'),
            ),
            _row(
              Icons.source_outlined,
              'Источник',
              _field('source', 'Не указан'),
            ),
            _row(Icons.flag_outlined, 'Статус', _field('status', 'Записан')),
            if (_field('note', '').isNotEmpty)
              _row(Icons.notes_outlined, 'Комментарий', _field('note', '')),
          ],
        ),
      ),
    ),
    actions: [
      if (canEdit) ...[
        TextButton(
          onPressed: () =>
              Navigator.pop(context, CalendarAppointmentAction.move),
          child: const Text('Перенести'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, CalendarAppointmentAction.arrived),
          child: const Text('Приехал'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, CalendarAppointmentAction.missed),
          child: const Text('Не приехал'),
        ),
      ],
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
    ],
  );

  Widget _row(IconData icon, String label, String value) =>
      CalendarAppointmentInfoRow(
        icon: icon,
        label: label,
        value: value,
        mutedTextColor: mutedTextColor,
        mainTextColor: mainTextColor,
      );
}
