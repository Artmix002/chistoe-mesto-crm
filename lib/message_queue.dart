const supportedOutgoingChannels = {'vk', 'telegram', 'avito', 'instagram'};

bool isSupportedOutgoingChannel(String? channel) =>
    supportedOutgoingChannels.contains(channel);

Map<String, String> preparePendingMessage(
  Map<String, String> source, {
  DateTime? now,
}) {
  final value = Map<String, String>.from(source);
  final timestamp = now ?? DateTime.now();
  value.putIfAbsent('id', () => 'outgoing-${timestamp.microsecondsSinceEpoch}');
  // VK требует положительный целочисленный random_id. Значение сохраняется в
  // очереди, поэтому повторный запрос распознаётся API как тот же самый.
  value.putIfAbsent(
    'vkRandomId',
    () => '${timestamp.millisecondsSinceEpoch % 2000000000}',
  );
  value.putIfAbsent('attempts', () => '0');
  return value;
}

bool isSamePendingDelivery(
  Map<String, String> first,
  Map<String, String> second,
) =>
    first['channel'] == second['channel'] &&
    first['peer'] == second['peer'] &&
    first['chat'] == second['chat'] &&
    first['text'] == second['text'];

void markPendingAttempt(Map<String, String> message, DateTime now) {
  final attempts = int.tryParse(message['attempts'] ?? '') ?? 0;
  message['attempts'] = '${attempts + 1}';
  message['lastAttemptAt'] = now.toIso8601String();
}

/// Пауза между фоновыми отправками. Ограничение сверху позволяет очереди
/// восстановиться самостоятельно после долгого офлайна, не создавая шквал
/// запросов к внешним API.
Duration pendingRetryDelay(int attempts) {
  final exponent = attempts.clamp(0, 6).toInt();
  return Duration(seconds: 5 * (1 << exponent));
}

bool isPendingRetryReady(Map<String, String> message, DateTime now) {
  final attempts = int.tryParse(message['attempts'] ?? '') ?? 0;
  final rawLastAttempt = message['lastAttemptAt'];
  if (attempts <= 0 || rawLastAttempt == null) return true;
  final lastAttempt = DateTime.tryParse(rawLastAttempt);
  return lastAttempt == null ||
      !now.isBefore(lastAttempt.add(pendingRetryDelay(attempts)));
}
