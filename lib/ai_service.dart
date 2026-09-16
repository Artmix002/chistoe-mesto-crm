import 'dart:convert';
import 'dart:io';

import 'api_client.dart';
import 'workspace_models.dart';

class BotReply {
  const BotReply({
    required this.text,
    required this.needsHuman,
    this.usedKnowledgeSections = const [],
    this.reason = '',
  });

  final String text;
  final bool needsHuman;
  final List<String> usedKnowledgeSections;
  final String reason;
}

class AiConnectionCheck {
  const AiConnectionCheck({
    required this.model,
    this.availableModels = const [],
  });

  final String model;
  final List<String> availableModels;
}

enum TranscriptSpeaker { client, employee, unknown }

class TranscriptLine {
  const TranscriptLine({required this.speaker, required this.text});

  final TranscriptSpeaker speaker;
  final String text;
}

enum AiActionType { note, appointment, deal }

class AiActionRecommendation {
  const AiActionRecommendation({
    required this.type,
    required this.title,
    this.details = '',
    this.date,
    this.time,
    this.clientPhone,
    this.service,
    this.confidence = 0,
    this.missing = const [],
  });

  final AiActionType type;
  final String title;
  final String details;
  final String? date;
  final String? time;
  final String? clientPhone;
  final String? service;
  final double confidence;
  final List<String> missing;

  bool get requiresClarification => missing.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    'details': details,
    'date': date,
    'time': time,
    'clientPhone': clientPhone,
    'service': service,
    'confidence': confidence,
    'missing': missing,
  };

  factory AiActionRecommendation.fromJson(Map<String, dynamic> json) {
    final type = switch (json['type']?.toString()) {
      'appointment' => AiActionType.appointment,
      'deal' => AiActionType.deal,
      _ => AiActionType.note,
    };
    final rawMissing = json['missing'];
    return AiActionRecommendation(
      type: type,
      title: json['title']?.toString() ?? 'Рекомендованное действие',
      details: json['details']?.toString() ?? '',
      date: json['date']?.toString(),
      time: json['time']?.toString(),
      clientPhone: json['clientPhone']?.toString(),
      service: json['service']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      missing: rawMissing is List
          ? rawMissing.map((value) => value.toString()).toList()
          : const [],
    );
  }
}

class AiTranscriptAnalysis {
  const AiTranscriptAnalysis({
    required this.overview,
    required this.agreements,
    required this.nextSteps,
    required this.openQuestions,
    this.actions = const [],
  });

  final String overview;
  final String agreements;
  final String nextSteps;
  final String openQuestions;
  final List<AiActionRecommendation> actions;

  String get displayText => [
    'Обзор: $overview',
    'Договорились: $agreements',
    'Следующие шаги: $nextSteps',
    'Открытые вопросы: $openQuestions',
  ].join('\n');

  Map<String, dynamic> toJson() => {
    'overview': overview,
    'agreements': agreements,
    'nextSteps': nextSteps,
    'openQuestions': openQuestions,
    'actions': actions.map((action) => action.toJson()).toList(),
  };

