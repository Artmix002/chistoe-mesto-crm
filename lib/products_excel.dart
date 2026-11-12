import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import 'models.dart';

const productExcelHeaders = [
  'ID',
  'Артикул',
  'Название',
  'Категория',
  'Размер',
  'Количество',
  'Себестоимость',
  'Цена маркетплейса',
  'Ссылка',
  'Маркетплейс',
  'Скидка %',
  'Моя цена',
  'Статус',
  'Цена продажи',
  'Поставка №',
  'Поставка',
  'Стоимость поставки',
  'Фото',
];

String productStatusLabel(String status) => switch (status) {
  'sold' => 'Продан',
  'shipped' => 'Отправлен',
  'returned' => 'Возврат',
  'ready' => 'Готов к продаже',
  _ => 'В наличии',
};

String productStatusValue(String label) => switch (label.trim().toLowerCase()) {
  'продан' => 'sold',
  'отправлен' => 'shipped',
  'возврат' => 'returned',
  'готов к продаже' => 'ready',
  _ => 'in_stock',
};

List<int> buildProductsExcel(
  List<Product> products,
  List<Delivery> deliveries,
) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.tables.keys.first;
  if (defaultSheet != 'Товары') {
    excel.rename(defaultSheet, 'Товары');
  }
  final sheet = excel['Товары'];
  sheet.appendRow(
    [for (final header in productExcelHeaders) TextCellValue(header)],
  );
  final numbers = {for (final d in deliveries) d.id: d.number};
  final deliveryById = {for (final d in deliveries) d.id: d};
  for (final p in products) {
    sheet.appendRow([
      TextCellValue(p.id),
      TextCellValue(p.sku),
      TextCellValue(p.name),
      TextCellValue(p.category),
      TextCellValue(p.size),
      DoubleCellValue(p.quantity),
      p.costPrice == null ? TextCellValue('') : DoubleCellValue(p.costPrice!),
      DoubleCellValue(p.marketplacePrice),
      TextCellValue(p.marketplaceUrl),
      TextCellValue(p.marketplace),
      DoubleCellValue(p.discountPercent),
      DoubleCellValue(p.myPrice),
      TextCellValue(productStatusLabel(p.status)),
      DoubleCellValue(p.salePrice),
      TextCellValue(p.deliveryId.isEmpty ? '' : '${numbers[p.deliveryId] ?? ''}'),
      TextCellValue(
        p.deliveryId.isEmpty ? '' : (deliveryById[p.deliveryId]?.name ?? ''),
      ),
      TextCellValue(
        p.deliveryId.isEmpty || (deliveryById[p.deliveryId]?.totalCost ?? 0) == 0
            ? ''
            : '${deliveryById[p.deliveryId]!.totalCost}',
      ),
      TextCellValue(p.photos.join(', ')),
    ]);
  }
  return excel.encode()!;
}

String _cellText(Data? cell) {
  final value = cell?.value;
  if (value == null) return '';
  if (value is TextCellValue) {
    return value.value.toString();
  }
  if (value is IntCellValue) return value.value.toString();
  if (value is DoubleCellValue) return value.value.toString();
  if (value is BoolCellValue) return value.value.toString();
  return value.toString();
}

List<Map<String, String>> parseProductsExcel(List<int> bytes) {
  if (bytes.length > 4 &&
      bytes[0] == 0xD0 &&
      bytes[1] == 0xCF &&
      bytes[2] == 0x11 &&
      bytes[3] == 0xE0) {
    throw const FormatException(
      'Файл в старом формате .xls. Сохраните его как .xlsx и повторите импорт.',
    );
  }
  try {
    return _parseWithExcel(bytes);
  } catch (_) {
    return _parseXlsxFallback(bytes);
  }
}

List<Map<String, String>> _parseWithExcel(List<int> bytes) {
  final excel = Excel.decodeBytes(bytes);
  final table = excel.tables.values.firstOrNull;
  if (table == null || table.rows.isEmpty) return const [];
  final header = table.rows.first.map(_cellText).toList();
  final result = <Map<String, String>>[];
  for (final row in table.rows.skip(1)) {
    final values = <String, String>{};
    for (var i = 0; i < header.length && i < row.length; i++) {
      if (header[i].trim().isEmpty) continue;
      values[header[i].trim()] = _cellText(row[i]).trim();
    }
    if (values.values.every((v) => v.isEmpty)) continue;
    result.add(values);
  }
  return result;
}

