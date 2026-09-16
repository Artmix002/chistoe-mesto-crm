bool intervalsOverlap(
  DateTime start,
  DateTime end,
  DateTime otherStart,
  DateTime otherEnd,
) => start.isBefore(otherEnd) && end.isAfter(otherStart);

/// Напоминание отправляется один раз в окне от двух часов до десяти минут
/// перед началом: запуск после открытия приложения не создаёт просроченных
/// уведомлений.
bool isAppointmentReminderDue({
  required DateTime start,
  required DateTime now,
}) =>
    !now.isBefore(start.subtract(const Duration(hours: 2))) &&
    now.isBefore(start.subtract(const Duration(minutes: 10)));

bool isCancellationReasonValid(String value) => value.trim().isNotEmpty;

double calculateServiceTemplateDuration(
  Iterable<String> serviceNames,
  Map<String, double> templates,
) => serviceNames.fold(0, (sum, name) => sum + (templates[name.trim()] ?? 0));

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime? calendarEventLocalDate(Map<String, dynamic> event) {
  final start = (event['start'] as Map?) ?? {};
  final raw = (start['dateTime'] ?? start['date'] ?? '').toString();
  if (raw.isEmpty) return null;
  return googleToMoscow(raw, DateTime.now());
}

List<Map<String, dynamic>> filterCalendarEvents(
  Iterable<Map<String, dynamic>> events,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return events.toList(growable: false);
  return events
      .where(
        (event) => '${event['summary'] ?? ''} ${event['description'] ?? ''}'
            .toLowerCase()
            .contains(normalized),
      )
      .toList(growable: false);
}

List<Map<String, dynamic>> calendarEventsForDay(
  Iterable<Map<String, dynamic>> events,
  DateTime day,
) => events
    .where((event) {
      final date = calendarEventLocalDate(event);
      return date != null && isSameCalendarDay(date, day);
    })
    .toList(growable: false);

String russianMonthName(DateTime date) => const [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
][date.month - 1];

DateTime googleToMoscow(String value, DateTime fallback) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return fallback;
  // Возвращаем именно локальный DateTime со стендовым временем Москвы, а не
  // UTC-объект со сдвинутым часом. Так сравнение с выбранным в UI временем не
  // получает скрытую разницу часовых поясов.
  final moscow = parsed.toUtc().add(const Duration(hours: 3));
  return DateTime(
    moscow.year,
    moscow.month,
    moscow.day,
    moscow.hour,
    moscow.minute,
    moscow.second,
    moscow.millisecond,
    moscow.microsecond,
  );
}

DateTime? calendarEventStart(Map<String, dynamic> event) {
  final start = event['start'] as Map?;
  final raw = (start?['dateTime'] ?? start?['date'])?.toString();
  if (raw == null || raw.isEmpty) return null;
  return googleToMoscow(raw, DateTime.now());
}

bool hasCalendarConflict(
  Iterable<Map<String, dynamic>> events,
  DateTime start,
  DateTime end, {
  String? ignoreId,
}) {
  for (final event in events) {
    if (ignoreId != null && event['id']?.toString() == ignoreId) continue;
    final otherStart = calendarEventStart(event);
    if (otherStart == null) continue;
    final eventEnd = event['end'] as Map?;
    final endRaw = (eventEnd?['dateTime'] ?? eventEnd?['date'])?.toString();
    final otherEnd = endRaw == null
        ? otherStart.add(const Duration(hours: 1))
        : googleToMoscow(endRaw, otherStart.add(const Duration(hours: 1)));
    if (intervalsOverlap(start, end, otherStart, otherEnd)) return true;
  }
  return false;
}

/// Причина пересечения записи. `time` означает, что одна из записей ещё не
/// привязана к мастеру или автомобилю, поэтому для сохранности расписания она
/// блокирует параллельную запись.
enum CalendarConflictKind { time, performer, vehicle }

CalendarConflictKind? findCalendarResourceConflict(
  Iterable<Map<String, dynamic>> events,
  DateTime start,
  DateTime end, {
  String? ignoreId,
  String performer = '',
  String vehicleId = '',
  String vehicle = '',
}) {
  final candidatePerformers = _resourceNames(performer);
  final candidateVehicleId = vehicleId.trim();
  final candidateVehicle = _resourceValue(vehicle);
  for (final event in events) {
    if (ignoreId != null && event['id']?.toString() == ignoreId) continue;
    final otherStart = calendarEventStart(event);
    if (otherStart == null) continue;
    final eventEnd = event['end'] as Map?;
    final endRaw = (eventEnd?['dateTime'] ?? eventEnd?['date'])?.toString();
    final otherEnd = endRaw == null
        ? otherStart.add(const Duration(hours: 1))
        : googleToMoscow(endRaw, otherStart.add(const Duration(hours: 1)));
    if (!intervalsOverlap(start, end, otherStart, otherEnd)) continue;

    final private =
        ((event['extendedProperties'] as Map?)?['private'] as Map?) ?? const {};
    final eventPerformers = _resourceNames(
      private['performer']?.toString() ?? '',
    );
    final eventVehicleId = private['vehicleId']?.toString().trim() ?? '';
    final eventVehicle = _resourceValue(private['car']?.toString() ?? '');
    final hasCandidateResource =
        candidatePerformers.isNotEmpty ||
        candidateVehicleId.isNotEmpty ||
        candidateVehicle.isNotEmpty;
    final hasEventResource =
        eventPerformers.isNotEmpty ||
        eventVehicleId.isNotEmpty ||
        eventVehicle.isNotEmpty;
    if (!hasCandidateResource || !hasEventResource) {
      return CalendarConflictKind.time;
    }
    if (candidatePerformers.intersection(eventPerformers).isNotEmpty) {
      return CalendarConflictKind.performer;
    }
    if (candidateVehicleId.isNotEmpty &&
        eventVehicleId.isNotEmpty &&
        candidateVehicleId == eventVehicleId) {
      return CalendarConflictKind.vehicle;
    }
    if (candidateVehicle.isNotEmpty &&
        eventVehicleId.isEmpty &&
        candidateVehicle == eventVehicle) {
      return CalendarConflictKind.vehicle;
    }
  }
  return null;
}

Set<String> _resourceNames(String value) => value
    .split(RegExp(r'[,;/&\n]+'))
    .map(_resourceValue)
    .where((name) => name.isNotEmpty)
    .toSet();

String _resourceValue(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String moscowIso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}T${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
