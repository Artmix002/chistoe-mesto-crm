import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crm/main.dart';
import 'package:crm/models.dart';
import 'package:crm/validation.dart';
import 'package:crm/xlsx_export.dart';
import 'package:crm/permissions.dart';
import 'package:crm/schema.dart';
import 'package:crm/navigation.dart';
import 'package:crm/finance.dart';
import 'package:crm/calendar_logic.dart';
import 'package:crm/sync_queue.dart';
import 'package:crm/deal_logic.dart';
import 'package:crm/client_logic.dart';
import 'package:crm/widgets/unified_inbox.dart';
import 'package:crm/widgets/calendar_components.dart';
import 'package:crm/widgets/calendar_workspace.dart';
import 'package:crm/widgets/calendar_connection_panel.dart';
import 'package:crm/widgets/calendar_appointment_dialog.dart';
import 'package:crm/widgets/finance_reports.dart';
import 'package:crm/widgets/offline_status_banner.dart';
import 'package:crm/widgets/messenger_connection_card.dart';
import 'package:crm/widgets/dashboard_stat_card.dart';
import 'package:crm/widgets/app_sidebar.dart';
import 'package:crm/widgets/dashboard_shell.dart';
import 'package:crm/widgets/overview_dashboard.dart';
import 'package:crm/widgets/notification_center_dialog.dart';
import 'package:crm/widgets/client_detail_dialog.dart';
import 'package:crm/widgets/settings_page.dart';
import 'package:crm/widgets/quick_replies_dialog.dart';
import 'package:crm/widgets/accounting_page.dart';
import 'package:crm/widgets/accounting_table.dart';
import 'package:crm/widgets/accounting_categories_dialog.dart';
import 'package:crm/widgets/local_operations_list.dart';
import 'package:crm/widgets/stock_page.dart';
import 'package:crm/widgets/deals_kanban_board.dart';
import 'package:crm/widgets/deals_grouped_table.dart';
import 'package:crm/widgets/client_results_list.dart';
import 'package:crm/widgets/telegram_inbox.dart';
import 'package:crm/widgets/instagram_inbox.dart';
import 'package:crm/widgets/vk_inbox.dart';
import 'package:crm/widgets/messages_page.dart';
import 'package:crm/widgets/messaging_panels.dart';
import 'package:crm/widgets/integration_diagnostics_dialog.dart';
import 'package:crm/widgets/avito_connection_card.dart';
import 'package:crm/logger.dart';
import 'package:crm/api_client.dart';
import 'package:crm/repositories.dart';
import 'package:crm/sync_payload.dart';
import 'package:crm/workspace_models.dart';
import 'package:crm/ai_service.dart';
import 'package:crm/app_notification.dart';
import 'package:crm/stock_logic.dart';
import 'package:crm/onboarding_logic.dart';
import 'package:crm/reconciliation.dart';
import 'package:crm/layout.dart';
import 'package:crm/app_constants.dart';
import 'package:crm/config.dart';
import 'package:crm/avito_cache.dart';
import 'package:crm/message_queue.dart';
import 'package:crm/oauth_pkce.dart';
import 'package:crm/secure_store.dart';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.response);

  final http.Response response;
  Object? sentBody;

  @override
  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    int retries = 2,
    RequestCancellation? cancellation,
  }) async {
    sentBody = body;
    return response;
  }
}

class _FakeAiApiClient extends ApiClient {
  _FakeAiApiClient({required this.getResponse, required this.postResponse});

  final http.Response getResponse;
  final http.Response postResponse;
  Uri? getUri;
  Uri? postUri;
  Object? postBody;
  Map<String, String>? postHeaders;

  @override
  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    int retries = 2,
    RequestCancellation? cancellation,
  }) async {
    getUri = uri;
    return getResponse;
  }

  @override
  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    int retries = 2,
    RequestCancellation? cancellation,
  }) async {
    postUri = uri;
    postBody = body;
    postHeaders = headers;
    return postResponse;
  }
}

class _FakeSheetApiClient extends ApiClient {
  _FakeSheetApiClient(this.response);

  final http.Response response;
  Object? sentBody;
  Uri? sentUri;

  @override
  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    int retries = 2,
    RequestCancellation? cancellation,
  }) async {
    sentUri = uri;
    sentBody = body;
    return response;
  }
}

class _BlockingAbortableClient extends http.BaseClient {
  _BlockingAbortableClient(this.requestStarted);

  final Completer<void> requestStarted;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!requestStarted.isCompleted) requestStarted.complete();
    final abortable = request as http.Abortable;
    return abortable.abortTrigger!.then<http.StreamedResponse>(
      (_) => throw http.RequestAbortedException(),
    );
  }
}

class _RecordingHttpClient extends http.BaseClient {
  final List<String> methods = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    methods.add(request.method);
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }
}

