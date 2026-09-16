import 'package:flutter/material.dart';

class MessengerConnectionCard extends StatelessWidget {
  const MessengerConnectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    required this.status,
    required this.connected,
    required this.canConfigure,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
    required this.onConfigure,
  });

  final String title;
  final IconData icon;
  final String description;
  final String status;
  final bool connected;
  final bool canConfigure;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) => Container(
    width: 300,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: connected ? const Color(0xFFF28C28) : borderColor,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF28C28),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: mainTextColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          description,
          style: TextStyle(color: mutedTextColor, height: 1.35),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              connected ? Icons.check_circle : Icons.circle_outlined,
              size: 17,
              color: connected ? const Color(0xFFF28C28) : mutedTextColor,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                status,
                style: TextStyle(fontSize: 12, color: mutedTextColor),
              ),
            ),
            IconButton(
              tooltip: 'Настроить',
              onPressed: canConfigure ? onConfigure : null,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ],
    ),
  );
}
