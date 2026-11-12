String _skuKey(String value) {
  final trimmed = value.trim().toLowerCase();
  final numeric = RegExp(r'^\d+$').hasMatch(trimmed)
      ? BigInt.tryParse(trimmed)
      : null;
  return numeric == null ? trimmed : numeric.toString();
}

bool skuEquals(String left, String right) =>
    left.trim().isNotEmpty &&
    right.trim().isNotEmpty &&
    _skuKey(left) == _skuKey(right);

String nextProductSku(Iterable<String> skus) {
  var maximum = BigInt.zero;
  var width = 4;
  for (final raw in skus) {
    final value = raw.trim();
    final number = RegExp(r'^\d+$').hasMatch(value)
        ? BigInt.tryParse(value)
        : null;
    if (number != null) {
      if (number > maximum) maximum = number;
      if (value.length > width) width = value.length;
    }
  }
  final next = (maximum + BigInt.one).toString();
  return next.padLeft(width, '0');
}
