import 'package:flutter/material.dart';

class IntegrationDiagnostic {
  const IntegrationDiagnostic({
    required this.name,
    required this.connected,
    required this.status,
    required this.accountConfigured,
    required this.configureTooltip,
    required this.configureIcon,
    this.onConfigure,
  });

  final String name;
  final bool connected;
  final String status;
  final bool accountConfigured;
  final String configureTooltip;
  final IconData configureIcon;
  final VoidCallback? onConfigure;
}

class IntegrationDiagnosticsDialog extends StatelessWidget {
  const IntegrationDiagnosticsDialog({
    super.key,
    required this.diagnostics,
    required this.canConfigure,
  });

  final List<IntegrationDiagnostic> diagnostics;
  final bool canConfigure;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Диагностика интеграций'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in diagnostics)
            ListTile(
              leading: Icon(
                item.connected ? Icons.check_circle : Icons.error_outline,
                color: item.connected ? Colors.green : Colors.orange,
              ),
              title: Text(item.name),
              subtitle: Text(
                '${item.status}\nАккаунт: ${item.accountConfigured ? 'настроен' : 'не указан'}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: item.configureTooltip,
                onPressed: canConfigure && item.onConfigure != null
                    ? () {
                        Navigator.pop(context);
                        item.onConfigure!();
                      }
                    : null,
                icon: Icon(item.configureIcon),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Закрыть'),
      ),
    ],
  );
}
