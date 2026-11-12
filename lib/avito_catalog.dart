/// Модель справочника категорий Авито (дерево + поля).
///
/// Данные приходят из API автозагрузки Авито через VPS и кэшируются.
/// Используются в форме товара: при выборе категории показываются поля,
/// которые нужно заполнить для успешной публикации на Авито.
library;

class AvitoCategory {
  const AvitoCategory({required this.slug, required this.name});

  final String slug;
  final String name;

  factory AvitoCategory.fromJson(List<dynamic> json) => AvitoCategory(
    slug: '${json.isNotEmpty ? json[0] : ''}',
    name: '${json.length > 1 ? json[1] : ''}',
  );
}

class AvitoFieldContent {
  const AvitoFieldContent({
    required this.fieldType,
    required this.dataType,
    required this.required,
    this.values = const [],
    this.valuesLinkJson = '',
  });

  final String fieldType; // input | select | checkbox
  final String dataType; // string | integer | float
  final bool required;
  final List<dynamic> values;
  final String valuesLinkJson;

  Map<String, dynamic> toJson() => {
    'field_type': fieldType,
    'data_type': dataType,
    'required': required,
    'values': values,
  };

  factory AvitoFieldContent.fromJson(Map<String, dynamic> json) =>
      AvitoFieldContent(
        fieldType: '${json['field_type'] ?? ''}',
        dataType: '${json['data_type'] ?? 'string'}',
        required: json['required'] == true,
        values: json['values'] is List ? json['values'] as List : const [],
        valuesLinkJson: '${json['values_link_json'] ?? ''}',
      );
}

class AvitoField {
  const AvitoField({
    required this.tag,
    required this.label,
    required this.content,
  });

  final String tag;
  final String label;
  final List<AvitoFieldContent> content;

  /// Обязательные правила (одно из content, у которого required=true).
  List<AvitoFieldContent> get requiredContent =>
      content.where((c) => c.required).toList();
  bool get hasRequired => requiredContent.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'tag': tag,
    'label': label,
    'content': content.map((c) => c.toJson()).toList(),
  };

  factory AvitoField.fromJson(Map<String, dynamic> json) => AvitoField(
    tag: '${json['tag'] ?? ''}',
    label: '${json['label'] ?? ''}',
    content: (json['content'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => AvitoFieldContent.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

/// Узел дерева категорий Авито (категория → подкатегория → ...).
class AvitoCategoryNode {
  const AvitoCategoryNode({
    required this.name,
    required this.slug,
    required this.children,
  });

  final String name;
  final String slug;
  final List<AvitoCategoryNode> children;

  factory AvitoCategoryNode.fromJson(Map<String, dynamic> json) {
    final name = '${json['name'] ?? ''}';
    final slug = '${json['slug'] ?? ''}';
    final children = <AvitoCategoryNode>[];
    final nested = json['nested'];
    void collect(dynamic value) {
      if (value is Map) {
        for (final item in value.values) {
          collect(item);
        }
      } else if (value is List) {
        for (final item in value) {
          if (item is Map) {
            children.add(
                AvitoCategoryNode.fromJson(Map<String, dynamic>.from(item)));
          } else {
            collect(item);
          }
        }
      }
    }

    if (nested is List) {
      for (final item in nested) {
        if (item is Map) {
          // Узел может быть как самим узлом, так и группой узлов.
          if (item.containsKey('name') || item.containsKey('slug')) {
            children.add(
                AvitoCategoryNode.fromJson(Map<String, dynamic>.from(item)));
          } else {
            collect(item);
          }
        } else {
          collect(item);
        }
      }
    }
    return AvitoCategoryNode(name: name, slug: slug, children: children);
  }
}

/// Каталог целиком: список категорий (slug, name) и поля категорий по slug.
class AvitoCatalogData {
  const AvitoCatalogData({
    required this.categories,
    required this.fields,
    this.tree = const [],
  });

  final List<AvitoCategory> categories;
  final Map<String, List<AvitoField>> fields;
  final List<AvitoCategoryNode> tree;

  AvitoCategory? categoryBySlug(String slug) {
    for (final category in categories) {
      if (category.slug == slug) return category;
    }
    return null;
  }

  List<AvitoField>? fieldsBySlug(String slug) => fields[slug];

  /// Копия каталога с добавленными полями категории (поля грузятся точечно).
  AvitoCatalogData withFields(String slug, List<AvitoField> value) =>
      AvitoCatalogData(
        categories: categories,
        fields: {...fields, slug: value},
        tree: tree,
      );

  factory AvitoCatalogData.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'] as List? ?? const [];
    final rawFields = json['fields'] as Map? ?? const {};
    final rawTree = json['tree'];
    final tree = <AvitoCategoryNode>[];
    if (rawTree is Map) {
      final list = rawTree['categories'];
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            tree.add(
                AvitoCategoryNode.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
    }
    return AvitoCatalogData(
      tree: tree,
      categories: rawCategories
          .whereType<List>()
          .map(AvitoCategory.fromJson)
          .where((c) => c.slug.isNotEmpty)
          .toList(),
      fields: rawFields.map((slug, value) {
        final nodeFields = value is Map ? value['fields'] : null;
        return MapEntry(
          '$slug',
          (nodeFields is List ? nodeFields : const [])
              .whereType<Map>()
              .map((e) => AvitoField.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      }),
    );
  }
}
