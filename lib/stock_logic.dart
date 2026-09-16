/// Результат изменения остатка без привязки к UI.
class StockAdjustment {
  const StockAdjustment._({
    required this.isValid,
    required this.resultingQuantity,
    required this.delta,
    this.error,
  });

  final bool isValid;
  final double resultingQuantity;
  final double delta;
  final String? error;

  factory StockAdjustment.invalid(String error) => StockAdjustment._(
    isValid: false,
    resultingQuantity: 0,
    delta: 0,
    error: error,
  );
}

double weightedAveragePrice({
  required double currentQuantity,
  required double currentPrice,
  required double receivedQuantity,
  required double receivedPrice,
}) {
  final totalQuantity = currentQuantity + receivedQuantity;
  if (totalQuantity <= 0) return receivedPrice;
  return ((currentQuantity * currentPrice) +
          (receivedQuantity * receivedPrice)) /
      totalQuantity;
}

/// Считает новый остаток для прихода, расхода, списания и инвентаризации.
/// Для инвентаризации [enteredQuantity] — фактический остаток, а не дельта.
StockAdjustment calculateStockAdjustment({
  required String type,
  required double currentQuantity,
  required double enteredQuantity,
}) {
  if (currentQuantity < 0 ||
      (type == 'Инвентаризация' ? enteredQuantity < 0 : enteredQuantity <= 0)) {
    return StockAdjustment.invalid('Количество должно быть больше нуля');
  }
  if (type == 'Инвентаризация') {
    return StockAdjustment._(
      isValid: true,
      resultingQuantity: enteredQuantity,
      delta: enteredQuantity - currentQuantity,
    );
  }
  if (type == 'Приход') {
    return StockAdjustment._(
      isValid: true,
      resultingQuantity: currentQuantity + enteredQuantity,
      delta: enteredQuantity,
    );
  }
  if (type == 'Расход' || type == 'Списание') {
    if (enteredQuantity > currentQuantity) {
      return StockAdjustment.invalid('Недостаточно остатка');
    }
    return StockAdjustment._(
      isValid: true,
      resultingQuantity: currentQuantity - enteredQuantity,
      delta: -enteredQuantity,
    );
  }
  return StockAdjustment.invalid('Неизвестный тип движения');
}
