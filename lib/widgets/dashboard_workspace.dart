import 'package:flutter/material.dart';

import '../workspace_models.dart';

class DashboardWorkspace extends StatelessWidget {
  const DashboardWorkspace({
    super.key,
    required this.periodLabel,
    required this.periodOptions,
    required this.onPeriodChanged,
    required this.notes,
    required this.onEditNote,
    required this.onDeleteNote,
    required this.onAddNote,
    required this.canEditNotes,
    required this.plan,
    required this.actualRevenue,
    required this.onEditPlan,
    required this.surfaceColor,
    required this.borderColor,
    required this.mainTextColor,
    required this.mutedTextColor,
  });

  final String periodLabel;
  final List<String> periodOptions;
  final ValueChanged<String> onPeriodChanged;
  final List<StickyNote> notes;
  final ValueChanged<StickyNote> onEditNote;
  final ValueChanged<StickyNote> onDeleteNote;
  final VoidCallback onAddNote;
  final bool canEditNotes;
  final DashboardRevenuePlan? plan;
  final double actualRevenue;
  final VoidCallback onEditPlan;
  final Color surfaceColor;
  final Color borderColor;
  final Color mainTextColor;
  final Color mutedTextColor;

  @override
  Widget build(BuildContext context) {
    final planTarget = plan?.target ?? 0;
    final progress = planTarget <= 0
        ? 0.0
        : (actualRevenue / planTarget).clamp(0.0, 1.0);
    final remaining = (planTarget - actualRevenue).clamp(0.0, double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: Color(0xFFF28C28)),
            const SizedBox(width: 8),
            Text(
              'период дашборд',
              style: TextStyle(
                color: mainTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: periodLabel,
              items: periodOptions
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onPeriodChanged(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_outlined, color: Color(0xFFF28C28)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'План выручки',
                      style: TextStyle(
                        color: mainTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onEditPlan,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(plan == null ? 'Поставить план' : 'Изменить'),
                  ),
                ],
              ),
              if (plan == null)
                Text(
                  'План не задан. Укажите цель и период, чтобы отслеживать выполнение.',
                  style: TextStyle(color: mutedTextColor),
                )
              else ...[
                Text(
                  plan!.title,
                  style: TextStyle(
                    color: mainTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Период плана: ${_date(plan!.from)} — ${_date(plan!.to)}',
                  style: TextStyle(color: mutedTextColor, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Факт: ${actualRevenue.toStringAsFixed(0)} ₽ из ${planTarget.toStringAsFixed(0)} ₽ · ${(actualRevenue / planTarget * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: mainTextColor),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(9),
                  color: actualRevenue >= planTarget
                      ? Colors.green
                      : const Color(0xFFF28C28),
                ),
                const SizedBox(height: 8),
                Text(
                  actualRevenue >= planTarget
                      ? 'План выполнен и превышен на ${(actualRevenue - planTarget).toStringAsFixed(0)} ₽'
                      : 'До выполнения плана: ${remaining.toStringAsFixed(0)} ₽',
                  style: TextStyle(
                    color: actualRevenue >= planTarget
                        ? Colors.green
                        : mutedTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Быстрые заметки',
              style: TextStyle(
                color: mainTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text('${notes.length}/8', style: TextStyle(color: mutedTextColor)),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: !canEditNotes || notes.length >= 8 ? null : onAddNote,
              icon: const Icon(Icons.add),
              label: const Text('Заметка'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ...notes.map(
              (note) => _StickyNoteCard(
                note: note,
                onTap: canEditNotes ? () => onEditNote(note) : null,
                onDelete: canEditNotes ? () => onDeleteNote(note) : null,
              ),
            ),
            if (notes.isEmpty)
              Text(
                'Добавьте первую заметку: задачи, звонки и напоминания будут всегда на Dashboard.',
                style: TextStyle(color: mutedTextColor),
              ),
          ],
        ),
      ],
    );
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
}

class _StickyNoteCard extends StatelessWidget {
  const _StickyNoteCard({required this.note, this.onTap, this.onDelete});
  final StickyNote note;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 210,
      height: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE88B),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(1, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: InkWell(
              onTap: onDelete,
              child: const Icon(
                Icons.close,
                size: 18,
                color: Color(0xFF725B00),
              ),
            ),
          ),
          Expanded(
            child: Text(
              note.text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF3C3100),
                fontSize: 15,
                height: 1.25,
              ),
            ),
          ),
          const Text(
            'Нажмите, чтобы изменить',
            style: TextStyle(color: Color(0xFF806900), fontSize: 10),
          ),
        ],
      ),
    ),
  );
}
