/// Единые области доступа CRM. Уровень задаётся владельцем для каждого
/// пользователя и одинаково проверяется в интерфейсе и на сервере.
const crmPermissionAreas = <String>[
  'dashboard',
  'clients',
  'deals',
  'calendar',
  'finance',
  'stock',
  'settings',
  'messages',
  'bot',
  'integrations',
  'backup',
];

const crmPermissionLabels = <String, String>{
  'dashboard': 'Дашборд',
  'clients': 'Клиенты',
  'deals': 'Сделки',
  'calendar': 'Записи',
  'finance': 'Бухгалтерия',
  'stock': 'Склад',
  'settings': 'Настройки',
  'messages': 'Сообщения',
  'bot': 'Тест-бот',
  'integrations': 'Интеграции и таблицы',
  'backup': 'Резервные копии',
};

enum PermissionLevel {
  hidden('hidden', 'Скрыт'),
  view('view', 'Просмотр'),
  edit('edit', 'Изменение');

  const PermissionLevel(this.value, this.label);
  final String value;
  final String label;

  static PermissionLevel parse(Object? value) =>
      PermissionLevel.values
          .where((level) => level.value == value)
          .firstOrNull ??
      PermissionLevel.hidden;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

Map<String, String> defaultPermissionsForRole(String role) {
  final allEdit = {for (final area in crmPermissionAreas) area: 'edit'};
  if (role == 'Владелец') return allEdit;
  if (role == 'Мастер') {
    return {
      for (final area in crmPermissionAreas) area: 'hidden',
      'calendar': 'view',
    };
  }
  if (role == 'Бухгалтер') {
    return {
      for (final area in crmPermissionAreas) area: 'hidden',
      'dashboard': 'view',
      'finance': 'edit',
    };
  }
  if (role == 'Администратор') return allEdit;
  return {for (final area in crmPermissionAreas) area: 'hidden'};
}

class AccessControl {
  const AccessControl(this.permissions);

  final Map<String, String> permissions;

  PermissionLevel level(String area) =>
      PermissionLevel.parse(permissions[area]);
  bool canView(String area) => level(area) != PermissionLevel.hidden;
  bool canEdit(String area) => level(area) == PermissionLevel.edit;
}
