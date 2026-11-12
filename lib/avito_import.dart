import 'package:excel/excel.dart';

class AvitoExportRow {
  AvitoExportRow({
    required this.avitoId,
    required this.title,
    required this.description,
    required this.article,
    required this.price,
    required this.category,
    required this.status,
    required this.photos,
    required this.attributes,
  });

  final String avitoId;
  final String title;
  final String description;
  final String article;
  final String price;
  final String category;
  final String status;
  final List<String> photos;
  final Map<String, String> attributes;
}

String _cell(Data? cell) => cell?.value?.toString().trim() ?? '';

String _unescape(String value) => value
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'");

String _cleanHtml(String value) {
  var text = value.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  text = _unescape(text);
  return text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

String _photoFromAutoload(String link) {
  final index = link.indexOf('imageSlug=');
  if (index < 0) return '';
  final slug = link.substring(index + 'imageSlug='.length).trim();
  if (slug.isEmpty) return '';
  return 'https://90.img.avito.st$slug';
}

/// Разбирает выгрузку объявлений из кабинета Авито («Скачать файл»).
List<AvitoExportRow> parseAvitoExport(List<int> bytes) {
  final excel = Excel.decodeBytes(bytes);
  final result = <AvitoExportRow>[];
  for (final table in excel.tables.values) {
    if (table.rows.isEmpty) continue;
    var headerIndex = -1;
    for (var i = 0; i < table.rows.length && i < 6; i++) {
      final values = table.rows[i].map(_cell).toList();
      if (values.contains('Уникальный идентификатор объявления')) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex < 0) continue;
    final header = table.rows[headerIndex].map(_cell).toList();
    int column(String name) => header.indexOf(name);
    final idColumn = column('Уникальный идентификатор объявления');
    if (idColumn < 0) continue;
    for (var r = headerIndex + 3; r < table.rows.length; r++) {
      final row = table.rows[r];
      String value(String name) {
        final index = column(name);
        if (index < 0 || index >= row.length) return '';
        return _cell(row[index]);
      }

      final id = value('Уникальный идентификатор объявления');
      if (id.isEmpty) continue;
      final description = _cleanHtml(value('Описание объявления'));
      final lines = description
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      final article = lines.isEmpty ? '' : lines.last;
      final photos = <String>[];
      for (final link in value('Ссылки на фото').split('|')) {
        final photo = _photoFromAutoload(link.trim());
        if (photo.isNotEmpty) photos.add(photo);
      }
      const skipColumns = {
        'Уникальный идентификатор объявления',
        'Способ размещения',
        'Номер объявления на Авито',
        'Номер телефона',
        'Ссылки на фото',
        'Названия фото',
        'Почта',
        'Название компании',
        'AvitoStatus',
        'AvitoDateEnd',
        'Название объявления',
        'Описание объявления',
        'Категория',
        'Цена',
        'Способ связи',
      };
      final attributes = <String, String>{};
      for (var i = 0; i < header.length; i++) {
        final name = header[i].trim();
        if (name.isEmpty || skipColumns.contains(name)) continue;
        if (i >= row.length) continue;
        final text = _cell(row[i]).trim();
        if (text.isEmpty || text == 'Package') continue;
        attributes[name] = text;
      }
      result.add(
        AvitoExportRow(
          avitoId: id,
          title: value('Название объявления'),
          description: description,
          article: article,
          price: value('Цена'),
          category: value('Категория'),
          status: value('AvitoStatus'),
          photos: photos,
          attributes: attributes,
        ),
      );
    }
  }
  return result;
}