/// Резервный разбор xlsx без строгой библиотеки: берём первый лист,
/// общие строки и встроенный текст. Нужен для файлов, на которых
/// Excel.decodeBytes падает с «corrupted file».
List<Map<String, String>> _parseXlsxFallback(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: false);
  String? read(String name) {
    for (final file in archive.files) {
      if (file.name == name && file.content is List<int>) {
        return utf8.decode(file.content as List<int>, allowMalformed: true);
      }
    }
    return null;
  }

  final shared = <String>[];
  final sharedXml = read('xl/sharedStrings.xml');
  if (sharedXml != null) {
    for (final si in RegExp(r'<(?:\w+:)?si[^>]*>(.*?)</(?:\w+:)?si>', dotAll: true)
        .allMatches(sharedXml)) {
      final text = RegExp(r'<(?:\w+:)?t[^>]*>(.*?)</(?:\w+:)?t>', dotAll: true)
          .allMatches(si.group(1) ?? '')
          .map((m) => _xmlText(m.group(1) ?? ''))
          .join();
      shared.add(text);
    }
  }

  String? sheetXml;
  for (final file in archive.files) {
    if (file.name.startsWith('xl/worksheets/') &&
        file.name.endsWith('.xml') &&
        file.content is List<int>) {
      sheetXml = utf8.decode(file.content as List<int>, allowMalformed: true);
      break;
    }
  }
  if (sheetXml == null) throw const FormatException('В файле нет листов');

  final rows = <List<String>>[];
  for (final rowMatch in RegExp(r'<(?:\w+:)?row\b[^>]*>(.*?)</(?:\w+:)?row>', dotAll: true)
      .allMatches(sheetXml)) {
    final cells = <String>[];
    var autoIndex = 0;
    for (final cell in RegExp(r'<(?:\w+:)?c\b([^>]*)>(.*?)</(?:\w+:)?c>', dotAll: true)
        .allMatches(rowMatch.group(1) ?? '')) {
      final attrs = cell.group(1) ?? '';
      final body = cell.group(2) ?? '';
      final ref = RegExp(r'r="([A-Z]+)').firstMatch(attrs)?.group(1);
      final index = ref == null ? autoIndex : _columnIndex(ref);
      autoIndex = index + 1;
      final type = RegExp(r't="([^"]+)"').firstMatch(attrs)?.group(1);
      String value;
      if (type == 's') {
        final indexValue = int.tryParse(
          RegExp(r'<(?:\w+:)?v>(.*?)</(?:\w+:)?v>', dotAll: true).firstMatch(body)?.group(1) ?? '',
        );
        value = indexValue != null && indexValue < shared.length
            ? shared[indexValue]
            : '';
      } else if (type == 'inlineStr') {
        value = RegExp(r'<(?:\w+:)?t[^>]*>(.*?)</(?:\w+:)?t>', dotAll: true)
            .allMatches(body)
            .map((m) => _xmlText(m.group(1) ?? ''))
            .join();
      } else {
        value = _xmlText(
          RegExp(r'<(?:\w+:)?v>(.*?)</(?:\w+:)?v>', dotAll: true).firstMatch(body)?.group(1) ?? '',
        );
      }
      while (cells.length <= index) {
        cells.add('');
      }
      cells[index] = value;
    }
    if (cells.any((value) => value.trim().isNotEmpty)) rows.add(cells);
  }
  if (rows.isEmpty) return const [];

  final header = rows.first;
  final result = <Map<String, String>>[];
  for (final row in rows.skip(1)) {
    final values = <String, String>{};
    for (var i = 0; i < header.length && i < row.length; i++) {
      if (header[i].trim().isEmpty) continue;
      values[header[i].trim()] = row[i].trim();
    }
    if (values.values.every((v) => v.isEmpty)) continue;
    result.add(values);
  }
  return result;
}

int _columnIndex(String letters) {
  var value = 0;
  for (final code in letters.codeUnits) {
    value = value * 26 + (code - 64);
  }
  return value - 1;
}

String _xmlText(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

