String? nonNegativeAmount(String value, String label) {
  final n = double.tryParse(value.replaceAll(' ', '').replaceAll(',', '.'));
  if (n == null) return '$label: укажите число';
  if (n < 0) return '$label не может быть отрицательным';
  return null;
}

List<String> validateDealFields({
  required String revenue,
  required String expenses,
}) => [
  if (revenue.trim().isNotEmpty &&
      nonNegativeAmount(revenue, 'Выручка') != null)
    nonNegativeAmount(revenue, 'Выручка')!,
  if (expenses.trim().isNotEmpty &&
      nonNegativeAmount(expenses, 'Расходы') != null)
    nonNegativeAmount(expenses, 'Расходы')!,
];