  factory AiTranscriptAnalysis.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'];
    return AiTranscriptAnalysis(
      overview: json['overview']?.toString() ?? '',
      agreements: json['agreements']?.toString() ?? '',
      nextSteps: json['nextSteps']?.toString() ?? '',
      openQuestions: json['openQuestions']?.toString() ?? '',
      actions: rawActions is List
          ? rawActions
                .whereType<Map>()
                .map(
                  (item) => AiActionRecommendation.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

AiTranscriptAnalysis parseTranscriptAnalysis(String value) {
  final source = value.trim();
  Map<String, dynamic>? json;
  final fenced = RegExp(
    r'```(?:json)?\s*([\s\S]*?)```',
    caseSensitive: false,
  ).firstMatch(source)?.group(1)?.trim();
  for (final candidate in [fenced, source]) {
    if (candidate == null || candidate.isEmpty) continue;
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map) {
        json = Map<String, dynamic>.from(decoded);
        break;
      }
    } catch (_) {}
  }
  if (json != null) {
    final parsedJson = json;
    String text(String key) => parsedJson[key]?.toString().trim() ?? '';
    final rawActions = parsedJson['actions'];
    final actions = rawActions is List
        ? rawActions.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            final type = switch (item['type']?.toString().toLowerCase()) {
              'appointment' || 'запись' => AiActionType.appointment,
              'deal' || 'сделка' => AiActionType.deal,
              _ => AiActionType.note,
            };
            final rawMissing = item['missing'];
            return AiActionRecommendation(
              type: type,
              title: item['title']?.toString() ?? 'Рекомендованное действие',
              details: item['details']?.toString() ?? '',
              date: item['date']?.toString(),
              time: item['time']?.toString(),
              clientPhone: item['clientPhone']?.toString(),
              service: item['service']?.toString(),
              confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
              missing: rawMissing is List
                  ? rawMissing.map((entry) => entry.toString()).toList()
                  : const [],
            );
          }).toList()
        : const <AiActionRecommendation>[];
    return AiTranscriptAnalysis(
      overview: text('overview'),
      agreements: text('agreements'),
      nextSteps: text('nextSteps'),
      openQuestions: text('openQuestions'),
      actions: actions,
    );
  }

  String section(String label) {
    final match = RegExp(
      '$label\\s*:\\s*(.*?)(?=\\n(?:Обзор|Договорились|Следующие шаги|Открытые вопросы)\\s*:|\$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(source);
    return match?.group(1)?.trim() ?? '';
  }

  return AiTranscriptAnalysis(
    overview: section('Обзор'),
    agreements: section('Договорились'),
    nextSteps: section('Следующие шаги'),
    openQuestions: section('Открытые вопросы'),
  );
}

/// Parses the explicit speaker labels requested from the transcription model.
/// We never guess a speaker from the text itself.
List<TranscriptLine> parseTranscriptLines(String transcript) {
  final lines = <TranscriptLine>[];
  for (final raw in transcript.split(RegExp(r'[\r\n]+'))) {
    final value = raw.trim();
    if (value.isEmpty) continue;
    final match = RegExp(
      r'^(клиент|покупатель|сотрудник|оператор|вы|менеджер|мастер|говорящий)\s*[:—-]\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) {
      lines.add(
        TranscriptLine(speaker: TranscriptSpeaker.unknown, text: value),
      );
      continue;
    }
    final label = match.group(1)!.toLowerCase();
    final speaker = {'клиент', 'покупатель'}.contains(label)
        ? TranscriptSpeaker.client
        : {'сотрудник', 'оператор', 'вы', 'менеджер', 'мастер'}.contains(label)
        ? TranscriptSpeaker.employee
        : TranscriptSpeaker.unknown;
    lines.add(TranscriptLine(speaker: speaker, text: match.group(2)!.trim()));
  }
  return lines;
}

abstract class AiProvider {
  Future<BotReply> reply({
    required String question,
    required String knowledgeBase,
    required List<BotMessage> history,
    required AiSettings settings,
    RequestCancellation? cancellation,
  });

  Future<String> transcribe(
    File audio, {
    required AiSettings settings,
    RequestCancellation? cancellation,
  });

  /// Turns a raw speech-to-text result into speaker-labelled dialogue.
  /// This is deliberately separate from transcription because not every
  /// speech model has native diarization support.
  Future<String> formatTranscript(
    String transcript, {
    required AiSettings settings,
    RequestCancellation? cancellation,
  });

  Future<String> analyzeTranscript(
    String transcript, {
    required AiSettings settings,
    RequestCancellation? cancellation,
  });
}

/// Deterministic provider used before an API key is configured and by tests.
/// It intentionally refuses to invent an answer when the knowledge base lacks
/// enough overlapping words with the question.
class KnowledgeBaseMockProvider implements AiProvider {
  const KnowledgeBaseMockProvider();

