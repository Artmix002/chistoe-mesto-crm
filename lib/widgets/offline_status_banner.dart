import 'package:flutter/material.dart';

class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key, this.lastSynced});

  final DateTime? lastSynced;

  @override
  Widget build(BuildContext context) {
    final updated = lastSynced == null
        ? ''
        : ' Последнее обновление: ${lastSynced!.day.toString().padLeft(2, '0')}.${lastSynced!.month.toString().padLeft(2, '0')} ${lastSynced!.hour.toString().padLeft(2, '0')}:${lastSynced!.minute.toString().padLeft(2, '0')}.';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Google Sheets недоступна. Показаны последние сохранённые данные; локальные изменения останутся в очереди синхронизации.$updated',
      ),
    );
  }
}
