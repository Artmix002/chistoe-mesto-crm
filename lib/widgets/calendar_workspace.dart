import 'package:flutter/material.dart';

/// Общая оболочка календаря: шапка, навигация, режимы, поиск и список
/// записей выбранного дня. Содержимое месяца/недели/дня передаётся снаружи,
/// чтобы API календаря и состояние синхронизации оставались в Dashboard.
class CalendarWorkspace extends StatelessWidget {
  const CalendarWorkspace({
    super.key,
    required this.calendarName,
    required this.viewMode,
    required this.viewDate,
    required this.selectedDay,
    required this.selectedDayEventCount,
    required this.canEdit,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
    required this.calendarBody,
    required this.selectedDayTiles,
    required this.onNewAppointment,
    required this.onOpenSettings,
    required this.onMove,
    required this.onToday,
    required this.onViewModeChanged,
    required this.onSearchChanged,
  });

  final String calendarName;
  final String viewMode;
  final DateTime viewDate;
  final DateTime selectedDay;
  final int selectedDayEventCount;
  final bool canEdit;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;
  final Widget calendarBody;
  final List<Widget> selectedDayTiles;
  final VoidCallback onNewAppointment;
  final VoidCallback onOpenSettings;
  final ValueChanged<int> onMove;
  final VoidCallback onToday;
  final ValueChanged<String> onViewModeChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: borderColor),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    color: Color(0xFFF28C28),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Календарь записей',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: mainTextColor,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Настройки календаря',
                    onPressed: onOpenSettings,
                    icon: Icon(Icons.settings_outlined, color: mutedTextColor),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Text(
                  calendarName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: mutedTextColor),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canEdit ? onNewAppointment : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Новая запись'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF28C28),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            ] else
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    color: Color(0xFFF28C28),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Календарь записей',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: mainTextColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      calendarName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: mutedTextColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: canEdit ? onNewAppointment : null,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Новая запись'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF28C28),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Настройки календаря',
                        onPressed: onOpenSettings,
                        icon: Icon(
                          Icons.settings_outlined,
                          color: mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 10),
            const Divider(),
            Row(
              children: [
                IconButton(
                  tooltip: 'Назад',
                  onPressed: () => onMove(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _periodTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: mainTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Вперёд',
                  onPressed: () => onMove(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 6),
                TextButton(onPressed: onToday, child: const Text('Сегодня')),
              ],
            ),
            const SizedBox(height: 10),
            if (compact) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final mode in const [
                      'Месяц',
                      'Неделя',
                      'День',
                      'Список',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(mode),
                          selected: viewMode == mode,
                          onSelected: (_) => onViewModeChanged(mode),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Поиск по записям',
                  prefixIcon: Icon(Icons.search, size: 19),
                  border: OutlineInputBorder(),
                ),
              ),
            ] else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in const [
                    'Месяц',
                    'Неделя',
                    'День',
                    'Список',
                  ])
                    ChoiceChip(
                      label: Text(mode),
                      selected: viewMode == mode,
                      onSelected: (_) => onViewModeChanged(mode),
                    ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      onChanged: onSearchChanged,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Поиск по записям',
                        prefixIcon: Icon(Icons.search, size: 19),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            calendarBody,
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Icon(
                  Icons.today_outlined,
                  size: 18,
                  color: Color(0xFFE47B1B),
                ),
                Text(
                  'Выбрано: ${_formatDay(selectedDay)} · Записей: $selectedDayEventCount',
                  style: TextStyle(
                    color: mainTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: canEdit ? onNewAppointment : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Запись на этот день'),
                ),
              ],
            ),
            if (selectedDayTiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'На выбранный день записей нет.',
                  style: TextStyle(color: mutedTextColor),
                ),
              )
            else
              ...selectedDayTiles,
          ],
        );
      },
    ),
  );

  String get _periodTitle {
    if (viewMode == 'Месяц') {
      return '${_russianMonthName(viewDate.month)} ${viewDate.year}';
    }
    if (viewMode == 'Неделя') return 'Неделя ${_formatDay(selectedDay)}';
    if (viewMode == 'День') return _formatDay(selectedDay);
    return 'Записи';
  }
}

String _formatDay(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';

String _russianMonthName(int month) => const [
  'январь',
  'февраль',
  'март',
  'апрель',
  'май',
  'июнь',
  'июль',
  'август',
  'сентябрь',
  'октябрь',
  'ноябрь',
  'декабрь',
][month - 1];
