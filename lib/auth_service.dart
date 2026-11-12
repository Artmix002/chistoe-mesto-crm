import 'dart:convert';

import 'access_control.dart';
import 'api_client.dart';

class CrmSession {
  const CrmSession({
    required this.token,
    required this.user,
    required this.configuration,
  });

  final String token;
  final CrmUser user;
  final Map<String, dynamic> configuration;
}

class CrmUser {
  CrmUser({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
    Map<String, String>? permissions,
  }) : permissions = Map<String, String>.from(
         permissions ?? defaultPermissionsForRole(role),
       );

  final String id;
  String name;
  String role;
  bool active;
  Map<String, String> permissions;

  AccessControl get access => AccessControl(permissions);

  Map<String, dynamic> toJson({String? pin}) => {
    'id': id,
    'name': name,
    'role': role,
    'active': active,
    'permissions': permissions,
    if (pin != null && pin.isNotEmpty) 'pin': pin,
  };

  factory CrmUser.fromJson(Map<String, dynamic> json) => CrmUser(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    role: '${json['role'] ?? 'Сотрудник'}',
    active: json['active'] != false,
    permissions: json['permissions'] is Map
        ? (json['permissions'] as Map).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : null,
  );
}

class CrmAuthException implements Exception {
  const CrmAuthException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Клиент общего Apps Script API. PIN передаётся только при входе по HTTPS;
/// после этого на устройстве хранится лишь сессионный токен.
class CrmAuthService {
  CrmAuthService({required this.endpoint, ApiClient? client})
    : client = client ?? const ApiClient();

  final Uri endpoint;
  final ApiClient client;

  Future<Map<String, dynamic>> _call(
    String operation, {
    String? sessionToken,
    Map<String, dynamic> payload = const {},
    Duration? timeout,
  }) async {
    if (endpoint.scheme != 'https') {
      throw const CrmAuthException(
        'Адрес CRM-сервера должен использовать HTTPS.',
      );
    }
    final effective = timeout == null
        ? client
        : ApiClient(
            timeout: timeout,
            clientFactory: client.clientFactory,
            defaultCancellation: client.defaultCancellation,
          );
    final response = await effective.post(
      endpoint,
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'operation': operation,
        if (sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
        ...payload,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CrmAuthException(
        'CRM-сервер недоступен: HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const CrmAuthException('CRM-сервер вернул некорректный ответ.');
    }
    final result = Map<String, dynamic>.from(decoded);
    final error = result['error']?.toString().trim() ?? '';
    if (error.isNotEmpty) {
      throw CrmAuthException(error, code: result['errorCode']?.toString());
    }
    return result;
  }

  Future<List<CrmUser>> listUsers() async {
    final response = await _call('listUsers');
    final users = response['users'];
    if (users is! List) return const [];
    return users
        .whereType<Map>()
        .map((value) => CrmUser.fromJson(Map<String, dynamic>.from(value)))
        .where((user) => user.id.isNotEmpty && user.active)
        .toList(growable: false);
  }

  Future<CrmSession> login({
    required String userId,
    required String pin,
  }) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw const CrmAuthException('Введите PIN из 4 цифр.');
    }
    final response = await _call(
      'login',
      payload: {'userId': userId, 'pin': pin},
    );
    final user = response['user'];
    final token = response['sessionToken']?.toString() ?? '';
    if (user is! Map || token.isEmpty) {
      throw const CrmAuthException('CRM-сервер не выдал сессию.');
    }
    return CrmSession(
      token: token,
      user: CrmUser.fromJson(Map<String, dynamic>.from(user)),
      configuration: response['configuration'] is Map
          ? Map<String, dynamic>.from(response['configuration'])
          : const {},
    );
  }

  Future<CrmSession> resume(String sessionToken) async {
    final response = await _call('resumeSession', sessionToken: sessionToken);
    final user = response['user'];
    if (user is! Map) throw const CrmAuthException('Сессия недействительна.');
    return CrmSession(
      token: sessionToken,
      user: CrmUser.fromJson(Map<String, dynamic>.from(user)),
      configuration: response['configuration'] is Map
          ? Map<String, dynamic>.from(response['configuration'])
          : const {},
    );
  }

  Future<void> logout(String sessionToken) =>
      _call('logout', sessionToken: sessionToken);

