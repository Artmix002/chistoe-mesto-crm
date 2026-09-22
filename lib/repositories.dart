import 'dart:convert';
import 'api_client.dart';
import 'models.dart';
import 'schema.dart';
import 'sync_queue.dart';

class SheetsRepository {
  SheetsRepository(
    this.sheetId, [
    this.client = const ApiClient(),
    this.protectedEndpoint,
    this.protectedToken = '',
  ]);
  final String sheetId;
  final ApiClient client;

  /// When configured, reads go through the authenticated backend instead of
  /// the legacy public gviz CSV endpoint.
  final Uri? protectedEndpoint;
  final String protectedToken;
  Future<List<List<String>>> readSheet(
    String sheet, {
    RequestCancellation? cancellation,
  }) async {
    final endpoint = protectedEndpoint;
    if (endpoint != null &&
        endpoint.scheme == 'https' &&
        protectedToken.trim().isNotEmpty) {
      final response = await client.post(
        endpoint,
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'operation': 'readSheet',
          'sheet': sheet,
          'sessionToken': protectedToken,
          'syncToken': protectedToken,
        }),
        cancellation: cancellation,
      );
      if (response.statusCode != 200) {
        throw Exception('Защищённое чтение Sheets HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      final serverError = decoded is Map
          ? decoded['error']?.toString().trim() ?? ''
          : '';
      if (serverError.isNotEmpty) {
        throw StateError('Защищённое чтение Sheets: $serverError');
      }
      if (decoded is! Map || decoded['rows'] is! List) {
        throw StateError('Некорректный ответ защищённого чтения Sheets');
      }
      return (decoded['rows'] as List)
          .whereType<List>()
          .map((row) => row.map((cell) => cell.toString()).toList())
          .toList(growable: false);
    }
    final uri = Uri.parse(
      'https://docs.google.com/spreadsheets/d/$sheetId/gviz/tq?tqx=out:csv&sheet=${Uri.encodeComponent(sheet)}',
    );
    final response = await client.get(uri, cancellation: cancellation);
    if (response.statusCode != 200) {
      throw Exception('Google Sheets HTTP ${response.statusCode}');
    }
    final text = utf8.decode(response.bodyBytes);
    return parseCsv(text);
  }

  /// Loads the protected CRM_* workspace snapshot. This is deliberately
  /// unavailable through public CSV: another computer restores operational
  /// data only after it has the same protected endpoint and secret.
  Future<WorkspaceSnapshot?> readWorkspace({
    RequestCancellation? cancellation,
  }) async {
    final endpoint = protectedEndpoint;
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        protectedToken.trim().isEmpty) {
      return null;
    }
    final response = await client.post(
      endpoint,
      headers: {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'operation': 'readWorkspace',
        'sessionToken': protectedToken,
        'syncToken': protectedToken,
      }),
      cancellation: cancellation,
    );
    if (response.statusCode != 200) {
      throw Exception('Защищённое чтение CRM HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Некорректный ответ защищённого чтения CRM');
    }
    final error = decoded['error']?.toString().trim() ?? '';
    if (error.isNotEmpty) {
      throw StateError('Защищённое чтение CRM: $error');
    }
    final workspace = decoded['workspace'];
    if (workspace is! Map) return null;
    final revisions = decoded['revisions'];
    return WorkspaceSnapshot(
      workspace: Map<String, dynamic>.from(workspace),
      revisions: revisions is Map
          ? revisions.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num?)?.toInt() ?? int.tryParse(value.toString()) ?? 0,
              ),
            )
          : const {},
    );
  }
}

class WorkspaceSnapshot {
  const WorkspaceSnapshot({required this.workspace, required this.revisions});
  final Map<String, dynamic> workspace;
  final Map<String, int> revisions;
}

class LocalRepository {
  const LocalRepository();
  String encodeClients(List<Client> values) =>
      jsonEncode(values.map((e) => e.toJson()).toList());
  String encodeStock(List<StockItem> values) =>
      jsonEncode(values.map((e) => e.toJson()).toList());
}

class ChangesPushResult {
  const ChangesPushResult({
    required this.acceptedIds,
    required this.revisions,
    this.conflictIds = const [],
    this.conflictScopes = const [],
  });
  final List<String> acceptedIds;
  final Map<String, int> revisions;
  final List<String> conflictIds;
  final List<String> conflictScopes;
}

/// Отправляет изменения в защищённый backend. Google Sheets остаётся источником
/// чтения; запись через публичный CSV намеренно не используется.
class ChangesSyncRepository {
  static const maxChangesPerRequest = 20;

  ChangesSyncRepository({
    required this.endpoint,
    required this.token,
    ApiClient? client,
  }) : client = client ?? const ApiClient();

  final Uri endpoint;
  final String token;
  final ApiClient client;

  static List<PendingChange> nextBatch(Iterable<PendingChange> changes) =>
      changes.take(maxChangesPerRequest).toList(growable: false);

  Future<ChangesPushResult> push(
    Iterable<PendingChange> changes, {
    RequestCancellation? cancellation,
  }) async {
    if (endpoint.scheme != 'https') {
      throw ArgumentError.value(endpoint, 'endpoint', 'Разрешён только HTTPS');
    }
    if (token.trim().isEmpty) {
      throw StateError('Не выполнен вход в общую CRM.');
    }
    final queued = changes.toList(growable: false);
    if (queued.length > maxChangesPerRequest) {
      throw ArgumentError.value(
        queued.length,
        'changes',
        'В одном запросе допускается не более $maxChangesPerRequest изменений',
      );
    }
    final response = await client.post(
      endpoint,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'schemaVersion': SheetsSchema.version,
        // Сессия передаётся в HTTPS-теле: Apps Script web apps не передают
        // заголовок Authorization в doPost.
        'sessionToken': token,
        'syncToken': token,
        'changes': queued.map((e) => e.toJson()).toList(),
      }),
      cancellation: cancellation,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Сервер синхронизации: HTTP ${response.statusCode}');
    }
    final body = response.body.trim();
    if (body.isEmpty) {
      throw StateError('Сервер не подтвердил идентификаторы изменений');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map || decoded['acceptedIds'] is! List) {
      throw StateError('Некорректное подтверждение сервера синхронизации');
    }
    final serverError = decoded['error']?.toString().trim() ?? '';
    if (serverError.isNotEmpty) {
      throw StateError('Сервер синхронизации: $serverError');
    }
    final queuedIds = queued.map((item) => item.id).toSet();
    final acceptedIds = (decoded['acceptedIds'] as List)
        .map((id) => id.toString())
        .where(queuedIds.contains)
        .toList(growable: false);
    final conflicts = decoded['conflicts'];
    final conflictIds = conflicts is List
        ? conflicts
              .whereType<Map>()
              .map((item) => item['id']?.toString() ?? '')
              .where(queuedIds.contains)
              .toList(growable: false)
        : const <String>[];
    final conflictScopes = conflicts is List
        ? conflicts
              .whereType<Map>()
              .map((item) => item['scope']?.toString() ?? '')
              .where((scope) => scope.isNotEmpty)
              .toSet()
              .toList(growable: false)
        : const <String>[];
    final revisions = decoded['revisions'];
    return ChangesPushResult(
      acceptedIds: acceptedIds,
      conflictIds: conflictIds,
      conflictScopes: conflictScopes,
      revisions: revisions is Map
          ? revisions.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as num?)?.toInt() ?? int.tryParse(value.toString()) ?? 0,
              ),
            )
          : const {},
    );
  }
}
