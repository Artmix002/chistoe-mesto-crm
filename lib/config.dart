class AppConfig {
  static const sheetId = String.fromEnvironment(
    'CRM_SHEET_ID',
    defaultValue: '',
  );
  static const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  /// OAuth client ID is public configuration, but it must be present in the
  /// build. Without it Google responds with `Missing required parameter:
  /// client_id` before the user can sign in.
  static bool get googleClientIdConfigured =>
      isGoogleClientIdValid(googleClientId);

  /// HTTPS endpoint вашего backend, принимающий локальные изменения CRM.
  static const syncEndpoint = String.fromEnvironment('CRM_SYNC_ENDPOINT');
}

bool isGoogleClientIdValid(String value) => RegExp(
  r'^[0-9]+-[a-z0-9-]+\.apps\.googleusercontent\.com$',
).hasMatch(value.trim());

String explainGoogleOAuthError(String value) {
  final normalized = value.toLowerCase();
  if (normalized.contains('client_secret') && normalized.contains('missing')) {
    return 'Google требует client secret для этого Desktop-клиента. В CRM нажмите «Добавить client secret», вставьте секрет из Google Cloud и повторите подключение.';
  }
  if (normalized.contains('invalid_client') ||
      normalized.contains('provided client secret is invalid')) {
    return 'Google отклонил client secret: он не соответствует выбранному OAuth Client ID или был скопирован не полностью. Создайте новый секрет для этого Desktop-клиента и вставьте его целиком в CRM.';
  }
  return value;
}
