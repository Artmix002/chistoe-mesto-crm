typedef DealPeriodMatcher = bool Function(String date);

/// Фильтр дат сделок, общий для таблицы, Kanban и экспорта.
///
/// Старый режим «Август» сохранён для обратной совместимости с листом, но
/// ограничен текущим годом. «Диапазон» использует включительные границы.
bool matchesDealPeriod(
  String value, {
  required String filter,
  required DateTime now,
  DateTime? from,
  DateTime? to,
}) {
  final date = _parseDealDate(value);
  if (date == null) return false;
  final today = DateTime(now.year, now.month, now.day);
  switch (filter) {
    case 'Все':
      return true;
    case 'Август':
      return date.year == now.year && date.month == 8;
    case 'Неделя':
      return !date.isBefore(today.subtract(const Duration(days: 6))) &&
          !date.isAfter(today);
    case 'Месяц':
      return !date.isBefore(today.subtract(const Duration(days: 29))) &&
          !date.isAfter(today);
    case 'Диапазон':
      if (from == null || to == null) return false;
      final start = DateTime(from.year, from.month, from.day);
      final end = DateTime(to.year, to.month, to.day);
      return !date.isBefore(start) && !date.isAfter(end);
    default:
      return false;
  }
}

DateTime? _parseDealDate(String value) {
  final match = RegExp(
    r'^(\d{1,2})\.(\d{1,2})\.(\d{4})',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

/// Фрагмент списка для постраничного отображения.
///
/// [page] всегда находится в допустимом диапазоне, поэтому изменение фильтра
/// или синхронизация не могут оставить интерфейс на несуществующей странице.
class DealPage<T> {
  const DealPage({
    required this.items,
    required this.page,
    required this.pageCount,
  });

  final List<T> items;
  final int page;
  final int pageCount;

  bool get hasPrevious => page > 0;
  bool get hasNext => page + 1 < pageCount;
}

DealPage<T> paginateDeals<T>(
  Iterable<T> values, {
  required int requestedPage,
  int pageSize = 20,
}) {
  if (pageSize <= 0) {
    throw ArgumentError.value(pageSize, 'pageSize', 'Должен быть больше нуля');
  }
  final all = values.toList(growable: false);
  final pageCount = all.isEmpty ? 1 : (all.length / pageSize).ceil();
  final page = requestedPage.clamp(0, pageCount - 1);
  final start = page * pageSize;
  return DealPage<T>(
    items: all.skip(start).take(pageSize).toList(growable: false),
    page: page,
    pageCount: pageCount,
  );
}

/// Нормализованный результат импорта старого листа «Август».
class DealImportResult {
  const DealImportResult({required this.rows, required this.errors});

  final List<List<String>> rows;
  final List<String> errors;
}

double parseLocalizedNumber(String value) {
  var normalized = value
      .replaceAll('\u00a0', '')
      .replaceAll(' ', '')
      .replaceAll(RegExp(r'[^0-9,.-]'), '');
  // В русских таблицах запятая — десятичный разделитель. Если встречаются
  // обе формы, последние разделители считаем десятичными.
  if (normalized.contains(',') && normalized.contains('.')) {
    normalized = normalized.lastIndexOf(',') > normalized.lastIndexOf('.')
        ? normalized.replaceAll('.', '').replaceFirst(',', '.')
        : normalized.replaceAll(',', '');
  } else {
    normalized = normalized.replaceAll(',', '.');
  }
  return double.tryParse(normalized) ?? 0;
}

/// Короткая подпись источника отчисления для журнала бизнес-счёта.
/// Сделка может не содержать клиента, поэтому автомобиль и услуга — наиболее
/// надёжный способ понять, откуда поступила сумма.
String dealReserveLabel(List<String> row) {
  String cell(int index) => index < row.length ? row[index].trim() : '';
  final parts = [
    cell(1),
    cell(3),
  ].where((value) => value.isNotEmpty && value != '-').toList();
  if (parts.isNotEmpty) return parts.join(' — ');
  final client = cell(17);
  return client.isNotEmpty && client != '-'
      ? client
      : 'без указания автомобиля и услуги';
}

/// Компактное денежное представление: целые суммы без `.00`, дробные — без
/// лишних нулей. Это не округляет старые значения с копейками.
String formatDealNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Обновляет только производные итоги ручной сделки.
/// Выплаты работнику и сумма для бизнес-счёта всегда задаются вручную; старые
/// процентные колонки сохраняются только для совместимости со старыми рядами.
List<String> recalculateDealRow(List<String> source) {
  final row = List<String>.from(source);
  if (row.length < 21) row.addAll(List.filled(21 - row.length, ''));
  final income = parseLocalizedNumber(row[5]);
  final expenses = parseLocalizedNumber(row[6]);
  final net = income - expenses;
  final workerPay = parseLocalizedNumber(row[9]);
  final business = parseLocalizedNumber(row[11]);
  final owners = (net - workerPay - business)
      .clamp(0, double.infinity)
      .toDouble();
  row[7] = formatDealNumber(net);
  row[8] = '0';
  row[10] = '0';
  row[9] = formatDealNumber(workerPay);
  row[11] = formatDealNumber(business);
  row[12] = formatDealNumber(owners);
  row[13] = formatDealNumber(parseLocalizedNumber(row[13]));
  row[14] = formatDealNumber(parseLocalizedNumber(row[14]));
  row[15] = formatDealNumber(parseLocalizedNumber(row[15]));
  return row;
}

bool dealCalculationChanged(List<String> before, List<String> after) {
  const calculatedIndexes = [7, 9, 11, 12, 13, 14, 15];
  return calculatedIndexes.any(
    (index) =>
        (index < before.length ? before[index] : '') !=
        (index < after.length ? after[index] : ''),
  );
}

String _legacyCell(List<String> cells, int index) =>
    index < cells.length ? cells[index].trim() : '';

String? _legacyDateAtStart(String value) {
  final match = RegExp(r'^\s*(\d{1,2})\.(\d{1,2})\.(\d{4})').firstMatch(value);
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return '${day.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}.$year';
}

bool _looksLikeLegacyHeader(List<String> cells) {
  final text = cells
      .where((cell) => cell.trim().isNotEmpty)
      .join(' ')
      .toLowerCase();
  const markers = [
    'авто',
    'телефон',
    'услуг',
    'работник',
    'исполн',
    'стоим',
    'выруч',
    'расход',
    'чист',
    'прибыл',
  ];
  return markers.where(text.contains).length >= 2;
}

bool _looksLikeLegacyTotal(List<String> cells) {
  final text = cells
      .where((cell) => cell.trim().isNotEmpty)
      .join(' ')
      .toLowerCase();
  return text.contains('итого') ||
      text.contains('всего') ||
      text.startsWith('итог') ||
      _legacyCell(cells, 0).toLowerCase().startsWith('сумма');
}

/// Imports the old grouped sheet while ignoring its service rows. A deal only
/// requires the core columns through `Чистая прибыль`; payout columns are
/// optional and default to zero when omitted by Google Sheets.
DealImportResult importLegacyDealRows(Iterable<List<String>> source) {
  final rows = <List<String>>[];
  final errors = <String>[];
  var date = '';
  var rowNumber = 1;
  for (final cells in source) {
    final a = cells.map((cell) => cell.trim()).toList();
    if (a.isEmpty || a.every((cell) => cell.isEmpty)) {
      rowNumber++;
      continue;
    }
    final day = _legacyDateAtStart(_legacyCell(a, 0));
    if (day != null) date = day;
    if (_looksLikeLegacyHeader(a) || _looksLikeLegacyTotal(a)) {
      rowNumber++;
      continue;
    }

    // В старом листе справа от сделок расположен независимый финансовый
    // блок: даты, выручка и расходы по дням. У таких строк первые колонки
    // блока сделок пустые, поэтому это не незаполненная сделка и не ошибка
    // импорта.
    final legacyDealAreaIsEmpty = a.take(11).every((cell) => cell.isEmpty);
    // Иногда в листе остаётся только финансовая заготовка: суммы уже
    // проставлены, но реквизиты самой услуги (авто, услуга, исполнитель)
    // удалены. Такая строка не может быть восстановлена как сделка и не
    // должна засорять уведомление об импорте.
    final legacyDealTemplate =
        _legacyCell(a, 0).isEmpty &&
        _legacyCell(a, 2).isEmpty &&
        _legacyCell(a, 3).isEmpty;
    if (legacyDealAreaIsEmpty || legacyDealTemplate) {
      rowNumber++;
      continue;
    }

    final car = _legacyCell(a, 0);
    final phone = _legacyCell(a, 1);
    final service = _legacyCell(a, 2);
    final worker = _legacyCell(a, 3);
    final priceText = _legacyCell(a, 4);
    final price = parseLocalizedNumber(priceText);
    // A date row carries the date for following records and is not a deal.
    if (day != null && service.isEmpty && priceText.isEmpty) {
      rowNumber++;
      continue;
    }

    if (car.isNotEmpty && service.isNotEmpty && price > 0 && date.isNotEmpty) {
      final exp = parseLocalizedNumber(_legacyCell(a, 5));
      final netText = _legacyCell(a, 6);
      final net = netText.isEmpty ? price - exp : parseLocalizedNumber(netText);
      // В старом листе после чистой суммы расположена вручную внесённая
      // сумма для бизнес-счёта, затем выплаты Диме, Артёму и Егору.
      final business = parseLocalizedNumber(_legacyCell(a, 7));
      final dima = parseLocalizedNumber(_legacyCell(a, 8));
      final artem = parseLocalizedNumber(_legacyCell(a, 9));
      final egor = parseLocalizedNumber(_legacyCell(a, 10));
      rows.add([
        date,
        car,
        phone,
        service,
        worker,
        formatDealNumber(price),
        formatDealNumber(exp),
        formatDealNumber(net),
        '0',
        formatDealNumber(egor),
        '0',
        formatDealNumber(business),
        formatDealNumber(dima + artem),
        formatDealNumber(dima),
        formatDealNumber(artem),
        formatDealNumber(egor),
        'Выполнен',
      ]);
    } else {
      final reason = car.isEmpty
          ? 'не указан автомобиль'
          : service.isEmpty
          ? 'не указана услуга'
          : date.isEmpty
          ? 'не найдена дата блока'
          : 'не распознана стоимость в колонке «Стоимость»';
      errors.add('Строка $rowNumber: $reason');
    }
    rowNumber++;
  }
  return DealImportResult(rows: rows, errors: errors);
}

List<List<String>> filterDeals(
  Iterable<List<String>> rows, {
  required DealPeriodMatcher matchesPeriod,
  String? status,
}) => rows.where((row) {
  if (!matchesPeriod(row.isNotEmpty ? row[0] : '')) return false;
  return status == null || (row.length > 16 && row[16] == status);
}).toList();

String dealsToCsv(List<String> headers, Iterable<List<String>> rows) {
  String quote(String value) => '"${value.replaceAll('"', '""')}"';
  return [
    headers.map(quote).join(','),
    ...rows.map(
      (row) => List.generate(
        headers.length,
        (index) => quote(index < row.length ? row[index] : ''),
      ).join(','),
    ),
  ].join('\n');
}
