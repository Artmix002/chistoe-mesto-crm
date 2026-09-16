import 'package:flutter/material.dart';

class CalendarAppointmentInfoRow extends StatelessWidget {
  const CalendarAppointmentInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.mutedTextColor,
    required this.mainTextColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color mutedTextColor;
  final Color mainTextColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: const Color(0xFFF28C28)),
        const SizedBox(width: 10),
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: TextStyle(color: mutedTextColor, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: mainTextColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class CalendarEventTile extends StatelessWidget {
  const CalendarEventTile({
    super.key,
    required this.event,
    required this.selectedDay,
    required this.mainTextColor,
    required this.mutedTextColor,
    required this.canEdit,
    required this.timeLabel,
    required this.onOpen,
    required this.onEdit,
    required this.onCancel,
    this.onRepeat,
    required this.onMoveToDay,
  });

  final Map<String, dynamic> event;
  final DateTime selectedDay;
  final Color mainTextColor;
  final Color mutedTextColor;
  final bool canEdit;
  final String Function(Map<String, dynamic> event) timeLabel;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onCancel;
  final ValueChanged<Map<String, dynamic>>? onRepeat;
  final void Function(Map<String, dynamic> event, DateTime day) onMoveToDay;

  @override
  Widget build(BuildContext context) =>
      LongPressDraggable<Map<String, dynamic>>(
        data: event,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 320,
            child: Card(child: ListTile(title: Text(_title))),
          ),
        ),
        child: DragTarget<Map<String, dynamic>>(
          onAcceptWithDetails: canEdit
              ? (details) => onMoveToDay(details.data, selectedDay)
              : null,
          builder: (_, _, _) => InkWell(
            onTap: () => onOpen(event),
            borderRadius: BorderRadius.circular(8),
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: Colors.transparent,
              elevation: 0,
              child: ListTile(
                onTap: () => onOpen(event),
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF28C28),
                  child: Icon(Icons.event, color: Colors.white),
                ),
                title: Text(
                  _title,
                  style: TextStyle(
                    color: mainTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  timeLabel(event),
                  style: TextStyle(color: mutedTextColor),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Открыть карточку',
                      onPressed: () => onOpen(event),
                      icon: const Icon(Icons.open_in_new),
                    ),
                    IconButton(
                      tooltip: 'Изменить',
                      onPressed: canEdit ? () => onEdit(event) : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Удалить',
                      onPressed: canEdit ? () => onCancel(event) : null,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFC94343),
                      ),
                    ),
                    if (onRepeat != null)
                      IconButton(
                        tooltip: 'Повторить через неделю',
                        onPressed: canEdit ? () => onRepeat!(event) : null,
                        icon: const Icon(Icons.copy_outlined),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  String get _title {
    final title = event['summary']?.toString() ?? '';
    return title.isEmpty ? 'Без названия' : title;
  }
}
