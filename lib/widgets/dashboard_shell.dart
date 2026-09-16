import 'package:flutter/material.dart';

import '../layout.dart';

/// Общая адаптивная оболочка рабочего стола CRM.
///
/// Содержит навигационную панель, заголовок, действия верхней панели и
/// прокручиваемую область страницы. Бизнес-экраны передаются снаружи, поэтому
/// состояние CRM не смешивается с кодом адаптивной вёрстки.
class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.darkMode,
    required this.sidebar,
    required this.title,
    required this.now,
    required this.hasUnreadNotifications,
    required this.onOpenNotifications,
    required this.onThemeChanged,
    this.selectedPage = 0,
    this.mobileDestinations = const [],
    this.onPageSelected,
    required this.body,
  });

  final bool darkMode;
  final Widget sidebar;
  final String title;
  final DateTime now;
  final bool hasUnreadNotifications;
  final VoidCallback onOpenNotifications;
  final ValueChanged<bool> onThemeChanged;
  final int selectedPage;
  final List<DashboardMobileDestination> mobileDestinations;
  final ValueChanged<int>? onPageSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = usesCompactNavigation(constraints.maxWidth);
      return Scaffold(
        backgroundColor: darkMode
            ? const Color(0xFF101216)
            : const Color(0xFFF5F6F8),
        drawer: compact ? Drawer(child: sidebar) : null,
        bottomNavigationBar:
            compact && mobileDestinations.length >= 2 && onPageSelected != null
            ? _MobileNavigationBar(
                darkMode: darkMode,
                selectedPage: selectedPage,
                destinations: mobileDestinations,
                onPageSelected: onPageSelected!,
              )
            : null,
        body: Row(
          children: [
            if (!compact) sidebar,
            Expanded(
              child: Container(
                color: darkMode
                    ? const Color(0xFF101216)
                    : const Color(0xFFF5F6F8),
                child: Column(
                  children: [
                    _Header(
                      compact: compact,
                      darkMode: darkMode,
                      title: title,
                      now: now,
                      hasUnreadNotifications: hasUnreadNotifications,
                      onOpenNotifications: onOpenNotifications,
                      onThemeChanged: onThemeChanged,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(compact ? 16 : 32),
                        child: body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class DashboardMobileDestination {
  const DashboardMobileDestination({
    required this.pageIndex,
    required this.label,
    required this.icon,
  });

  final int pageIndex;
  final String label;
  final IconData icon;
}

class _MobileNavigationBar extends StatelessWidget {
  const _MobileNavigationBar({
    required this.darkMode,
    required this.selectedPage,
    required this.destinations,
    required this.onPageSelected,
  });

  final bool darkMode;
  final int selectedPage;
  final List<DashboardMobileDestination> destinations;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = destinations.indexWhere(
      (destination) => destination.pageIndex == selectedPage,
    );
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: darkMode ? const Color(0xFF1A1D23) : Colors.white,
          border: Border(
            top: BorderSide(
              color: darkMode
                  ? const Color(0xFF30343B)
                  : const Color(0xFFE7E9ED),
            ),
          ),
        ),
        child: NavigationBar(
          height: 68,
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0x33F28C28),
          selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) =>
              onPageSelected(destinations[index].pageIndex),
          destinations: destinations
              .map(
                (destination) => NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.icon),
                  label: destination.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.compact,
    required this.darkMode,
    required this.title,
    required this.now,
    required this.hasUnreadNotifications,
    required this.onOpenNotifications,
    required this.onThemeChanged,
  });

  final bool compact;
  final bool darkMode;
  final String title;
  final DateTime now;
  final bool hasUnreadNotifications;
  final VoidCallback onOpenNotifications;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 32),
    decoration: BoxDecoration(
      color: darkMode ? const Color(0xFF1A1D23) : Colors.white,
      border: Border(
        bottom: BorderSide(
          color: darkMode ? const Color(0xFF30343B) : const Color(0xFFE7E9ED),
        ),
      ),
    ),
    child: Row(
      children: [
        if (compact)
          Builder(
            builder: (scaffoldContext) => IconButton(
              tooltip: 'Разделы',
              onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
              icon: const Icon(Icons.menu),
            ),
          ),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: darkMode ? Colors.white : const Color(0xFF191B20),
                fontSize: compact ? 20 : 23,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Уведомления',
              onPressed: onOpenNotifications,
              icon: Icon(
                Icons.notifications_none,
                color: darkMode
                    ? const Color(0xFFD7DAE0)
                    : const Color(0xFF6E737C),
              ),
            ),
            if (hasUnreadNotifications)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF28C28),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: darkMode ? 'Включить дневную тему' : 'Включить ночную тему',
          child: Semantics(
            button: true,
            label: darkMode ? 'Включить дневную тему' : 'Включить ночную тему',
            child: InkWell(
              onTap: () => onThemeChanged(!darkMode),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: darkMode ? const Color(0xFF2A2E36) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF28C28)),
                ),
                child: AnimatedRotation(
                  turns: darkMode ? 0.5 : 0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    darkMode ? Icons.dark_mode : Icons.light_mode,
                    color: const Color(0xFFF28C28),
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _Clock(now: now, compact: compact),
      ],
    ),
  );
}

class _Clock extends StatelessWidget {
  const _Clock({required this.now, required this.compact});

  final DateTime now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final full =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}  ${['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][now.weekday - 1]}  $time:${now.second.toString().padLeft(2, '0')}';
    return Tooltip(
      message: full,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF28C28),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, color: Colors.white, size: 18),
            if (!compact) ...[
              const SizedBox(width: 8),
              Text(
                full,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
