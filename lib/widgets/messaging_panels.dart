import 'package:flutter/material.dart';

class AvitoCallsPanel extends StatelessWidget {
  const AvitoCallsPanel({
    super.key,
    required this.calls,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
    required this.formatDate,
  });

  final List<Map<String, dynamic>> calls;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;
  final String Function(dynamic value) formatDate;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 980),
    height: 250,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Звонки',
          style: TextStyle(
            color: mainTextColor,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: calls.isEmpty
              ? Center(
                  child: Text(
                    'Звонков пока нет',
                    style: TextStyle(color: mutedTextColor),
                  ),
                )
              : ListView.builder(
                  itemCount: calls.length,
                  itemBuilder: (_, index) {
                    final call = calls[index];
                    return ListTile(
                      leading: const Icon(Icons.call, color: Color(0xFFF28C28)),
                      title: Text(
                        call['buyerPhone']?.toString() ?? 'Клиент Avito',
                        style: TextStyle(color: mainTextColor),
                      ),
                      subtitle: Text(
                        formatDate(call['callTime'] ?? call['createTime']),
                        style: TextStyle(color: mutedTextColor),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class VkNotificationChatPanel extends StatelessWidget {
  const VkNotificationChatPanel({
    super.key,
    required this.peerId,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
    required this.canEdit,
    required this.onSendSummary,
    required this.onSendTest,
  });

  final String peerId;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;
  final bool canEdit;
  final Future<String?> Function() onSendSummary;
  final Future<String?> Function() onSendTest;

  bool get _configured => peerId.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 980),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _configured ? const Color(0xFFF28C28) : borderColor,
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final actions = Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: _configured && canEdit
                  ? () => _sendSummary(context)
                  : null,
              icon: const Icon(Icons.summarize_outlined, size: 18),
              label: const Text('Отправить сводку'),
            ),
            if (_configured)
              ElevatedButton.icon(
                onPressed: canEdit ? () => _sendTest(context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF28C28),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Отправить тест'),
              ),
          ],
        );
        final details = _details();
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [details, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          children: [
            Expanded(child: details),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    ),
  );

  Widget _details() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF28C28),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.campaign_outlined, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Чат уведомлений сотрудников',
              style: TextStyle(
                color: mainTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _configured
                  ? 'Беседа VK: $peerId. Она не является клиентским диалогом и поэтому не показывается ниже.'
                  : 'Выберите ID беседы в настройках ВКонтакте.',
              style: TextStyle(color: mutedTextColor, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _sendSummary(BuildContext context) async {
    final error = await onSendSummary();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Сводка отправлена в чат сотрудников.')),
    );
  }

  Future<void> _sendTest(BuildContext context) async {
    final error = await onSendTest();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Тестовое уведомление отправлено в беседу сотрудников.',
        ),
      ),
    );
  }
}
