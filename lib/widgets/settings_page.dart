import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../schema.dart';

/// Настройки подключения и локального рабочего пространства.
///
/// Экран не владеет данными: сохранение, права и синхронизация остаются в
/// dashboard, чтобы у настроек не появлялся второй источник состояния.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.currentUserId,
    required this.userProfiles,
    required this.onSelectUser,
    required this.sheetController,
    required this.canManageIntegrations,
    required this.canBackup,
    required this.canRestore,
    required this.canEditMessages,
    required this.isOwner,
    required this.onSaveAndCheckSheet,
    required this.onManageServices,
    required this.onBackup,
    required this.onRestore,
    required this.onManageQuickReplies,
    required this.onSetupSync,
    required this.onManageUsers,
    required this.hasSyncCredentials,
    required this.pendingChangesCount,
    required this.pendingChangesSyncing,
    required this.pendingChangesSyncError,
    required this.lastPendingChangesSync,
    required this.onSyncPendingChanges,
    required this.onExportPendingChanges,
    required this.auditEntries,
    this.onSetupAi,
    this.aiConfigured = false,
  });

  final String currentUserId;
  final List<UserProfile> userProfiles;
  final ValueChanged<String> onSelectUser;
  final TextEditingController sheetController;
  final bool canManageIntegrations;
  final bool canBackup;
  final bool canRestore;
  final bool canEditMessages;
  final bool isOwner;
  final Future<void> Function() onSaveAndCheckSheet;
  final Future<void> Function() onManageServices;
  final Future<void> Function() onBackup;
  final Future<void> Function() onRestore;
  final Future<void> Function() onManageQuickReplies;
  final Future<void> Function() onSetupSync;
  final Future<void> Function() onManageUsers;
  final bool hasSyncCredentials;
  final int pendingChangesCount;
  final bool pendingChangesSyncing;
  final String? pendingChangesSyncError;
  final DateTime? lastPendingChangesSync;
  final Future<void> Function() onSyncPendingChanges;
  final Future<void> Function() onExportPendingChanges;
  final List<AuditEntry> auditEntries;
  final Future<void> Function()? onSetupAi;
  final bool aiConfigured;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB2B8C2)
        : const Color(0xFF626975);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Подключение данных', style: text.titleLarge),
            const Spacer(),
            DropdownButton<String>(
              value: currentUserId,
              items: userProfiles
                  .where((profile) => profile.active)
                  .map(
                    (profile) => DropdownMenuItem(
                      value: profile.id,
                      child: Text('${profile.name} · ${profile.role}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onSelectUser(value);
              },
            ),
          ],
        ),
        Text(
          'Схема Google Sheets v${SheetsSchema.version}',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          'Укажите ссылку на Google Таблицу с бухгалтерией. Для рабочего режима используйте защищённый доступ через backend; публичная публикация подходит только для временного чтения.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Container(
          width: 700,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ссылка на Google Таблицу', style: text.titleSmall),
              const SizedBox(height: 10),
              TextField(
                controller: sheetController,
                enabled: canManageIntegrations,
                decoration: const InputDecoration(
                  hintText: 'https://docs.google.com/spreadsheets/d/...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: canManageIntegrations
                    ? () => unawaited(onSaveAndCheckSheet())
                    : null,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить и проверить'),
              ),
              const SizedBox(height: 12),
              _actionButton(
                label: 'Список доступных услуг',
                icon: Icons.home_repair_service,
                enabled: canManageIntegrations,
                onPressed: onManageServices,
              ),
              _actionButton(
                label: 'Создать резервную копию',
                icon: Icons.backup_outlined,
                enabled: canBackup,
                onPressed: onBackup,
              ),
              _actionButton(
                label: 'Восстановить последнюю копию',
                icon: Icons.restore,
                enabled: canRestore,
                onPressed: onRestore,
              ),
              _actionButton(
                label: 'Шаблоны быстрых ответов',
                icon: Icons.flash_on_outlined,
                enabled: canEditMessages,
                onPressed: onManageQuickReplies,
              ),
              _actionButton(
                label: hasSyncCredentials
                    ? 'Изменить защищённую синхронизацию'
                    : 'Настроить защищённую синхронизацию',
                icon: Icons.sync_lock,
                enabled: canManageIntegrations,
                onPressed: onSetupSync,
              ),
              _actionButton(
                label: aiConfigured
                    ? 'Настроить AI и тест-бот'
                    : 'Подключить AI для тест-бота',
                icon: Icons.smart_toy_outlined,
                enabled: canManageIntegrations && onSetupAi != null,
                onPressed: onSetupAi ?? () async {},
              ),
              _actionButton(
                label: 'Профили пользователей и роли',
                icon: Icons.manage_accounts_outlined,
                enabled: isOwner,
                onPressed: onManageUsers,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Журнал действий', style: text.titleLarge),
        const SizedBox(height: 8),
        if (pendingChangesCount > 0) _syncStatus(context, muted),
        if (auditEntries.isEmpty)
          Text('Действий пока нет', style: TextStyle(color: muted)),
        ...auditEntries.reversed
            .take(20)
            .map(
              (entry) => ListTile(
                dense: true,
                leading: const Icon(Icons.history),
                title: Text('${entry.action}: ${entry.entity}'),
                subtitle: Text(
                  '${entry.details} • ${entry.date} • ${entry.actor.isEmpty ? 'Система' : entry.actor}',
                ),
              ),
            ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Future<void> Function() onPressed,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: OutlinedButton.icon(
      onPressed: enabled ? () => unawaited(onPressed()) : null,
      icon: Icon(icon),
      label: Text(label),
    ),
  );

  Widget _syncStatus(BuildContext context, Color muted) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Локальных изменений ожидает синхронизации: $pendingChangesCount',
                style: const TextStyle(color: Colors.orange),
              ),
              if (pendingChangesSyncError != null)
                Text(
                  'Последняя ошибка: $pendingChangesSyncError',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: muted, fontSize: 12),
                )
              else if (lastPendingChangesSync != null)
                Text(
                  'Последняя синхронизация: ${lastPendingChangesSync!.toLocal()}',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: pendingChangesSyncing
              ? null
              : () => unawaited(onSyncPendingChanges()),
          icon: pendingChangesSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync, size: 18),
          label: Text(
            pendingChangesSyncing ? 'Синхронизация…' : 'Синхронизировать',
          ),
        ),
        TextButton.icon(
          onPressed: () => unawaited(onExportPendingChanges()),
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Экспорт очереди'),
        ),
      ],
    ),
  );
}
