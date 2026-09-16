String? requiredField(String value, String label) =>
    value.trim().isEmpty ? '$label обязательно' : null;
String? nonNegativeAmount(String value, String label) {
  final n = double.tryParse(value.replaceAll(' ', '').replaceAll(',', '.'));
  if (n == null) return '$label: укажите число';
  if (n < 0) return '$label не может быть отрицательным';
  return null;
}

List<String> validateDealFields({
  required String client,
  required String revenue,
  required String expenses,
}) => [
  if (requiredField(client, 'Клиент') != null) requiredField(client, 'Клиент')!,
  if (nonNegativeAmount(revenue, 'Выручка') != null)
    nonNegativeAmount(revenue, 'Выручка')!,
  if (nonNegativeAmount(expenses, 'Расходы') != null)
    nonNegativeAmount(expenses, 'Расходы')!,
];
