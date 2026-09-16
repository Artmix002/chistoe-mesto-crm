import 'dart:developer' as developer;

enum CrmLogLevel { debug, info, error }

class CrmLogger {
  const CrmLogger._();

  static void debug(String message, {String name = 'crm'}) =>
      _write(CrmLogLevel.debug, message, name: name);

  static void info(String message, {String name = 'crm'}) =>
      _write(CrmLogLevel.info, message, name: name);

  static void error(String message, {Object? error, String name = 'crm'}) =>
      _write(CrmLogLevel.error, message, error: error, name: name);

  static void _write(
    CrmLogLevel level,
    String message, {
    Object? error,
    required String name,
  }) {
    final safe = redact(message);
    developer.log(
      safe,
      name: name,
      level: switch (level) {
        CrmLogLevel.debug => 500,
        CrmLogLevel.info => 800,
        CrmLogLevel.error => 1000,
      },
      error: error == null ? null : redact(error.toString()),
    );
  }

  static String redact(String value) {
    var safe = value.replaceAllMapped(
      RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      (_) => 'Bearer [REDACTED]',
    );
    safe = safe.replaceAllMapped(
      RegExp(
        r'''\b(access[_-]?token|refresh[_-]?token|client[_-]?secret|api[_-]?key|sync[_-]?token|token)\b\s*['"]?\s*[:=]\s*['"]?([^,\s&}\]'"']+)''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=[REDACTED]',
    );
    return safe.replaceAllMapped(
      RegExp(
        r'([?&](?:access[_-]?token|refresh[_-]?token|client[_-]?secret|api[_-]?key|sync[_-]?token|token)=)[^&#\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );
  }
}
