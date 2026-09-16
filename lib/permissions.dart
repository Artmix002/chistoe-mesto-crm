/// Centralized authorization policy for the local CRM profile.
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
