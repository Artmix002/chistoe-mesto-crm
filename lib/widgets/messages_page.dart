import 'package:flutter/material.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({
    super.key,
    required this.sections,
    required this.connectionCards,
    required this.pendingCount,
    required this.mainTextColor,
    required this.mutedTextColor,
    required this.canRetry,
    required this.onRetry,
    required this.onDiagnostics,
    this.onRefresh,
  });

  final List<Widget> sections;
  final List<Widget> connectionCards;
  final int pendingCount;
  final Color mainTextColor;
  final Color mutedTextColor;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onDiagnostics;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LayoutBuilder(
        builder: (_, constraints) {
          final title = Text(
            'Сообщения',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: mainTextColor,
            ),
          );
          final actions = Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onRefresh != null)
                IconButton(
                  tooltip: 'Обновить сообщения',
                  onPressed: () {
                    onRefresh!();
                  },
                  icon: const Icon(Icons.refresh),
                ),
              OutlinedButton.icon(
                onPressed: onDiagnostics,
                icon: const Icon(Icons.health_and_safety_outlined),
                label: const Text('Диагностика интеграций'),
              ),
            ],
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 8), actions],
            );
          }
          return Row(children: [title, const Spacer(), actions]);
        },
      ),
      const SizedBox(height: 6),
      Text(
        'Все обращения клиентов в одном окне.',
        style: TextStyle(color: mutedTextColor),
      ),
      const SizedBox(height: 10),
      if (pendingCount > 0)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: LayoutBuilder(
            builder: (_, constraints) {
              final message = Text(
                'В очереди на отправку: $pendingCount',
                style: TextStyle(color: mainTextColor),
              );
              final retry = TextButton(
                onPressed: canRetry ? onRetry : null,
                child: const Text('Повторить сейчас'),
              );
              if (constraints.maxWidth < 380) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [message, retry],
                );
              }
              return Row(
                children: [
                  const Icon(Icons.schedule_send, color: Colors.orange),
                  const SizedBox(width: 8),
                  message,
                  const Spacer(),
                  retry,
                ],
              );
            },
          ),
        ),
      const SizedBox(height: 16),
      ...sections,
      if (connectionCards.isNotEmpty) ...[
        const SizedBox(height: 18),
        Wrap(spacing: 16, runSpacing: 16, children: connectionCards),
      ],
    ],
  );
}
