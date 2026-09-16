import 'access_control.dart';

/// Совместимость для старого локального профиля до его миграции на сервер.
class RolePolicy {
  static bool canManageIntegrations(String role) =>
      role == 'Владелец' || role == 'Администратор';

  static bool canEdit(String role, String area) {
    if (role == 'Только просмотр') return false;
    if (role == 'Владелец' || role == 'Администратор') return true;
    if (role == 'Бухгалтер' && area == 'finance') return true;
    if (role == 'Мастер' &&
        const {'clients', 'deals', 'calendar', 'stock'}.contains(area)) {
      return true;
    }
    return false;
  }
}

bool canViewPermission(Map<String, String> permissions, String area) =>
    AccessControl(permissions).canView(area);

bool canEditPermission(Map<String, String> permissions, String area) =>
    AccessControl(permissions).canEdit(area);
