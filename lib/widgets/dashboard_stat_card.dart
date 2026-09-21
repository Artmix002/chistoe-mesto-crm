import 'package:flutter/material.dart';

class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
    this.accentColor = const Color(0xFFF28C28),
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 190,
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 8 : 16,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: mutedTextColor, fontSize: 11)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: mainTextColor,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