  Future<List<CrmUser>> saveUser(
    String sessionToken,
    CrmUser user, {
    String? pin,
  }) async {
    final response = await _call(
      'saveUser',
      sessionToken: sessionToken,
      payload: {'user': user.toJson(pin: pin)},
    );
    final users = response['users'];
    return users is List
        ? users
              .whereType<Map>()
              .map((item) => CrmUser.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
        : const [];
  }

  Future<List<CrmUser>> deactivateUser(
    String sessionToken,
    String userId,
  ) async {
    final response = await _call(
      'deactivateUser',
      sessionToken: sessionToken,
      payload: {'userId': userId},
    );
    final users = response['users'];
    return users is List
        ? users
              .whereType<Map>()
              .map((item) => CrmUser.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
        : const [];
  }

  Future<Map<String, dynamic>> proxy(
    String sessionToken,
    Map<String, dynamic> request,
  ) => _call(
    'integrationProxy',
    sessionToken: sessionToken,
    payload: {'request': request},
  );

  Future<Map<String, dynamic>> migrateConfiguration(
    String sessionToken,
    Map<String, dynamic> configuration,
  ) => _call(
    'migrateConfiguration',
    sessionToken: sessionToken,
    payload: {'configuration': configuration},
  );

  Future<Map<String, dynamic>> importSheets(
    String sessionToken,
    Map<String, dynamic> sheets,
  ) => _call(
    'importSheets',
    sessionToken: sessionToken,
    payload: {'sheets': sheets},
    timeout: const Duration(minutes: 2),
  );

  Future<String> uploadPhoto(String sessionToken, List<int> bytes) async {
    final response = await _call(
      'uploadPhoto',
      sessionToken: sessionToken,
      payload: {'dataBase64': base64Encode(bytes)},
      timeout: const Duration(seconds: 60),
    );
    final url = response['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw const CrmAuthException('Сервер не вернул адрес фото.');
    }
    return url;
  }

  /// Список SKU, которые реально попадают в фид автозагрузки Авито.
  Future<Map<String, dynamic>> avitoFeedSkus(String sessionToken) => _call(
    'avitoFeedSkus',
    sessionToken: sessionToken,
    timeout: const Duration(seconds: 20),
  );

  /// Полное обновление справочника категорий (дерево + поля).
  Future<Map<String, dynamic>> avitoCatalogSync(
    String sessionToken, {
    required String clientId,
    required String clientSecret,
    bool onlyFailed = false,
  }) => _call(
    'avitoCatalogSync',
    sessionToken: sessionToken,
    payload: {
      'clientId': clientId,
      'clientSecret': clientSecret,
      if (onlyFailed) 'onlyFailed': true,
    },
    timeout: const Duration(minutes: 30),
  );

  /// Быстрое обновление только дерева категорий (1 запрос к Авито).
  Future<Map<String, dynamic>> avitoCatalogTree(
    String sessionToken, {
    required String clientId,
    required String clientSecret,
  }) => _call(
    'avitoCatalogTree',
    sessionToken: sessionToken,
    payload: {'clientId': clientId, 'clientSecret': clientSecret},
    timeout: const Duration(minutes: 2),
  );

  /// Кэшированный справочник: весь список или поля категории по slug.
  Future<Map<String, dynamic>> avitoCatalog(
    String sessionToken, {
    String? slug,
  }) => _call(
    'avitoCatalog',
    sessionToken: sessionToken,
    payload: {if (slug != null && slug.isNotEmpty) 'slug': slug},
    timeout: const Duration(seconds: 20),
  );

  /// Дети категории (пустой parent — корневые): маленький ответ.
  Future<Map<String, dynamic>> avitoCatalogChildren(
    String sessionToken, {
    String parent = '',
  }) => _call(
    'avitoCatalogChildren',
    sessionToken: sessionToken,
    payload: {'parent': parent},
    timeout: const Duration(seconds: 20),
  );

  /// Поиск категорий по названию на сервере.
  Future<Map<String, dynamic>> avitoCatalogSearch(
    String sessionToken,
    String query,
  ) => _call(
    'avitoCatalogSearch',
    sessionToken: sessionToken,
    payload: {'query': query},
    timeout: const Duration(seconds: 20),
  );

  /// Ход загрузки справочника.
  Future<Map<String, dynamic>> avitoCatalogProgress(String sessionToken) =>
      _call(
        'avitoCatalogProgress',
        sessionToken: sessionToken,
        timeout: const Duration(seconds: 15),
      );
}

bool isValidPin(String value) => RegExp(r'^\d{4}$').hasMatch(value);