  @override
  Future<BotReply> reply({
    required String question,
    required String knowledgeBase,
    required List<BotMessage> history,
    required AiSettings settings,
    RequestCancellation? cancellation,
  }) async {
    if (cancellation?.isCancelled == true) {
      throw const RequestCancelledException();
    }
    if (_explicitlyBlocked(question, knowledgeBase)) {
      return const BotReply(
        text: '',
        needsHuman: true,
        reason: 'В базе знаний есть прямой запрет отвечать на этот вопрос.',
      );
    }
    final tokens = _tokens(question);
    final blocks = knowledgeBase
        .split(RegExp(r'\n(?=#|[-*] )'))
        .where((block) => block.trim().isNotEmpty)
        .toList();
    final scored =
        blocks
            .map(
              (block) => (
                block: block,
                score: _tokens(block).intersection(tokens).length,
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    final best = scored.isEmpty ? null : scored.first;
    if (best == null || best.score < 2) {
      return const BotReply(
        text: '',
        needsHuman: true,
        reason: 'В базе знаний нет подтверждённого ответа на этот вопрос.',
      );
    }
    final answer = _firstAnswerLine(best.block);
    if (answer.isEmpty) {
      return const BotReply(
        text: '',
        needsHuman: true,
        reason: 'Найденный раздел базы знаний не содержит готового ответа.',
      );
    }
    return BotReply(
      text: answer,
      needsHuman: false,
      usedKnowledgeSections: [_sectionTitle(best.block)],
      reason:
          'Ответ сформирован только по подтверждённому разделу базы знаний.',
    );
  }

  @override
  Future<String> transcribe(
    File audio, {
    required AiSettings settings,
    RequestCancellation? cancellation,
  }) async => throw UnsupportedError(
    'В тестовом режиме транскрибация недоступна: настройте API-ключ.',
  );

  @override
  Future<String> formatTranscript(
    String transcript, {
    required AiSettings settings,
    RequestCancellation? cancellation,
  }) async => transcript;

  @override
  Future<String> analyzeTranscript(
    String transcript, {
    required AiSettings settings,
    RequestCancellation? cancellation,
  }) async => 'Анализ доступен после подключения внешнего AI.';

  Set<String> _tokens(String value) => value
      .toLowerCase()
      .split(RegExp(r'[^a-zа-яё0-9]+', caseSensitive: false))
      .where((token) => token.length >= 3)
      .toSet();

  bool _explicitlyBlocked(String question, String knowledgeBase) {
    final questionTokens = _tokens(question);
    if (questionTokens.isEmpty) return false;
    final negative = RegExp(
      r'(не\s+отвеч|нельзя\s+отвеч|запрещено\s+отвеч|не\s+нужно\s+отвеч|не\s+сообщ)',
      caseSensitive: false,
    );
    return knowledgeBase.split(RegExp(r'[\r\n]+')).any((line) {
      if (!negative.hasMatch(line)) return false;
      return _tokens(line).intersection(questionTokens).isNotEmpty;
    });
  }

  String _sectionTitle(String block) => block
      .split('\n')
      .first
      .replaceFirst(RegExp(r'^#+\s*'), '')
      .trim()
      .ifEmpty('Подтверждённое правило');

  String _firstAnswerLine(String block) {
    final lines = block
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'));
    for (final line in lines) {
      final text = line.replaceFirst(RegExp(r'^[-*]\s*'), '').trim();
      if (text.length >= 12) return text;
    }
    return '';
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

/// OpenAI-compatible Codex Sale gateway implementation. The key is supplied
/// by secure storage at call time and never becomes part of these models.
class OpenAiCompatibleProvider implements AiProvider {
  OpenAiCompatibleProvider({required this.apiKey, ApiClient? client})
    : client = client ?? const ApiClient();

  final String apiKey;
  final ApiClient client;

  /// Performs a small authenticated request without sending CRM data. The
  /// models endpoint is best-effort because some compatible gateways disable
  /// it; the completion probe remains the source of truth.
  Future<AiConnectionCheck> verifyConnection({
    required AiSettings settings,
    RequestCancellation? cancellation,
  }) async {
    if (apiKey.trim().isEmpty) throw StateError('Не задан API-ключ AI');
    final modelsUri = Uri.parse(
      settings.baseUrl,
    ).replace(path: _basePath(settings.baseUrl, 'models'));
    var available = <String>[];
    try {
      final modelsResponse = await client.get(
        modelsUri,
        headers: {'authorization': 'Bearer $apiKey'},
        retries: 0,
        cancellation: cancellation,
      );
      if (modelsResponse.statusCode >= 200 && modelsResponse.statusCode < 300) {
        final decoded = jsonDecode(modelsResponse.body);
        final rawModels = decoded is Map
            ? (decoded['data'] ?? decoded['models'])
            : null;
        if (rawModels is List) {
          available = rawModels
              .map(
                (item) =>
                    item is Map ? item['id']?.toString() : item.toString(),
              )
              .whereType<String>()
              .where((id) => id.trim().isNotEmpty)
              .toList();
        }
      }
    } on FormatException {
      // A non-JSON /models response should not prevent the completion probe.
    } catch (_) {
      // Some providers return 404 for /models; probe chat below instead.
    }

    final probeUri = Uri.parse(
      settings.baseUrl,
    ).replace(path: _basePath(settings.baseUrl, 'chat/completions'));
    final response = await client.post(
      probeUri,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': settings.model,
        'messages': [
          {
            'role': 'system',
            'content': 'Служебная проверка подключения. Не раскрывай секреты.',
          },
          {'role': 'user', 'content': 'Ответь ровно: OK'},
        ],
        'temperature': 0,
        'max_tokens': 8,
      }),
      retries: 0,
      cancellation: cancellation,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'AI API вернул HTTP ${response.statusCode} для модели ${settings.model}',
      );
    }
    final decoded = jsonDecode(response.body);
    final content = _extractContent(decoded);
    if (content.isEmpty) throw StateError('AI API вернул пустой ответ');
    return AiConnectionCheck(model: settings.model, availableModels: available);
  }

  @override
  Future<BotReply> reply({
    required String question,
    required String knowledgeBase,
    required List<BotMessage> history,
    required AiSettings settings,
    RequestCancellation? cancellation,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('Не задан API-ключ AI');
    }
    if (_explicitlyBlocked(question, knowledgeBase)) {
      return const BotReply(
        text: '',
        needsHuman: true,
        reason: 'В базе знаний есть прямой запрет отвечать на этот вопрос.',
      );
    }
    final base = Uri.parse(
      settings.baseUrl,
    ).replace(path: _basePath(settings.baseUrl, 'chat/completions'));
    final priorHistory = history
        .where(
          (message) => message.role == 'user' || message.role == 'assistant',
        )
        .toList();
    // The current user message is already present in the conversation model;
    // send it only once as the final turn.
    if (priorHistory.isNotEmpty &&
        priorHistory.last.role == 'user' &&
        priorHistory.last.text.trim() == question.trim()) {
      priorHistory.removeLast();
    }
    final recentHistory = priorHistory.length <= 12
        ? priorHistory
        : priorHistory.sublist(priorHistory.length - 12);
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': '''${settings.systemInstruction}

Ты ведёшь естественный диалог с клиентом. Отвечай только на текущий вопрос,
учитывая последние сообщения переписки. Не пересказывай всю базу знаний и не
перечисляй все услуги, цены или правила, если клиент прямо об этом не просил.
Отвечай кратко: обычно 1–3 предложения. Если для точного ответа не хватает
данных, задай один уточняющий вопрос. Используй только факты из базы знаний
ниже. Если подтверждённого ответа нет, верни строго `NEEDS_HUMAN` без пояснений.

$knowledgeBase''',
      },
      ...recentHistory.map(
        (message) => {'role': message.role, 'content': message.text},
      ),
      {'role': 'user', 'content': question},
    ];
    final response = await client.post(
      base,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': settings.model,
        'messages': messages,
        'temperature': settings.temperature.clamp(0, 1),
        'max_tokens': settings.maxTokens.clamp(64, 2000),
      }),
      cancellation: cancellation,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('AI API вернул HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final raw = _extractContent(data);
    if (raw.isEmpty || raw.toUpperCase().contains('NEEDS_HUMAN')) {
      return const BotReply(
        text: '',
        needsHuman: true,
        reason: 'AI не нашёл подтверждённого ответа в базе знаний.',
      );
    }
    // A model response is never enough by itself: at least one meaningful
    // question token must be present in the approved knowledge base. This
    // prevents a confident-looking answer to an unrelated customer question.
    final questionTokens = _tokens(question);
    final knowledgeTokens = _tokens(knowledgeBase);
    if (questionTokens.intersection(knowledgeTokens).isEmpty) {
      return const BotReply(
        text: '',
        needsHuman: true,
        reason: 'Вопрос не связан с подтверждёнными сведениями базы знаний.',
      );
    }
    return BotReply(
      text: raw,
      needsHuman: false,
      reason:
          'Ответ сформирован внешним AI по базе знаний. В тестовом режиме он не отправляется клиенту.',
    );
  }

  @override
  Future<String> transcribe(
    File audio, {
    required AiSettings settings,
    RequestCancellation? cancellation,
  }) async {
    if (apiKey.trim().isEmpty) throw StateError('Не задан API-ключ AI');
    if (cancellation?.isCancelled == true) {
      throw const RequestCancelledException();
    }
    final uri = Uri.parse(
      settings.baseUrl,
    ).replace(path: _basePath(settings.baseUrl, 'audio/transcriptions'));
    final request = HttpClientRequestPlaceholder(uri);
    return request.send(audio, apiKey, cancellation);
  }

  @override
  Future<String> formatTranscript(
    String transcript, {
    required AiSettings settings,
    RequestCancellation? cancellation,
  }) async {
    if (apiKey.trim().isEmpty) throw StateError('Не задан API-ключ AI');
    final source = transcript.trim();
    if (source.isEmpty) return source;
    final uri = Uri.parse(
      settings.baseUrl,
    ).replace(path: _basePath(settings.baseUrl, 'chat/completions'));
    final response = await client.post(
      uri,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': settings.model,
        'temperature': 0,
        'max_tokens': 2400,
        'messages': [
          {
            'role': 'system',
            'content':
                '''Раздели расшифровку телефонного разговора на короткие реплики двух сторон. Не добавляй, не исправляй и не пересказывай слова. Каждая строка должна начинаться строго с одного из префиксов: `Клиент:`, `Сотрудник:` или `Говорящий:`. Определи сторону только когда это ясно из контекста; если есть сомнение, используй `Говорящий:`. Верни только размеченные реплики без пояснений.''',
          },
          {'role': 'user', 'content': source},
        ],
      }),
      cancellation: cancellation,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Разметка разговора: HTTP ${response.statusCode}');
    }
    final formatted = _extractContent(jsonDecode(response.body));
    return formatted.isEmpty ? source : formatted;
  }

  @override
  Future<String> analyzeTranscript(
    String transcript, {
    required AiSettings settings,
    RequestCancellation? cancellation,
  }) async {
    if (apiKey.trim().isEmpty) throw StateError('Не задан API-ключ AI');
    final source = transcript.trim();
    if (source.isEmpty) throw StateError('Нет текста для анализа');
    final uri = Uri.parse(
      settings.baseUrl,
    ).replace(path: _basePath(settings.baseUrl, 'chat/completions'));
    final response = await client.post(
      uri,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': settings.model,
        'temperature': 0,
        'max_tokens': 1200,
        'messages': [
          {
            'role': 'system',
            'content':
                '''Проанализируй расшифровку телефонного разговора автосервиса. Не выдумывай факты и не добавляй отсутствующие договорённости. Верни только JSON без markdown в формате: {"overview":"краткий обзор","agreements":"о чём договорились или не зафиксировано","nextSteps":"следующие шаги или не зафиксировано","openQuestions":"что нужно уточнить или не зафиксировано","actions":[{"type":"note|appointment|deal","title":"краткое название","details":"основание из разговора","date":"YYYY-MM-DD или null","time":"HH:mm или null","clientPhone":"телефон или null","service":"услуга или null","confidence":0.0,"missing":["перечень отсутствующих обязательных полей"]}]}. Добавляй action только если клиент явно просил или стороны явно договорились о действии. Для записи обязательны дата, время и услуга; для сделки обязательны клиент и услуга; заметка может быть создана всегда, если есть важная договорённость. Если данных нет, actions должен быть пустым массивом.''',
          },
          {'role': 'user', 'content': source},
        ],
      }),
      cancellation: cancellation,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Анализ разговора: HTTP ${response.statusCode}');
    }
    final result = _extractContent(jsonDecode(response.body));
    if (result.isEmpty) throw StateError('AI не вернул анализ разговора');
    return result;
  }

  String _basePath(String base, String endpoint) {
    final current = Uri.parse(base).path.replaceAll(RegExp(r'/+$'), '');
    return '${current.isEmpty ? '/v1' : current}/$endpoint';
  }

  Set<String> _tokens(String value) => value
      .toLowerCase()
      .split(RegExp(r'[^a-zа-яё0-9]+', caseSensitive: false))
      .where((token) => token.length >= 3)
      .toSet();

  bool _explicitlyBlocked(String question, String knowledgeBase) {
    final questionTokens = _tokens(question);
    if (questionTokens.isEmpty) return false;
    final negative = RegExp(
      r'(не\s+отвеч|нельзя\s+отвеч|запрещено\s+отвеч|не\s+нужно\s+отвеч|не\s+сообщ)',
      caseSensitive: false,
    );
    return knowledgeBase.split(RegExp(r'[\r\n]+')).any((line) {
      if (!negative.hasMatch(line)) return false;
      return _tokens(line).intersection(questionTokens).isNotEmpty;
    });
  }

  String _extractContent(dynamic data) {
    final content = data is Map
        ? ((data['choices'] as List? ?? const []).firstOrNull
              as Map?)?['message']?['content']
        : null;
    if (content is List) {
      return content
          .map(
            (part) =>
                part is Map ? part['text']?.toString() ?? '' : part.toString(),
          )
          .join()
          .trim();
    }
    return content?.toString().trim() ?? '';
  }
}

extension on List<dynamic> {
  dynamic get firstOrNull => isEmpty ? null : first;
}

/// Uses dart:io multipart support while keeping the public provider free from
/// any secret persistence. It is deliberately small and has the same timeout
/// contract as the rest of CRM integration calls.
class HttpClientRequestPlaceholder {
  const HttpClientRequestPlaceholder(this.uri);
  final Uri uri;

  Future<String> send(
    File audio,
    String apiKey,
    RequestCancellation? cancellation,
  ) async {
    if (!await audio.exists()) throw StateError('Аудиофайл не найден');
    final client = HttpClient();
    try {
      final boundary = 'crm-${DateTime.now().microsecondsSinceEpoch}';
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 30));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': boundary},
      );
      void writeUtf8(String value) => request.add(utf8.encode(value));
      void field(String name, String value) {
        writeUtf8('--$boundary\r\n');
        writeUtf8('Content-Disposition: form-data; name="$name"\r\n\r\n');
        writeUtf8('$value\r\n');
      }

      field('model', 'gpt-4o-transcribe');
      field(
        'prompt',
        'Это разговор клиента и сотрудника. Расшифруй дословно и каждую реплику начинай с новой строки. Обязательно помечай говорящих строго как «Клиент:» или «Сотрудник:». Если говорящего нельзя определить, используй «Говорящий:». Не пересказывай разговор и не добавляй комментарии.',
      );
      writeUtf8('--$boundary\r\n');
      writeUtf8(
        'Content-Disposition: form-data; name="file"; filename="${audio.uri.pathSegments.last}"\r\n',
      );
      writeUtf8('Content-Type: application/octet-stream\r\n\r\n');
      await request.addStream(audio.openRead());
      writeUtf8('\r\n--$boundary--\r\n');
      if (cancellation?.isCancelled == true) {
        request.abort();
        throw const RequestCancelledException();
      }
      final response = await request.close().timeout(
        const Duration(seconds: 90),
      );
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var details = '';
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            final error = decoded['error'];
            details = error is Map
                ? (error['message'] ?? error['code'] ?? '').toString()
                : (decoded['message'] ?? '').toString();
          }
        } catch (_) {
          details = body.trim();
        }
        throw StateError(
          'Транскрибация: HTTP ${response.statusCode}${details.isEmpty ? '' : ' — $details'}',
        );
      }
      final data = jsonDecode(body);
      final text = data is Map ? data['text']?.toString().trim() ?? '' : '';
      if (text.isEmpty) throw StateError('Транскрибация не вернула текст');
      return text;
    } finally {
      client.close(force: true);
    }
  }
}
