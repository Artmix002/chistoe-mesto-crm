import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

typedef HttpClientFactory = http.Client Function();

/// Сигнал отмены для сетевой операции.
///
/// Один сигнал можно передать во все запросы одного экрана или синхронизации:
/// при уходе с экрана отмена не даст им продолжить работу и не выполнит retry.
class RequestCancellation {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

class RequestCancelledException implements Exception {
  const RequestCancelledException();

  @override
  String toString() => 'RequestCancelledException: Запрос отменён';
}

/// Единая точка выполнения HTTP-запросов CRM.
///
/// Она даёт всем интеграциям одинаковые таймауты, повтор временных ошибок и
/// управляемую отмену. Тело ответа читается до конца, поэтому отмена работает
/// и после получения заголовков ответа.
class ApiClient {
  const ApiClient({
    this.timeout = const Duration(seconds: 20),
    this.clientFactory,
    this.defaultCancellation,
  });

  final Duration timeout;
  final HttpClientFactory? clientFactory;
  final RequestCancellation? defaultCancellation;

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    int retries = 2,
    RequestCancellation? cancellation,
  }) => _request(
    'GET',
    uri,
    headers: headers,
    retries: retries,
    cancellation: cancellation,
  );

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    int retries = 2,
    RequestCancellation? cancellation,
  }) => _request(
    'POST',
    uri,
    headers: headers,
    body: body,
    retries: retries,
    cancellation: cancellation,
  );

  Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    int retries = 2,
    RequestCancellation? cancellation,
  }) => _request(
    'PATCH',
    uri,
    headers: headers,
    body: body,
    retries: retries,
    cancellation: cancellation,
  );

  Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    int retries = 2,
    RequestCancellation? cancellation,
  }) => _request(
    'DELETE',
    uri,
    headers: headers,
    body: body,
    retries: retries,
    cancellation: cancellation,
  );

  Future<http.Response> _request(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    required int retries,
    RequestCancellation? cancellation,
  }) async {
    final effectiveCancellation = cancellation ?? defaultCancellation;
    if (retries < 0) {
      throw ArgumentError.value(
        retries,
        'retries',
        'Не может быть отрицательным',
      );
    }
    _throwIfCancelled(effectiveCancellation);

    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await _send(
          method,
          uri,
          headers: headers,
          body: body,
          cancellation: effectiveCancellation,
        );
        final retryable =
            response.statusCode >= 500 ||
            response.statusCode == 408 ||
            response.statusCode == 429;
        if (!retryable || attempt == retries) return response;
        await _waitBeforeRetry(response, attempt, effectiveCancellation);
      } on http.RequestAbortedException {
        throw const RequestCancelledException();
      } catch (_) {
        _throwIfCancelled(effectiveCancellation);
        if (attempt == retries) rethrow;
        await _waitBeforeRetry(null, attempt, effectiveCancellation);
      }
    }
    throw TimeoutException('Не удалось выполнить запрос', timeout);
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    RequestCancellation? cancellation,
  }) async {
    _throwIfCancelled(cancellation);
    final request =
        http.AbortableRequest(
            method,
            uri,
            abortTrigger: cancellation?.whenCancelled,
          )
          // Google Apps Script redirects a Web app request to its content host.
          // Following that redirect is required for the desktop CRM to receive
          // the JSON response instead of treating the normal 302 as an outage.
          ..followRedirects = true
          ..maxRedirects = 5;
    if (headers != null) request.headers.addAll(headers);
    if (body is String) {
      request.body = body;
    } else if (body is List<int>) {
      request.bodyBytes = body;
    } else if (body is Map<String, String>) {
      request.bodyFields = body;
    } else if (body != null) {
      throw ArgumentError.value(body, 'body', 'Неподдерживаемое тело запроса');
    }

    final client = clientFactory?.call() ?? http.Client();
    try {
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      // Apps Script responds to POST with a 302 to a one-time content URL.
      // dart:io follows a 302 as GET, which results in the Google 405 page.
      // Re-send the original request body once to that URL instead.
      if (response.statusCode == HttpStatus.found &&
          method == 'POST' &&
          response.headers['location'] != null) {
        final redirect = uri.resolve(response.headers['location']!);
        return await _sendPostRedirect(
          redirect,
          headers: headers,
          body: body,
          cancellation: cancellation,
        );
      }
      return response;
    } finally {
      client.close();
    }
  }

  Future<http.Response> _sendPostRedirect(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    RequestCancellation? cancellation,
  }) async {
    _throwIfCancelled(cancellation);
    final request = http.AbortableRequest(
      'POST',
      uri,
      abortTrigger: cancellation?.whenCancelled,
    )..followRedirects = false;
    if (headers != null) request.headers.addAll(headers);
    if (body is String) {
      request.body = body;
    } else if (body is List<int>) {
      request.bodyBytes = body;
    } else if (body is Map<String, String>) {
      request.bodyFields = body;
    } else if (body != null) {
      throw ArgumentError.value(body, 'body', 'Неподдерживаемое тело запроса');
    }
    final client = clientFactory?.call() ?? http.Client();
    try {
      return await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } finally {
      client.close();
    }
  }

  Future<void> _waitBeforeRetry(
    http.Response? response,
    int attempt,
    RequestCancellation? cancellation,
  ) async {
    final retryAfter = int.tryParse(response?.headers['retry-after'] ?? '');
    final delay = retryAfter != null && retryAfter > 0
        ? Duration(seconds: retryAfter)
        : Duration(milliseconds: 300 * (attempt + 1));
    final pause = Future<void>.delayed(delay);
    if (cancellation == null) {
      await pause;
    } else {
      await Future.any<void>([pause, cancellation.whenCancelled]);
      _throwIfCancelled(cancellation);
    }
  }

  void _throwIfCancelled(RequestCancellation? cancellation) {
    if (cancellation?.isCancelled == true) {
      throw const RequestCancelledException();
    }
  }
}
