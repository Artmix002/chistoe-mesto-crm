import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';

/// Карточки результатов поиска клиентов с локальной пагинацией.
class ClientResultsList extends StatelessWidget {
  const ClientResultsList({
    super.key,
    required this.clients,
    required this.totalCount,
    required this.page,
    required this.pageCount,
    required this.canEdit,
    required this.onOpen,
    required this.onDelete,
    required this.onPageChanged,
  });

  final List<Client> clients;
  final int totalCount;
  final int page;
  final int pageCount;
  final bool canEdit;
  final ValueChanged<Client> onOpen;
  final Future<void> Function(Client) onDelete;
  final ValueChanged<int> onPageChanged;

  String _subtitle(Client client) {
    final contact = client.lastContact.isEmpty
        ? ''
        : ' • контакт ${client.lastContact.length > 10 ? client.lastContact.substring(0, 10) : client.lastContact}';
    return '${client.phone}${client.car.isEmpty ? '' : ' • ${client.car}'} • '
        '${client.status}${client.responsible.isEmpty ? '' : ' • ${client.responsible}'}$contact';
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (totalCount == 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 34,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                Text(
                  'Клиентов пока нет',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Добавьте первого клиента, чтобы вести историю обращений.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ...clients.map(
        (client) => Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                client.name.isEmpty ? '?' : client.name[0].toUpperCase(),
              ),
            ),
            title: Text(client.name),
            subtitle: Text(_subtitle(client)),
            onTap: () => onOpen(client),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Удалить клиента',
              onPressed: canEdit ? () => unawaited(onDelete(client)) : null,
            ),
          ),
        ),
      ),
      if (totalCount > clients.length && pageCount > 1)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Предыдущая страница',
              onPressed: page == 0 ? null : () => onPageChanged(page - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${page + 1} из $pageCount'),
            IconButton(
              tooltip: 'Следующая страница',
              onPressed: page + 1 >= pageCount
                  ? null
                  : () => onPageChanged(page + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
    ],
  );
}
