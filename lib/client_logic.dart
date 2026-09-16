String normalizePhone(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 11 && digits.startsWith('8')) {
    return '+7${digits.substring(1)}';
  }
  if (digits.length == 11 && digits.startsWith('7')) return '+$digits';
  return value.startsWith('+') ? '+$digits' : digits;
}

bool clientMatchesQuery({
  required String query,
  required String name,
  required String phone,
  required String car,
  required String source,
  String status = '',
  Iterable<String> phones = const [],
  Iterable<String> cars = const [],
}) => '$name $phone ${phones.join(' ')} $car ${cars.join(' ')} $source $status'
    .toLowerCase()
    .contains(query.trim().toLowerCase());

bool isDuplicatePhone(String candidate, Iterable<String> existingPhones) {
  final normalized = normalizePhone(candidate);
  if (normalized.isEmpty) return false;
  return existingPhones.any((phone) => normalizePhone(phone) == normalized);
}

bool clientContactInPeriod(
  String lastContact, {
  required DateTime now,
  int? days,
}) {
  if (days == null) return true;
  final contact = DateTime.tryParse(lastContact);
  if (contact == null) return false;
  return !contact.isBefore(now.subtract(Duration(days: days)));
}