void main() {
  test('AiSettings defaults to GPT-5.4 and migrates the old default', () {
    expect(const AiSettings().model, 'gpt-5.4');
    expect(AiSettings.fromJson({'model': 'claude-haiku-4-5'}).model, 'gpt-5.4');
  });

  test('Avito transcription keeps client and employee speakers', () {
    final lines = parseTranscriptLines(
      'Клиент: Здравствуйте\nСотрудник: Добрый день\nГоворящий: Не слышно',
    );
    expect(lines[0].speaker, TranscriptSpeaker.client);
    expect(lines[1].speaker, TranscriptSpeaker.employee);
    expect(lines[2].speaker, TranscriptSpeaker.unknown);
    expect(lines[1].text, 'Добрый день');
  });

  test('structured transcript analysis exposes recommended actions', () {
    final analysis = parseTranscriptAnalysis(
      '{"overview":"Обсудили мойку","agreements":"Запись подтверждена","nextSteps":"Приехать","openQuestions":"не зафиксировано","actions":[{"type":"appointment","title":"Мойка","date":"2026-09-05","time":"12:00","service":"Мойка автомобиля","confidence":0.9,"missing":[]}]}',
    );
    expect(analysis.overview, 'Обсудили мойку');
    expect(analysis.actions.single.type, AiActionType.appointment);
    expect(analysis.actions.single.date, '2026-09-05');
  });

  test('transcript analysis cache preserves text and action metadata', () {
    final original = AiTranscriptAnalysis(
      overview: 'Клиент интересуется мойкой',
      agreements: 'Запись на пятницу',
      nextSteps: 'Подтвердить время',
      openQuestions: 'не зафиксировано',
      actions: const [
        AiActionRecommendation(
          type: AiActionType.note,
          title: 'Перезвонить',
          details: 'Подтвердить время записи',
          confidence: .8,
        ),
      ],
    );
    final restored = AiTranscriptAnalysis.fromJson(original.toJson());
    expect(restored.displayText, contains('Запись на пятницу'));
    expect(restored.actions.single.type, AiActionType.note);
    expect(restored.actions.single.details, 'Подтвердить время записи');
  });

  test(
    'GPT formats a raw Avito transcript into speaker-labelled lines',
    () async {
      final client = _FakeAiApiClient(
        getResponse: http.Response('{}', 404),
        postResponse: http.Response.bytes(
          utf8.encode(
            '{"choices":[{"message":{"content":"Клиент: Здравствуйте\\nСотрудник: Добрый день"}}]}',
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final provider = OpenAiCompatibleProvider(
        apiKey: 'test-key',
        client: client,
      );
      final result = await provider.formatTranscript(
        'Здравствуйте. Добрый день.',
        settings: const AiSettings(enabled: true),
      );
      expect(result, contains('Клиент:'));
      expect(result, contains('Сотрудник:'));
      final payload =
          jsonDecode(client.postBody! as String) as Map<String, dynamic>;
      expect(
        (payload['messages'] as List).first['content'],
        contains('Не добавляй'),
      );
    },
  );

  test('GPT analyzes an Avito transcript into a structured summary', () async {
    final client = _FakeAiApiClient(
      getResponse: http.Response('{}', 404),
      postResponse: http.Response.bytes(
        utf8.encode(
          '{"choices":[{"message":{"content":"Обзор: Обсудили мойку.\\nДоговорились: Запись на завтра."}}]}',
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final provider = OpenAiCompatibleProvider(
      apiKey: 'test-key',
      client: client,
    );
    final result = await provider.analyzeTranscript(
      'Клиент: Можно завтра?\nСотрудник: Да, записал.',
      settings: const AiSettings(enabled: true),
    );
    expect(result, contains('Договорились:'));
    final payload =
        jsonDecode(client.postBody! as String) as Map<String, dynamic>;
    expect(
      (payload['messages'] as List).first['content'],
      contains('openQuestions'),
    );
  });

  test(
    'Codex Sale provider probes GPT-5.4 with OpenAI-compatible payload',
    () async {
      final client = _FakeAiApiClient(
        getResponse: http.Response('{"data":[{"id":"gpt-5.4"}]}', 200),
        postResponse: http.Response(
          '{"choices":[{"message":{"content":"OK"}}]}',
          200,
        ),
      );
      final provider = OpenAiCompatibleProvider(
        apiKey: 'test-key',
        client: client,
      );
      final result = await provider.verifyConnection(
        settings: const AiSettings(enabled: true),
      );

      expect(result.model, 'gpt-5.4');
      expect(client.getUri?.path, '/v1/models');
      expect(client.postUri?.path, '/v1/chat/completions');
      expect(client.postHeaders?['authorization'], 'Bearer test-key');
      final payload =
          jsonDecode(client.postBody! as String) as Map<String, dynamic>;
      expect(payload['model'], 'gpt-5.4');
      expect((payload['messages'] as List).last['content'], 'Ответь ровно: OK');
    },
  );

  test(
    'AI sends only recent conversation turns and asks for a concise answer',
    () async {
      final client = _FakeAiApiClient(
        getResponse: http.Response('{}', 404),
        postResponse: http.Response.bytes(
          utf8.encode(
            '{"choices":[{"message":{"content":"Да, можем записать."}}]}',
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      final provider = OpenAiCompatibleProvider(
        apiKey: 'test-key',
        client: client,
      );
      await provider.reply(
        question: 'Можно ли записаться?',
        knowledgeBase: '## Запись\n- Запись доступна ежедневно.',
        history: [
          for (var i = 0; i < 14; i++)
            BotMessage(
              id: 'm$i',
              role: i.isEven ? 'user' : 'assistant',
              text: 'старое сообщение $i',
              createdAt: '',
            ),
          BotMessage(
            id: 'current',
            role: 'user',
            text: 'Можно ли записаться?',
            createdAt: '',
          ),
        ],
        settings: const AiSettings(enabled: true),
      );
      final payload =
          jsonDecode(client.postBody! as String) as Map<String, dynamic>;
      final messages = payload['messages'] as List;
      expect(
        messages.length,
        14,
      ); // system + 12 recent turns + current question
      expect(messages[1]['content'], 'старое сообщение 2');
      expect(messages[messages.length - 1]['content'], 'Можно ли записаться?');
      expect(
        messages.first['content'],
        contains('Не пересказывай всю базу знаний'),
      );
    },
  );

  test('CSV parser handles quoted commas', () {
    expect(parseCsvLine('"Иванов, Иван",BMW,"18 500"'), [
      'Иванов, Иван',
      'BMW',
      '18 500',
    ]);
  });

  test('PKCE uses the RFC 7636 S256 challenge', () {
    const verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
    expect(
      pkceCodeChallenge(verifier),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
    expect(generatePkceCodeVerifier().length, inInclusiveRange(43, 128));
  });

  test('Google OAuth configuration rejects an empty client ID', () {
    expect(isGoogleClientIdValid(''), isFalse);
    expect(
      isGoogleClientIdValid(
        '123456789012-abcdefghijklmnopqrstuvwxyz123456.apps.googleusercontent.com',
      ),
      isTrue,
    );
  });

  test('Google OAuth explains a web client missing its secret', () {
    expect(
      explainGoogleOAuthError(
        'Google OAuth: invalid_request — client_secret is missing',
      ),
      contains('Добавить client secret'),
    );
    expect(
      explainGoogleOAuthError(
        'Google OAuth: invalid_client — The provided client secret is invalid',
      ),
      contains('не соответствует выбранному OAuth Client ID'),
    );
  });

  test('empty secure-storage entries are eligible for legacy migration', () {
    expect(shouldMigrateSecret(null), isTrue);
    expect(shouldMigrateSecret(''), isTrue);
    expect(shouldMigrateSecret('stored-token'), isFalse);
  });

  test('API client cancels a request before sending it', () async {
    final cancellation = RequestCancellation()..cancel();
    await expectLater(
      const ApiClient().get(
        Uri.parse('https://crm.example.com/sync'),
        cancellation: cancellation,
      ),
      throwsA(isA<RequestCancelledException>()),
    );
  });

  test('API client applies its lifecycle cancellation by default', () async {
    final cancellation = RequestCancellation()..cancel();
    await expectLater(
      ApiClient(
        defaultCancellation: cancellation,
      ).get(Uri.parse('https://crm.example.com/sync')),
      throwsA(isA<RequestCancelledException>()),
    );
  });

  test('API client aborts an in-flight request', () async {
    final requestStarted = Completer<void>();
    final cancellation = RequestCancellation();
    final response =
        ApiClient(
          clientFactory: () => _BlockingAbortableClient(requestStarted),
        ).get(
          Uri.parse('https://crm.example.com/sync'),
          cancellation: cancellation,
        );
    await requestStarted.future;
    cancellation.cancel();
    await expectLater(response, throwsA(isA<RequestCancelledException>()));
  });

  test(
    'API client sends PATCH and DELETE through the shared transport',
    () async {
      final transport = _RecordingHttpClient();
      final client = ApiClient(clientFactory: () => transport);
      final endpoint = Uri.parse('https://crm.example.com/record');
      await client.patch(endpoint, body: '{"status":"done"}');
      await client.delete(endpoint);
      expect(transport.methods, ['PATCH', 'DELETE']);
    },
  );

  test('CSV document preserves quoted line breaks', () {
    final rows = parseCsv('name,note\n"Иван","первая строка\nвторая строка"\n');
    expect(rows, hasLength(2));
    expect(rows[1][1], 'первая строка\nвторая строка');
  });
  test('Deal validation and profit are deterministic', () {
    final deal = Deal(
      id: '1',
      date: '01.01.2026',
      clientId: 'c1',
      clientName: 'Иван',
      revenue: 1000,
      expenses: 250,
    );
    expect(deal.profit, 750);
    expect(deal.validate(), isEmpty);
    expect(
      Deal(
        id: '2',
        date: '',
        clientId: '',
        clientName: '',
        revenue: 0,
      ).validate(),
      isNotEmpty,
    );
  });
  test('legacy deal row maps to typed deal', () {
    final deal = Deal.fromRow([
      '01.08.2026',
      'BMW',
      '+7999',
      'Полировка',
      'Егор',
      '1 500',
      '200',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      'Выполнен',
      'Иван',
      'Avito',
      'Комментарий',
    ]);
    expect(deal.clientName, 'Иван');
    expect(deal.revenue, 1500);
    expect(deal.profit, 1300);
    final linkedRow = List<String>.filled(19, '');
    linkedRow[2] = '8 999 000 00 00';
    linkedRow[17] = 'Иван';
    expect(Deal.fromRow(linkedRow).clientId, 'client-phone-79990000000');
    final persistedRow = List<String>.filled(22, '');
    persistedRow[21] = 'deal-stable-1';
    expect(Deal.fromRow(persistedRow).id, 'deal-stable-1');
  });

  test('deal recalculation keeps manually entered payouts', () {
    final row = List<String>.filled(21, '');
    row[4] = 'Егор';
    row[5] = '1000';
    row[6] = '200';
    row[9] = '80';
    row[11] = '360';
    final recalculated = recalculateDealRow(row);
    expect(recalculated[7], '800');
    expect(recalculated[9], '80');
    expect(recalculated[11], '360');
    expect(recalculated[12], '360');
    expect(recalculated[15], '0');
    expect(dealCalculationChanged(row, recalculated), isTrue);
  });

  test('business reserve label identifies car and service', () {
    final row = List<String>.filled(18, '');
    row[1] = 'Kia Rio';
    row[3] = 'Установка камеры заднего вида';
    row[17] = 'Иван';
    expect(dealReserveLabel(row), 'Kia Rio — Установка камеры заднего вида');
  });

  test('manual deal calculation preserves manually allocated payouts', () {
    final row = List<String>.filled(21, '');
    row[5] = '1000';
    row[6] = '100';
    row[9] = '123';
    row[20] = 'Да';
    final recalculated = recalculateDealRow(row);
    expect(recalculated[7], '900');
    expect(recalculated[9], '123');
  });
  test('deal field validation rejects invalid values', () {
    expect(
      validateDealFields(client: '', revenue: '-1', expenses: 'x'),
      hasLength(3),
    );
  });
  test('client serializes history', () {
    final c = Client(
      id: 'c',
      name: 'Test',
      car: 'BMW',
      phones: const ['+79990000000', '+78880000000'],
      cars: const ['BMW', 'Audi'],
      responsible: 'Мастер',
      telegramChatId: '123',
      vkPeerId: '456',
    );
    c.carHistory.add('BMW');
    c.lastContact = '2026-08-31T10:00:00Z';
    final restored = Client.fromJson(c.toJson());
    expect(restored.carHistory, contains('BMW'));
    expect(restored.lastContact, c.lastContact);
    expect(restored.responsible, 'Мастер');
    expect(restored.telegramChatId, '123');
    expect(restored.vkPeerId, '456');
    expect(restored.phones, contains('+78880000000'));
    expect(restored.cars, contains('Audi'));
    expect(restored.vehicleIdFor('BMW'), 'vehicle-c-bmw');
  });

  test('audit entry keeps actor information', () {
    final entry = AuditEntry(
      action: 'Изменён',
      entity: 'Сделка',
      date: 'now',
      actor: 'Бухгалтер',
    );
    expect(AuditEntry.fromJson(entry.toJson()).actor, 'Бухгалтер');
  });

  test('user profile persists assigned role', () {
    final profile = UserProfile(id: 'master-1', name: 'Егор', role: 'Мастер');
    final restored = UserProfile.fromJson(profile.toJson());
    expect(restored.name, 'Егор');
    expect(restored.role, 'Мастер');
    expect(restored.active, isTrue);
  });

  test('XLSX export creates a readable workbook archive', () {
    final bytes = buildXlsx(
      sheetName: 'Сделки',
      rows: const [
        ['Клиент', 'Сумма'],
        ['Иван', '1500'],
      ],
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(
      archive.files.map((f) => f.name),
      contains('xl/worksheets/sheet1.xml'),
    );
  });

  test('role policy protects functional areas', () {
    expect(RolePolicy.canEdit('Бухгалтер', 'finance'), isTrue);
    expect(RolePolicy.canEdit('Бухгалтер', 'deals'), isFalse);
    expect(RolePolicy.canEdit('Бухгалтер', 'stock'), isFalse);
    expect(RolePolicy.canEdit('Мастер', 'clients'), isTrue);
    expect(RolePolicy.canEdit('Мастер', 'stock'), isTrue);
    expect(RolePolicy.canEdit('Мастер', 'finance'), isFalse);
    expect(RolePolicy.canEdit('Только просмотр', 'finance'), isFalse);
    expect(RolePolicy.canManageIntegrations('Администратор'), isTrue);
  });

  test('sheet schema reports missing required columns', () {
    expect(
      SheetsSchema.missingColumns([
        'Авто',
        'Телефон',
      ], SheetsSchema.requiredDealColumns),
      contains('Услуга'),
    );
    expect(SheetsSchema.crmClientColumns, contains('telegramChatId'));
    expect(SheetsSchema.crmClosedPeriodColumns, contains('ownerProfit'));
  });

  test('sheets repository reads through the protected endpoint', () async {
    final client = _FakeSheetApiClient(
      http.Response(
        jsonEncode({
          'schemaVersion': SheetsSchema.version,
          'rows': [
            ['Дата', 'Сумма'],
            ['31.08.2026', '1 200,50'],
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final repository = SheetsRepository(
      'sheet-id',
      client,
      Uri.parse('https://crm.example.com/sync'),
      'secret',
    );
    expect(await repository.readSheet('Основное'), [
      ['Дата', 'Сумма'],
      ['31.08.2026', '1 200,50'],
    ]);
    final body = jsonDecode(client.sentBody! as String) as Map;
    expect(body['operation'], 'readSheet');
    expect(body['sheet'], 'Основное');
    expect(body['syncToken'], 'secret');
  });

  test('sheets repository restores protected workspace snapshots', () async {
    final client = _FakeSheetApiClient(
      http.Response(
        jsonEncode({
          'workspace': {
            'clients': [
              {'id': 'client-remote', 'name': 'Maria'},
            ],
            'manualDeals': [
              ['01.09.2026', '', '', 'Polish'],
            ],
          },
        }),
        200,
      ),
    );
    final repository = SheetsRepository(
      'sheet-id',
      client,
      Uri.parse('https://sync.example.test/run'),
      'secret',
    );
    final workspace = await repository.readWorkspace();
    expect(workspace?['clients'], isA<List>());
    expect((workspace?['clients'] as List).single['id'], 'client-remote');
    expect(jsonDecode(client.sentBody as String)['operation'], 'readWorkspace');
  });

  test('navigation pages and icons stay aligned', () {
    expect(crmPages.length, crmPageIcons.length);
  });

  test('compact navigation activates for narrow CRM windows', () {
    expect(usesCompactNavigation(979), isTrue);
    expect(usesCompactNavigation(980), isFalse);
  });

  test('search updates use a short common debounce interval', () {
    expect(AppConstants.searchDebounce, const Duration(milliseconds: 250));
  });

  test(
    'pending message keeps a stable VK delivery identity across retries',
    () {
      final item = preparePendingMessage(const {
        'channel': 'vk',
        'peer': '1',
        'text': 'Здравствуйте',
      }, now: DateTime(2026, 9, 1, 10));
      final same = preparePendingMessage(item, now: DateTime(2026, 9, 1, 11));
      expect(same['id'], item['id']);
      expect(same['vkRandomId'], item['vkRandomId']);
      expect(isSamePendingDelivery(item, same), isTrue);
      markPendingAttempt(item, DateTime(2026, 9, 1, 10, 1));
      expect(item['attempts'], '1');
    },
  );

  test('outgoing queue accepts only supported integration channels', () {
    expect(isSupportedOutgoingChannel('vk'), isTrue);
    expect(isSupportedOutgoingChannel('telegram'), isTrue);
    expect(isSupportedOutgoingChannel('unknown'), isFalse);
    expect(isSupportedOutgoingChannel(null), isFalse);
  });

  test('outgoing queue applies exponential retry delay', () {
    final message = preparePendingMessage({
      'channel': 'telegram',
      'chat': '42',
      'text': 'Напоминание',
    }, now: DateTime.utc(2026, 8, 31, 10));
    markPendingAttempt(message, DateTime.utc(2026, 8, 31, 10));
    expect(pendingRetryDelay(1), const Duration(seconds: 10));
    expect(
      isPendingRetryReady(message, DateTime.utc(2026, 8, 31, 10, 0, 9)),
      isFalse,
    );
    expect(
      isPendingRetryReady(message, DateTime.utc(2026, 8, 31, 10, 0, 10)),
      isTrue,
    );
  });

  test('Avito audio cache removes oldest files before exceeding limits', () {
    final plan = planAvitoCache(
      [
        CachedAudioFile(
          path: 'old.mp3',
          byteLength: 4,
          modified: DateTime.utc(2026, 8, 31, 9),
        ),
        CachedAudioFile(
          path: 'middle.mp3',
          byteLength: 4,
          modified: DateTime.utc(2026, 8, 31, 10),
        ),
        CachedAudioFile(
          path: 'new.mp3',
          byteLength: 4,
          modified: DateTime.utc(2026, 8, 31, 11),
        ),
      ],
      maxFiles: 2,
      maxBytes: 8,
    );
    expect(plan.evictions.map((file) => file.path), ['old.mp3']);
    expect(plan.retainedCount, 2);
    expect(plan.retainedBytes, 8);
    expect(formatAvitoCacheSize(1024 * 1024), '1.0 МБ');
  });

  test('financial snapshot calculates profit and margin', () {
    final snapshot = summarizeDeals([
      Deal(
        id: '1',
        date: '',
        clientId: '',
        clientName: 'A',
        revenue: 1000,
        expenses: 250,
      ),
      Deal(
        id: '2',
        date: '',
        clientId: '',
        clientName: 'B',
        revenue: 500,
        expenses: 100,
      ),
    ]);
    expect(snapshot.revenue, 1500);
    expect(snapshot.profit, 1150);
    expect(snapshot.margin, closeTo(76.666, .01));
  });

  test(
    'financial snapshot keeps payroll, reserve and owner result separate',
    () {
      final snapshot = summarizeDeals([
        Deal(
          id: '1',
          date: '',
          clientId: '',
          clientName: 'A',
          revenue: 1000,
          expenses: 200,
          workerPayout: 300,
          businessReserve: 100,
          ownerProfit: 400,
        ),
        Deal(
          id: '2',
          date: '',
          clientId: '',
          clientName: 'B',
          revenue: 500,
          expenses: 100,
          workerPayout: 100,
          businessReserve: 50,
        ),
      ]);
      expect(snapshot.workerPayout, 400);
      expect(snapshot.businessReserve, 150);
      expect(snapshot.effectiveOwnerProfit, 650);
    },
  );

  test('business account balance is cumulative and independent of period', () {
    final deals = [
      Deal(
        id: 'august',
        date: '01.08.2026',
        clientId: '',
        clientName: 'A',
        businessReserve: 200,
      ),
      Deal(
        id: 'september',
        date: '01.09.2026',
        clientId: '',
        clientName: 'B',
        businessReserve: 500,
      ),
    ];
    expect(
      businessAccountBalance(deals, const [
        {'amount': -100},
      ]),
      600,
    );
  });

  test(
    'business account movements are ordered by date, not operation type',
    () {
      final sorted = sortBusinessTransactionsByDate([
        {'id': 'expense', 'date': '02.09.2026', 'amount': -500},
        {'id': 'deal', 'date': '04.09.2026', 'amount': 1200},
        {'id': 'income', 'date': '03.09.2026', 'amount': 1000},
      ]);
      expect(sorted.map((item) => item['id']), ['deal', 'income', 'expense']);
    },
  );

  test('business account sorting keeps invalid calendar dates at the end', () {
    final sorted = sortBusinessTransactionsByDate([
      {'id': 'invalid', 'date': '31.09.2026', 'amount': 400},
      {'id': 'valid', 'date': '04.09.2026', 'amount': 1000},
    ]);
    expect(sorted.map((item) => item['id']), ['valid', 'invalid']);
  });

  test('daily revenue period includes days without completed work', () {
    expect(
      elapsedCalendarDaysInPeriod(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        now: DateTime(2026, 9, 6, 18),
      ),
      6,
    );
    expect(
      elapsedCalendarDaysInPeriod(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
        now: DateTime(2026, 9, 6),
      ),
      31,
    );
    expect(
      elapsedCalendarDaysInPeriod(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
        now: DateTime(2026, 9, 6),
      ),
      0,
    );
  });

  test(
    'finance reconciliation compares only explicitly named sheet columns',
    () {
      final report = reconcileFinanceSources(
        deals: [
          Deal(
            id: '1',
            date: '01.08.2026',
            clientId: 'c',
            clientName: 'Иван',
            revenue: 1000,
            expenses: 200,
          ),
        ],
        accountingRows: const [
          ['Дата', 'Выручка', 'Расходы'],
          ['01.08.2026', '1 000', '200'],
        ],
        transactions: const [
          {'source': 'google_sheets', 'date': '01.08.2026', 'amount': -200},
        ],
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
      );
      expect(report.isReconciled, isTrue);
      expect(report.expensesSheetAmount, 200);
      expect(report.discrepancies, isEmpty);
    },
  );

  test('finance reconciliation reports mismatched named totals', () {
    final report = reconcileFinanceSources(
      deals: [
        Deal(
          id: '1',
          date: '',
          clientId: 'c',
          clientName: 'Иван',
          revenue: 1000,
        ),
      ],
      accountingRows: const [
        ['Выручка'],
        ['900'],
      ],
      transactions: const [],
    );
    expect(report.isReconciled, isFalse);
    expect(
      report.discrepancies,
      contains('Выручка сделок отличается от листа «Основное»'),
    );
  });

  test('performance report groups services, staff and daily load', () {
    final report = summarizeDealPerformance([
      Deal(
        id: '1',
        date: '01.08.2026',
        clientId: 'c1',
        clientName: 'Иван',
        service: 'Полировка',
        performers: 'Егор, Артём',
        revenue: 1000,
        expenses: 200,
        workerPayout: 300,
      ),
      Deal(
        id: '2',
        date: '01.08.2026',
        clientId: 'c2',
        clientName: 'Пётр',
        service: 'Полировка',
        performers: 'Егор',
        revenue: 500,
        expenses: 100,
        workerPayout: 150,
      ),
    ]);
    expect(report.byService['Полировка']!.profit, 1200);
    expect(report.byService['Полировка']!.dealCount, 2);
    expect(report.byPerformer['Егор']!.workerPayout, 300);
    expect(report.byDay['01.08.2026']!.dealCount, 2);
    expect(report.activeDays, 1);
  });

  test(
    'closed financial period accepts Russian dates only inside its range',
    () {
      final period = {
        'from': '2026-08-01T00:00:00.000',
        'to': '2026-08-31T00:00:00.000',
      };
      expect(isDateWithinClosedPeriod('31.08.2026', period), isTrue);
      expect(isDateWithinClosedPeriod('01.09.2026', period), isFalse);
    },
  );

  test('sheet expenses import keeps source and avoids duplicates', () {
    final rows = importSheetExpenses([
      const [
        'x',
        'x',
        'x',
        'exp-1',
        '31.08.2026',
        'x',
        'Материалы',
        '1 250,50',
      ],
      const [
        'x',
        'x',
        'x',
        'exp-1',
        '31.08.2026',
        'x',
        'Материалы',
        '1 250,50',
      ],
    ]);
    expect(rows, hasLength(1));
    expect(rows.single['amount'], -1250.5);
    expect(rows.single['source'], 'google_sheets');
  });

  test(
    'financial operations cannot change closed periods or use invalid date',
    () {
      final periods = [
        {'from': '2026-08-01T00:00:00.000', 'to': '2026-08-31T00:00:00.000'},
      ];
      expect(isFinancialOperationEditable('31.08.2026', periods), isFalse);
      expect(isFinancialOperationEditable('01.09.2026', periods), isTrue);
      expect(isFinancialOperationEditable('не дата', periods), isFalse);
    },
  );

  test('stock movement keeps deal link and calculates material cost', () {
    final movement = StockMovement(
      id: 'm1',
      itemId: 'i1',
      type: 'Расход',
      quantity: 2.5,
      date: '2026-08-31',
      dealId: 'deal-1',
      service: 'Полировка',
    );
    final restored = StockMovement.fromJson(movement.toJson());
    expect(restored.dealId, 'deal-1');
    expect(restored.service, 'Полировка');
    expect(restored.costAt(120), 300);
  });

  test('stock weighted average price uses quantity of each receipt', () {
    expect(
      weightedAveragePrice(
        currentQuantity: 10,
        currentPrice: 100,
        receivedQuantity: 5,
        receivedPrice: 160,
      ),
      closeTo(120, 0.001),
    );
  });

  test(
    'stock inventory sets actual balance while write-off cannot go below zero',
    () {
      final inventory = calculateStockAdjustment(
        type: 'Инвентаризация',
        currentQuantity: 5,
        enteredQuantity: 8,
      );
      expect(inventory.isValid, isTrue);
      expect(inventory.resultingQuantity, 8);
      expect(inventory.delta, 3);
      final writeOff = calculateStockAdjustment(
        type: 'Списание',
        currentQuantity: 2,
        enteredQuantity: 3,
      );
      expect(writeOff.isValid, isFalse);
    },
  );

  test('onboarding leads to the first incomplete required connection', () {
    expect(
      const OnboardingProgress(
        sheetConfigured: false,
        calendarConfigured: false,
        channelConfigured: false,
      ).nextPageIndex,
      6,
    );
    const onlyCalendar = OnboardingProgress(
      sheetConfigured: true,
      calendarConfigured: false,
      channelConfigured: false,
    );
    expect(onlyCalendar.nextPageIndex, 3);
    expect(onlyCalendar.isReadyToFinish, isFalse);
    expect(
      const OnboardingProgress(
        sheetConfigured: true,
        calendarConfigured: true,
        channelConfigured: false,
      ).isReadyToFinish,
      isTrue,
    );
  });

  test('calendar conflict detects overlapping intervals', () {
    final start = DateTime(2026, 8, 31, 10);
    expect(
      intervalsOverlap(
        start,
        start.add(const Duration(hours: 1)),
        start.add(const Duration(minutes: 30)),
        start.add(const Duration(hours: 2)),
      ),
      isTrue,
    );
    expect(
      intervalsOverlap(
        start,
        start.add(const Duration(hours: 1)),
        start.add(const Duration(hours: 1)),
        start.add(const Duration(hours: 2)),
      ),
      isFalse,
    );
    expect(
      hasCalendarConflict(
        [
          {
            'id': 'event-1',
            'start': {'dateTime': '2026-08-31T10:00:00Z'},
            'end': {'dateTime': '2026-08-31T11:00:00Z'},
          },
        ],
        DateTime(2026, 8, 31, 13, 30),
        DateTime(2026, 8, 31, 14),
      ),
      isTrue,
    );
    expect(moscowIso(DateTime(2026, 8, 31, 9, 5)), '2026-08-31T09:05:00');
  });

  test(
    'calendar resource conflict allows parallel work on other resources',
    () {
      final events = [
        {
          'id': 'event-1',
          'start': {'dateTime': '2026-08-31T07:00:00Z'},
          'end': {'dateTime': '2026-08-31T08:00:00Z'},
          'extendedProperties': {
            'private': {
              'performer': 'Егор, Артём',
              'vehicleId': 'vehicle-1',
              'car': 'BMW X3',
            },
          },
        },
      ];
      final start = DateTime(2026, 8, 31, 10, 30);
      final end = DateTime(2026, 8, 31, 11, 30);
      expect(
        findCalendarResourceConflict(
          events,
          start,
          end,
          performer: 'Артём',
          vehicleId: 'vehicle-2',
          vehicle: 'Audi A6',
        ),
        CalendarConflictKind.performer,
      );
      expect(
        findCalendarResourceConflict(
          events,
          start,
          end,
          performer: 'Иван',
          vehicleId: 'vehicle-1',
          vehicle: 'BMW X3',
        ),
        CalendarConflictKind.vehicle,
      );
      expect(
        findCalendarResourceConflict(
          events,
          start,
          end,
          performer: 'Иван',
          vehicleId: 'vehicle-2',
          vehicle: 'Audi A6',
        ),
        isNull,
      );
    },
  );

  test('appointment reminder is limited to the two-hour window', () {
    final start = DateTime(2026, 8, 31, 12);
    expect(
      isAppointmentReminderDue(start: start, now: DateTime(2026, 8, 31, 9, 59)),
      isFalse,
    );
    expect(
      isAppointmentReminderDue(start: start, now: DateTime(2026, 8, 31, 10)),
      isTrue,
    );
    expect(
      isAppointmentReminderDue(
        start: start,
        now: DateTime(2026, 8, 31, 11, 50),
      ),
      isFalse,
    );
  });

  test('service duration templates add up only configured services', () {
    expect(
      calculateServiceTemplateDuration(
        const ['Полировка', 'Химчистка', 'Неизвестно'],
        const {'Полировка': 2, 'Химчистка': 3.5},
      ),
      5.5,
    );
  });

  test('calendar filtering and day grouping handle local event dates', () {
    final events = [
      {
        'summary': 'Полировка BMW',
        'description': 'Иван',
        'start': {'dateTime': '2026-08-31T10:00:00'},
      },
      {
        'summary': 'Химчистка',
        'description': 'Пётр',
        'start': {'dateTime': '2026-09-01T11:00:00'},
      },
    ];
    expect(filterCalendarEvents(events, 'иван'), hasLength(1));
    expect(calendarEventsForDay(events, DateTime(2026, 8, 31)), hasLength(1));
    expect(russianMonthName(DateTime(2026, 8)), 'Август');
  });

  test('appointment cancellation requires a reason', () {
    expect(isCancellationReasonValid(''), isFalse);
    expect(isCancellationReasonValid('   '), isFalse);
    expect(isCancellationReasonValid('Клиент попросил перенести'), isTrue);
  });

  test('sync queue deduplicates and keeps the freshest payload', () {
    final queue = SyncQueue();
    expect(
      queue.enqueue(
        entity: 'Клиент',
        details: 'создан',
        payload: {'name': 'Старое имя'},
      ),
      isTrue,
    );
    expect(
      queue.enqueue(
        entity: 'Клиент',
        details: 'создан',
        payload: {'name': 'Новое имя'},
      ),
      isFalse,
    );
    expect(queue.items, hasLength(1));
    expect(queue.items.single.payload['name'], 'Новое имя');
  });

  test(
    'sync queue retains rejected changes and removes only confirmations',
    () {
      final queue = SyncQueue();
      queue.enqueue(entity: 'Клиент', details: 'создан');
      queue.enqueue(entity: 'Сделка', details: 'создана');
      final firstId = queue.items.first.id;
      queue.markAttempt(queue.items.map((item) => item.id), error: 'Нет сети');
      expect(queue.items.every((item) => item.attempts == 1), isTrue);
      expect(queue.items.first.lastError, 'Нет сети');
      queue.removeAccepted([firstId]);
      expect(queue.items, hasLength(1));
      expect(queue.items.single.entity, 'Сделка');
    },
  );

  test('sync queue backs off retries after a failed request', () {
    final item = PendingChange(
      id: 'change-1',
      entity: 'Клиент',
      details: 'создан',
      createdAt: '2026-08-31T10:00:00Z',
      attempts: 2,
      lastAttemptAt: '2026-08-31T10:00:00Z',
    );
    expect(SyncQueue.retryDelay(2), const Duration(seconds: 20));
    expect(
      SyncQueue.isReadyForRetry(item, DateTime.utc(2026, 8, 31, 10, 0, 19)),
      isFalse,
    );
    expect(
      SyncQueue.isReadyForRetry(item, DateTime.utc(2026, 8, 31, 10, 0, 20)),
      isTrue,
    );
  });

  test('corrupt queued change does not block ready sync snapshots', () {
    final queue = SyncQueue();
    queue.load([
      {
        'id': 'broken-change',
        'entity': 'Клиент',
        'details': 'старый снимок',
        'createdAt': '2026-08-31T10:00:00Z',
        'payload': <String, dynamic>{},
      },
      {
        'id': 'ready-change',
        'entity': 'Клиент',
        'details': 'актуальный снимок',
        'createdAt': '2026-08-31T10:01:00Z',
        'payload': {
          'schemaVersion': SheetsSchema.version,
          'kind': 'snapshot',
          'scope': 'clients',
        },
      },
    ]);
    expect(queue.invalidTransportItems.map((item) => item.id), [
      'broken-change',
    ]);
    expect(queue.hasRetryableItems(DateTime.utc(2026, 8, 31, 10, 2)), isTrue);
    final batch = ChangesSyncRepository.nextBatch(
      queue.items.where(SyncQueue.isTransportReady),
    );
    expect(batch.map((item) => item.id), ['ready-change']);
    queue.markTransportValidationError(['broken-change'], 'Неполный снимок');
    expect(queue.items.first.lastError, 'Неполный снимок');
    expect(queue.items.first.attempts, 0);
  });

  test('sync repository sends queue in bounded batches', () {
    final changes = List.generate(
      ChangesSyncRepository.maxChangesPerRequest + 3,
      (index) => PendingChange(
        id: 'change-$index',
        entity: 'Клиент',
        details: 'изменение',
        createdAt: '2026-08-31T10:00:00Z',
      ),
    );
    final batch = ChangesSyncRepository.nextBatch(changes);
    expect(batch, hasLength(ChangesSyncRepository.maxChangesPerRequest));
    expect(batch.first.id, 'change-0');
    expect(batch.last.id, 'change-19');
  });

  test(
    'changes endpoint sends snapshot and accepts only confirmed IDs',
    () async {
      final client = _FakeApiClient(
        http.Response('{"acceptedIds":["change-1","foreign"]}', 200),
      );
      final result =
          await ChangesSyncRepository(
            endpoint: Uri.parse('https://crm.example.com/sync'),
            token: 'test-secret',
            client: client,
          ).push([
            PendingChange(
              id: 'change-1',
              entity: 'Клиент',
              details: 'Создан: Иван',
              createdAt: '2026-08-31T10:00:00Z',
              payload: {
                'schemaVersion': SheetsSchema.version,
                'kind': 'snapshot',
                'scope': 'clients',
              },
            ),
          ]);
      final sent =
          jsonDecode(client.sentBody! as String) as Map<String, dynamic>;
      expect(sent['syncToken'], 'test-secret');
      expect(sent['schemaVersion'], SheetsSchema.version);
      expect((sent['changes'] as List).single['payload']['scope'], 'clients');
      expect(result.acceptedIds, ['change-1']);
    },
  );

  test(
    'changes endpoint surfaces an application-level backend error',
    () async {
      final client = _FakeApiClient(
        http.Response('{"acceptedIds":[],"error":"Unauthorized"}', 200),
      );
      final repository = ChangesSyncRepository(
        endpoint: Uri.parse('https://crm.example.com/sync'),
        token: 'wrong-secret',
        client: client,
      );
      await expectLater(
        repository.push([
          PendingChange(
            id: 'change-1',
            entity: 'Клиент',
            details: 'Создан: Иван',
            createdAt: '2026-08-31T10:00:00Z',
            payload: {
              'schemaVersion': SheetsSchema.version,
              'kind': 'snapshot',
              'scope': 'clients',
            },
          ),
        ]),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('failed sync keeps change until a later backend confirmation', () async {
    final queue = SyncQueue();
    queue.enqueue(
      entity: 'Клиент',
      details: 'Создан: Иван',
      payload: {
        'schemaVersion': SheetsSchema.version,
        'kind': 'snapshot',
        'scope': 'clients',
      },
    );
    final change = queue.items.single;
    final rejected = ChangesSyncRepository(
      endpoint: Uri.parse('https://crm.example.com/sync'),
      token: 'test-secret',
      client: _FakeApiClient(
        http.Response(
          '{"acceptedIds":[],"error":"Synchronization is busy"}',
          200,
        ),
      ),
    );
    await expectLater(rejected.push([change]), throwsA(isA<StateError>()));
    queue.markAttempt([change.id], error: 'Synchronization is busy');
    expect(queue.items.single.attempts, 1);

    final accepted = ChangesSyncRepository(
      endpoint: Uri.parse('https://crm.example.com/sync'),
      token: 'test-secret',
      client: _FakeApiClient(
        http.Response('{"acceptedIds":["${change.id}"]}', 200),
      ),
    );
    final result = await accepted.push([change]);
    queue.removeAccepted(result.acceptedIds);
    expect(queue.items, isEmpty);
  });

  test('sync payload scopes CRM data and excludes integration secrets', () {
    final payload = buildSyncPayload(
      'Клиент',
      clients: [Client(id: 'client-1', name: 'Иван')],
      stockItems: const [],
      stockMovements: const [],
      manualDeals: const [],
      businessTransactions: const [],
      closedPeriods: const [],
    );
    expect(payload['schemaVersion'], SheetsSchema.version);
    expect(payload['scope'], 'clients');
    expect((payload['data'] as List).single['id'], 'client-1');
    expect(payload.containsKey('token'), isFalse);
  });

  test('manual deal sync payload includes stable ID column header', () {
    final payload = buildSyncPayload(
      'Сделка',
      clients: const [],
      stockItems: const [],
      stockMovements: const [],
      manualDeals: const [
        [
          '01.09.2026',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          'Нет',
          'deal-1',
        ],
      ],
      businessTransactions: const [],
      closedPeriods: const [],
    );
    expect(payload['scope'], 'manualDeals');
    expect((payload['headers'] as List).last, 'ID');
    expect((payload['rows'] as List).single.last, 'deal-1');
  });

  test('integration audit payload contains no connection settings', () {
    final payload = buildSyncPayload(
      'Интеграция',
      clients: const [],
      stockItems: const [],
      stockMovements: const [],
      manualDeals: const [],
      businessTransactions: const [],
      closedPeriods: const [],
    );
    expect(payload['scope'], 'auditOnly');
    expect(jsonEncode(payload), isNot(contains('token')));
    expect(jsonEncode(payload), isNot(contains('endpoint')));
  });

  test(
    'workspace sync scopes preserve service, dashboard and appointment data',
    () {
      final catalog = ServiceCatalogItem(
        id: 'service-1',
        name: 'Полировка',
        prices: {'crossover': 12000},
        materialIds: const ['stock-1'],
      );
      expect(catalog.priceFor(VehicleClass.crossover), 12000);
      catalog.botInstructions = 'Уточнить состояние кузова';
      final restored = ServiceCatalogItem.fromJson(catalog.toJson());
      expect(restored.botInstructions, contains('Уточнить'));
      final payload = buildSyncPayload(
        'Запись',
        clients: const [],
        stockItems: const [],
        stockMovements: const [],
        manualDeals: const [],
        businessTransactions: const [],
        closedPeriods: const [],
        appointments: const [
          {'id': 'appointment-1', 'summary': 'Полировка'},
        ],
      );
      expect(payload['scope'], 'appointments');
      expect((payload['events'] as List).single['id'], 'appointment-1');
      final queue = SyncQueue()
        ..enqueue(
          entity: 'Запись',
          details: 'Создана запись',
          payload: payload,
        );
      expect(queue.invalidTransportItems, isEmpty);
    },
  );

  test('safe mock bot refuses unknown facts and cites a known rule', () async {
    const provider = KnowledgeBaseMockProvider();
    final known = await provider.reply(
      question: 'Какая цена полировки?',
      knowledgeBase: '## Полировка\n- Цена полировки от 10 000 ₽.',
      history: const [],
      settings: const AiSettings(),
    );
    expect(known.needsHuman, isFalse);
    expect(known.text, contains('10 000'));
    final unknown = await provider.reply(
      question: 'Есть ли у вас рассрочка?',
      knowledgeBase: '## Полировка\n- Цена полировки от 10 000 ₽.',
      history: const [],
      settings: const AiSettings(),
    );
    expect(unknown.needsHuman, isTrue);
    expect(unknown.text, isEmpty);
  });

  test(
    'explicit knowledge-base prohibition wins over an earlier answer rule',
    () async {
      const provider = KnowledgeBaseMockProvider();
      final result = await provider.reply(
        question: 'привет',
        knowledgeBase: '''
на привет отвечай привет
## Обратная связь
- Не отвечать так: привет
- Правильный ответ: передать вопрос сотруднику.
''',
        history: const [],
        settings: const AiSettings(),
      );
      expect(result.needsHuman, isTrue);
      expect(result.text, isEmpty);
    },
  );

  test('notification keeps level and read state after serialization', () {
    final notification = CrmNotification(
      id: 'n1',
      title: 'Синхронизация',
      message: 'Готово',
      level: CrmNotificationLevel.success,
      createdAt: '2026-08-31T10:00:00Z',
    );
    notification.read = true;
    final restored = CrmNotification.fromJson(notification.toJson());
    expect(restored.level, CrmNotificationLevel.success);
    expect(restored.read, isTrue);
  });

  test('logger redacts credentials before writing diagnostics', () {
    expect(
      CrmLogger.redact('access_token=secret-value'),
      contains('[REDACTED]'),
    );
    expect(
      () => CrmLogger.info('access_token=secret-value', name: 'crm.test'),
      returnsNormally,
    );
  });

  test('logger redacts bearer, JSON and URL credentials', () {
    final source = '''Authorization: Bearer super-secret
{"clientSecret":"client-secret","token":"plain-secret"}
https://crm.example.com/sync?syncToken=query-secret''';
    final redacted = CrmLogger.redact(source);
    expect(redacted, isNot(contains('super-secret')));
    expect(redacted, isNot(contains('client-secret')));
    expect(redacted, isNot(contains('plain-secret')));
    expect(redacted, isNot(contains('query-secret')));
    expect(redacted, contains('Bearer [REDACTED]'));
  });

  test('deal filter and CSV export preserve quoted values', () {
    final rows = filterDeals(
      [
        [
          '01.08.2026',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          'Выполнен',
        ],
        [
          '02.08.2026',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          'Отказался',
        ],
      ],
      matchesPeriod: (_) => true,
      status: 'Выполнен',
    );
    expect(rows, hasLength(1));
    expect(
      dealsToCsv(
        ['Клиент', 'Комментарий'],
        [
          ['Иван', 'hello, world'],
        ],
      ),
      contains('"hello, world"'),
    );
  });

  test('deal period filter keeps years and custom range separate', () {
    final now = DateTime(2026, 8, 31, 15);
    expect(matchesDealPeriod('31.08.2026', filter: 'Август', now: now), isTrue);
    expect(
      matchesDealPeriod('31.08.2025', filter: 'Август', now: now),
      isFalse,
    );
    expect(
      matchesDealPeriod(
        '15.07.2026',
        filter: 'Диапазон',
        now: now,
        from: DateTime(2026, 7, 10),
        to: DateTime(2026, 7, 20),
      ),
      isTrue,
    );
    expect(
      matchesDealPeriod(
        '21.07.2026',
        filter: 'Диапазон',
        now: now,
        from: DateTime(2026, 7, 10),
        to: DateTime(2026, 7, 20),
      ),
      isFalse,
    );
  });

  test('deal pagination clamps stale page after filter changes', () {
    final page = paginateDeals(['a', 'b', 'c'], requestedPage: 8, pageSize: 2);
    expect(page.page, 1);
    expect(page.pageCount, 2);
    expect(page.items, ['c']);
    expect(page.hasPrevious, isTrue);
    expect(page.hasNext, isFalse);
  });

  test('sheet deal import is isolated and handles local number formats', () {
    final imported = importLegacyDealRows([
      const ['01.08.2026'],
      const [
        'BMW',
        'X5',
        '+7999',
        'Егор',
        '18 500,50',
        '1 000,25',
        '500',
        '0',
        '0',
        '0',
        '0',
      ],
      const ['BMW', 'X3'],
    ]);
    expect(imported.rows, hasLength(1));
    expect(imported.rows.first[5], '18500.5');
    expect(imported.errors, hasLength(1));
  });

  test('sheet deal import skips headers, totals and date dividers', () {
    final imported = importLegacyDealRows([
      const [
        'Авто',
        'Телефон',
        'Услуга',
        'Работник',
        'Стоимость',
        'Расходы',
        'Чистая прибыль',
      ],
      const ['31.08.2026 Воскресенье'],
      const [
        'Toyota Camry',
        '+79990000000',
        'Мойка автомобиля',
        'Егор',
        '2 500 ₽',
        '250',
        '2 250',
      ],
      const [
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'Расходы',
        '',
        '',
        '31.08',
        '2 500',
      ],
      const ['', '', '', '', '4 000', '0', '4 000', '800'],
      const ['ИТОГО', '', '', '', '2 500'],
      const ['BMW', '', '', 'Егор', '3000'],
    ]);

    expect(imported.rows, hasLength(1));
    expect(imported.rows.single[0], '31.08.2026');
    expect(imported.rows.single[5], '2500');
    expect(imported.errors, ['Строка 7: не указана услуга']);
  });

  test('sheet deal import keeps a manually entered business reserve', () {
    final imported = importLegacyDealRows([
      const ['05.09.2026'],
      const [
        'Lada Granta',
        '-',
        'Установка магнитолы',
        'Артём',
        '18 000',
        '0',
        '18 000',
        '7 500',
        '5 250',
        '5 250',
        '0',
      ],
    ]);

    expect(imported.rows.single[11], '7500');
    expect(imported.rows.single[13], '5250');
    expect(imported.rows.single[14], '5250');
  });

  test('client search and phone normalization are consistent', () {
    expect(normalizePhone('+7 (999) 111-22-33'), '+79991112233');
    expect(isDuplicatePhone('8 999 111 22 33', ['+79991112233']), isTrue);
    expect(
      clientMatchesQuery(
        query: 'avito',
        name: 'Иван',
        phone: '',
        car: 'BMW',
        source: 'Avito',
      ),
      isTrue,
    );
    expect(
      clientMatchesQuery(
        query: 'audi',
        name: 'Иван',
        phone: '+79990000000',
        car: 'BMW',
        source: 'Avito',
        cars: const ['Audi'],
      ),
      isTrue,
    );
    final now = DateTime(2026, 8, 31, 12);
    expect(
      clientContactInPeriod('2026-08-30T12:00:00', now: now, days: 7),
      isTrue,
    );
    expect(
      clientContactInPeriod('2026-07-01T12:00:00', now: now, days: 7),
      isFalse,
    );
  });

  test('lead to payment flow preserves IDs, stock cost and sync payload', () {
    final client = Client(
      id: 'client-1',
      name: 'Иван',
      phone: '+79990000000',
      car: 'BMW X3',
    );
    final vehicleId = client.vehicleIdFor('BMW X3');
    expect(vehicleId, isNotEmpty);

    final appointment = {
      'id': 'appointment-1',
      'start': {'dateTime': '2026-08-31T07:00:00Z'},
      'end': {'dateTime': '2026-08-31T09:00:00Z'},
      'extendedProperties': {
        'private': {
          'clientId': client.id,
          'vehicleId': vehicleId,
          'car': 'BMW X3',
          'performer': 'Егор',
        },
      },
    };
    expect(
      findCalendarResourceConflict(
        [appointment],
        DateTime(2026, 8, 31, 12),
        DateTime(2026, 8, 31, 13),
        performer: 'Егор',
        vehicleId: vehicleId!,
        vehicle: 'BMW X3',
      ),
      isNull,
    );

    final deal = Deal(
      id: 'deal-1',
      date: '31.08.2026',
      clientId: client.id,
      clientName: client.name,
      service: 'Полировка',
      performers: 'Егор',
      status: 'Выполнен',
      revenue: 15000,
      expenses: 4000,
      workerPayout: 3000,
      businessReserve: 1000,
      ownerProfit: 7000,
    );
    final stock = StockItem(
      id: 'material-1',
      name: 'Паста',
      quantity: 5,
      purchasePrice: 800,
    );
    final adjustment = calculateStockAdjustment(
      type: 'Расход',
      currentQuantity: stock.quantity,
      enteredQuantity: 1,
    );
    expect(adjustment.isValid, isTrue);
    final movement = StockMovement(
      id: 'movement-1',
      itemId: stock.id,
      type: 'Расход',
      quantity: 1,
      date: '31.08.2026',
      dealId: deal.id,
      service: deal.service,
    );
    expect(movement.costAt(stock.purchasePrice), 800);
    final report = summarizeDeals([deal]);
    expect(report.revenue, 15000);
    expect(report.effectiveOwnerProfit, 7000);

    final queue = SyncQueue();
    queue.enqueue(
      entity: 'Сделка',
      details: 'Создана: ${deal.id}',
      payload: buildSyncPayload(
        'Сделка',
        clients: [client],
        stockItems: [stock],
        stockMovements: [movement],
        manualDeals: const [],
        businessTransactions: const [],
        closedPeriods: const [],
      ),
    );
    expect(queue.items, hasLength(1));
    expect(queue.items.single.payload['scope'], 'manualDeals');
  });

  testWidgets('CRM launches with dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await tester.pumpWidget(const CleanPlaceApp());
    expect(find.text('Сводка по работе детейлинг-центра'), findsOneWidget);
  });

  testWidgets('key CRM sections render on a desktop window', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await tester.pumpWidget(const CleanPlaceApp());

    Future<void> open(String navigationTitle) async {
      await tester.tap(find.text(navigationTitle).first);
      await tester.pump();
    }

    await open('CRM');
    expect(find.text('Клиенты и автомобили'), findsOneWidget);
    await open('Сделки');
    expect(find.text('Сделки'), findsWidgets);
    await open('Записи');
    expect(find.text('Подключите Google Календарь'), findsOneWidget);
    await open('Бухгалтерия');
    expect(find.text('Бухгалтерия'), findsWidgets);
    await open('Склад');
    expect(find.text('Склад'), findsWidgets);
    await open('Настройки');
    expect(find.text('Настройки'), findsWidgets);
    await open('Сообщения');
    expect(find.text('Сообщения'), findsWidgets);
    expect(find.text('Avito: сообщения и звонки'), findsOneWidget);
    expect(find.text('Avito'), findsNothing);
    expect(find.text('Avito • аккаунт 1'), findsNothing);
  });

  testWidgets('CRM opens from compact navigation without layout errors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const CleanPlaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Разделы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CRM').last);
    await tester.pumpAndSettle();
    expect(find.text('Клиенты и автомобили'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('messages stay usable in a compact CRM window', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await tester.pumpWidget(const CleanPlaceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Разделы'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сообщения').last);
    await tester.pumpAndSettle();
    expect(find.text('Avito: сообщения и звонки'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unified inbox renders assignee and tags', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnifiedInboxList(
            dialogs: [
              UnifiedDialog(
                platform: 'Telegram',
                id: '1',
                name: 'Иван',
                preview: 'Здравствуйте',
                unread: true,
                assignee: 'Мастер',
                tags: const ['VIP', 'BMW'],
                onTap: () {},
              ),
            ],
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
            cardBorderColor: Colors.grey,
          ),
        ),
      ),
    );
    expect(find.textContaining('Мастер'), findsOneWidget);
    expect(find.textContaining('#VIP #BMW'), findsOneWidget);
  });

  testWidgets('calendar event tile exposes permitted quick actions', (
    tester,
  ) async {
    var opened = 0;
    var edited = 0;
    var cancelled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarEventTile(
            event: const {'summary': 'Полировка BMW'},
            selectedDay: DateTime(2026, 8, 31),
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
            canEdit: true,
            timeLabel: (_) => '10:00',
            onOpen: (_) => opened++,
            onEdit: (_) => edited++,
            onCancel: (_) => cancelled++,
            onMoveToDay: (_, _) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Открыть карточку'));
    await tester.tap(find.byTooltip('Изменить'));
    await tester.tap(find.byTooltip('Удалить'));
    expect(opened, 1);
    expect(edited, 1);
    expect(cancelled, 1);
  });

  testWidgets('read-only calendar appointment dialog has no write actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarAppointmentDialog(
            event: const {
              'summary': 'Полировка BMW',
              'extendedProperties': {
                'private': {'name': 'Иван', 'note': 'Позвонить заранее'},
              },
            },
            timeLabel: (_) => '31.08, 10:00',
            canEdit: false,
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
          ),
        ),
      ),
    );
    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('Позвонить заранее'), findsOneWidget);
    expect(find.text('Перенести'), findsNothing);
    expect(find.text('Приехал'), findsNothing);
    expect(find.text('Не приехал'), findsNothing);
  });

  testWidgets('calendar workspace delegates navigation, view and search', (
    tester,
  ) async {
    var requestedMove = 0;
    String? requestedMode;
    String? requestedSearch;
    var settingsOpened = false;
    var appointmentCreated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarWorkspace(
            calendarName: 'Основной календарь',
            viewMode: 'Месяц',
            viewDate: DateTime(2026, 8, 1),
            selectedDay: DateTime(2026, 8, 31),
            selectedDayEventCount: 1,
            canEdit: true,
            surfaceColor: Colors.white,
            borderColor: Colors.grey,
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
            calendarBody: const Text('Календарная сетка'),
            selectedDayTiles: const [Text('Запись клиента')],
            onNewAppointment: () => appointmentCreated = true,
            onOpenSettings: () => settingsOpened = true,
            onMove: (value) => requestedMove = value,
            onToday: () {},
            onViewModeChanged: (value) => requestedMode = value,
            onSearchChanged: (value) => requestedSearch = value,
          ),
        ),
      ),
    );
    expect(find.text('август 2026'), findsOneWidget);
    expect(find.textContaining('Записей: 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Вперёд'));
    expect(requestedMove, 1);
    await tester.tap(find.text('Неделя'));
    expect(requestedMode, 'Неделя');
    await tester.enterText(find.byType(TextField), 'Иван');
    expect(requestedSearch, 'Иван');
    await tester.tap(find.byTooltip('Настройки календаря'));
    expect(settingsOpened, isTrue);
    await tester.tap(find.text('Новая запись'));
    expect(appointmentCreated, isTrue);
  });

  testWidgets('calendar connection panel protects reconnect configuration', (
    tester,
  ) async {
    var connected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarConnectionPanel(
            status: 'Нужна авторизация',
            loading: false,
            canConfigure: false,
            surfaceColor: Colors.white,
            borderColor: Colors.grey,
            onConnect: () => connected = true,
          ),
        ),
      ),
    );
    expect(find.text('Нужна авторизация'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarConnectionPanel(
            status: null,
            loading: false,
            canConfigure: true,
            surfaceColor: Colors.white,
            borderColor: Colors.grey,
            onConnect: () => connected = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Подключить'));
    expect(connected, isTrue);
  });

  testWidgets('calendar connection panel exposes secret configuration', (
    tester,
  ) async {
    var configured = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarConnectionPanel(
            status: 'Нужна авторизация',
            loading: false,
            canConfigure: true,
            surfaceColor: Colors.white,
            borderColor: Colors.grey,
            onConnect: () {},
            onConfigureSecret: () => configured = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Добавить client secret'));
    expect(configured, isTrue);
  });

  testWidgets('telegram inbox opens a dialog and delegates a reply', (
    tester,
  ) async {
    final controller = TextEditingController();
    Map<String, dynamic>? opened;
    var sent = false;
    final chat = <String, dynamic>{
      'id': 'telegram-1',
      'title': 'Иван',
      'messages': [
        {'text': 'Здравствуйте'},
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TelegramInbox(
            chats: [chat],
            selectedChat: chat,
            loading: false,
            replyController: controller,
            canEdit: true,
            surfaceColor: Colors.white,
            borderColor: Colors.grey,
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
            titleOf: (value) => value['title'].toString(),
            onOpenChat: (value) => opened = value,
            onSend: () => sent = true,
          ),
        ),
      ),
    );
    expect(find.text('Здравствуйте'), findsOneWidget);
    await tester.tap(find.text('Иван').first);
    expect(opened, same(chat));
    await tester.enterText(find.byType(TextField), 'Записываю вас');
    await tester.tap(find.byTooltip('Отправить в Telegram'));
    expect(sent, isTrue);
    controller.dispose();
  });

  testWidgets('instagram inbox renders messages and respects read-only mode', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final conversation = <String, dynamic>{'id': 'ig-1'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InstagramInbox(
            conversations: [conversation],
            selectedConversation: conversation,
            messages: const [
              {'message': 'Здравствуйте'},
            ],
            loading: false,
            replyController: controller,
            canEdit: false,
            surfaceColor: Colors.white,
            borderColor: Colors.grey,
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
            titleOf: (_) => 'Клиент Instagram',
            onOpenConversation: (_) {},
            onSend: () {},
          ),
        ),
      ),
    );
    expect(find.text('Клиент Instagram'), findsNWidgets(2));
    expect(find.text('Здравствуйте'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });

  testWidgets('VK inbox renders conversations and disables read-only reply', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final conversation = <String, dynamic>{
      'conversation': {
        'peer': {'id': 42},
      },
      'last_message': {'text': 'Добрый день'},
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VkInbox(
            conversations: [conversation],
            selectedConversation: conversation,
            messages: const [
              {'text': 'Добрый день'},
            ],
            loading: false,
            darkMode: false,
            canEdit: false,
            canConfigure: false,
            replyController: controller,
            quickReplyTemplates: const ['Здравствуйте!'],
            surfaceColor: Colors.white,
            borderColor: Colors.grey,
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
            titleOf: (_) => 'Клиент VK',
            textOf: (value) => value['text']?.toString() ?? '',
            onRefresh: () {},
            onOpenConversation: (_) {},
            isNotificationChat: false,
            onSelectNotificationChat: (_) {},
            onSendTest: () async => null,
            onSend: () {},
          ),
        ),
      ),
    );
    expect(find.text('Клиент VK'), findsNWidgets(2));
    expect(find.text('Добрый день'), findsNWidgets(2));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('messages page adapts header and retry action', (tester) async {
    var retried = false;
    var diagnosed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesPage(
            sections: const [Text('Inbox')],
            connectionCards: const [Text('Telegram')],
            pendingCount: 2,
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
            canRetry: true,
            onRetry: () => retried = true,
            onDiagnostics: () => diagnosed = true,
          ),
        ),
      ),
    );
    expect(find.text('Inbox'), findsOneWidget);
    await tester.tap(find.text('Повторить сейчас'));
    await tester.tap(find.text('Диагностика интеграций'));
    expect(retried, isTrue);
    expect(diagnosed, isTrue);
  });

  testWidgets('messaging panels show calls and delegate VK actions', (
    tester,
  ) async {
    var summarySent = false;
    var testSent = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AvitoCallsPanel(
                calls: const [
                  {'buyerPhone': '+79990000000', 'callTime': '31.08'},
                ],
                surfaceColor: Colors.white,
                borderColor: Colors.grey,
                mainTextColor: Colors.black,
                mutedTextColor: Colors.grey,
                formatDate: (value) => value.toString(),
              ),
              VkNotificationChatPanel(
                peerId: '123',
                surfaceColor: Colors.white,
                borderColor: Colors.grey,
                mainTextColor: Colors.black,
                mutedTextColor: Colors.grey,
                canEdit: true,
                onSendSummary: () async {
                  summarySent = true;
                  return null;
                },
                onSendTest: () async {
                  testSent = true;
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('+79990000000'), findsOneWidget);
    await tester.tap(find.text('Отправить сводку'));
    await tester.pump();
    expect(summarySent, isTrue);
    await tester.tap(find.text('Отправить тест'));
    await tester.pump();
    expect(testSent, isTrue);
  });

  testWidgets('Avito connection card delegates permitted actions', (
    tester,
  ) async {
    var refreshed = false;
    var configured = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvitoConnectionCard(
            accounts: const [
              {'key': 'main', 'name': 'Основной', 'userId': '123'},
            ],
            activeAccountKey: 'main',
            connected: true,
            loading: false,
            status: 'Подключён',
            surfaceColor: Colors.white,
            borderColor: Colors.grey,
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
            onRefresh: () => refreshed = true,
            canConfigure: true,
            onConfigure: () => configured = true,
            onSelectAccount: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Основной • 123'), findsOneWidget);
    await tester.tap(find.text('Обновить'));
    expect(refreshed, isTrue);
    await tester.tap(find.text('Добавить аккаунт'));
    expect(configured, isTrue);
  });

  testWidgets('integration diagnostics delegates configuration', (
    tester,
  ) async {
    var configured = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => IntegrationDiagnosticsDialog(
                  canConfigure: true,
                  diagnostics: [
                    IntegrationDiagnostic(
                      name: 'Telegram',
                      connected: false,
                      status: 'Не подключён',
                      accountConfigured: false,
                      configureTooltip: 'Проверить снова',
                      configureIcon: Icons.refresh,
                      onConfigure: () => configured = true,
                    ),
                  ],
                ),
              ),
              child: const Text('Открыть диагностику'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть диагностику'));
    await tester.pumpAndSettle();
    expect(find.text('Диагностика интеграций'), findsOneWidget);
    await tester.tap(find.byTooltip('Проверить снова'));
    await tester.pumpAndSettle();
    expect(configured, isTrue);
    expect(find.text('Диагностика интеграций'), findsNothing);
  });

  testWidgets('financial summary card presents typed report values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FinancialSummaryCard(
            snapshot: const FinancialSnapshot(
              revenue: 15000,
              expenses: 4000,
              dealCount: 2,
              workerPayout: 3000,
              businessReserve: 1000,
              ownerProfit: 7000,
            ),
            materialCost: 800,
            surfaceColor: Colors.white,
            borderColor: Colors.grey,
            mainTextColor: Colors.black,
          ),
        ),
      ),
    );
    expect(find.textContaining('Выручка: 15000 ₽'), findsOneWidget);
    expect(find.textContaining('Материалы: 800 ₽'), findsOneWidget);
  });

  testWidgets('offline banner explains cached data state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineStatusBanner(lastSynced: DateTime(2026, 8, 31, 14, 5)),
        ),
      ),
    );
    expect(find.textContaining('последние сохранённые данные'), findsOneWidget);
    expect(find.textContaining('31.08 14:05'), findsOneWidget);
  });

  testWidgets('messenger connection card exposes configuration action', (
    tester,
  ) async {
    var configured = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessengerConnectionCard(
            title: 'Telegram',
            icon: Icons.send,
            description: 'Сообщения',
            status: 'Подключён',
            connected: true,
            canConfigure: true,
            surfaceColor: Colors.white,
            borderColor: Colors.grey,
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
            onConfigure: () => configured = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Настроить'));
    expect(configured, isTrue);
    expect(find.text('Подключён'), findsOneWidget);
  });

  testWidgets('dashboard stat card keeps its optional action', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardStatCard(
            title: 'Выручка',
            value: '15 000 ₽',
            icon: Icons.payments,
            surfaceColor: Colors.white,
            borderColor: Colors.grey,
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
            onTap: () => opened = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('15 000 ₽'));
    expect(opened, isTrue);
  });

  testWidgets('sidebar navigation exposes an accessible section label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CrmSidebar(selected: 1, onSelect: (_) {})),
      ),
    );
    expect(find.bySemanticsLabel('Раздел CRM'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('dashboard shell opens navigation drawer on a compact window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardShell(
          darkMode: false,
          sidebar: const Text('Навигация CRM'),
          title: 'CRM',
          now: DateTime(2026, 8, 31, 12, 30),
          hasUnreadNotifications: true,
          onOpenNotifications: () {},
          onThemeChanged: (_) {},
          body: const Text('Рабочая область'),
        ),
      ),
    );
    expect(find.byTooltip('Разделы'), findsOneWidget);
    await tester.tap(find.byTooltip('Разделы'));
    await tester.pumpAndSettle();
    expect(find.text('Навигация CRM'), findsOneWidget);
  });

  testWidgets('overview dashboard shows metrics and preserves quick action', (
    tester,
  ) async {
    var openedBusinessAccount = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewDashboard(
            metrics: [
              const OverviewMetric(
                title: 'Выручка',
                value: '10 000 ₽',
                icon: Icons.payments_outlined,
              ),
              OverviewMetric(
                title: 'Бизнес-счёт',
                value: '3 000 ₽',
                icon: Icons.account_balance_outlined,
                onTap: () => openedBusinessAccount = true,
              ),
            ],
            loadedDeals: 2,
            loading: false,
            surfaceColor: Colors.white,
            borderColor: Colors.orange,
            mainTextColor: Colors.black,
            mutedTextColor: Colors.grey,
            financialSummary: const Text('Финансовый итог'),
          ),
        ),
      ),
    );
    expect(find.text('Загружено заказов: 2'), findsOneWidget);
    expect(find.text('Финансовый итог'), findsOneWidget);
    await tester.tap(find.text('3 000 ₽'));
    expect(openedBusinessAccount, isTrue);
  });

  testWidgets('notification center renders levels and clears notifications', (
    tester,
  ) async {
    var cleared = false;
    final notifications = [
      CrmNotification(
        id: 'n1',
        title: 'Синхронизация',
        message: 'Готово',
        level: CrmNotificationLevel.success,
        createdAt: '2026-08-31T12:00:00.000',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => NotificationCenterDialog(
                notifications: notifications,
                onClear: () async => cleared = true,
              ),
            ),
            child: const Text('Открыть'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('Синхронизация'), findsOneWidget);
    await tester.tap(find.text('Очистить'));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
    expect(find.text('Уведомления'), findsNothing);
  });

  testWidgets('client detail keeps history and quick deal action', (
    tester,
  ) async {
    final client = Client(
      id: 'client-1',
      name: 'Иван',
      phone: '+79990000000',
      car: 'BMW X5',
    );
    client.interactionHistory.add('Звонок клиента');
    var createDeal = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ClientDetailDialog(
          client: client,
          relatedDeals: const [
            ['01.08.2026', '', '', 'Полировка', '', '15000'],
          ],
          relatedAppointments: const [],
          statuses: const ['Новый лид', 'Записан'],
          appointmentTime: (_) => '',
          canEditDeals: true,
          canEditCalendar: true,
          canEditClients: true,
          canContact: true,
          onCreateDeal: () => createDeal = true,
        ),
      ),
    );
    expect(find.text('История сделок (1)'), findsOneWidget);
    expect(find.text('Звонок клиента'), findsOneWidget);
    await tester.tap(find.text('Новая сделка'));
    expect(createDeal, isTrue);
  });

  testWidgets('client detail disables contact actions for read-only role', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClientDetailDialog(
          client: Client(id: 'client-1', name: 'Иван', phone: '+79990000000'),
          relatedDeals: const [],
          relatedAppointments: const [],
          statuses: const ['Новый лид'],
          appointmentTime: (_) => '',
          canEditDeals: false,
          canEditCalendar: false,
          canEditClients: false,
          canContact: false,
        ),
      ),
    );
    final call = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Позвонить'),
    );
    final message = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Написать'),
    );
    expect(call.onPressed, isNull);
    expect(message.onPressed, isNull);
  });

  testWidgets('settings page keeps sync actions and audit visible', (
    tester,
  ) async {
    var synced = false;
    final sheetController = TextEditingController();
    addTearDown(sheetController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SettingsPage(
              currentUserId: 'owner',
              userProfiles: [
                UserProfile(id: 'owner', name: 'Владелец', role: 'Владелец'),
              ],
              onSelectUser: (_) {},
              sheetController: sheetController,
              canManageIntegrations: true,
              canBackup: true,
              canRestore: true,
              canEditMessages: true,
              isOwner: true,
              onSaveAndCheckSheet: () async {},
              onManageServices: () async {},
              onBackup: () async {},
              onRestore: () async {},
              onManageQuickReplies: () async {},
              onSetupSync: () async {},
              onManageUsers: () async {},
              hasSyncCredentials: true,
              pendingChangesCount: 2,
              pendingChangesSyncing: false,
              pendingChangesSyncError: null,
              lastPendingChangesSync: DateTime(2026, 8, 31, 12),
              onSyncPendingChanges: () async => synced = true,
              onExportPendingChanges: () async {},
              auditEntries: [
                AuditEntry(
                  action: 'Изменён клиент',
                  entity: 'Иван',
                  date: '31.08.2026',
                  actor: 'Владелец',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Локальных изменений ожидает синхронизации: 2'),
      findsOneWidget,
    );
    expect(find.text('Изменён клиент: Иван'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Синхронизировать'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Синхронизировать'));
    expect(synced, isTrue);
  });

  testWidgets('quick replies apply their draft only after confirmation', (
    tester,
  ) async {
    final source = ['Здравствуйте'];
    List<String>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => QuickRepliesDialog(
                templates: source,
                onSave: (templates) async => saved = templates,
              ),
            ),
            child: const Text('Открыть шаблоны'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть шаблоны'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Записать вас на завтра?');
    await tester.tap(find.byTooltip('Добавить шаблон'));
    await tester.pump();
    expect(find.text('Записать вас на завтра?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(source, ['Здравствуйте']);
    expect(saved, isNull);

    await tester.tap(find.text('Открыть шаблоны'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Записать вас на завтра?');
    await tester.tap(find.byTooltip('Добавить шаблон'));
    await tester.pump();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(saved, ['Здравствуйте', 'Записать вас на завтра?']);
  });

  testWidgets(
    'accounting page keeps offline data and finance actions available',
    (tester) async {
      var synchronized = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AccountingPage(
                lastSheetsSync: DateTime(2026, 8, 31, 12, 30),
                sheetsOfflineMode: true,
                loading: false,
                canEditFinance: true,
                onSync: () async => synchronized = true,
                onClosePeriod: () async {},
                from: null,
                to: null,
                onPeriodChanged: (_) {},
                categoryFilter: 'Все категории',
                categories: const ['Материалы'],
                onCategoryChanged: (_) {},
                onManageCategories: () async {},
                sheetError: 'Нет сети',
                hasRows: false,
                table: null,
                localOperations: const Text('Локальные операции'),
                reconciliationReport: const Text('Сверка'),
                closedPeriodSummary: 'Последнее закрытие: 31.08.2026',
              ),
            ),
          ),
        ),
      );
      expect(
        find.text(
          'Google Sheets недоступна. Показаны последние сохранённые финансовые данные; локальные операции не потеряны.',
        ),
        findsOneWidget,
      );
      expect(find.text('Локальные операции'), findsOneWidget);
      await tester.tap(find.text('Синхронизировать'));
      expect(synchronized, isTrue);
    },
  );

  testWidgets('accounting table paginates sheet rows', (tester) async {
    var nextPage = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountingTable(
            rows: const [
              ['Дата', 'Сумма'],
              ['01.08.2026', '100'],
              ['02.08.2026', '200'],
              ['03.08.2026', '300'],
            ],
            page: 0,
            pageSize: 1,
            onPageChanged: (page) => nextPage = page,
          ),
        ),
      ),
    );
    expect(find.text('Строки 1–1 из 3'), findsOneWidget);
    expect(find.text('01.08.2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Следующая страница'));
    expect(nextPage, 1);
  });

  testWidgets('accounting categories keep an unsaved draft isolated', (
    tester,
  ) async {
    final source = ['Материалы'];
    List<String>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AccountingCategoriesDialog(
                categories: source,
                onSave: (categories) async => saved = categories,
              ),
            ),
            child: const Text('Открыть категории'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть категории'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Аренда');
    await tester.tap(find.byTooltip('Добавить категорию'));
    await tester.pump();
    expect(find.text('Аренда'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(source, ['Материалы']);
    expect(saved, isNull);

    await tester.tap(find.text('Открыть категории'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Аренда');
    await tester.tap(find.byTooltip('Добавить категорию'));
    await tester.pump();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(saved, ['Материалы', 'Аренда']);
  });

  testWidgets('local operations list exposes source and signed amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LocalOperationsList(
            operations: [
              {
                'comment': 'Закупка химии',
                'date': '31.08.2026',
                'source': 'local',
                'amount': -1200,
              },
              {
                'comment': 'Импорт расхода',
                'date': '30.08.2026',
                'source': 'google_sheets',
                'amount': 500,
              },
            ],
          ),
        ),
      ),
    );
    expect(find.text('Закупка химии'), findsOneWidget);
    expect(find.text('31.08.2026 • Локально'), findsOneWidget);
    expect(find.text('-1200 ₽'), findsOneWidget);
    expect(find.text('30.08.2026 • Google Sheets'), findsOneWidget);
    expect(find.text('+500 ₽'), findsOneWidget);
  });

  testWidgets(
    'stock page renders critical stock and delegates movement action',
    (tester) async {
      StockItem? moved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StockPage(
              items: [
                StockItem(
                  id: 'item-1',
                  name: 'Шампунь',
                  quantity: 1,
                  minQuantity: 2,
                  supplier: 'Поставщик',
                ),
              ],
              movementCount: (_) => 3,
              query: '',
              page: 0,
              pageSize: 20,
              canEdit: true,
              onAdd: () {},
              onSearchChanged: (_) {},
              onPageChanged: (_) {},
              onEdit: (_) {},
              onMovement: (item) => moved = item,
              onShowMovements: (_) {},
              onDelete: (_) async {},
            ),
          ),
        ),
      );
      expect(find.text('Шампунь'), findsOneWidget);
      expect(find.text('Пополнить'), findsOneWidget);
      expect(find.textContaining('движений: 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Движение'));
      expect(moved?.id, 'item-1');
    },
  );

  testWidgets('kanban groups deals and delegates card opening', (tester) async {
    List<String>? opened;
    var tableRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DealsKanbanBoard(
              rows: [
                List.filled(18, '')
                  ..[16] = 'Записан'
                  ..[17] = 'Иван'
                  ..[5] = '15000',
              ],
              canEdit: true,
              onShowTable: () => tableRequested = true,
              onAddDeal: () {},
              onOpenDeal: (row) => opened = row,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Записан (1)'), findsOneWidget);
    expect(find.text('Иван'), findsOneWidget);
    await tester.tap(find.text('Иван'));
    expect(opened?[17], 'Иван');
    await tester.tap(find.text('Таблица'));
    expect(tableRequested, isTrue);
  });

  testWidgets('grouped deals table paginates and delegates a row opening', (
    tester,
  ) async {
    List<String>? opened;
    final row = List.filled(18, '')
      ..[0] = '31.08.2026'
      ..[5] = '15000'
      ..[17] = 'Иван';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DealsGroupedTable(
            headers: const ['Дата', 'Клиент'],
            entries: [
              MapEntry('31.08.2026', [row]),
            ],
            page: 0,
            pageSize: 10,
            visibleColumns: const {0, 1},
            columnWidths: const {},
            defaultColumnWidth: 120,
            wrapText: false,
            canEdit: true,
            weekdayForDate: (_) => 'Воскресенье',
            onPageChanged: (_) {},
            onOpenDeal: (value) => opened = value,
          ),
        ),
      ),
    );
    expect(find.textContaining('Услуг: 1'), findsOneWidget);
    await tester.tap(find.textContaining('Услуг: 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('31.08.2026').last);
    expect(opened, same(row));
  });

  testWidgets('client results open a card and use delegated pagination', (
    tester,
  ) async {
    Client? opened;
    var requestedPage = -1;
    final client = Client(
      id: 'client-1',
      name: 'Иван',
      phone: '+79990000000',
      car: 'BMW X5',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientResultsList(
            clients: [client],
            totalCount: 2,
            page: 0,
            pageCount: 2,
            canEdit: true,
            onOpen: (value) => opened = value,
            onDelete: (_) async {},
            onPageChanged: (page) => requestedPage = page,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Иван'));
    expect(opened, same(client));
    await tester.tap(find.byTooltip('Следующая страница'));
    expect(requestedPage, 1);
  });
}
