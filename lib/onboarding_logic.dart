class OnboardingProgress {
  const OnboardingProgress({
    required this.sheetConfigured,
    required this.calendarConfigured,
    required this.channelConfigured,
  });

  final bool sheetConfigured;
  final bool calendarConfigured;
  final bool channelConfigured;

  /// Каналы сообщений необязательны: CRM можно использовать без них.
  bool get isReadyToFinish => sheetConfigured && calendarConfigured;

  /// Индексы экранов определены в navigation.dart.
  int get nextPageIndex {
    if (!sheetConfigured) return 6;
    if (!calendarConfigured) return 3;
    return 7;
  }

  String get nextStep {
    if (!sheetConfigured) return 'Указать Google Sheets';
    if (!calendarConfigured) return 'Подключить календарь';
    return 'Настроить каналы сообщений';
  }
}
