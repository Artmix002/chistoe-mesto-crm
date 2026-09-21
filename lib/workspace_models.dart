import 'dart:convert';

String stableWorkspaceId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

class ServiceCatalogItem {
  ServiceCatalogItem({
    required this.id,
    required this.name,
    this.durationHours = 1,
    this.category = 'Основные услуги',
    this.materialIds = const [],
    this.botInstructions = '',
    this.archived = false,
    this.updatedAt,
  });

  final String id;
  String name;
  double durationHours;
  String category;
  List<String> materialIds;

  /// Service-specific facts/rules injected into the bot knowledge base.
  String botInstructions;
  bool archived;
  String? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'durationHours': durationHours,
    'category': category,
    'materialIds': materialIds,
    'botInstructions': botInstructions,
    'archived': archived,
    'updatedAt': updatedAt,
  };

  factory ServiceCatalogItem.fromJson(Map<String, dynamic> json) {
    return ServiceCatalogItem(
      id: json['id']?.toString() ?? stableWorkspaceId('service'),
      name: json['name']?.toString() ?? '',
      durationHours: (json['durationHours'] as num?)?.toDouble() ?? 1,
      category: json['category']?.toString() ?? 'Основные услуги',
      materialIds: (json['materialIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      botInstructions: json['botInstructions']?.toString() ?? '',
      archived: json['archived'] == true,
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}

class StickyNote {
  StickyNote({
    required this.id,
    required this.text,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  String text;
  final String createdAt;
  String? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory StickyNote.fromJson(Map<String, dynamic> json) => StickyNote(
    id: json['id']?.toString() ?? stableWorkspaceId('note'),
    text: json['text']?.toString() ?? '',
    createdAt:
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    updatedAt: json['updatedAt']?.toString(),
  );
}

class DashboardRevenuePlan {
  DashboardRevenuePlan({
    required this.id,
    required this.title,
    required this.target,
    required this.from,
    required this.to,
    this.createdAt,
  });

  final String id;
  String title;
  double target;
  DateTime from;
  DateTime to;
  String? createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'target': target,
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
    'createdAt': createdAt,
  };

  factory DashboardRevenuePlan.fromJson(Map<String, dynamic> json) =>
      DashboardRevenuePlan(
        id: json['id']?.toString() ?? stableWorkspaceId('revenue-plan'),
        title: json['title']?.toString() ?? 'План выручки',
        target: (json['target'] as num?)?.toDouble() ?? 0,
        from:
            DateTime.tryParse(json['from']?.toString() ?? '') ?? DateTime.now(),
        to: DateTime.tryParse(json['to']?.toString() ?? '') ?? DateTime.now(),
        createdAt: json['createdAt']?.toString(),
      );
}

class KnowledgeBaseVersion {
  KnowledgeBaseVersion({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.source,
    this.comment = '',
  });

  final String id;
  final String content;
  final String createdAt;
  final String source;
  final String comment;

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'createdAt': createdAt,
    'source': source,
    'comment': comment,
  };

  factory KnowledgeBaseVersion.fromJson(Map<String, dynamic> json) =>
      KnowledgeBaseVersion(
        id: json['id']?.toString() ?? stableWorkspaceId('knowledge'),
        content: json['content']?.toString() ?? '',
        createdAt:
            json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        source: json['source']?.toString() ?? 'ручная правка',
        comment: json['comment']?.toString() ?? '',
      );
}

class BotMessage {
  BotMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.needsHuman = false,
    this.usedKnowledgeSections = const [],
  });

  final String id;
  final String role;
  final String text;
  final String createdAt;
  final bool needsHuman;
  final List<String> usedKnowledgeSections;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'text': text,
    'createdAt': createdAt,
    'needsHuman': needsHuman,
    'usedKnowledgeSections': usedKnowledgeSections,
  };

  factory BotMessage.fromJson(Map<String, dynamic> json) => BotMessage(
    id: json['id']?.toString() ?? stableWorkspaceId('message'),
    role: json['role']?.toString() ?? 'user',
    text: json['text']?.toString() ?? '',
    createdAt:
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    needsHuman: json['needsHuman'] == true,
    usedKnowledgeSections: (json['usedKnowledgeSections'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(),
  );
}

class BotConversation {
  BotConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    List<BotMessage>? messages,
  }) : messages = messages ?? [];

  final String id;
  String title;
  final String createdAt;
  final List<BotMessage> messages;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt,
    'messages': messages.map((item) => item.toJson()).toList(),
  };

  factory BotConversation.fromJson(Map<String, dynamic> json) =>
      BotConversation(
        id: json['id']?.toString() ?? stableWorkspaceId('conversation'),
        title: json['title']?.toString() ?? 'Новый тестовый диалог',
        createdAt:
            json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        messages: (json['messages'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => BotMessage.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
}

class AiSettings {
  static const defaultBaseUrl = 'https://codex.sale/v1';
  static const defaultModel = 'gpt-5.4';

  const AiSettings({
    this.enabled = false,
    this.baseUrl = defaultBaseUrl,
    this.model = defaultModel,
    this.maxTokens = 700,
    this.temperature = 0.2,
    this.systemInstruction = '',
    this.storeConversationText = true,
  });

  final bool enabled;
  final String baseUrl;
  final String model;
  final int maxTokens;
  final double temperature;
  final String systemInstruction;
  final bool storeConversationText;

  AiSettings copyWith({
    bool? enabled,
    String? baseUrl,
    String? model,
    int? maxTokens,
    double? temperature,
    String? systemInstruction,
    bool? storeConversationText,
  }) => AiSettings(
    enabled: enabled ?? this.enabled,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    maxTokens: maxTokens ?? this.maxTokens,
    temperature: temperature ?? this.temperature,
    systemInstruction: systemInstruction ?? this.systemInstruction,
    storeConversationText: storeConversationText ?? this.storeConversationText,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'baseUrl': baseUrl,
    'model': model,
    'maxTokens': maxTokens,
    'temperature': temperature,
    'systemInstruction': systemInstruction,
    'storeConversationText': storeConversationText,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) => AiSettings(
    enabled: json['enabled'] == true,
    baseUrl: json['baseUrl']?.toString() ?? defaultBaseUrl,
    // Migrate the old pre-GPT-5.4 default without changing an explicitly
    // selected model.
    model: _migrateModel(json['model']?.toString()),
    maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 700,
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.2,
    systemInstruction: json['systemInstruction']?.toString() ?? '',
    storeConversationText: json['storeConversationText'] != false,
  );

  String encode() => jsonEncode(toJson());

  static String _migrateModel(String? value) {
    if (value == null || value.trim().isEmpty || value == 'claude-haiku-4-5') {
      return defaultModel;
    }
    return value;
  }
}

class KnowledgeSuggestion {
  const KnowledgeSuggestion({
    required this.id,
    required this.question,
    required this.answer,
    required this.reason,
  });

  final String id;
  final String question;
  final String answer;
  final String reason;

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'answer': answer,
    'reason': reason,
  };
}
