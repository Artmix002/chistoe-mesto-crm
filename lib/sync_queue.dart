import 'schema.dart';

class PendingChange {
  PendingChange({
    required this.id,
    required this.entity,
    required this.details,
    required this.createdAt,
    this.attempts = 0,
    this.lastAttemptAt,
    this.lastError,
    Map<String, dynamic>? payload,
  }) : payload = payload ?? <String, dynamic>{};

  final String id;
  final String entity;
  final String details;
  final String createdAt;
  int attempts;
  String? lastAttemptAt;
  String? lastError;
  Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'id': id,
    'entity': entity,
    'details': details,
    'createdAt': createdAt,
    'attempts': attempts,
    'lastAttemptAt': lastAttemptAt,
    'lastError': lastError,
    'payload': payload,
  };

  factory PendingChange.fromJson(Map<String, dynamic> json) => PendingChange(
    id: '${json['id'] ?? ''}',
    entity: '${json['entity'] ?? ''}',
    details: '${json['details'] ?? ''}',
    createdAt: '${json['createdAt'] ?? ''}',
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    lastAttemptAt: json['lastAttemptAt']?.toString(),
    lastError: json['lastError']?.toString(),
    payload: json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : null,
  );
}

class SyncQueue {
  final List<PendingChange> items = [];

  static const _supportedScopes = {
    'clients',
    'stock',
    'manualDeals',
    'finance',
    'appointments',
    'serviceCatalog',
    'workspace',
    'dashboardNotes',
    'revenuePlans',
    'knowledgeBase',
    'auditOnly',
  };

  /// Старый или повреждённый снимок не должен блокировать остальные локальные
  /// изменения. Такие элементы остаются в очереди и доступны для экспорта.
  static bool isTransportReady(PendingChange item) {
    final payload = item.payload;
    return item.id.trim().isNotEmpty &&
        item.entity.trim().isNotEmpty &&
        item.details.trim().isNotEmpty &&
        payload['schemaVersion'] == SheetsSchema.version &&
        payload['kind'] == 'snapshot' &&
        _supportedScopes.contains(payload['scope']);
  }

  Iterable<PendingChange> get invalidTransportItems =>
      items.where((item) => !isTransportReady(item));

  bool enqueue({
    required String entity,
    required String details,
    Map<String, dynamic>? payload,
  }) {
    final duplicate = items.where(
      (item) => item.entity == entity && item.details == details,
    );
    if (duplicate.isNotEmpty) {
      // Несколько локальных правок одного объекта объединяются в самый свежий
      // снимок. Это предотвращает отправку устаревшего состояния.
      duplicate.first.payload = payload ?? <String, dynamic>{};
      return false;
    }
    items.add(
      PendingChange(
        id: 'change-${DateTime.now().microsecondsSinceEpoch}',
        entity: entity,
        details: details,
        createdAt: DateTime.now().toIso8601String(),
        payload: payload,
      ),
    );
    return true;
  }

  List<Map<String, dynamic>> toJson() =>
      items.map((item) => item.toJson()).toList();

  /// Удаляет только записи, которые endpoint подтвердил по стабильному ID.
  void removeAccepted(Iterable<String> ids) {
    final accepted = ids.toSet();
    items.removeWhere((item) => accepted.contains(item.id));
  }

  /// Оставляет запись в очереди: повторная синхронизация не потеряет данные.
  void markAttempt(Iterable<String> ids, {String? error}) {
    final selected = ids.toSet();
    final at = DateTime.now().toIso8601String();
    for (final item in items) {
      if (!selected.contains(item.id)) continue;
      item.attempts++;
      item.lastAttemptAt = at;
      item.lastError = error;
    }
  }

  /// Экспоненциальная пауза не перегружает endpoint при длительном офлайне.
  static Duration retryDelay(int attempts) {
    final exponent = attempts.clamp(0, 6).toInt();
    return Duration(seconds: 5 * (1 << exponent));
  }

  bool hasRetryableItems(DateTime now) =>
      items.any((item) => isTransportReady(item) && isReadyForRetry(item, now));

  void markTransportValidationError(Iterable<String> ids, String error) {
    final selected = ids.toSet();
    for (final item in items) {
      if (selected.contains(item.id)) item.lastError = error;
    }
  }

  static bool isReadyForRetry(PendingChange item, DateTime now) {
    if (item.attempts == 0 || item.lastAttemptAt == null) return true;
    final lastAttempt = DateTime.tryParse(item.lastAttemptAt!);
    return lastAttempt == null ||
        !now.isBefore(lastAttempt.add(retryDelay(item.attempts)));
  }

  void load(Iterable<dynamic> values) {
    items
      ..clear()
      ..addAll(
        values.whereType<Map>().map(
          (value) => PendingChange.fromJson(Map<String, dynamic>.from(value)),
        ),
      );
  }
}
