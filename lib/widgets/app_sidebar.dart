import 'package:flutter/material.dart';

import '../navigation.dart';

class CrmSidebar extends StatelessWidget {
  const CrmSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    this.canView,
    this.userName = 'Профиль',
    this.userRole = 'Настройте аккаунт',
    this.onSwitchUser,
    this.onLogout,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final bool Function(int index)? canView;
  final String userName;
  final String userRole;
  final VoidCallback? onSwitchUser;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xFF17191D),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/logo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ЧИСТОЕ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'МЕСТО',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 34),
        const Text(
          'РАЗДЕЛЫ',
          style: TextStyle(
            color: Color(0xFF777B83),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: List.generate(crmPages.length, (index) => index)
                .where((index) => canView?.call(index) ?? true)
                .map(
                  (index) => _NavigationItem(
                    title: crmPages[index].title,
                    icon: crmPageIcons[index],
                    active: index == selected,
                    onTap: () => onSelect(index),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onSwitchUser,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF23262C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFFF28C28),
                  child: Text(
                    'А',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        userRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8D929B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onLogout != null)
                  IconButton(
                    tooltip: 'Выйти из аккаунта',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_outlined),
                    color: const Color(0xFFB9BDC5),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.title,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: active,
    label: 'Раздел $title',
    onTap: onTap,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF28C28) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: active ? Colors.white : const Color(0xFFA2A6AE),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFFB9BDC5),
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
