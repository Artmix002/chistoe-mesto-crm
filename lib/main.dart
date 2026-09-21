import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'app_constants.dart';
import 'avito_cache.dart';
import 'config.dart';
import 'repositories.dart';
import 'api_client.dart';
import 'schema.dart';
import 'xlsx_export.dart';
import 'permissions.dart';
import 'navigation.dart';
import 'layout.dart';
import 'finance.dart';
import 'calendar_logic.dart';
import 'sync_queue.dart';
import 'sync_payload.dart';
import 'sync_status.dart';
import 'app_notification.dart';
import 'deal_logic.dart';
import 'client_logic.dart';
import 'widgets/unified_inbox.dart';
import 'secure_store.dart';
import 'logger.dart';
import 'stock_logic.dart';
import 'onboarding_logic.dart';
import 'reconciliation.dart';
import 'message_queue.dart';
import 'workspace_models.dart';
import 'ai_service.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/calendar_components.dart';
import 'widgets/calendar_workspace.dart';
import 'widgets/finance_reports.dart';
import 'oauth_pkce.dart';
import 'access_control.dart';
import 'auth_service.dart';
import 'widgets/offline_status_banner.dart';
import 'widgets/messenger_connection_card.dart';
import 'widgets/dashboard_shell.dart';
import 'widgets/overview_dashboard.dart';
import 'widgets/notification_center_dialog.dart';
import 'widgets/client_detail_dialog.dart';
import 'widgets/settings_page.dart';
import 'widgets/quick_replies_dialog.dart';
import 'widgets/accounting_page.dart';
import 'widgets/accounting_table.dart';
import 'widgets/accounting_categories_dialog.dart';
import 'widgets/local_operations_list.dart';
import 'widgets/stock_page.dart';
import 'widgets/deals_kanban_board.dart';
import 'widgets/deals_grouped_table.dart';
import 'widgets/client_results_list.dart';
import 'widgets/telegram_inbox.dart';
import 'widgets/messaging_panels.dart';
import 'widgets/integration_diagnostics_dialog.dart';
import 'widgets/avito_connection_card.dart';
import 'widgets/calendar_connection_panel.dart';
import 'widgets/calendar_appointment_dialog.dart';
import 'widgets/instagram_inbox.dart';
import 'widgets/vk_inbox.dart';
import 'widgets/messages_page.dart';
import 'widgets/dashboard_workspace.dart';
import 'widgets/bot_test_workspace.dart';
import 'widgets/login_screen.dart';

void main() {
  FlutterError.onError = (details) {
    CrmLogger.error(
      'Необработанная ошибка Flutter',
      error: details.exception,
      name: 'crm.flutter',
    );
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    CrmLogger.error(
      'Необработанная ошибка платформы',
      error: error,
      name: 'crm.platform',
    );
    return false;
  };
  runApp(const CleanPlaceApp());
}

class CleanPlaceApp extends StatefulWidget {
  const CleanPlaceApp({super.key});

  @override
  State<CleanPlaceApp> createState() => _CleanPlaceAppState();
}

class _CleanPlaceAppState extends State<CleanPlaceApp> {
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOutCubic,
      theme: ThemeData(
        fontFamily: 'Arial',
        scaffoldBackgroundColor: darkMode
            ? const Color(0xFF101216)
            : const Color(0xFFFFF1E4),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF28C28),
          brightness: darkMode ? Brightness.dark : Brightness.light,
        ).copyWith(primary: const Color(0xFFF28C28)),
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(7)),
            borderSide: BorderSide(color: Color(0xFF4A4F59), width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(7)),
            borderSide: BorderSide(color: Color(0xFFF28C28), width: 1.2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(7)),
            borderSide: BorderSide(color: Color(0xFF4A4F59), width: 0.8),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          floatingLabelStyle: TextStyle(color: Color(0xFFF28C28)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF28C28),
            side: BorderSide.none,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFF28C28)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: darkMode ? Color(0xFF17191D) : Color(0xFFFFF8F1),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black87,
          titleTextStyle: TextStyle(
            color: darkMode ? Color(0xFFF1F3F5) : Color(0xFF20242A),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: Dashboard(
        darkMode: darkMode,
        onThemeChanged: (value) => setState(() => darkMode = value),
      ),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({
    super.key,
    required this.darkMode,
    required this.onThemeChanged,
  });
  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  SheetsRepository get _sheets => SheetsRepository(
    currentSheetId,
    _apiClient,
    Uri.tryParse(syncEndpoint),
    syncToken,
  );
  final List<Client> clients = [];
  final List<StockItem> stockItems = [];
  final List<StockMovement> stockMovements = [];
  final List<AuditEntry> auditEntries = [];
  final SyncQueue localChangeQueue = SyncQueue();
  final SecretStore secretStore = const SecretStore();
  final RequestCancellation _lifecycleCancellation = RequestCancellation();
  late final ApiClient _apiClient;
  CrmAuthService? _authService;
  bool _serverConfigurationInitialized = false;
  // У CRM нет локального анонимного режима: рабочее пространство открывается
  // только после проверки серверной сессии.
  CrmSession? _session;
  List<CrmUser> _serverUsers = [];
  bool _authLoading = true;
  String? _authError;
  String currentRole = 'Владелец';
  List<UserProfile> userProfiles = [
    UserProfile(id: 'owner', name: 'Владелец', role: 'Владелец'),
  ];
  String currentUserId = 'owner';
  UserProfile? get currentUser => userProfiles.cast<UserProfile?>().firstWhere(
    (user) => user?.id == currentUserId,
    orElse: () => null,
  );
  Map<String, String> get _permissions =>
      _session?.user.permissions ?? defaultPermissionsForRole(currentRole);
  bool get canManageIntegrations => _canEdit('integrations');
  bool _canView(String area) => canViewPermission(_permissions, area);
  bool _canEdit(String area) => canEditPermission(_permissions, area);
  static const clientStatuses = [
    'Новый лид',
    'Написал',
    'Записан',
    'В работе',
    'Отказался',
    'Не приехал',
    'Выполнен',
  ];
  Color get _surfaceColor =>
      widget.darkMode ? const Color(0xFF24272E) : const Color(0xFFFFFAF5);
  Color get _cardBorderColor =>
      widget.darkMode ? const Color(0xFF3B404A) : const Color(0xFFFFC080);
  Color get _mainTextColor =>
      widget.darkMode ? const Color(0xFFF1F3F5) : const Color(0xFF20242A);
  Color get _mutedTextColor =>
      widget.darkMode ? const Color(0xFFB7BDC7) : const Color(0xFF777D87);
  int selected = 0;
  bool loading = false;
  int _dealsRequestId = 0;
  int _accountingRequestId = 0;
  int _activeSheetLoads = 0;
  RequestCancellation? _dealsCancellation;
  RequestCancellation? _accountingCancellation;
  String? sheetError;
  bool sheetsOfflineMode = false;
  DateTime? lastSheetsSync;
  bool pendingChangesSyncing = false;
  String? pendingChangesSyncError;
  DateTime? lastPendingChangesSync;
  final List<CrmNotification> notifications = [];
  String syncEndpoint = AppConfig.syncEndpoint;
  String syncToken = '';
  Map<String, String> dataSources = const {
    'deals': SheetsSchema.dealsSheet,
    'accounting': SheetsSchema.accountingSheet,
    'expenses': SheetsSchema.expensesSheet,
    'appointments': 'CRM_Appointments',
  };
  String calendarClientSecret = '';
  final TextEditingController sheetController = TextEditingController(
    text: 'https://docs.google.com/spreadsheets/d/${AppConfig.sheetId}/edit',
  );
  List<List<String>> accountingRows = [];
  int accountingPage = 0;
  static const accountingPageSize = 50;
  List<Map<String, dynamic>> businessTransactions = [];
  List<String> accountingCategories = [
    'Материалы',
    'Зарплата',
    'Аренда',
    'Реклама',
    'Налоги',
    'Прочее',
  ];
  String accountingCategoryFilter = 'Все категории';
  String clientStatusFilter = 'Все статусы';
  DateTime? accountingFrom, accountingTo;
  Map<String, dynamic>? closedAccountingPeriod;
  final List<Map<String, dynamic>> closedAccountingPeriods = [];
  List<List<String>> dealRows = [];
  List<List<String>> syncedDealRows = [];
  List<String> dealImportErrors = [];
  List<List<String>> manualDealRows = [];
  List<Deal> typedDeals = [];
  static const dealHeaders = SheetsSchema.manualDealColumns;
  static const _hiddenDealColumns = {8, 10};
  Set<int> visibleDealCols = {0, 1, 2, 4, 5, 6, 9, 11, 12, 13, 14, 15, 16};
  double dealColWidth = 120;
  late SharedPreferences prefs;
  DateTime now = DateTime.now();
  String periodFilter = "Август";
  bool dealsOldestFirst = false;
  bool dealsKanban = false;
  int dealsPage = 0;
  static const dealGroupsPageSize = 20;
  int stockPage = 0;
  static const stockPageSize = 50;
  String stockSearch = '';
  String stockCategoryFilter = '';
  Timer? stockSearchDebounce;
  String? dealStatusFilter;
  DateTime? customFrom, customTo;
  Timer? clock;
  Timer? pendingChangesSyncTimer;
  Timer? workspaceRefreshTimer;
  Timer? appointmentReminderTimer;
  final Set<String> sentAppointmentReminderKeys = {};
  bool preferencesLoaded = false;
  // Prevent an early user action or background callback from writing empty
  // collections before the persisted CRM data has finished loading.
  bool _crmDataLoaded = false;
  bool _workspaceRefreshInProgress = false;
  bool _workspaceSaveInProgress = false;
  bool calendarConnected = false;
  String? calendarStatus;
  String? calendarAccessToken;
  String? calendarRefreshToken;
  final Map<String, String> messengerSecrets = {};
  List<Map<String, dynamic>> calendarEvents = [];
  final Set<String> _seenAppointmentIds = {};
  bool _appointmentNotificationsReady = false;
  List<Map<String, dynamic>> archivedCalendarEvents = [];
  List<Map<String, dynamic>> availableCalendars = [];
  String calendarId = 'primary';
  String calendarName = 'Основной календарь';
  bool calendarLoading = false;
  DateTime calendarViewDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  DateTime selectedCalendarDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  String calendarViewMode = 'Месяц';
  String calendarSearch = '';
  Timer? calendarSearchDebounce;
  Map<String, bool> messengerConnected = {
    'telegram': false,
    'vk': false,
    'instagram': false,
  };
  Map<String, String> messengerStatus = {
    'telegram': 'Не подключён',
    'vk': 'Не подключён',
    'instagram': 'Не подключён',
  };
  bool avitoConnected = false;
  bool avitoLoading = false;
  String avitoStatus = 'Не подключён';
  String? avitoAccessToken;
  String? avitoUserId;
  List<Map<String, dynamic>> avitoAccounts = [];
  String? activeAvitoAccountKey;
  int? _lastVkMessageId;
  String avitoSection = 'Чаты';
  List<String> availableServices = [
    'Химчистка салона',
    'Полировка кузова',
    'Керамика',
    'Мойка автомобиля',
  ];
  Map<String, double> serviceDurations = {};
  List<ServiceCatalogItem> serviceCatalog = [
    ServiceCatalogItem(id: 'service-interior', name: 'Химчистка салона'),
    ServiceCatalogItem(id: 'service-polish', name: 'Полировка кузова'),
    ServiceCatalogItem(id: 'service-ceramic', name: 'Керамика'),
    ServiceCatalogItem(id: 'service-wash', name: 'Мойка автомобиля'),
  ];
  final List<StickyNote> dashboardNotes = [];
  final List<DashboardRevenuePlan> revenuePlans = [];
  String dashboardPeriod = 'Все время';
  DateTime? dashboardCustomFrom;
  DateTime? dashboardCustomTo;
  String knowledgeBase = '''# База знаний «Чистое место»

## Правило для бота
- Отвечай только подтверждёнными фактами из этой базы.
- Если подтверждённого ответа нет — не придумывай ответ и передай вопрос сотруднику.

## Услуги
- Состав, сроки и правила работ ведутся в справочнике услуг CRM.
- Стоимость сотрудник указывает вручную в конкретной записи или сделке.

## Передача сотруднику
- Если вопроса нет в базе, сообщи CRM, что нужен ответ сотрудника.
''';
  final List<KnowledgeBaseVersion> knowledgeVersions = [];
  final List<BotConversation> botConversations = [];
  String? selectedBotConversationId;
  AiSettings aiSettings = const AiSettings();
  String aiApiKey = '';
  bool botRequestInProgress = false;
  List<Map<String, dynamic>> avitoChats = [];
  List<Map<String, dynamic>> avitoCalls = [];
  List<Map<String, dynamic>> avitoChatMessages = [];
  Map<String, dynamic>? selectedAvitoChat;
  final Set<String> loadingAvitoCallIds = {};
  final AudioPlayer avitoAudioPlayer = AudioPlayer();
  StreamSubscription<Duration>? avitoAudioPositionSubscription;
  StreamSubscription<PlayerState>? avitoAudioStateSubscription;
  String? playingAvitoCallId;
  String? playingAvitoAudioPath;
  Duration avitoAudioPosition = Duration.zero;
  Duration avitoAudioDuration = Duration.zero;
  bool avitoAudioPlaying = false;
  final Map<String, String> avitoTranscriptions = {};
  final Set<String> transcribingAvitoCallIds = {};
  final Map<String, AiTranscriptAnalysis> avitoCallAnalyses = {};
  final Set<String> analyzingAvitoCallIds = {};
  final Set<String> appliedAnalysisActions = {};
  bool avitoCacheLoading = false;
  int avitoCachedAudioCount = 0;
  int avitoCachedAudioBytes = 0;
  final TextEditingController avitoReplyController = TextEditingController();
  final TextEditingController messagesSearchController =
      TextEditingController();
  final TextEditingController crmSearchController = TextEditingController();
  String messagesSearch = '';
  Timer? crmSearchDebounce;
  Timer? messagesSearchDebounce;
  final Set<String> readMessageDialogs = {};
  final List<Map<String, String>> pendingMessages = [];
  bool pendingMessagesRetrying = false;
  Timer? pendingMessageTimer;
  final Map<String, String> messageAssignees = {};
  final Map<String, List<String>> messageTags = {};
  List<String> quickReplyTemplates = [
    'Здравствуйте! Подскажите, пожалуйста, удобное время для записи.',
    'Стоимость услуги зависит от состояния автомобиля. Пришлите фото для оценки.',
    'Спасибо за обращение! Мы скоро ответим.',
  ];
  bool vkLoading = false;
  bool telegramLoading = false;
  List<Map<String, dynamic>> telegramChats = [];
  Map<String, dynamic>? selectedTelegramChat;
  final TextEditingController telegramReplyController = TextEditingController();
  bool instagramLoading = false;
  List<Map<String, dynamic>> instagramConversations = [];
  Map<String, dynamic>? selectedInstagramConversation;
  List<Map<String, dynamic>> instagramMessages = [];
  final TextEditingController instagramReplyController =
      TextEditingController();
  int _instagramRequestId = 0;
  List<Map<String, dynamic>> vkConversations = [];
  List<Map<String, dynamic>> vkMessages = [];
  Map<String, dynamic>? selectedVkConversation;
  final TextEditingController vkReplyController = TextEditingController();
  bool resizing = false;
  Map<int, double> dealColWidths = {};
  bool wrapDealText = true;
  DateTime? fromDate, toDate;
  static const sheetId = AppConfig.sheetId;
  bool get _hasProtectedSheetAccess {
    final endpoint = Uri.tryParse(syncEndpoint);
    return endpoint?.scheme == 'https' && syncToken.trim().isNotEmpty;
  }

  String get currentSheetId {
    final m = RegExp(
      r'/spreadsheets/d/([a-zA-Z0-9_-]+)',
    ).firstMatch(sheetController.text);
    return m?.group(1) ?? sheetId;
  }

  Future<void> _saveSheetUrl() async {
    if (!canManageIntegrations) return;
    await prefs.setString('sheet_url', sheetController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка на таблицу сохранена')),
      );
    }
  }

  Future<void> _saveUserProfiles() async {
    await prefs.setString(
      'crm_user_profiles',
      jsonEncode(userProfiles.map((profile) => profile.toJson()).toList()),
    );
    await prefs.setString('crm_current_user', currentUserId);
    await prefs.setString('crm_role', currentRole);
  }

  Uri? get _serverEndpoint {
    final saved = prefs.getString('crm_server_url') ?? '';
    // CRM_SERVER_URL в релизе является единым источником для iPhone, macOS
    // и Windows. Локальное поле нужно лишь старым сборкам без dart-define.
    final configured = AppConfig.serverUrl.trim();
    return Uri.tryParse(configured.isNotEmpty ? configured : saved);
  }

  Future<void> _initializeAuth() async {
    final endpoint = _serverEndpoint;
    if (endpoint == null || endpoint.scheme != 'https') {
      if (mounted) {
        setState(() {
          _authService = null;
          _session = null;
          _authLoading = false;
          _authError =
              'CRM-сервер не задан. Установите сборку с CRM_SERVER_URL.';
        });
      }
      return;
    }
    _authService = CrmAuthService(endpoint: endpoint, client: _apiClient);
    final storedToken = await secretStore.read('crm_session_token');
    if (storedToken != null && storedToken.isNotEmpty) {
      final profile = currentUser;
      if (profile != null) {
        _session = CrmSession(
          token: storedToken,
          user: CrmUser(
            id: profile.id,
            name: profile.name,
            role: profile.role,
            active: profile.active,
            permissions: profile.permissions,
          ),
          configuration: const {},
        );
        syncEndpoint = endpoint.toString();
        syncToken = storedToken;
        if (mounted) setState(() => _authLoading = false);
        unawaited(_validateStoredSession(storedToken));
        return;
      }
    }
    try {
      _serverUsers = await _authService!.listUsers();
      if (mounted) setState(() => _authLoading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _authLoading = false;
          _authError = _safeAuthError(error);
          _session = null;
        });
      }
    }
  }

  Future<void> _validateStoredSession(String token) async {
    final service = _authService;
    if (service == null) return;
    try {
      final resumed = await service.resume(token);
      _serverUsers = await service.listUsers();
      if (!mounted || _session?.token != token) return;
      setState(() {
        _authError = null;
        _session = resumed;
        _applyServerSession(resumed);
      });
      unawaited(_saveUserProfiles());
    } on CrmAuthException catch (error) {
      if (error.code != 'SESSION_INVALID' && error.code != 'ACCOUNT_REVOKED') {
        return;
      }
      await secretStore.delete('crm_session_token');
      if (!mounted || _session?.token != token) return;
      setState(() {
        _session = null;
        _authError = 'Сессия завершена. Войдите по PIN.';
      });
    } catch (_) {
      // Network errors preserve the local session and offline workspace.
    }
  }

  String _safeAuthError(Object error) {
    final message = error.toString();
    return message.length > 180
        ? 'Не удалось связаться с CRM-сервером.'
        : message;
  }

  Future<void> _configureServer() async {
    final controller = TextEditingController(
      text: prefs.getString('crm_server_url') ?? AppConfig.serverUrl,
    );
    String? error;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: const Text('Общий CRM-сервер'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Введите URL опубликованного Web app из Google Apps Script. Это публичный адрес приложения, но доступ к CRM защищён персональным PIN и сессией.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'HTTPS URL CRM-сервера',
                    hintText: 'https://script.google.com/macros/s/…/exec',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final endpoint = Uri.tryParse(controller.text.trim());
                if (endpoint == null || endpoint.scheme != 'https') {
                  refresh(() => error = 'Укажите корректный HTTPS URL.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      await prefs.setString('crm_server_url', controller.text.trim());
      if (!mounted) return;
      setState(() {
        _authLoading = true;
        _authError = null;
        _session = null;
      });
      await _initializeAuth();
    }
    controller.dispose();
  }

  void _applyServerSession(CrmSession session) {
    currentUserId = session.user.id;
    currentRole = session.user.role;
    userProfiles = _serverUsers
        .map(
          (user) => UserProfile(
            id: user.id,
            name: user.name,
            role: user.role,
            active: user.active,
            permissions: user.permissions,
          ),
        )
        .toList();
    final configuration = session.configuration;
    _serverConfigurationInitialized =
        configuration.containsKey('dataSources') ||
        configuration.containsKey('messengers') ||
        configuration.containsKey('avitoAccounts');
    final sheetUrl = configuration['sheetUrl']?.toString() ?? '';
    if (sheetUrl.isNotEmpty) sheetController.text = sheetUrl;
    final configuredSources = configuration['dataSources'];
    if (configuredSources is Map) {
      final nextSources = Map<String, String>.from(dataSources);
      configuredSources.forEach((key, value) {
        final source = value.toString().trim();
        if (source.isNotEmpty) nextSources[key.toString()] = source;
      });
      dataSources = nextSources;
    }
    final configuredMessengers = configuration['messengers'];
    if (configuredMessengers is Map) {
      configuredMessengers.forEach((key, value) {
        if (messengerConnected.containsKey(key.toString()) && value == true) {
          messengerConnected[key.toString()] = true;
          messengerStatus[key.toString()] = 'Подключён через CRM-сервер';
        }
      });
    }
    final configuredAccounts = configuration['messengerAccounts'];
    if (configuredAccounts is Map) {
      configuredAccounts.forEach((key, value) {
        final channel = key.toString();
        if (messengerConnected.containsKey(channel) &&
            value.toString().trim().isNotEmpty) {
          unawaited(
            prefs.setString('messenger_${channel}_account', value.toString()),
          );
        }
      });
    }
    final configuredVkPeer = configuration['vkNotificationPeer']
        ?.toString()
        .trim();
    if (configuredVkPeer != null && configuredVkPeer.isNotEmpty) {
      unawaited(prefs.setString('messenger_vk_notify_peer', configuredVkPeer));
    }
    final configuredAvito = configuration['avitoAccounts'];
    if (configuredAvito is List && configuredAvito.isNotEmpty) {
      avitoAccounts = configuredAvito
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    syncEndpoint = _serverEndpoint?.toString() ?? syncEndpoint;
    syncToken = session.token;
  }

  String _dataSource(String key, String fallback) =>
      dataSources[key]?.trim().isNotEmpty == true
      ? dataSources[key]!.trim()
      : fallback;

  bool get _usesGoogleCalendar =>
      _dataSource('appointments', 'CRM_Appointments').toLowerCase() ==
          'google_calendar' &&
      calendarAccessToken != null;

  Future<void> _login(String userId, String pin) async {
    final service = _authService;
    if (service == null) return;
    try {
      final session = await service.login(userId: userId, pin: pin);
      _serverUsers = await service.listUsers();
      await secretStore.write('crm_session_token', session.token);
      await prefs.setString('crm_current_user', session.user.id);
      if (!mounted) return;
      setState(() {
        _authError = null;
        _session = session;
        _applyServerSession(session);
      });
      await _saveUserProfiles();
      // На первом входе _loadPrefs завершился на экране PIN. После успешной
      // авторизации восстанавливаем кэш, очередь и общее рабочее пространство.
      await _loadPrefs();
      if (!mounted) return;
      setState(() => _applyServerSession(session));
      if (messengerConnected['vk'] == true) {
        unawaited(_loadVkConversations(silent: true));
      }
      _audit('Вход в CRM', 'Сессия', session.user.name);
    } catch (error) {
      if (mounted) setState(() => _authError = _safeAuthError(error));
    }
  }

  Future<void> _switchUser() async {
    final token = _session?.token;
    if (token != null && _authService != null) {
      try {
        await _authService!.logout(token);
      } catch (_) {
        // Logout is best effort; local token is still removed.
      }
    }
    await secretStore.delete('crm_session_token');
    if (!mounted) return;
    setState(() {
      _session = null;
      _authError = null;
    });
    if (_authService == null) await _configureServer();
  }

  Future<void> _confirmLogout() async {
    final name =
        _session?.user.name ?? currentUser?.name ?? 'текущего пользователя';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: Text(
          'Сессия пользователя «$name» будет завершена на этом компьютере. '
          'Для следующего входа потребуется личный PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _switchUser();
  }

  Future<void> _setupSyncEndpoint() async {
    if (!canManageIntegrations || _session == null) return;
    final endpoint = TextEditingController(text: syncEndpoint);
    // Сессионный токен не редактируется вручную: он выдаётся после PIN-входа.
    final token = TextEditingController();
    String? validationError;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: const Text('Защищённая синхронизация'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'URL должен вести на ваш HTTPS endpoint. Токен хранится в защищённом хранилище системы и не попадает в резервные копии.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: endpoint,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'HTTPS endpoint',
                    hintText: 'https://script.google.com/macros/s/…/exec',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: token,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Сессия общей CRM',
                    helperText:
                        'Токен выдаётся автоматически после входа по PIN.',
                  ),
                ),
                if (validationError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    validationError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final uri = Uri.tryParse(endpoint.text.trim());
                if (uri == null || uri.scheme != 'https') {
                  refresh(
                    () => validationError = 'Укажите корректный HTTPS URL',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final endpointValue = endpoint.text.trim();
      if (!mounted) {
        endpoint.dispose();
        token.dispose();
        return;
      }
      setState(() {
        syncEndpoint = endpointValue;
        pendingChangesSyncError = null;
      });
      await prefs.setString('crm_server_url', endpointValue);
      await _migrateLocalConfiguration(clearLocalSecrets: false);
      unawaited(_syncPendingChanges(silent: true));
    }
    endpoint.dispose();
    token.dispose();
  }

  Future<void> _migrateLocalConfiguration({
    required bool clearLocalSecrets,
    bool silent = false,
  }) async {
    final service = _authService;
    final session = _session;
    if (service == null || session == null) return;
    final configuration = <String, dynamic>{
      'sheetUrl': sheetController.text.trim(),
      'dataSources': dataSources,
      'syncToken': syncToken,
      'calendarAccessToken': calendarAccessToken ?? '',
      'calendarRefreshToken': calendarRefreshToken ?? '',
      'calendarClientSecret': calendarClientSecret,
      'calendarId': calendarId,
      'calendarName': calendarName,
      'aiApiKey': aiApiKey,
      'aiSettings': aiSettings.toJson(),
      'messengerTokens': messengerSecrets,
      'messengers': messengerConnected,
      'messengerAccounts': {
        for (final channel in messengerConnected.keys)
          channel: prefs.getString('messenger_${channel}_account') ?? '',
      },
      'vkNotificationPeer': prefs.getString('messenger_vk_notify_peer') ?? '',
      'avitoAccounts': avitoAccounts,
    };
    try {
      final response = await service.migrateConfiguration(
        session.token,
        configuration,
      );
      final serverConfig = response['configuration'] is Map
          ? Map<String, dynamic>.from(response['configuration'])
          : const <String, dynamic>{};
      if (serverConfig['sheetUrl']?.toString().isNotEmpty == true) {
        sheetController.text = serverConfig['sheetUrl'].toString();
      }
      final configuredSources = serverConfig['dataSources'];
      if (configuredSources is Map) {
        dataSources = configuredSources.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
      if (clearLocalSecrets) await _clearLocalIntegrationSecrets();
      _serverConfigurationInitialized = true;
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              clearLocalSecrets
                  ? 'Ключи перенесены в общий CRM-сервер и удалены с этого компьютера.'
                  : 'Общая конфигурация CRM сохранена на сервере.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_safeAuthError(error))));
      }
    }
  }

  Future<void> _clearLocalIntegrationSecrets() async {
    for (final key in [
      'sync_token',
      'calendar_access_token',
      'calendar_refresh_token',
      'calendar_client_secret',
      'ai_api_key',
      'avito_accounts',
      'messenger_telegram_token',
      'messenger_vk_token',
      'messenger_instagram_token',
    ]) {
      await secretStore.delete(key);
    }
    messengerSecrets.clear();
    aiApiKey = '';
    calendarAccessToken = null;
    calendarRefreshToken = null;
    calendarClientSecret = '';
    avitoAccounts = avitoAccounts.map((account) {
      final copy = Map<String, dynamic>.from(account);
      copy.remove('clientSecret');
      return copy;
    }).toList();
    await prefs.remove('avito_client_secret');
    await prefs.setBool('crm_server_managed_secrets', true);
  }

  final pages = crmPages;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apiClient = ApiClient(
      timeout: AppConstants.networkTimeout,
      defaultCancellation: _lifecycleCancellation,
    );
    _loadPrefs();
    unawaited(_refreshAvitoAudioCacheUsage());
    avitoAudioPositionSubscription = avitoAudioPlayer.positionStream.listen((
      position,
    ) {
      if (mounted) setState(() => avitoAudioPosition = position);
    });
    avitoAudioStateSubscription = avitoAudioPlayer.playerStateStream.listen((
      state,
    ) {
      if (!mounted) return;
      setState(() {
        avitoAudioPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          avitoAudioPlaying = false;
          avitoAudioPosition = avitoAudioDuration;
        }
      });
    });
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
    pendingMessageTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _retryPendingMessages(),
    );
    pendingChangesSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (localChangeQueue.hasRetryableItems(DateTime.now())) {
        unawaited(_syncPendingChanges(silent: true, respectBackoff: true));
      }
    });
    workspaceRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_refreshWorkspaceFromCloud());
    });
    appointmentReminderTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_sendScheduledAppointmentReminders()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleCancellation.cancel();
    _dealsCancellation?.cancel();
    _accountingCancellation?.cancel();
    clock?.cancel();
    pendingMessageTimer?.cancel();
    pendingChangesSyncTimer?.cancel();
    workspaceRefreshTimer?.cancel();
    appointmentReminderTimer?.cancel();
    avitoAudioPositionSubscription?.cancel();
    avitoAudioStateSubscription?.cancel();
    avitoAudioPlayer.dispose();
    avitoReplyController.dispose();
    vkReplyController.dispose();
    telegramReplyController.dispose();
    instagramReplyController.dispose();
    messagesSearchController.dispose();
    crmSearchController.dispose();
    sheetController.dispose();
    crmSearchDebounce?.cancel();
    messagesSearchDebounce?.cancel();
    stockSearchDebounce?.cancel();
    calendarSearchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshWorkspaceFromCloud());
    }
  }

  Future<void> _loadPrefs() async {
    prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedTheme = prefs.getBool('dark_mode') ?? false;
    if (savedTheme != widget.darkMode) widget.onThemeChanged(savedTheme);
    // При входе через общий CRM-сервер ключи интеграций остаются только на
    // сервере. Не трогаем локальную связку ключей при каждом запуске — это
    // исключает лишний системный запрос macOS и не выдаёт секреты сотруднику.
    await _loadSecureTokens();
    if (!mounted) return;
    currentRole = prefs.getString('crm_role') ?? 'Владелец';
    if (currentRole == 'Просмотр') currentRole = 'Только просмотр';
    const roles = {
      'Владелец',
      'Администратор',
      'Мастер',
      'Бухгалтер',
      'Только просмотр',
    };
    if (!roles.contains(currentRole)) currentRole = 'Владелец';
    try {
      final savedProfiles = prefs.getString('crm_user_profiles');
      if (savedProfiles != null) {
        final restored = (jsonDecode(savedProfiles) as List)
            .whereType<Map>()
            .map(
              (item) => UserProfile.fromJson(Map<String, dynamic>.from(item)),
            )
            .where(
              (profile) =>
                  profile.id.isNotEmpty && roles.contains(profile.role),
            )
            .toList();
        if (restored.isNotEmpty) userProfiles = restored;
      }
    } catch (_) {}
    if (!userProfiles.any((profile) => profile.role == 'Владелец')) {
      userProfiles.insert(
        0,
        UserProfile(id: 'owner', name: 'Владелец', role: 'Владелец'),
      );
    }
    currentUserId = prefs.getString('crm_current_user') ?? currentUserId;
    final selectedUser = userProfiles.cast<UserProfile?>().firstWhere(
      (profile) => profile?.id == currentUserId && profile!.active,
      orElse: () => null,
    );
    final activeUser =
        selectedUser ??
        userProfiles.firstWhere(
          (profile) => profile.active,
          orElse: () => userProfiles.first,
        );
    currentUserId = activeUser.id;
    currentRole = activeUser.role;
    await _initializeAuth();
    if (!mounted) return;
    if (_session == null) {
      preferencesLoaded = true;
      return;
    }
    try {
      final queued = prefs.getString('pending_messages');
      if (queued != null) {
        pendingMessages.addAll(
          (jsonDecode(queued) as List).whereType<Map>().map(
            (e) => preparePendingMessage(Map<String, String>.from(e)),
          ),
        );
      }
    } catch (_) {}
    try {
      final savedChanges = prefs.getString('pending_changes');
      if (savedChanges != null) {
        localChangeQueue.load(jsonDecode(savedChanges) as List);
      }
    } catch (_) {}
    try {
      final savedNotifications = prefs.getString('crm_notifications');
      if (savedNotifications != null) {
        notifications.addAll(
          (jsonDecode(savedNotifications) as List).whereType<Map>().map(
            (item) => CrmNotification.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
      }
    } catch (_) {}
    notifications.removeWhere(
      (notification) => notification.title != 'Новая запись',
    );
    await prefs.setString(
      'crm_notifications',
      jsonEncode(notifications.map((item) => item.toJson()).toList()),
    );
    final savedSync = prefs.getString('sheets_last_sync');
    if (savedSync != null) lastSheetsSync = DateTime.tryParse(savedSync);
    final savedClosedPeriods = prefs.getString('closed_accounting_periods');
    if (savedClosedPeriods != null) {
      try {
        closedAccountingPeriods.addAll(
          (jsonDecode(savedClosedPeriods) as List).whereType<Map>().map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
      } catch (_) {}
    }
    final savedClosed = prefs.getString('closed_accounting_period');
    if (savedClosed != null && closedAccountingPeriods.isEmpty) {
      try {
        closedAccountingPeriods.add(
          Map<String, dynamic>.from(jsonDecode(savedClosed)),
        );
      } catch (_) {}
    }
    if (closedAccountingPeriods.isNotEmpty) {
      closedAccountingPeriod = closedAccountingPeriods.last;
    }
    final savedServices = prefs.getStringList('available_services');
    final savedTemplates = prefs.getStringList('quick_reply_templates');
    if (savedTemplates != null && savedTemplates.isNotEmpty) {
      quickReplyTemplates = savedTemplates;
    }
    readMessageDialogs.addAll(
      prefs.getStringList('read_message_dialogs') ?? const [],
    );
    sentAppointmentReminderKeys.addAll(
      prefs.getStringList('sent_appointment_reminders') ?? const [],
    );
    try {
      final savedAssignees = prefs.getString('message_assignees');
      if (savedAssignees != null) {
        messageAssignees.addAll(
          Map<String, String>.from(jsonDecode(savedAssignees)),
        );
      }
      final savedTags = prefs.getString('message_tags');
      if (savedTags != null) {
        (jsonDecode(savedTags) as Map).forEach(
          (k, v) => messageTags[k.toString()] = (v as List)
              .map((x) => x.toString())
              .toList(),
        );
      }
    } catch (_) {}
    final savedCategories = prefs.getStringList('accounting_categories');
    if (savedCategories != null && savedCategories.isNotEmpty) {
      accountingCategories = savedCategories;
    }
    final savedSheetUrl = prefs.getString('sheet_url');
    if (savedSheetUrl != null && savedSheetUrl.isNotEmpty) {
      sheetController.text = savedSheetUrl;
    }
    try {
      final savedClients = prefs.getString('crm_clients');
      if (savedClients != null) {
        clients.addAll(
          (jsonDecode(savedClients) as List).whereType<Map>().map(
            (e) => Client.fromJson(Map<String, dynamic>.from(e)),
          ),
        );
      }
      final savedStock = prefs.getString('crm_stock');
      if (savedStock != null) {
        stockItems.addAll(
          (jsonDecode(savedStock) as List).whereType<Map>().map(
            (e) => StockItem.fromJson(Map<String, dynamic>.from(e)),
          ),
        );
      }
      final savedMoves = prefs.getString('crm_stock_movements');
      if (savedMoves != null) {
        stockMovements.addAll(
          (jsonDecode(savedMoves) as List).whereType<Map>().map(
            (e) => StockMovement.fromJson(Map<String, dynamic>.from(e)),
          ),
        );
      }
      final savedAudit = prefs.getString('crm_audit');
      if (savedAudit != null) {
        auditEntries.addAll(
          (jsonDecode(savedAudit) as List).whereType<Map>().map(
            (e) => AuditEntry.fromJson(Map<String, dynamic>.from(e)),
          ),
        );
      }
    } catch (error) {
      CrmLogger.error(
        'Не удалось прочитать локальные данные CRM: клиенты не изменены',
        error: error,
        name: 'crm.persistence',
      );
    }
    final savedTransactions = prefs.getString('business_transactions');
    if (savedTransactions != null) {
      try {
        businessTransactions = (jsonDecode(savedTransactions) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } catch (_) {}
    }
    if (savedServices != null && savedServices.isNotEmpty) {
      availableServices = savedServices;
    }
    try {
      final savedDurations = prefs.getString('service_durations');
      if (savedDurations != null) {
        serviceDurations = (jsonDecode(savedDurations) as Map).map(
          (key, value) => MapEntry(
            key.toString(),
            (value as num?)?.toDouble() ??
                double.tryParse(value.toString().replaceAll(',', '.')) ??
                0,
          ),
        )..removeWhere((_, hours) => hours <= 0);
      }
    } catch (_) {}
    try {
      final savedCatalog = prefs.getString('service_catalog');
      if (savedCatalog != null) {
        final restored = (jsonDecode(savedCatalog) as List)
            .whereType<Map>()
            .map(
              (item) =>
                  ServiceCatalogItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((item) => item.name.trim().isNotEmpty)
            .toList();
        if (restored.isNotEmpty) serviceCatalog = restored;
      }
    } catch (_) {}
    _migrateLegacyServicesToCatalog();
    try {
      final savedNotes = prefs.getString('dashboard_notes');
      if (savedNotes != null) {
        dashboardNotes.addAll(
          (jsonDecode(savedNotes) as List)
              .whereType<Map>()
              .map(
                (item) => StickyNote.fromJson(Map<String, dynamic>.from(item)),
              )
              .take(8),
        );
      }
      final savedPlans = prefs.getString('dashboard_revenue_plans');
      if (savedPlans != null) {
        revenuePlans.addAll(
          (jsonDecode(savedPlans) as List).whereType<Map>().map(
            (item) =>
                DashboardRevenuePlan.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
      }
      dashboardPeriod = prefs.getString('dashboard_period') ?? 'Все время';
      dashboardCustomFrom = DateTime.tryParse(
        prefs.getString('dashboard_period_from') ?? '',
      );
      dashboardCustomTo = DateTime.tryParse(
        prefs.getString('dashboard_period_to') ?? '',
      );
      final savedKnowledge = prefs.getString('knowledge_base');
      if (savedKnowledge != null && savedKnowledge.trim().isNotEmpty) {
        knowledgeBase = savedKnowledge;
      }
      await _syncServiceKnowledge(source: 'синхронизация справочника услуг');
      final savedKnowledgeVersions = prefs.getString('knowledge_versions');
      if (savedKnowledgeVersions != null) {
        knowledgeVersions.addAll(
          (jsonDecode(savedKnowledgeVersions) as List).whereType<Map>().map(
            (item) =>
                KnowledgeBaseVersion.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
      }
      final savedAiSettings = prefs.getString('ai_settings');
      if (savedAiSettings != null) {
        aiSettings = AiSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(savedAiSettings) as Map),
        );
      }
      final savedConversations = prefs.getString('bot_test_conversations');
      if (savedConversations != null && aiSettings.storeConversationText) {
        botConversations.addAll(
          (jsonDecode(savedConversations) as List).whereType<Map>().map(
            (item) => BotConversation.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
      }
      selectedBotConversationId = prefs.getString('bot_selected_conversation');
    } catch (error) {
      CrmLogger.error(
        'Не удалось прочитать рабочее пространство CRM',
        error: error,
        name: 'crm.workspace',
      );
    }
    calendarId = prefs.getString('calendar_id') ?? 'primary';
    calendarName = prefs.getString('calendar_name') ?? 'Основной календарь';
    try {
      final cachedCalendar = prefs.getString('calendar_events_cache');
      if (cachedCalendar != null) {
        calendarEvents = (jsonDecode(cachedCalendar) as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}
    _seenAppointmentIds.addAll(
      prefs.getStringList('seen_appointment_ids') ?? const [],
    );
    _appointmentNotificationsReady =
        prefs.getBool('appointment_notifications_ready') ?? false;
    _loadAvitoAccountsFromPrefs();
    _loadAvitoAiCache();
    await _loadSecureAvitoAccounts();
    // Сделки из листа нужны для накопительного бизнес-счёта уже на первом
    // экране. Запрос к другому листу может отменить обновление «Августа»,
    // поэтому сначала восстанавливаем последнюю подтверждённую копию, а затем
    // заменяем её свежими данными после успешной синхронизации.
    try {
      final cachedDeals = prefs.getString('cached_deals');
      if (cachedDeals != null) {
        syncedDealRows = (jsonDecode(cachedDeals) as List)
            .whereType<List>()
            .map((row) => row.map((cell) => cell.toString()).toList())
            .toList();
      }
    } catch (_) {
      // При повреждённом кэше CRM продолжит загрузку непосредственно из Sheets.
      syncedDealRows = [];
    }
    try {
      final savedManual = prefs.getString('manual_deal_rows');
      if (savedManual != null) {
        manualDealRows = (jsonDecode(savedManual) as List)
            .map((row) => (row as List).map((cell) => cell.toString()).toList())
            .toList();
        _recalculateManualDeals();
      }
    } catch (_) {
      manualDealRows = [];
    }
    // Older builds exported manual deals to Documents but could lose the
    // preferences entry during an upgrade. Recover the newest export only
    // when the persisted collection is absent/empty.
    if (manualDealRows.isEmpty) {
      await _restoreManualDealsFromExport();
    }
    // When protected cloud synchronisation is configured, operational CRM_*
    // sheets are the source of truth for a fresh computer. We never overwrite
    // a device that still has unsent local changes.
    await _restoreCloudWorkspaceIfAvailable();
    if (!mounted) return;
    setState(() {
      wrapDealText = prefs.getBool("wrap") ?? true;
      final savedWidths = prefs.getString('widths');
      if (savedWidths != null) {
        try {
          final decoded = jsonDecode(savedWidths) as Map;
          dealColWidths = decoded.map(
            (k, v) => MapEntry(int.parse(k.toString()), (v as num).toDouble()),
          );
        } catch (_) {
          dealColWidths = {};
        }
      }
      visibleDealCols =
          (prefs.getStringList("cols") ??
                  [
                    "0",
                    "1",
                    "2",
                    "4",
                    "5",
                    "6",
                    "9",
                    "11",
                    "13",
                    "12",
                    "14",
                    "15",
                    "16",
                  ])
              .map(int.parse)
              .where((index) => !_hiddenDealColumns.contains(index))
              .toSet();
      messengerConnected['telegram'] =
          prefs.getBool('messenger_telegram') ?? false;
      messengerConnected['vk'] = prefs.getBool('messenger_vk') ?? false;
      messengerConnected['instagram'] =
          prefs.getBool('messenger_instagram') ?? false;
      for (final key in messengerConnected.keys) {
        if (messengerConnected[key]!) messengerStatus[key] = 'Подключён';
      }
      avitoConnected = false;
      avitoStatus = avitoAccounts.isEmpty
          ? 'Не подключён'
          : 'Подключаю аккаунт…';
      calendarConnected = calendarAccessToken != null;
      _rebuildDealRows();
    });
    if (calendarAccessToken != null) {
      _loadCalendarList();
      _loadCalendarEvents();
    }
    if (!_serverConfigurationInitialized &&
        currentRole == 'Владелец' &&
        (calendarAccessToken != null ||
            messengerSecrets.isNotEmpty ||
            avitoAccounts.any(
              (account) =>
                  (account['clientSecret']?.toString().isNotEmpty ?? false),
            ) ||
            aiApiKey.isNotEmpty)) {
      await _migrateLocalConfiguration(clearLocalSecrets: false, silent: true);
    }
    _saveManualDeals();
    if (avitoAccounts.isNotEmpty) {
      _connectAvito(silent: true);
    }
    if (messengerConnected['vk'] == true) _loadVkConversations(silent: true);
    if (messengerConnected['telegram'] == true) {
      _loadTelegramUpdates(silent: true);
    }
    if (messengerConnected['instagram'] == true) {
      _loadInstagramConversations(silent: true);
    }
    // Load remote data only after preferences (and the configured sheet ID)
    // are ready. This avoids a first-frame race with `late SharedPreferences`.
    if (mounted) {
      await _loadDeals();
      await _loadAccounting();
      await _showOnboardingIfNeeded();
    }
    // From this point writes are safe: all persisted CRM collections have
    // been loaded and the first frame cannot overwrite them with defaults.
    _crmDataLoaded = true;
    preferencesLoaded = true;
    unawaited(_syncPendingChanges(silent: true));
    unawaited(_sendScheduledAppointmentReminders());
  }

  Future<void> _showOnboardingIfNeeded() async {
    if (prefs.getBool('onboarding_completed') == true || !mounted) return;
    final progress = OnboardingProgress(
      sheetConfigured: currentSheetId.isNotEmpty,
      calendarConfigured: calendarConnected,
      channelConfigured:
          avitoAccounts.isNotEmpty ||
          messengerConnected.values.any((value) => value),
    );
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        title: const Text('Добро пожаловать в «Чистое место»'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Подключите рабочие сервисы — затем создайте первого клиента и проведите его до оплаты.',
              ),
              const SizedBox(height: 14),
              _onboardingStep(
                done: progress.sheetConfigured,
                title: 'Google Sheets',
                subtitle: 'Источник данных и резервная синхронизация',
              ),
              _onboardingStep(
                done: progress.calendarConfigured,
                title: 'Google Календарь',
                subtitle: 'Записи, переносы и напоминания',
              ),
              _onboardingStep(
                done: progress.channelConfigured,
                title: 'Каналы сообщений',
                subtitle: 'Avito, VK, Telegram или Instagram — необязательно',
                optional: true,
              ),
              const SizedBox(height: 8),
              Text(
                'Локальные изменения сохраняются автоматически; при сбое сети показывается последняя копия данных.',
                style: TextStyle(color: _mutedTextColor, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Позже'),
          ),
          if (progress.isReadyToFinish)
            ElevatedButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Начать работу'),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(d, false);
                setState(() => selected = progress.nextPageIndex);
              },
              icon: const Icon(Icons.arrow_forward),
              label: Text(progress.nextStep),
            ),
        ],
      ),
    );
    if (completed == true) await prefs.setBool('onboarding_completed', true);
  }

  Widget _onboardingStep({
    required bool done,
    required String title,
    required String subtitle,
    bool optional = false,
  }) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      done ? Icons.check_circle : Icons.radio_button_unchecked,
      color: done ? Colors.green : _mutedTextColor,
    ),
    title: Text('$title${optional ? ' · необязательно' : ''}'),
    subtitle: Text(subtitle),
  );

  Future<void> _saveServices() async {
    await prefs.setStringList('available_services', availableServices);
    await prefs.setString('service_durations', jsonEncode(serviceDurations));
    await prefs.setString(
      'service_catalog',
      jsonEncode(serviceCatalog.map((item) => item.toJson()).toList()),
    );
  }

  /// Keeps one readable Markdown section per service in the bot knowledge
  /// base. Sections are keyed by the stable service ID so renaming a service
  /// never leaves stale rules behind.
  Future<void> _syncServiceKnowledge({
    String source = 'справочник услуг',
    bool sync = true,
  }) async {
    var updated = knowledgeBase;
    for (final item in serviceCatalog) {
      final marker = RegExp.escape(item.id);
      final sectionPattern = RegExp(
        '<!-- service:$marker -->[\\s\\S]*?<!-- /service:$marker -->\\s*',
      );
      if (item.archived) {
        updated = updated.replaceAll(sectionPattern, '');
        continue;
      }
      final instructions = item.botInstructions.trim().isEmpty
          ? '- Дополнительные правила для этой услуги не заданы.'
          : item.botInstructions
                .trim()
                .split(RegExp(r'[\\r\\n]+'))
                .map(
                  (line) => line.trim().startsWith('-')
                      ? line.trim()
                      : '- ${line.trim()}',
                )
                .where((line) => line.trim() != '-')
                .join('\n');
      final section =
          '''<!-- service:${item.id} -->
## Услуга: ${item.name}
- Категория: ${item.category}
- Длительность: ${item.durationHours.toStringAsFixed(1)} ч
### Правила ответа по услуге
$instructions
<!-- /service:${item.id} -->
''';
      if (sectionPattern.hasMatch(updated)) {
        updated = updated.replaceFirst(sectionPattern, section);
      } else {
        updated = '${updated.trim()}\n\n$section';
      }
    }
    if (updated == knowledgeBase) return;
    knowledgeBase = updated.trim();
    await _saveKnowledgeBase(source: source, addVersion: false, sync: sync);
  }

  void _migrateLegacyServicesToCatalog() {
    final byName = {
      for (final item in serviceCatalog) item.name.trim().toLowerCase(): item,
    };
    for (final name in availableServices) {
      final normalized = name.trim().toLowerCase();
      if (normalized.isEmpty || byName.containsKey(normalized)) continue;
      final item = ServiceCatalogItem(
        id: stableWorkspaceId('service'),
        name: name.trim(),
        durationHours: serviceDurations[name] ?? 1,
      );
      serviceCatalog.add(item);
      byName[normalized] = item;
    }
    availableServices = serviceCatalog
        .where((item) => !item.archived)
        .map((item) => item.name)
        .toList();
    serviceDurations = {
      for (final item in serviceCatalog.where((item) => !item.archived))
        item.name: item.durationHours,
    };
  }

  ServiceCatalogItem? _serviceByName(String value) {
    final wanted = value.trim().toLowerCase();
    return serviceCatalog.cast<ServiceCatalogItem?>().firstWhere(
      (item) => item?.name.trim().toLowerCase() == wanted,
      orElse: () => null,
    );
  }

  List<ServiceCatalogItem> get _activeServiceCatalog =>
      serviceCatalog.where((item) => !item.archived).toList();

  Future<void> _saveWorkspaceData({
    bool sync = true,
    String entity = 'Рабочее пространство',
    String details = 'Обновлены настройки дашборда',
  }) async {
    _workspaceSaveInProgress = true;
    try {
      await prefs.setString(
        'dashboard_notes',
        jsonEncode(dashboardNotes.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        'dashboard_revenue_plans',
        jsonEncode(revenuePlans.map((item) => item.toJson()).toList()),
      );
      await prefs.setString('dashboard_period', dashboardPeriod);
      await prefs.setString(
        'dashboard_period_from',
        dashboardCustomFrom?.toIso8601String() ?? '',
      );
      await prefs.setString(
        'dashboard_period_to',
        dashboardCustomTo?.toIso8601String() ?? '',
      );
      if (sync && _crmDataLoaded) {
        _enqueueCloudSnapshot(entity, details);
      }
    } finally {
      _workspaceSaveInProgress = false;
    }
  }

  Future<void> _saveKnowledgeBase({
    required String source,
    String comment = '',
    bool addVersion = true,
    bool sync = true,
  }) async {
    if (addVersion) {
      knowledgeVersions.add(
        KnowledgeBaseVersion(
          id: stableWorkspaceId('knowledge'),
          content: knowledgeBase,
          createdAt: DateTime.now().toIso8601String(),
          source: source,
          comment: comment,
        ),
      );
      if (knowledgeVersions.length > 30) knowledgeVersions.removeAt(0);
    }
    await prefs.setString('knowledge_base', knowledgeBase);
    await prefs.setString(
      'knowledge_versions',
      jsonEncode(knowledgeVersions.map((item) => item.toJson()).toList()),
    );
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/crm-knowledge-base.md');
      await file.writeAsString(knowledgeBase, flush: true);
    } catch (error) {
      CrmLogger.error(
        'Не удалось сохранить читаемый файл базы знаний',
        error: error,
        name: 'crm.knowledge',
      );
    }
    if (sync && _crmDataLoaded) {
      _enqueueCloudSnapshot('База знаний', 'Изменение: $source');
    }
  }

  Future<void> _saveBotConversations() async {
    if (aiSettings.storeConversationText) {
      await prefs.setString(
        'bot_test_conversations',
        jsonEncode(botConversations.map((item) => item.toJson()).toList()),
      );
    } else {
      await prefs.remove('bot_test_conversations');
    }
    if (selectedBotConversationId != null) {
      await prefs.setString(
        'bot_selected_conversation',
        selectedBotConversationId!,
      );
    } else {
      await prefs.remove('bot_selected_conversation');
    }
  }

  Map<String, dynamic> _syncPayload(String entity) => buildSyncPayload(
    entity,
    clients: clients,
    stockItems: stockItems,
    stockMovements: stockMovements,
    manualDeals: manualDealRows,
    businessTransactions: businessTransactions,
    closedPeriods: closedAccountingPeriods,
    closedPeriod: closedAccountingPeriod,
    serviceCatalog: serviceCatalog.map((item) => item.toJson()),
    stickyNotes: dashboardNotes.map((item) => item.toJson()),
    revenuePlans: revenuePlans.map((item) => item.toJson()),
    knowledgeBase: knowledgeBase,
    knowledgeVersions: knowledgeVersions.map((item) => item.toJson()),
    appointments: calendarEvents.map(Map<String, dynamic>.from),
    auditEntries: auditEntries.map((item) => item.toJson()),
    pendingMessages: pendingMessages,
    messageAssignees: messageAssignees,
    messageTags: messageTags,
    quickReplyTemplates: quickReplyTemplates,
    accountingCategories: accountingCategories,
    dashboardPeriod: dashboardPeriod,
    dashboardPeriodFrom: dashboardCustomFrom?.toIso8601String() ?? '',
    dashboardPeriodTo: dashboardCustomTo?.toIso8601String() ?? '',
  );

  void _enqueueCloudSnapshot(String entity, String details) {
    localChangeQueue.enqueue(
      entity: entity,
      details: details,
      payload: _syncPayload(entity),
    );
    unawaited(_saveCrmData());
    unawaited(_syncPendingChanges(silent: true));
  }

  String _templateDurationText(String service) {
    final hours = serviceDurations[service.trim()];
    return hours == null ? '1' : hours.toStringAsFixed(2);
  }

  bool _dashboardDealMatches(Deal deal) {
    final date = DateTime.tryParse(deal.date) ?? _parseRuDate(deal.date);
    if (date == null || dashboardPeriod == 'Все время') return true;
    if (dashboardPeriod == 'Диапазон') {
      if (dashboardCustomFrom == null || dashboardCustomTo == null) return true;
      final from = DateTime(
        dashboardCustomFrom!.year,
        dashboardCustomFrom!.month,
        dashboardCustomFrom!.day,
      );
      final to = DateTime(
        dashboardCustomTo!.year,
        dashboardCustomTo!.month,
        dashboardCustomTo!.day,
        23,
        59,
        59,
      );
      return !date.isBefore(from) && !date.isAfter(to);
    }
    final now = DateTime.now();
    if (dashboardPeriod == 'Текущий месяц') {
      return date.year == now.year && date.month == now.month;
    }
    final named = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(dashboardPeriod);
    if (named != null) {
      return date.year == int.parse(named.group(1)!) &&
          date.month == int.parse(named.group(2)!);
    }
    return true;
  }

  List<String> get _dashboardPeriods {
    final periods = <String>{'Все время', 'Текущий месяц'};
    for (final deal in typedDeals) {
      final date = DateTime.tryParse(deal.date) ?? _parseRuDate(deal.date);
      if (date != null) {
        periods.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
      }
    }
    final sorted =
        periods
            .where((value) => RegExp(r'^\d{4}-\d{2}$').hasMatch(value))
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return ['Все время', 'Текущий месяц', 'Диапазон', ...sorted];
  }

  Future<void> _selectDashboardRange() async {
    final now = DateTime.now();
    final initial = dashboardCustomFrom != null && dashboardCustomTo != null
        ? DateTimeRange(start: dashboardCustomFrom!, end: dashboardCustomTo!)
        : DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0),
          );
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initial,
    );
    if (selected == null) return;
    dashboardPeriod = 'Диапазон';
    dashboardCustomFrom = selected.start;
    dashboardCustomTo = selected.end;
    await _saveWorkspaceData();
    if (mounted) setState(() {});
  }

  double get _dashboardRevenue => typedDeals
      .where(_dashboardDealMatches)
      .fold(0, (total, deal) => total + deal.revenue);

  double _revenueForRange(DateTime from, DateTime to) => typedDeals
      .where((deal) {
        final date = DateTime.tryParse(deal.date) ?? _parseRuDate(deal.date);
        if (date == null) return false;
        return !date.isBefore(DateTime(from.year, from.month, from.day)) &&
            !date.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59));
      })
      .fold(0, (total, deal) => total + deal.revenue);

  DashboardRevenuePlan? get _activeDashboardPlan {
    if (revenuePlans.isEmpty) return null;
    final selectionFrom = _dashboardFrom ?? DateTime.now();
    final selectionTo = _dashboardTo ?? selectionFrom;
    return revenuePlans.cast<DashboardRevenuePlan?>().firstWhere(
      (plan) =>
          plan != null &&
          !DateTime(plan.to.year, plan.to.month, plan.to.day).isBefore(
            DateTime(
              selectionFrom.year,
              selectionFrom.month,
              selectionFrom.day,
            ),
          ) &&
          !DateTime(plan.from.year, plan.from.month, plan.from.day).isAfter(
            DateTime(selectionTo.year, selectionTo.month, selectionTo.day),
          ),
      orElse: () => revenuePlans.last,
    );
  }

  Future<void> _editDashboardNote([StickyNote? note]) async {
    if (!_canEdit('dashboard')) return;
    if (note == null && dashboardNotes.length >= 8) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Можно создать не больше 8 заметок')),
        );
      }
      return;
    }
    final controller = TextEditingController(text: note?.text ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note == null ? 'Новая заметка' : 'Изменить заметку'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          decoration: const InputDecoration(
            hintText: 'Позвонить клиенту, заказать материалы…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (saved != true || text.isEmpty) return;
    if (note == null) {
      dashboardNotes.add(
        StickyNote(
          id: stableWorkspaceId('note'),
          text: text,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    } else {
      note.text = text;
      note.updatedAt = DateTime.now().toIso8601String();
    }
    await _saveWorkspaceData(
      entity: 'Заметки',
      details: note == null ? 'Создана заметка' : 'Изменена заметка',
    );
    if (mounted) setState(() {});
  }

  Future<void> _deleteDashboardNote(StickyNote note) async {
    if (!_canEdit('dashboard')) return;
    dashboardNotes.removeWhere((item) => item.id == note.id);
    await _saveWorkspaceData(entity: 'Заметки', details: 'Удалена заметка');
    if (mounted) setState(() {});
  }

  Future<void> _editRevenuePlan() async {
    if (!_canEdit('finance')) return;
    final existing = _activeDashboardPlan;
    final title = TextEditingController(
      text: existing?.title ?? 'План выручки',
    );
    final target = TextEditingController(
      text: existing?.target.toStringAsFixed(0) ?? '500000',
    );
    DateTime from =
        existing?.from ??
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime to =
        existing?.to ??
        DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('План выручки'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Название плана',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: target,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Цель, ₽'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Период'),
                  subtitle: Text(
                    '${_formatCrmDate(from)} — ${_formatCrmDate(to)}',
                  ),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDateRange: DateTimeRange(start: from, end: to),
                    );
                    if (range != null) {
                      refresh(() {
                        from = range.start;
                        to = range.end;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    final amount = _num(target.text);
    final label = title.text.trim();
    title.dispose();
    target.dispose();
    if (saved != true || amount <= 0 || label.isEmpty) return;
    final next = DashboardRevenuePlan(
      id: existing?.id ?? stableWorkspaceId('revenue-plan'),
      title: label,
      target: amount,
      from: from,
      to: to,
      createdAt: existing?.createdAt ?? DateTime.now().toIso8601String(),
    );
    if (existing == null) {
      revenuePlans.add(next);
    } else {
      revenuePlans[revenuePlans.indexOf(existing)] = next;
    }
    await _saveWorkspaceData(
      entity: 'План выручки',
      details: existing == null
          ? 'Создан план выручки'
          : 'Изменён план выручки',
    );
    if (mounted) setState(() {});
  }

  BotConversation? get _selectedBotConversation =>
      botConversations.cast<BotConversation?>().firstWhere(
        (item) => item?.id == selectedBotConversationId,
        orElse: () => null,
      );

  void _createBotConversation() {
    final conversation = BotConversation(
      id: stableWorkspaceId('bot-conversation'),
      title: 'Новый тестовый диалог',
      createdAt: DateTime.now().toIso8601String(),
    );
    botConversations.add(conversation);
    selectedBotConversationId = conversation.id;
    unawaited(_saveBotConversations());
    if (mounted) setState(() {});
  }

  Future<void> _renameBotConversation(BotConversation conversation) async {
    final controller = TextEditingController(text: conversation.title);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Название тестового диалога'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      conversation.title = controller.text.trim();
      await _saveBotConversations();
      if (mounted) setState(() {});
    }
    controller.dispose();
  }

  Future<void> _deleteBotConversation(BotConversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить тестовый диалог?'),
        content: Text(
          'Диалог «${conversation.title}» будет удалён только из тестовой CRM.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    botConversations.removeWhere((item) => item.id == conversation.id);
    if (selectedBotConversationId == conversation.id) {
      selectedBotConversationId = botConversations.isEmpty
          ? null
          : botConversations.last.id;
    }
    await _saveBotConversations();
    if (mounted) setState(() {});
  }

  Future<void> _clearBotConversation(BotConversation conversation) async {
    conversation.messages.clear();
    await _saveBotConversations();
    if (mounted) setState(() {});
  }

  AiProvider get _aiProvider => aiSettings.enabled && aiApiKey.isNotEmpty
      ? OpenAiCompatibleProvider(apiKey: aiApiKey, client: _apiClient)
      : const KnowledgeBaseMockProvider();

  Future<void> _sendBotTestMessage(
    String text, {
    bool addUserMessage = true,
  }) async {
    final conversation = _selectedBotConversation;
    if (conversation == null || botRequestInProgress) return;
    if (addUserMessage) {
      conversation.messages.add(
        BotMessage(
          id: stableWorkspaceId('bot-message'),
          role: 'user',
          text: text,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }
    setState(() => botRequestInProgress = true);
    try {
      final reply = await _aiProvider.reply(
        question: text,
        knowledgeBase: knowledgeBase,
        history: conversation.messages,
        settings: aiSettings,
        cancellation: _lifecycleCancellation,
      );
      if (!mounted) return;
      final needsHuman = reply.needsHuman;
      final message = BotMessage(
        id: stableWorkspaceId('bot-message'),
        role: 'assistant',
        text: needsHuman
            ? 'Я не знаю, как на это ответить по подтверждённой базе знаний. Передаю вопрос сотруднику.'
            : reply.text,
        createdAt: DateTime.now().toIso8601String(),
        needsHuman: needsHuman,
        usedKnowledgeSections: reply.usedKnowledgeSections,
      );
      conversation.messages.add(message);
      if (needsHuman) {
        _pushNotification(
          CrmNotificationLevel.warning,
          'Бот не знает ответа',
          'Тестовый вопрос: $text',
        );
      }
    } catch (error) {
      if (!mounted) return;
      conversation.messages.add(
        BotMessage(
          id: stableWorkspaceId('bot-message'),
          role: 'assistant',
          text:
              'Не удалось получить ответ: ${CrmLogger.redact(error.toString())}',
          createdAt: DateTime.now().toIso8601String(),
          needsHuman: true,
        ),
      );
    } finally {
      if (mounted) setState(() => botRequestInProgress = false);
      await _saveBotConversations();
    }
  }

  Future<void> _retryBotReply(BotMessage message) async {
    final conversation = _selectedBotConversation;
    if (conversation == null || botRequestInProgress) return;
    final index = conversation.messages.indexWhere(
      (item) => item.id == message.id,
    );
    if (index < 1) return;
    BotMessage? question;
    for (var cursor = index - 1; cursor >= 0; cursor--) {
      if (conversation.messages[cursor].role == 'user') {
        question = conversation.messages[cursor];
        break;
      }
    }
    if (question == null) return;
    conversation.messages.removeAt(index);
    await _sendBotTestMessage(question.text, addUserMessage: false);
  }

  void _markBotReplyGood(BotMessage message) {
    _pushNotification(
      CrmNotificationLevel.success,
      'Ответ отмечен',
      'Хороший ответ сохранён в журнале теста.',
    );
  }

  Future<void> _markBotReplyBad(BotMessage message) async {
    final issue = TextEditingController();
    final expected = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Почему ответ плохой?'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: issue,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Что было неверно?',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expected,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Как нужно отвечать?',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Создать черновик правила'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        issue.text.trim().isNotEmpty &&
        expected.text.trim().isNotEmpty) {
      final question =
          _selectedBotConversation?.messages.reversed
              .firstWhere(
                (item) => item.role == 'user',
                orElse: () => BotMessage(
                  id: '',
                  role: 'user',
                  text: 'Вопрос клиента',
                  createdAt: '',
                ),
              )
              .text ??
          'Вопрос клиента';
      final proposal =
          '''\n\n## Правило из обратной связи\n- Вопрос: $question\n- Не отвечать так: ${message.text}\n- Почему неверно: ${issue.text.trim()}\n- Правильный ответ: ${expected.text.trim()}\n''';
      if (!mounted) {
        issue.dispose();
        expected.dispose();
        return;
      }
      final accept = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Добавить правило в базу знаний?'),
          content: SingleChildScrollView(child: Text(proposal)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Подтвердить'),
            ),
          ],
        ),
      );
      if (accept == true) {
        knowledgeBase += proposal;
        await _saveKnowledgeBase(
          source: 'обратная связь тест-бота',
          comment: issue.text.trim(),
        );
        if (mounted) {
          _pushNotification(
            CrmNotificationLevel.success,
            'Правило добавлено',
            'Черновик подтверждён и добавлен в базу знаний.',
          );
        }
      }
    }
    issue.dispose();
    expected.dispose();
  }

  Future<void> _editKnowledgeBase() async {
    final controller = TextEditingController(text: knowledgeBase);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('База знаний бота'),
        content: SizedBox(
          width: 760,
          height: 560,
          child: TextField(
            controller: controller,
            expands: true,
            maxLines: null,
            minLines: null,
            decoration: const InputDecoration(
              alignLabelWithHint: true,
              labelText: 'Markdown / текст базы знаний',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => unawaited(_showKnowledgeBaseVersions()),
            child: Text('История (${knowledgeVersions.length})'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить новую версию'),
          ),
        ],
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      knowledgeBase = controller.text.trim();
      await _saveKnowledgeBase(source: 'ручная правка');
      if (mounted) setState(() {});
    }
    controller.dispose();
  }

  Future<void> _analyzeAvitoForKnowledge() async {
    if (avitoAccounts.length > 1) {
      final selectedAccount = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Аккаунт Avito'),
          content: DropdownButtonFormField<String>(
            initialValue:
                activeAvitoAccountKey ?? avitoAccounts.first['key']?.toString(),
            items: avitoAccounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account['key']?.toString(),
                    child: Text(account['name']?.toString() ?? 'Аккаунт Avito'),
                  ),
                )
                .toList(),
            onChanged: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
          ],
        ),
      );
      if (selectedAccount == null) return;
      if (selectedAccount != activeAvitoAccountKey) {
        await _selectAvitoAccount(selectedAccount);
        if (!mounted) return;
      }
    }
    if (!mounted) return;
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      ),
      helpText: 'Период сообщений Avito для анализа',
    );
    if (range == null || !mounted) return;
    final proposed = <KnowledgeSuggestion>[];
    final questionPattern = RegExp(r'\?');
    final analysisMessages = <Map<String, dynamic>>[...avitoChatMessages];
    // Avito returns messages per chat. Load the currently connected account's
    // chats explicitly by button, rather than silently analyzing one open
    // conversation only. Failures are counted as skipped below.
    var skippedChats = 0;
    if (avitoUserId != null) {
      for (final chat in avitoChats.take(50)) {
        final chatId = chat['id']?.toString();
        if (chatId == null) continue;
        try {
          final response = await _avitoGet(
            Uri.https(
              'api.avito.ru',
              '/messenger/v3/accounts/$avitoUserId/chats/$chatId/messages/',
              {'limit': '100', 'offset': '0'},
            ),
            headers: _avitoHeaders(),
          );
          if (response.statusCode == 200) {
            analysisMessages.addAll(
              _avitoList(jsonDecode(response.body), ['messages']),
            );
          } else {
            skippedChats++;
          }
        } catch (_) {
          skippedChats++;
        }
      }
    }
    final uniqueMessages = <String, Map<String, dynamic>>{};
    for (final message in analysisMessages) {
      final key = message['id']?.toString() ?? jsonEncode(message);
      uniqueMessages[key] = message;
    }
    final messages = uniqueMessages.values.where((message) {
      final created = message['created'] ?? message['created_at'];
      final date = created is num
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt() * 1000)
          : DateTime.tryParse(created?.toString() ?? '');
      return date == null ||
          (!date.isBefore(range.start) &&
              !date.isAfter(range.end.add(const Duration(days: 1))));
    }).toList();
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      if (message['direction'] == 'out') continue;
      final text = _avitoText(message);
      if (!questionPattern.hasMatch(text)) continue;
      final sanitized = text.replaceAll(
        RegExp(r'\+?\d[\d\s()\-]{7,}'),
        '[телефон]',
      );
      if (sanitized.trim().isEmpty) continue;
      String answer = '';
      for (
        var responseIndex = index + 1;
        responseIndex < messages.length;
        responseIndex++
      ) {
        final candidate = messages[responseIndex];
        if (candidate['direction'] != 'out') continue;
        answer = _avitoText(
          candidate,
        ).replaceAll(RegExp(r'\+?\d[\d\s()\-]{7,}'), '[телефон]');
        break;
      }
      proposed.add(
        KnowledgeSuggestion(
          id: stableWorkspaceId('avito-suggestion'),
          question: sanitized,
          answer: answer,
          reason: answer.isEmpty
              ? 'Нет следующего ответа сотрудника — не будет добавлено в базу'
              : 'Пара вопрос–ответ из текущего загруженного чата Avito',
        ),
      );
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Предпросмотр Avito • ${activeAvitoAccountKey ?? 'текущий аккаунт'}',
        ),
        content: SizedBox(
          width: 600,
          child: proposed.isEmpty
              ? const Text(
                  'В загруженном чате за выбранный период не найдено вопросов. Откройте нужный диалог в «Сообщениях» и повторите анализ.',
                )
              : Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Обработано сообщений: ${messages.length} • вопросов: ${proposed.length} • с ответом: ${proposed.where((item) => item.answer.isNotEmpty).length} • пропущено чатов: $skippedChats',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: proposed
                            .take(20)
                            .map(
                              (item) => ListTile(
                                title: Text(item.question),
                                subtitle: Text(
                                  item.answer.isEmpty
                                      ? item.reason
                                      : 'Ответ сотрудника: ${item.answer}',
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: proposed.any((item) => item.answer.isNotEmpty)
                ? () => Navigator.pop(context, true)
                : null,
            child: const Text('Добавить подтверждённые предложения'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final known = knowledgeBase.toLowerCase();
    final confirmedItems = proposed
        .where((item) => item.answer.isNotEmpty)
        .where(
          (item) =>
              !known.contains(item.question.toLowerCase()) ||
              !known.contains(item.answer.toLowerCase()),
        )
        .toList();
    if (confirmedItems.isEmpty) {
      if (mounted) {
        _pushNotification(
          CrmNotificationLevel.info,
          'Новых знаний нет',
          'Все подтверждённые пары из выбранного чата уже есть в базе знаний.',
        );
      }
      return;
    }
    knowledgeBase +=
        '\n\n## Подтверждённые ответы из Avito\n${confirmedItems.map((item) => '- Вопрос: ${item.question}\n  Ответ: ${item.answer}').join('\n')}\n';
    await _saveKnowledgeBase(
      source: 'анализ Avito',
      comment:
          'Добавлено ${confirmedItems.length} подтверждённых пар вопрос–ответ',
    );
    if (mounted) {
      setState(() {});
      _pushNotification(
        CrmNotificationLevel.success,
        'База знаний обновлена',
        'Добавлено ${confirmedItems.length} подтверждённых ответов из Avito.',
      );
    }
  }

  Future<void> _loadSecureTokens() async {
    try {
      // После миграции общая CRM получает только сессионный токен. Ключи
      // интеграций не считываются и не возвращаются на компьютеры сотрудников.
      if (prefs.getBool('crm_server_managed_secrets') == true) return;
      final secureAccess = await secretStore.read('calendar_access_token');
      final secureRefresh = await secretStore.read('calendar_refresh_token');
      final secureCalendarClientSecret = await secretStore.read(
        'calendar_client_secret',
      );
      final secureSyncEndpoint = await secretStore.read('sync_endpoint');
      final secureSyncToken = await secretStore.read('sync_token');
      final secureAiApiKey = await secretStore.read('ai_api_key');
      if (secureAccess != null && secureAccess.isNotEmpty) {
        calendarAccessToken = secureAccess;
      }
      if (secureRefresh != null && secureRefresh.isNotEmpty) {
        calendarRefreshToken = secureRefresh;
      }
      if (secureCalendarClientSecret != null &&
          secureCalendarClientSecret.isNotEmpty) {
        calendarClientSecret = secureCalendarClientSecret;
      }
      if (secureSyncEndpoint != null && secureSyncEndpoint.isNotEmpty) {
        syncEndpoint = secureSyncEndpoint;
      } else if (AppConfig.syncEndpoint.isNotEmpty) {
        await secretStore.write('sync_endpoint', AppConfig.syncEndpoint);
      }
      if (secureSyncToken != null && secureSyncToken.isNotEmpty) {
        syncToken = secureSyncToken;
      }
      if (secureAiApiKey != null && secureAiApiKey.isNotEmpty) {
        aiApiKey = secureAiApiKey;
      }
      if (shouldMigrateSecret(secureAccess)) {
        final legacy = prefs.getString('calendar_access_token');
        if (legacy != null && legacy.isNotEmpty) {
          await secretStore.write('calendar_access_token', legacy);
          calendarAccessToken = legacy;
        }
        await prefs.remove('calendar_access_token');
      }
      if (shouldMigrateSecret(secureRefresh)) {
        final legacy = prefs.getString('calendar_refresh_token');
        if (legacy != null && legacy.isNotEmpty) {
          await secretStore.write('calendar_refresh_token', legacy);
          calendarRefreshToken = legacy;
        }
        await prefs.remove('calendar_refresh_token');
      }
      await prefs.remove('calendar_access_token');
      await prefs.remove('calendar_refresh_token');
      for (final channel in ['telegram', 'vk', 'instagram']) {
        final key = 'messenger_${channel}_token';
        final secure = await secretStore.read(key);
        final legacy = prefs.getString(key);
        final value = secure ?? legacy;
        if (value != null && value.isNotEmpty) {
          messengerSecrets[channel] = value;
          if (secure == null) await secretStore.write(key, value);
          await prefs.remove(key);
        }
      }
    } catch (error) {
      CrmLogger.error(
        'Не удалось завершить миграцию защищённых настроек',
        error: error,
        name: 'crm.security',
      );
    }
  }

  String _messengerToken(String channel) => messengerSecrets[channel] ?? '';

  Future<Map<String, dynamic>> _proxyIntegration(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final service = _authService;
    final session = _session;
    if (service == null || session == null) {
      throw StateError('Войдите в общую CRM, чтобы использовать интеграцию.');
    }
    final response = await service.proxy(session.token, {
      'action': action,
      'payload': payload,
    });
    final body = response['body'];
    if (body is! Map) {
      throw StateError('CRM-сервер вернул некорректный ответ интеграции.');
    }
    return Map<String, dynamic>.from(body);
  }

  Future<void> _saveMessageMeta({bool sync = true}) async {
    await prefs.setString('message_assignees', jsonEncode(messageAssignees));
    await prefs.setString('message_tags', jsonEncode(messageTags));
    await prefs.setStringList('quick_reply_templates', quickReplyTemplates);
    await prefs.setStringList(
      'read_message_dialogs',
      readMessageDialogs.toList(),
    );
    await prefs.setString('pending_messages', jsonEncode(pendingMessages));
    if (sync && _crmDataLoaded) {
      _enqueueCloudSnapshot('Сообщения', 'Обновлены общие настройки сообщений');
    }
  }

  Future<void> _backupLocalData() async {
    if (!_canEdit('admin')) return;
    final dir = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    final file = File(
      '${dir.path}/crm-backup-${DateTime.now().millisecondsSinceEpoch}.json',
    );
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'schemaVersion': SheetsSchema.version,
        'createdAt': DateTime.now().toIso8601String(),
        'clients': clients.map((e) => e.toJson()).toList(),
        'stock': stockItems.map((e) => e.toJson()).toList(),
        'movements': stockMovements.map((e) => e.toJson()).toList(),
        'audit': auditEntries.map((e) => e.toJson()).toList(),
        'transactions': businessTransactions,
        'manualDeals': manualDealRows,
        'closedPeriods': closedAccountingPeriods,
        'pendingChanges': localChangeQueue.toJson(),
        'settings': {
          'role': currentRole,
          'darkMode': widget.darkMode,
          'wrapDealText': wrapDealText,
          'visibleDealCols': visibleDealCols,
          'dealColWidths': dealColWidths.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
          'quickReplyTemplates': quickReplyTemplates,
          'messageAssignees': messageAssignees,
          'messageTags': messageTags,
          'availableServices': availableServices,
          'serviceDurations': serviceDurations,
          'serviceCatalog': serviceCatalog
              .map((item) => item.toJson())
              .toList(),
          'dashboardNotes': dashboardNotes
              .map((item) => item.toJson())
              .toList(),
          'revenuePlans': revenuePlans.map((item) => item.toJson()).toList(),
          'dashboardPeriod': dashboardPeriod,
          'dashboardPeriodFrom': dashboardCustomFrom?.toIso8601String(),
          'dashboardPeriodTo': dashboardCustomTo?.toIso8601String(),
          'knowledgeBase': knowledgeBase,
          'knowledgeVersions': knowledgeVersions
              .map((item) => item.toJson())
              .toList(),
          'accountingCategories': accountingCategories,
          'accountingCategoryFilter': accountingCategoryFilter,
          'sheetUrl': sheetController.text.trim(),
          'calendarId': calendarId,
          'calendarName': calendarName,
          'calendarViewMode': calendarViewMode,
          'periodFilter': periodFilter,
          'customDealFrom': customFrom?.toIso8601String(),
          'customDealTo': customTo?.toIso8601String(),
          'dealsOldestFirst': dealsOldestFirst,
          'dealsKanban': dealsKanban,
          'userProfiles': userProfiles
              .map((profile) => profile.toJson())
              .toList(),
          'currentUserId': currentUserId,
        },
      }),
      flush: true,
    );
    await temporary.rename(file.path);
    final backups =
        (await dir
              .list()
              .where(
                (e) =>
                    e.path.contains('crm-backup-') && e.path.endsWith('.json'),
              )
              .toList())
          ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in backups.skip(10)) {
      if (old.path != file.path && old is File) await old.delete();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Резервная копия сохранена: ${file.path}')),
      );
    }
  }

  Future<void> _restoreLocalData() async {
    if (!_canEdit('admin')) return;
    final dir = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    final files =
        (await dir
              .list()
              .where(
                (e) =>
                    e.path.contains('crm-backup-') && e.path.endsWith('.json'),
              )
              .toList())
          ..sort((a, b) => b.path.compareTo(a.path));
    if (files.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Резервных копий нет')));
      }
      return;
    }
    Map data;
    try {
      final raw = await File(files.first.path).readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Ожидался JSON-объект');
      data = decoded;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Последняя резервная копия повреждена')),
        );
      }
      return;
    }
    if (data['schemaVersion'] is num &&
        (data['schemaVersion'] as num).toInt() > SheetsSchema.version) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Резервная копия создана более новой версией CRM'),
          ),
        );
      }
      return;
    }
    clients
      ..clear()
      ..addAll(
        (data['clients'] as List? ?? []).whereType<Map>().map(
          (e) => Client.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    stockItems
      ..clear()
      ..addAll(
        (data['stock'] as List? ?? []).whereType<Map>().map(
          (e) => StockItem.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    stockMovements
      ..clear()
      ..addAll(
        (data['movements'] as List? ?? []).whereType<Map>().map(
          (e) => StockMovement.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    auditEntries
      ..clear()
      ..addAll(
        (data['audit'] as List? ?? []).whereType<Map>().map(
          (e) => AuditEntry.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    businessTransactions = (data['transactions'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    closedAccountingPeriods
      ..clear()
      ..addAll(
        (data['closedPeriods'] as List? ?? const []).whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    if (closedAccountingPeriods.isNotEmpty) {
      closedAccountingPeriod = closedAccountingPeriods.last;
    }
    manualDealRows = (data['manualDeals'] as List? ?? [])
        .whereType<List>()
        .map((row) => row.map((cell) => cell.toString()).toList())
        .toList();
    localChangeQueue.load(data['pendingChanges'] as List? ?? const []);
    final settings = data['settings'];
    if (settings is Map) {
      final role = settings['role']?.toString();
      const allowedRoles = {
        'Владелец',
        'Администратор',
        'Мастер',
        'Бухгалтер',
        'Только просмотр',
      };
      if (role != null && allowedRoles.contains(role)) currentRole = role;
      if (settings['darkMode'] is bool) {
        final value = settings['darkMode'] as bool;
        widget.onThemeChanged(value);
        await prefs.setBool('dark_mode', value);
      }
      if (settings['wrapDealText'] is bool) {
        wrapDealText = settings['wrapDealText'] as bool;
      }
      final savedColumns = (settings['visibleDealCols'] as List? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .toSet();
      if (savedColumns.isNotEmpty) {
        visibleDealCols = savedColumns.where((index) {
          return !_hiddenDealColumns.contains(index);
        }).toSet();
      }
      final widths = settings['dealColWidths'];
      if (widths is Map) {
        dealColWidths = widths.map(
          (key, value) => MapEntry(
            int.tryParse(key.toString()) ?? 0,
            (value as num?)?.toDouble() ?? dealColWidth,
          ),
        );
      }
      final templates = settings['quickReplyTemplates'];
      if (templates is List && templates.isNotEmpty) {
        quickReplyTemplates = templates
            .map((value) => value.toString())
            .toList();
      }
      final assignees = settings['messageAssignees'];
      if (assignees is Map) {
        messageAssignees
          ..clear()
          ..addAll(
            assignees.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
          );
      }
      final tags = settings['messageTags'];
      if (tags is Map) {
        messageTags
          ..clear()
          ..addAll(
            tags.map(
              (key, value) => MapEntry(
                key.toString(),
                (value as List? ?? const [])
                    .map((tag) => tag.toString())
                    .toList(),
              ),
            ),
          );
      }
      final restoredServices = settings['availableServices'];
      if (restoredServices is List && restoredServices.isNotEmpty) {
        availableServices = restoredServices
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();
      }
      final restoredDurations = settings['serviceDurations'];
      if (restoredDurations is Map) {
        serviceDurations = restoredDurations.map(
          (key, value) => MapEntry(
            key.toString(),
            (value as num?)?.toDouble() ??
                double.tryParse(value.toString().replaceAll(',', '.')) ??
                0,
          ),
        )..removeWhere((_, hours) => hours <= 0);
      }
      final restoredCatalog = settings['serviceCatalog'];
      if (restoredCatalog is List) {
        final catalog = restoredCatalog
            .whereType<Map>()
            .map(
              (item) =>
                  ServiceCatalogItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((item) => item.name.trim().isNotEmpty)
            .toList();
        if (catalog.isNotEmpty) serviceCatalog = catalog;
      }
      final restoredNotes = settings['dashboardNotes'];
      if (restoredNotes is List) {
        dashboardNotes
          ..clear()
          ..addAll(
            restoredNotes
                .whereType<Map>()
                .map(
                  (item) =>
                      StickyNote.fromJson(Map<String, dynamic>.from(item)),
                )
                .take(8),
          );
      }
      final restoredPlans = settings['revenuePlans'];
      if (restoredPlans is List) {
        revenuePlans
          ..clear()
          ..addAll(
            restoredPlans.whereType<Map>().map(
              (item) => DashboardRevenuePlan.fromJson(
                Map<String, dynamic>.from(item),
              ),
            ),
          );
      }
      final restoredDashboardPeriod = settings['dashboardPeriod']?.toString();
      if (restoredDashboardPeriod != null &&
          restoredDashboardPeriod.isNotEmpty) {
        dashboardPeriod = restoredDashboardPeriod;
      }
      dashboardCustomFrom = DateTime.tryParse(
        settings['dashboardPeriodFrom']?.toString() ?? '',
      );
      dashboardCustomTo = DateTime.tryParse(
        settings['dashboardPeriodTo']?.toString() ?? '',
      );
      final restoredKnowledgeBase = settings['knowledgeBase']?.toString();
      if (restoredKnowledgeBase != null &&
          restoredKnowledgeBase.trim().isNotEmpty) {
        knowledgeBase = restoredKnowledgeBase;
      }
      final restoredKnowledgeVersions = settings['knowledgeVersions'];
      if (restoredKnowledgeVersions is List) {
        knowledgeVersions
          ..clear()
          ..addAll(
            restoredKnowledgeVersions.whereType<Map>().map(
              (item) => KnowledgeBaseVersion.fromJson(
                Map<String, dynamic>.from(item),
              ),
            ),
          );
      }
      _migrateLegacyServicesToCatalog();
      final restoredCategories = settings['accountingCategories'];
      if (restoredCategories is List && restoredCategories.isNotEmpty) {
        accountingCategories = restoredCategories
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();
      }
      final categoryFilter = settings['accountingCategoryFilter']?.toString();
      if (categoryFilter != null &&
          (categoryFilter == 'Все категории' ||
              accountingCategories.contains(categoryFilter))) {
        accountingCategoryFilter = categoryFilter;
      }
      final restoredSheetUrl = settings['sheetUrl']?.toString().trim();
      if (restoredSheetUrl != null && restoredSheetUrl.isNotEmpty) {
        sheetController.text = restoredSheetUrl;
      }
      final restoredCalendarId = settings['calendarId']?.toString().trim();
      if (restoredCalendarId != null && restoredCalendarId.isNotEmpty) {
        calendarId = restoredCalendarId;
      }
      final restoredCalendarName = settings['calendarName']?.toString().trim();
      if (restoredCalendarName != null && restoredCalendarName.isNotEmpty) {
        calendarName = restoredCalendarName;
      }
      const calendarModes = {'Месяц', 'Неделя', 'День', 'Список'};
      final restoredCalendarMode = settings['calendarViewMode']?.toString();
      if (restoredCalendarMode != null &&
          calendarModes.contains(restoredCalendarMode)) {
        calendarViewMode = restoredCalendarMode;
      }
      const periodFilters = {'Август', 'Неделя', 'Месяц', 'Диапазон', 'Все'};
      final restoredPeriodFilter = settings['periodFilter']?.toString();
      if (restoredPeriodFilter != null &&
          periodFilters.contains(restoredPeriodFilter)) {
        periodFilter = restoredPeriodFilter;
      }
      customFrom = DateTime.tryParse(
        settings['customDealFrom']?.toString() ?? '',
      );
      customTo = DateTime.tryParse(settings['customDealTo']?.toString() ?? '');
      if (settings['dealsOldestFirst'] is bool) {
        dealsOldestFirst = settings['dealsOldestFirst'] as bool;
      }
      if (settings['dealsKanban'] is bool) {
        dealsKanban = settings['dealsKanban'] as bool;
      }
      final profiles = settings['userProfiles'];
      if (profiles is List) {
        final restored = profiles
            .whereType<Map>()
            .map(
              (item) => UserProfile.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((profile) => profile.id.isNotEmpty)
            .toList();
        if (restored.isNotEmpty) userProfiles = restored;
      }
      final restoredUserId = settings['currentUserId']?.toString();
      if (restoredUserId != null &&
          userProfiles.any((profile) => profile.id == restoredUserId)) {
        currentUserId = restoredUserId;
        currentRole = userProfiles
            .firstWhere((profile) => profile.id == currentUserId)
            .role;
      }
    }
    _rebuildDealRows();
    await _saveUserProfiles();
    await prefs.setString(
      'closed_accounting_periods',
      jsonEncode(closedAccountingPeriods),
    );
    if (closedAccountingPeriod != null) {
      await prefs.setString(
        'closed_accounting_period',
        jsonEncode(closedAccountingPeriod),
      );
    }
    await _savePrefs();
    await _saveServices();
    await _saveAccountingCategories();
    await _saveMessageMeta();
    await prefs.setString('sheet_url', sheetController.text.trim());
    await prefs.setString('calendar_id', calendarId);
    await prefs.setString('calendar_name', calendarName);
    await _saveCrmData();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Восстановлена копия: ${files.first.path}')),
      );
    }
  }

  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    int attempts = 3,
  }) async {
    Object? last;
    for (var i = 0; i < attempts; i++) {
      try {
        return await operation();
      } catch (e) {
        last = e;
        if (i + 1 < attempts) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (i + 1)));
        }
      }
    }
    throw last ?? Exception('Операция не выполнена');
  }

  Future<void> _retryPendingMessages() async {
    if (pendingMessages.isEmpty ||
        !_canEdit('messages') ||
        pendingMessagesRetrying) {
      return;
    }
    pendingMessagesRetrying = true;
    try {
      final queue = List<Map<String, String>>.from(pendingMessages);
      for (final item in queue) {
        final attemptTime = DateTime.now();
        if (!isPendingRetryReady(item, attemptTime)) continue;
        markPendingAttempt(item, attemptTime);
        await _saveMessageMeta();
        try {
          if (item['channel'] == 'vk') {
            final data = await _withRetry(
              () => _vkRequest('messages.send', {
                'peer_id': item['peer'] ?? '',
                'random_id': item['vkRandomId'] ?? '',
                'message': item['text'] ?? '',
              }),
            );
            if (data['error'] != null) {
              throw Exception('VK не принял сообщение');
            }
          } else if (item['channel'] == 'telegram') {
            final token = _messengerToken('telegram');
            if (token.isEmpty) throw Exception('Telegram не подключён');
            final response = await _withRetry(
              () => _apiClient.post(
                Uri.https('api.telegram.org', '/bot$token/sendMessage'),
                body: {
                  'chat_id': item['chat'] ?? '',
                  'text': item['text'] ?? '',
                },
                retries: 0,
              ),
            );
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            if (data['ok'] != true) {
              throw Exception('Telegram не принял сообщение');
            }
          } else if (item['channel'] == 'avito') {
            final accountId = item['account'] ?? avitoUserId ?? '';
            if (accountId.isEmpty) {
              throw Exception('Avito аккаунт не подключён');
            }
            final response = await _withRetry(
              () => _avitoPost(
                Uri.parse(
                  'https://api.avito.ru/messenger/v1/accounts/$accountId/chats/${item['chat']}/messages',
                ),
                headers: _avitoHeaders(),
                body: jsonEncode({
                  'type': 'text',
                  'message': {'text': item['text'] ?? ''},
                }),
              ),
            );
            if (response.statusCode < 200 || response.statusCode >= 300) {
              throw Exception('Avito не принял сообщение');
            }
          } else if (item['channel'] == 'instagram') {
            final token = _messengerToken('instagram');
            final account =
                prefs.getString('messenger_instagram_account') ?? '';
            final recipient = item['chat'] ?? '';
            if (token.isEmpty || account.isEmpty || recipient.isEmpty) {
              throw Exception('Instagram не подключён');
            }
            final response = await _withRetry(
              () => _apiClient.post(
                Uri.https('graph.facebook.com', '/v20.0/$account/messages', {
                  'access_token': token,
                }),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'recipient': {'id': recipient},
                  'message': {'text': item['text'] ?? ''},
                }),
                retries: 0,
              ),
            );
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            if (response.statusCode < 200 ||
                response.statusCode >= 300 ||
                data['error'] != null) {
              throw Exception('Instagram не принял сообщение');
            }
          } else {
            throw Exception('Неизвестный канал отправки');
          }
          pendingMessages.removeWhere((queued) => queued['id'] == item['id']);
        } catch (_) {
          // Оставляем элемент в очереди с тем же идентификатором доставки.
        }
      }
      if (pendingMessages.isNotEmpty) {
        if (mounted) setState(() {});
      }
      await _saveMessageMeta();
    } finally {
      pendingMessagesRetrying = false;
    }
  }

  Future<void> _enqueuePendingMessage(Map<String, String> message) async {
    final prepared = preparePendingMessage(message);
    if (!isSupportedOutgoingChannel(prepared['channel'])) {
      CrmLogger.error(
        'Очередь: неизвестный канал отправки',
        name: 'crm.messages',
      );
      _pushNotification(
        CrmNotificationLevel.error,
        'Сообщение не поставлено в очередь',
        'Неизвестный канал отправки.',
      );
      return;
    }
    final duplicate = pendingMessages.any(
      (item) => isSamePendingDelivery(item, prepared),
    );
    if (!duplicate) pendingMessages.add(prepared);
    await _saveMessageMeta();
  }

  Future<void> _saveAccountingCategories({bool sync = true}) async {
    await prefs.setStringList('accounting_categories', accountingCategories);
    if (sync && _crmDataLoaded) {
      _enqueueCloudSnapshot('Бухгалтерия', 'Обновлены категории бухгалтерии');
    }
  }

  Future<void> _saveCrmData() async {
    if (!_crmDataLoaded) {
      CrmLogger.debug(
        'Пропущено раннее сохранение CRM до завершения загрузки',
        name: 'crm.persistence',
      );
      return;
    }
    // Keep a one-step recovery copy if a transient load/parse problem would
    // otherwise replace a populated client list with an empty one.
    final previousClients = prefs.getString('crm_clients');
    final nextClients = jsonEncode(clients.map((e) => e.toJson()).toList());
    if (clients.isEmpty &&
        previousClients != null &&
        previousClients.trim().isNotEmpty &&
        previousClients.trim() != '[]') {
      await prefs.setString('crm_clients_previous', previousClients);
      await prefs.setString(
        'crm_clients_previous_at',
        DateTime.now().toIso8601String(),
      );
    }
    await prefs.setString('crm_clients', nextClients);
    await prefs.setString(
      'crm_stock',
      jsonEncode(stockItems.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'crm_stock_movements',
      jsonEncode(stockMovements.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'crm_audit',
      jsonEncode(auditEntries.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'pending_changes',
      jsonEncode(localChangeQueue.toJson()),
    );
    await _saveWorkspaceData(sync: false);
    await _saveKnowledgeBase(
      source: 'Автоматическое сохранение',
      addVersion: false,
      sync: false,
    );
    await _saveBotConversations();
  }

  void _pushNotification(
    CrmNotificationLevel level,
    String title,
    String message,
  ) {
    CrmLogger.debug('$title: $message', name: 'crm.notification');
  }

  void _pushIncomingAppointmentNotification(Map<String, dynamic> event) {
    notifications.insert(
      0,
      CrmNotification(
        id: 'notification-${DateTime.now().microsecondsSinceEpoch}',
        title: 'Новая запись',
        message: CrmLogger.redact(
          '${event['summary']?.toString().trim().isNotEmpty == true ? event['summary'] : 'Без названия'} · ${_eventTime(event)}',
        ),
        level: CrmNotificationLevel.info,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    if (notifications.length > 100) {
      notifications.removeRange(100, notifications.length);
    }
    if (mounted) setState(() {});
    unawaited(
      prefs.setString(
        'crm_notifications',
        jsonEncode(notifications.map((item) => item.toJson()).toList()),
      ),
    );
  }

  Future<void> _recordIncomingAppointments(
    Iterable<Map<String, dynamic>> events,
  ) async {
    final received = events
        .where((event) => event['id']?.toString().trim().isNotEmpty == true)
        .toList(growable: false);
    if (!_appointmentNotificationsReady) {
      _seenAppointmentIds.addAll(
        received.map((event) => event['id'].toString()),
      );
      _appointmentNotificationsReady = true;
    } else {
      for (final event in received) {
        final id = event['id'].toString();
        if (_seenAppointmentIds.add(id)) {
          final private =
              ((event['extendedProperties'] as Map?)?['private'] as Map?) ??
              const {};
          if (private['createdBy']?.toString() != currentUserId) {
            _pushIncomingAppointmentNotification(event);
          }
        }
      }
    }
    if (_seenAppointmentIds.length > 500) {
      final idsToRemove = _seenAppointmentIds
          .take(_seenAppointmentIds.length - 500)
          .toList(growable: false);
      _seenAppointmentIds.removeAll(idsToRemove);
    }
    await prefs.setStringList(
      'seen_appointment_ids',
      _seenAppointmentIds.toList(),
    );
    await prefs.setBool('appointment_notifications_ready', true);
  }

  Future<void> _showNotificationCenter() async {
    if (notifications.any((item) => !item.read)) {
      for (final item in notifications) {
        item.read = true;
      }
      await prefs.setString(
        'crm_notifications',
        jsonEncode(notifications.map((item) => item.toJson()).toList()),
      );
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => NotificationCenterDialog(
        notifications: notifications,
        onClear: () async {
          notifications.clear();
          await prefs.remove('crm_notifications');
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _exportPendingChanges() async {
    if (localChangeQueue.items.isEmpty) return;
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/crm-pending-changes-${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(localChangeQueue.toJson()),
      flush: true,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Очередь изменений сохранена: ${file.path}')),
      );
    }
  }

  Future<void> _syncPendingChanges({
    bool silent = false,
    bool respectBackoff = false,
  }) async {
    if (localChangeQueue.items.isEmpty || pendingChangesSyncing) return;
    const invalidChangeMessage =
        'Повреждённое локальное изменение не отправлено. Экспортируйте очередь для восстановления.';
    final invalidChanges = localChangeQueue.invalidTransportItems.toList();
    if (invalidChanges.isNotEmpty) {
      localChangeQueue.markTransportValidationError(
        invalidChanges.map((item) => item.id),
        invalidChangeMessage,
      );
      await _saveCrmData();
      if (mounted) {
        setState(() => pendingChangesSyncError = invalidChangeMessage);
        if (!silent) {
          _pushNotification(
            CrmNotificationLevel.warning,
            'Требуется восстановление очереди',
            '$invalidChangeMessage Некорректных записей: ${invalidChanges.length}.',
          );
        }
      }
    }
    final candidates = localChangeQueue.items
        .where(SyncQueue.isTransportReady)
        .where(
          (item) =>
              !respectBackoff ||
              SyncQueue.isReadyForRetry(item, DateTime.now()),
        )
        .toList(growable: false);
    if (candidates.isEmpty) return;
    final endpoint = Uri.tryParse(syncEndpoint);
    if (endpoint == null || syncToken.trim().isEmpty) {
      if (!silent && mounted) {
        _pushNotification(
          CrmNotificationLevel.warning,
          'Синхронизация не настроена',
          'Укажите HTTPS endpoint и токен в настройках.',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Синхронизация недоступна: войдите в общую CRM.'),
          ),
        );
      }
      return;
    }
    final batch = ChangesSyncRepository.nextBatch(candidates);
    final ids = batch.map((item) => item.id).toList();
    if (mounted) {
      setState(() {
        pendingChangesSyncing = true;
        pendingChangesSyncError = invalidChanges.isEmpty
            ? null
            : invalidChangeMessage;
      });
    }
    try {
      final result = await ChangesSyncRepository(
        endpoint: endpoint,
        token: syncToken,
      ).push(batch, cancellation: _lifecycleCancellation);
      if (result.acceptedIds.isEmpty) {
        throw StateError('Сервер не подтвердил ни одного изменения');
      }
      localChangeQueue.removeAccepted(result.acceptedIds);
      await _saveCrmData();
      CrmLogger.info(
        'Подтверждено изменений: ${result.acceptedIds.length}',
        name: 'crm.sync',
      );
      if (!mounted) return;
      setState(() => lastPendingChangesSync = DateTime.now());
      unawaited(_refreshWorkspaceFromCloud());
      _pushNotification(
        CrmNotificationLevel.success,
        'Синхронизация завершена',
        'Подтверждено изменений: ${result.acceptedIds.length}',
      );
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Синхронизировано: ${result.acceptedIds.length}'),
          ),
        );
      }
    } on RequestCancelledException {
      // Закрытие окна отменяет сетевой запрос, но не является неудачной
      // синхронизацией: запись остаётся в очереди без искусственной задержки.
      return;
    } catch (error) {
      final safeError = CrmLogger.redact(error.toString());
      localChangeQueue.markAttempt(ids, error: safeError);
      await _saveCrmData();
      CrmLogger.error('Ошибка синхронизации: $safeError', name: 'crm.sync');
      if (!mounted) return;
      final newError = pendingChangesSyncError != safeError;
      setState(() => pendingChangesSyncError = safeError);
      if (newError) {
        _pushNotification(
          CrmNotificationLevel.error,
          'Ошибка синхронизации',
          safeError,
        );
      }
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Изменения остались в очереди: $safeError')),
        );
      }
    } finally {
      if (mounted) setState(() => pendingChangesSyncing = false);
    }
  }

  void _audit(String action, String entity, [String details = '']) {
    auditEntries.add(
      AuditEntry(
        action: action,
        entity: entity,
        details: details,
        date: DateTime.now().toIso8601String(),
        actor: currentUser?.name ?? currentRole,
      ),
    );
    if (auditEntries.length > AppConstants.maxAuditEntries) {
      auditEntries.removeRange(
        0,
        auditEntries.length - AppConstants.maxAuditEntries,
      );
    }
    localChangeQueue.enqueue(
      entity: entity,
      details: '$action: $details',
      payload: _syncPayload(entity),
    );
    _saveCrmData();
    unawaited(_syncPendingChanges(silent: true));
  }

  String _upsertClient({
    required String name,
    required String phone,
    required String car,
    String source = '',
    String note = '',
  }) {
    final normalized = normalizePhone(phone);
    Client? client;
    if (normalized.isNotEmpty) {
      for (final item in clients) {
        if (normalizePhone(item.phone) == normalized ||
            item.phones.any((value) => normalizePhone(value) == normalized)) {
          client = item;
          break;
        }
      }
    }
    client ??= clients.firstWhere(
      (x) =>
          x.name.trim().toLowerCase() == name.trim().toLowerCase() &&
          name.trim().isNotEmpty,
      orElse: () => Client(
        id: stableClientId(phone: phone, name: name),
        name: name.trim(),
      ),
    );
    client.name = name.trim();
    client.phone = phone.trim();
    client.car = car.trim();
    if (client.phone.isNotEmpty && !client.phones.contains(client.phone)) {
      client.phones.add(client.phone);
    }
    if (client.car.isNotEmpty && !client.cars.contains(client.car)) {
      client.cars.add(client.car);
    }
    client.syncVehicleIds();
    client.source = source.trim();
    client.note = note.trim();
    client.lastContact = DateTime.now().toIso8601String();
    if (!clients.contains(client)) clients.add(client);
    _saveCrmData();
    return client.id;
  }

  Future<void> _manageServices() async {
    if (!canManageIntegrations) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Справочник услуг'),
          content: SizedBox(
            width: 640,
            height: 500,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      for (final item in serviceCatalog)
                        ListTile(
                          leading: Icon(
                            item.archived
                                ? Icons.inventory_2_outlined
                                : Icons.build_circle_outlined,
                            color: item.archived
                                ? _mutedTextColor
                                : const Color(0xFFF28C28),
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              decoration: item.archived
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            '${item.category} • ${item.durationHours.toStringAsFixed(1)} ч'
                            '${item.botInstructions.trim().isNotEmpty ? ' • правила бота заданы' : ''}'
                            '${item.archived ? ' • в архиве' : ''}',
                          ),
                          trailing: Wrap(
                            spacing: 2,
                            children: [
                              IconButton(
                                tooltip: 'Редактировать',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  await _editServiceCatalogItem(item);
                                  setDialog(() {});
                                },
                              ),
                              IconButton(
                                tooltip: item.archived
                                    ? 'Восстановить'
                                    : 'Переместить в архив',
                                icon: Icon(
                                  item.archived
                                      ? Icons.unarchive_outlined
                                      : Icons.archive_outlined,
                                ),
                                onPressed: () async {
                                  item.archived = !item.archived;
                                  item.updatedAt = DateTime.now()
                                      .toIso8601String();
                                  _migrateLegacyServicesToCatalog();
                                  await _saveServices();
                                  await _syncServiceKnowledge(
                                    source: 'архив услуги',
                                  );
                                  _enqueueCloudSnapshot(
                                    'Справочник услуг',
                                    '${item.archived ? 'Архивирована' : 'Восстановлена'} услуга ${item.name}',
                                  );
                                  setDialog(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final item = ServiceCatalogItem(
                        id: stableWorkspaceId('service'),
                        name: '',
                      );
                      final saved = await _editServiceCatalogItem(
                        item,
                        persist: false,
                      );
                      if (saved) {
                        serviceCatalog.add(item);
                        _migrateLegacyServicesToCatalog();
                        await _saveServices();
                        await _syncServiceKnowledge(
                          source: 'добавлена услуга ${item.name}',
                        );
                        _enqueueCloudSnapshot(
                          'Справочник услуг',
                          'Добавлена услуга ${item.name}',
                        );
                        setDialog(() {});
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить услугу'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<bool> _editServiceCatalogItem(
    ServiceCatalogItem item, {
    bool persist = true,
  }) async {
    final name = TextEditingController(text: item.name);
    final category = TextEditingController(text: item.category);
    final duration = TextEditingController(
      text: item.durationHours.toStringAsFixed(1),
    );
    final botInstructions = TextEditingController(text: item.botInstructions);
    final selectedMaterials = {...item.materialIds};
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: Text(item.name.isEmpty ? 'Новая услуга' : 'Услуга'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: item.name.isEmpty,
                    decoration: const InputDecoration(labelText: 'Название *'),
                  ),
                  TextField(
                    controller: category,
                    decoration: const InputDecoration(labelText: 'Категория'),
                  ),
                  TextField(
                    controller: duration,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Длительность, часов',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: botInstructions,
                    minLines: 3,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Правила для бота по этой услуге',
                      hintText:
                          'Например: какие вопросы уточнить, что входит в услугу, ограничения',
                      helperText:
                          'Сохраняется отдельным разделом базы знаний и обновляется автоматически.',
                    ),
                  ),
                  if (stockItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Материалы по умолчанию'),
                    ),
                    for (final stock in stockItems)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${stock.name} (${stock.unit})'),
                        value: selectedMaterials.contains(stock.id),
                        onChanged: (checked) => setDialog(() {
                          if (checked == true) {
                            selectedMaterials.add(stock.id);
                          } else {
                            selectedMaterials.remove(stock.id);
                          }
                        }),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final duplicate = serviceCatalog.any(
                  (other) =>
                      other.id != item.id &&
                      other.name.trim().toLowerCase() ==
                          name.text.trim().toLowerCase(),
                );
                if (name.text.trim().isEmpty ||
                    duplicate ||
                    _num(duration.text) <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        duplicate
                            ? 'Услуга с таким названием уже есть'
                            : 'Укажите название и положительную длительность',
                      ),
                    ),
                  );
                  return;
                }
                item.name = name.text.trim();
                item.category = category.text.trim().isEmpty
                    ? 'Основные услуги'
                    : category.text.trim();
                item.durationHours = _num(duration.text);
                item.botInstructions = botInstructions.text.trim();
                item.materialIds = selectedMaterials.toList();
                item.updatedAt = DateTime.now().toIso8601String();
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    category.dispose();
    duration.dispose();
    botInstructions.dispose();
    if (saved == true && persist) {
      _migrateLegacyServicesToCatalog();
      await _saveServices();
      await _syncServiceKnowledge(source: 'изменена услуга ${item.name}');
      _enqueueCloudSnapshot('Справочник услуг', 'Изменена услуга ${item.name}');
    }
    return saved == true;
  }

  Future<void> _savePrefs() async {
    if (!mounted) return;
    await prefs.setBool("wrap", wrapDealText);
    await prefs.setStringList(
      "cols",
      visibleDealCols.map((e) => e.toString()).toList(),
    );
  }

  void _rebuildDealRows() {
    dealRows = [dealHeaders, ...syncedDealRows, ...manualDealRows];
    typedDeals = dealRows.skip(1).map(Deal.fromRow).toList();
  }

  Future<void> _saveManualDeals() async {
    await prefs.setString('manual_deal_rows', jsonEncode(manualDealRows));
  }

  Future<void> _restoreCloudWorkspaceIfAvailable() async {
    if (syncEndpoint.isEmpty ||
        syncToken.isEmpty ||
        localChangeQueue.items.isNotEmpty) {
      return;
    }
    try {
      final cloud = await _sheets.readWorkspace(
        cancellation: _lifecycleCancellation,
      );
      if (cloud == null || cloud.isEmpty) return;
      List<Map<String, dynamic>> objects(String key) =>
          (cloud[key] as List? ?? const [])
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList();
      final cloudClients = objects('clients');
      if (cloud.containsKey('clients')) {
        clients
          ..clear()
          ..addAll(cloudClients.map(Client.fromJson));
      }
      final cloudStock = objects('stockItems');
      if (cloud.containsKey('stockItems')) {
        stockItems
          ..clear()
          ..addAll(cloudStock.map(StockItem.fromJson));
      }
      final cloudMovements = objects('stockMovements');
      if (cloud.containsKey('stockMovements')) {
        stockMovements
          ..clear()
          ..addAll(cloudMovements.map(StockMovement.fromJson));
      }
      final cloudDeals = cloud['manualDeals'];
      if (cloudDeals is List) {
        manualDealRows = cloudDeals
            .whereType<List>()
            .map((row) => row.map((value) => value.toString()).toList())
            .toList();
        _recalculateManualDeals();
      }
      final cloudTransactions = objects('transactions');
      if (cloud.containsKey('transactions')) {
        businessTransactions = cloudTransactions;
      }
      final cloudClosed = objects('closedPeriods');
      if (cloud.containsKey('closedPeriods')) {
        closedAccountingPeriods
          ..clear()
          ..addAll(cloudClosed);
        closedAccountingPeriod = closedAccountingPeriods.last;
      }
      final cloudAppointments = objects('appointments');
      if (cloud.containsKey('appointments') && calendarAccessToken == null) {
        calendarEvents = cloudAppointments;
      }
      final cloudCatalog = objects('serviceCatalog');
      if (cloud.containsKey('serviceCatalog')) {
        serviceCatalog = cloudCatalog
            .map(ServiceCatalogItem.fromJson)
            .where((item) => item.name.trim().isNotEmpty)
            .toList();
        _migrateLegacyServicesToCatalog();
      }
      final cloudNotes = objects('notes');
      if (cloud.containsKey('notes')) {
        dashboardNotes
          ..clear()
          ..addAll(cloudNotes.map(StickyNote.fromJson).take(8));
      }
      final cloudPlans = objects('revenuePlans');
      if (cloud.containsKey('revenuePlans')) {
        revenuePlans
          ..clear()
          ..addAll(cloudPlans.map(DashboardRevenuePlan.fromJson));
      }
      final cloudSettings = cloud['workspaceSettings'];
      if (cloudSettings is Map) {
        final period = cloudSettings['dashboardPeriod']?.toString();
        if (period != null && period.isNotEmpty) dashboardPeriod = period;
        dashboardCustomFrom = DateTime.tryParse(
          cloudSettings['dashboardPeriodFrom']?.toString() ?? '',
        );
        dashboardCustomTo = DateTime.tryParse(
          cloudSettings['dashboardPeriodTo']?.toString() ?? '',
        );
      }
      final cloudFinanceSettings = cloud['financeSettings'];
      if (cloudFinanceSettings is Map) {
        final categories = cloudFinanceSettings['categories'];
        if (categories is List && categories.isNotEmpty) {
          accountingCategories = categories
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList();
        }
      }
      final cloudMessageSettings = cloud['messageSettings'];
      if (cloudMessageSettings is Map) {
        final templates = cloudMessageSettings['quickReplyTemplates'];
        if (templates is List && templates.isNotEmpty) {
          quickReplyTemplates = templates
              .map((value) => value.toString())
              .toList();
        }
        final assignees = cloudMessageSettings['assignees'];
        if (assignees is Map) {
          messageAssignees
            ..clear()
            ..addAll(
              assignees.map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              ),
            );
        }
        final tags = cloudMessageSettings['tags'];
        if (tags is Map) {
          messageTags
            ..clear()
            ..addAll(
              tags.map(
                (key, value) => MapEntry(
                  key.toString(),
                  (value as List? ?? const [])
                      .map((tag) => tag.toString())
                      .toList(),
                ),
              ),
            );
        }
        final queue = cloudMessageSettings['pendingMessages'];
        if (queue is List) {
          pendingMessages
            ..clear()
            ..addAll(
              queue.whereType<Map>().map(
                (item) => Map<String, String>.from(
                  item.map(
                    (key, value) => MapEntry(key.toString(), value.toString()),
                  ),
                ),
              ),
            );
        }
      }
      final cloudAudit = cloud['audit'];
      if (cloudAudit is List) {
        auditEntries
          ..clear()
          ..addAll(
            cloudAudit.whereType<Map>().map(
              (item) => AuditEntry.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
      }
      final cloudKnowledge = objects('knowledge');
      final cloudKnowledgeText = cloudKnowledge.isEmpty
          ? ''
          : cloudKnowledge.first['content']?.toString().trim() ?? '';
      if (cloudKnowledgeText.isNotEmpty) knowledgeBase = cloudKnowledgeText;
      await _syncServiceKnowledge(
        source: 'синхронизация услуг из облака',
        sync: false,
      );
      final cloudKnowledgeVersions = objects('knowledgeVersions');
      if (cloud.containsKey('knowledgeVersions')) {
        knowledgeVersions
          ..clear()
          ..addAll(cloudKnowledgeVersions.map(KnowledgeBaseVersion.fromJson));
      }
      await _saveServices();
      await _saveManualDeals();
      await _saveMessageMeta(sync: false);
      await _saveAccountingCategories(sync: false);
      // _crmDataLoaded is intentionally still false during startup, so save
      // the restored cache explicitly without enabling early user writes.
      await prefs.setString(
        'crm_clients',
        jsonEncode(clients.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        'crm_stock',
        jsonEncode(stockItems.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        'crm_stock_movements',
        jsonEncode(stockMovements.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        'business_transactions',
        jsonEncode(businessTransactions),
      );
      await prefs.setString(
        'closed_accounting_periods',
        jsonEncode(closedAccountingPeriods),
      );
      await prefs.setString(
        'calendar_events_cache',
        jsonEncode(calendarEvents),
      );
      await _recordIncomingAppointments(calendarEvents);
      await _saveWorkspaceData(sync: false);
      await _saveKnowledgeBase(
        source: 'Восстановление из облака',
        addVersion: false,
        sync: false,
      );
      lastSheetsSync = DateTime.now();
      await prefs.setString(
        'sheets_last_sync',
        lastSheetsSync!.toIso8601String(),
      );
    } catch (error) {
      // The local cache remains usable; this is not an error that can erase it.
      CrmLogger.error(
        'Не удалось восстановить облачное рабочее пространство',
        error: error,
        name: 'crm.cloud',
      );
    }
  }

  Future<void> _refreshWorkspaceFromCloud() async {
    if (_workspaceRefreshInProgress ||
        _workspaceSaveInProgress ||
        !_crmDataLoaded ||
        _session == null ||
        pendingChangesSyncing ||
        localChangeQueue.items.isNotEmpty) {
      return;
    }
    _workspaceRefreshInProgress = true;
    try {
      await _restoreCloudWorkspaceIfAvailable();
      if (mounted) setState(() {});
    } finally {
      _workspaceRefreshInProgress = false;
    }
  }

  Future<int> _restoreManualDealsFromExport() async {
    try {
      final currentDir = await getApplicationDocumentsDirectory();
      final legacyHome = Platform.environment['HOME'];
      final directories = <Directory>[
        currentDir,
        if (legacyHome != null && legacyHome.isNotEmpty)
          Directory(
            '$legacyHome/Library/Containers/com.example.crm/Data/Documents',
          ),
      ];
      final exports = <File>[];
      for (final directory in directories) {
        if (!directory.existsSync()) continue;
        exports.addAll(
          (await directory.list().toList()).whereType<File>().where(
            (file) => file.path.contains('/crm-deals-'),
          ),
        );
      }
      exports.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );
      if (exports.isEmpty) return 0;
      final rows = parseCsv(await exports.first.readAsString());
      if (rows.length <= 1 || rows.first.length < dealHeaders.length) return 0;
      final restored = rows
          .skip(1)
          .map((row) => row.take(dealHeaders.length).toList())
          .where((row) => row.any((cell) => cell.trim().isNotEmpty))
          .toList();
      if (restored.isEmpty) return 0;
      manualDealRows = restored;
      _recalculateManualDeals();
      await _saveManualDeals();
      if (mounted) setState(_rebuildDealRows);
      return restored.length;
    } catch (error) {
      CrmLogger.error(
        'Не удалось восстановить локальные сделки из CSV-экспорта',
        error: error,
        name: 'crm.persistence',
      );
      return 0;
    }
  }

  Map<String, dynamic>? get _activeAvitoAccount {
    for (final account in avitoAccounts) {
      if (account['key'] == activeAvitoAccountKey) return account;
    }
    return avitoAccounts.isEmpty ? null : avitoAccounts.first;
  }

  void _loadAvitoAccountsFromPrefs() {
    try {
      final saved = prefs.getString('avito_accounts');
      if (saved != null) {
        avitoAccounts = (jsonDecode(saved) as List)
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList();
      }
    } catch (_) {
      avitoAccounts = [];
    }
    if (avitoAccounts.isEmpty) {
      final legacyId = prefs.getString('avito_client_id') ?? '';
      final legacySecret = prefs.getString('avito_client_secret') ?? '';
      if (legacyId.isNotEmpty && legacySecret.isNotEmpty) {
        avitoAccounts = [
          {
            'key': legacyId,
            'name': 'Avito аккаунт',
            'clientId': legacyId,
            'clientSecret': legacySecret,
            'webhook': prefs.getString('avito_webhook') ?? '',
            'userId': prefs.getString('avito_user_id') ?? '',
          },
        ];
      }
    }
    activeAvitoAccountKey =
        prefs.getString('avito_active_account') ??
        (avitoAccounts.isNotEmpty
            ? avitoAccounts.first['key']?.toString()
            : null);
    if (!avitoAccounts.any(
      (account) => account['key']?.toString() == activeAvitoAccountKey,
    )) {
      activeAvitoAccountKey = avitoAccounts.isNotEmpty
          ? avitoAccounts.first['key']?.toString()
          : null;
    }
  }

  Future<void> _saveAvitoAccounts() async {
    await secretStore.write('avito_accounts', jsonEncode(avitoAccounts));
    final publicAccounts = avitoAccounts
        .map(
          (account) =>
              Map<String, dynamic>.from(account)..remove('clientSecret'),
        )
        .toList();
    await prefs.setString('avito_accounts', jsonEncode(publicAccounts));
    if (activeAvitoAccountKey != null) {
      await prefs.setString('avito_active_account', activeAvitoAccountKey!);
    }
  }

  Future<void> _loadSecureAvitoAccounts() async {
    try {
      final raw = await secretStore.read('avito_accounts');
      if (raw == null || raw.isEmpty) {
        if (avitoAccounts.any(
          (account) => (account['clientSecret'] ?? '').toString().isNotEmpty,
        )) {
          await secretStore.write('avito_accounts', jsonEncode(avitoAccounts));
          final publicAccounts = avitoAccounts
              .map(
                (account) =>
                    Map<String, dynamic>.from(account)..remove('clientSecret'),
              )
              .toList();
          await prefs.setString('avito_accounts', jsonEncode(publicAccounts));
          await prefs.remove('avito_client_secret');
        }
        return;
      }
      final secureAccounts = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
      for (final account in avitoAccounts) {
        final key = account['key']?.toString();
        final secure = secureAccounts.cast<Map<String, dynamic>?>().firstWhere(
          (value) => value?['key']?.toString() == key,
          orElse: () => null,
        );
        if (secure != null && secure['clientSecret'] != null) {
          account['clientSecret'] = secure['clientSecret'];
        }
      }
      final publicAccounts = avitoAccounts
          .map(
            (account) =>
                Map<String, dynamic>.from(account)..remove('clientSecret'),
          )
          .toList();
      await prefs.setString('avito_accounts', jsonEncode(publicAccounts));
    } catch (_) {
      // Older installations may not have secure storage initialized yet.
    }
  }

  void _recalculateManualDeals() {
    manualDealRows = manualDealRows.map((source) {
      final row = recalculateDealRow(source);
      if (row.length < dealHeaders.length) {
        row.addAll(List.filled(dealHeaders.length - row.length, ''));
      }
      if (row[21].trim().isEmpty) {
        row[21] = 'deal-${DateTime.now().microsecondsSinceEpoch}';
      }
      return row;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return LoginScreen(
        users: _serverUsers,
        loading: _authLoading,
        error: _authError,
        initialUserId: preferencesLoaded
            ? prefs.getString('crm_current_user')
            : null,
        onLogin: _login,
        onRetry: () {
          setState(() {
            _authLoading = true;
            _authError = null;
          });
          unawaited(_initializeAuth());
        },
        onConfigureServer: () => unawaited(_configureServer()),
      );
    }
    final allowed = _firstVisiblePage();
    if (!_canView(_pagePermissionArea(selected))) selected = allowed;
    return DashboardShell(
      darkMode: widget.darkMode,
      sidebar: _sidebar(),
      title: pages[selected].title,
      now: now,
      hasUnreadNotifications: notifications.any((item) => !item.read),
      onOpenNotifications: _showNotificationCenter,
      selectedPage: selected,
      mobileDestinations: _mobileDestinations(),
      onPageSelected: _selectPage,
      onThemeChanged: (next) {
        widget.onThemeChanged(next);
        unawaited(
          SharedPreferences.getInstance().then(
            (prefs) => prefs.setBool('dark_mode', next),
          ),
        );
      },
      body: _pageBody(),
    );
  }

  int _firstVisiblePage() {
    for (var index = 0; index < pages.length; index++) {
      if (_canView(_pagePermissionArea(index))) return index;
    }
    return 0;
  }

  String _pagePermissionArea(int index) => switch (index) {
    0 => 'dashboard',
    1 => 'clients',
    2 => 'deals',
    3 => 'calendar',
    4 => 'finance',
    5 => 'stock',
    6 => 'settings',
    7 => 'messages',
    8 => 'bot',
    _ => 'dashboard',
  };

  Widget _sidebar() => CrmSidebar(
    selected: selected,
    canView: (index) => _canView(_pagePermissionArea(index)),
    userName: currentUser?.name ?? _session?.user.name ?? 'Профиль',
    userRole: currentRole,
    onSwitchUser: () => unawaited(_switchUser()),
    onLogout: () => unawaited(_confirmLogout()),
    onSelect: _selectPage,
  );

  List<DashboardMobileDestination> _mobileDestinations() {
    const primary = [
      (0, 'Сегодня', Icons.today_outlined),
      (1, 'Клиенты', Icons.people_outline),
      (3, 'Записи', Icons.calendar_month_outlined),
      (7, 'Сообщения', Icons.forum_outlined),
    ];
    final destinations = primary
        .where((item) => _canView(_pagePermissionArea(item.$1)))
        .map(
          (item) => DashboardMobileDestination(
            pageIndex: item.$1,
            label: item.$2,
            icon: item.$3,
          ),
        )
        .toList();
    if (destinations.length >= 2) {
      destinations.add(
        const DashboardMobileDestination(
          pageIndex: -1,
          label: 'Ещё',
          icon: Icons.more_horiz,
          isMore: true,
        ),
      );
    }
    return destinations;
  }

  void _selectPage(int index) {
    setState(() => selected = index);
    if (index == 4) _loadAccounting();
    if (index == 2 || index == 0) _loadDeals();
    if (index == 3 && _usesGoogleCalendar) _loadCalendarEvents();
    if (index == 7) unawaited(_refreshMessageSources());
    if (usesCompactNavigation(MediaQuery.sizeOf(context).width)) {
      unawaited(Navigator.of(context).maybePop());
    }
  }

  Future<void> _refreshMessageSources() async {
    final requests = <Future<void>>[
      if (messengerConnected['vk'] == true) _loadVkConversations(silent: true),
      if (messengerConnected['telegram'] == true)
        _loadTelegramUpdates(silent: true),
      if (messengerConnected['instagram'] == true)
        _loadInstagramConversations(silent: true),
      if (avitoAccounts.isNotEmpty) _connectAvito(silent: true),
    ];
    await Future.wait(requests);
  }

  Widget _pageBody() {
    if (selected == 0) return _overview();
    if (selected == 1) return _crm();
    if (selected == 3) return _appointments();
    if (selected == 2) return _deals();
    if (selected == 4) return _accounting();
    if (selected == 5) return _stock();
    if (selected == 6) return _settings();
    if (selected == 7) return _messages();
    if (selected == 8) return _botTest();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pages[selected].subtitle,
          style: TextStyle(color: _mutedTextColor, fontSize: 14),
        ),
        const SizedBox(height: 26),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorderColor),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  crmPageIcons[selected.clamp(0, crmPageIcons.length - 1)],
                  size: 44,
                  color: const Color(0xFFF28C28),
                ),
                const SizedBox(height: 14),
                Text(
                  'Раздел «${pages[selected].title}» готов к настройке',
                  style: TextStyle(
                    color: _mainTextColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Здесь появятся данные и инструменты вашего бизнеса',
                  style: TextStyle(color: _mutedTextColor, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _connectCalendar() async {
    if (!canManageIntegrations) return;
    if (!AppConfig.googleClientIdConfigured) {
      const message =
          'Не задан GOOGLE_CLIENT_ID. Соберите приложение с OAuth Client ID из Google Cloud Console.';
      if (mounted) {
        setState(() => calendarStatus = message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(message)));
      }
      CrmLogger.error(message, name: 'crm.calendar');
      return;
    }
    if (mounted) {
      setState(() {
        calendarStatus = 'Запускаю безопасный локальный приём ответа Google…';
        calendarLoading = true;
      });
    }
    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final redirect = 'http://127.0.0.1:${server.port}/';
      final verifier = generatePkceCodeVerifier();
      final state = generateOAuthState();
      final auth = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': AppConfig.googleClientId,
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope':
            'https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/spreadsheets.readonly',
        'access_type': 'offline',
        'prompt': 'consent',
        'code_challenge': pkceCodeChallenge(verifier),
        'code_challenge_method': 'S256',
        'state': state,
      });
      final opened = await launchUrl(
        auth,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '', auth.toString()]);
        } else {
          await Process.run('open', [auth.toString()]);
        }
      }
      if (mounted) {
        setState(
          () => calendarStatus =
              'Подтвердите доступ в браузере. После этого CRM завершит подключение сама…',
        );
      }
      final req = await server.first.timeout(const Duration(minutes: 3));
      final code = req.uri.queryParameters['code'];
      final returnedState = req.uri.queryParameters['state'];
      req.response.statusCode = 200;
      req.response.headers.contentType = ContentType.html;
      req.response.write('<h2>Готово. Вернитесь в CRM.</h2>');
      await req.response.close();
      await server.close();
      if (code == null) throw Exception('no code');
      if (returnedState != state) throw Exception('invalid oauth state');
      final token = await _apiClient.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'code': code,
          'client_id': AppConfig.googleClientId,
          'redirect_uri': redirect,
          'grant_type': 'authorization_code',
          'code_verifier': verifier,
          if (calendarClientSecret.trim().isNotEmpty)
            'client_secret': calendarClientSecret.trim(),
        },
      );
      if (token.statusCode != 200) {
        throw Exception('Google OAuth: ${_oauthErrorText(token)}');
      }
      final tokenData = jsonDecode(token.body) as Map<String, dynamic>;
      final access = tokenData['access_token'] as String;
      final refresh = tokenData['refresh_token']?.toString();
      calendarAccessToken = access;
      await secretStore.write('calendar_access_token', access);
      await prefs.remove('calendar_access_token');
      if (refresh != null && refresh.isNotEmpty) {
        calendarRefreshToken = refresh;
        await secretStore.write('calendar_refresh_token', refresh);
        await prefs.remove('calendar_refresh_token');
      }
      if (mounted) {
        setState(() {
          calendarConnected = true;
          calendarStatus = 'Календарь подключён. Загружаю записи…';
        });
      }
      await _loadCalendarList();
      await _loadCalendarEvents();
      _audit('Подключена интеграция', 'Интеграция', 'Google Календарь');
    } catch (e) {
      final safeError = explainGoogleOAuthError(
        CrmLogger.redact(e.toString().replaceFirst('Exception: ', '')),
      );
      CrmLogger.error(
        'Calendar OAuth failed: $safeError',
        name: 'crm.calendar',
      );
      await server?.close();
      if (mounted) {
        setState(() => calendarStatus = 'Подключение не завершено: $safeError');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Календарь: $safeError')));
      }
    } finally {
      if (mounted) setState(() => calendarLoading = false);
    }
  }

  String _oauthErrorText(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map) {
        final error = data['error']?.toString();
        final description = data['error_description']?.toString();
        if (error != null && description != null && description.isNotEmpty) {
          return '$error — $description';
        }
        if (error != null && error.isNotEmpty) return error;
      }
    } catch (_) {}
    return 'HTTP ${response.statusCode}';
  }

  Future<void> _configureCalendarClientSecret() async {
    if (!canManageIntegrations) return;
    final controller = TextEditingController();
    try {
      final value = await showDialog<String?>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Client secret Google OAuth'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Вставьте client secret из карточки OAuth-клиента Google. Секрет будет сохранён только в защищённом хранилище системы и не попадёт в исходный код или логи.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Client secret',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (calendarClientSecret.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, ''),
                child: const Text('Удалить сохранённый'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
      if (value == null) return;
      final secret = value.trim();
      try {
        if (secret.isEmpty) {
          await secretStore.delete('calendar_client_secret');
          final stored = await secretStore.read('calendar_client_secret');
          if (stored != null && stored.isNotEmpty) {
            throw StateError(
              'Защищённое хранилище не подтвердило удаление client secret',
            );
          }
        } else {
          await secretStore.write('calendar_client_secret', secret);
          final stored = await secretStore.read('calendar_client_secret');
          if (stored != secret) {
            throw StateError(
              'Защищённое хранилище не подтвердило сохранение client secret',
            );
          }
        }
      } catch (error) {
        CrmLogger.error(
          'Не удалось сохранить client secret в защищённом хранилище',
          error: error,
          name: 'crm.security',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(
              'Не удалось сохранить client secret в защищённом хранилище: $error',
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => calendarClientSecret = secret);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            secret.isEmpty
                ? 'Client secret удалён из защищённого хранилища'
                : 'Client secret сохранён в защищённом хранилище',
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _refreshCalendarAccessToken() async {
    final refresh = calendarRefreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final response = await _apiClient.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        body: {
          'client_id': AppConfig.googleClientId,
          'refresh_token': refresh,
          'grant_type': 'refresh_token',
          if (calendarClientSecret.trim().isNotEmpty)
            'client_secret': calendarClientSecret.trim(),
        },
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final access = data['access_token']?.toString();
      if (access == null || access.isEmpty) return false;
      calendarAccessToken = access;
      await secretStore.write('calendar_access_token', access);
      await prefs.remove('calendar_access_token');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadCalendarList() async {
    final access = calendarAccessToken;
    if (access == null) return;
    try {
      var res = await _apiClient.get(
        Uri.parse(
          'https://www.googleapis.com/calendar/v3/users/me/calendarList',
        ),
        headers: {'Authorization': 'Bearer $access'},
      );
      if (res.statusCode == 401 && await _refreshCalendarAccessToken()) {
        res = await _apiClient.get(
          Uri.parse(
            'https://www.googleapis.com/calendar/v3/users/me/calendarList',
          ),
          headers: {'Authorization': 'Bearer $calendarAccessToken'},
        );
      }
      if (res.statusCode != 200) return;
      final items = (jsonDecode(res.body)['items'] as List? ?? []).cast<Map>();
      if (mounted) {
        setState(
          () => availableCalendars = items
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _chooseCalendar() async {
    if (!canManageIntegrations) return;
    if (availableCalendars.isEmpty) await _loadCalendarList();
    if (!mounted) return;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выберите календарь'),
        content: SizedBox(
          width: 460,
          height: 360,
          child: ListView(
            children: [
              for (final c in availableCalendars)
                ListTile(
                  selected: c['id'].toString() == calendarId,
                  leading: Icon(
                    c['id'].toString() == calendarId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onTap: () => Navigator.pop(ctx, c),
                  title: Text(c['summary']?.toString() ?? 'Без названия'),
                  subtitle: Text(
                    c['primary'] == true
                        ? 'Основной календарь'
                        : c['id']?.toString() ?? '',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    calendarId = selected['id'].toString();
    calendarName = selected['summary']?.toString() ?? 'Календарь';
    await prefs.setString('calendar_id', calendarId);
    await prefs.setString('calendar_name', calendarName);
    if (mounted) {
      setState(() => calendarStatus = 'Выбран календарь: $calendarName');
    }
    await _loadCalendarEvents();
  }

  Future<void> _loadCalendarEvents() async {
    final access = calendarAccessToken;
    if (access == null) return;
    if (mounted) setState(() => calendarLoading = true);
    try {
      final start = DateTime.now()
          .subtract(const Duration(days: 1))
          .toUtc()
          .toIso8601String();
      final uri = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events?maxResults=100&singleEvents=true&orderBy=startTime&timeMin=${Uri.encodeQueryComponent(start)}',
      );
      var res = await _apiClient.get(
        uri,
        headers: {'Authorization': 'Bearer $access'},
      );
      if (res.statusCode == 401) {
        if (await _refreshCalendarAccessToken()) {
          res = await _apiClient.get(
            uri,
            headers: {'Authorization': 'Bearer $calendarAccessToken'},
          );
        }
      }
      if (res.statusCode == 401) {
        await secretStore.delete('calendar_access_token');
        await secretStore.delete('calendar_refresh_token');
        await prefs.remove('calendar_access_token');
        await prefs.remove('calendar_refresh_token');
        if (mounted) {
          setState(() {
            calendarAccessToken = null;
            calendarRefreshToken = null;
            calendarConnected = false;
            calendarStatus =
                'Срок доступа закончился. Подключите календарь снова.';
          });
        }
        return;
      }
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final items = (jsonDecode(res.body)['items'] as List? ?? []).cast<Map>();
      if (mounted) {
        setState(() {
          calendarEvents = items
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          calendarStatus = 'Календарь подключён. Записей: ${items.length}';
        });
      }
      await prefs.setString(
        'calendar_events_cache',
        jsonEncode(calendarEvents),
      );
      await _recordIncomingAppointments(calendarEvents);
    } catch (_) {
      if (mounted) {
        setState(
          () => calendarStatus = 'Не удалось загрузить записи календаря.',
        );
      }
    } finally {
      if (mounted) setState(() => calendarLoading = false);
    }
  }

  String _eventTime(Map<String, dynamic> e) {
    final start = (e['start'] as Map?) ?? {};
    final value = (start['dateTime'] ?? start['date'] ?? '').toString();
    if (DateTime.tryParse(value) == null) return value;
    final moscow = _googleToMoscow(value, DateTime.now());
    return '${moscow.day.toString().padLeft(2, '0')}.${moscow.month.toString().padLeft(2, '0')}.${moscow.year} ${moscow.hour.toString().padLeft(2, '0')}:${moscow.minute.toString().padLeft(2, '0')}';
  }

  DateTime? _eventStart(Map<String, dynamic> e) {
    final raw =
        ((e['start'] as Map?)?['dateTime'] ?? (e['start'] as Map?)?['date'])
            ?.toString();
    if (raw == null || raw.isEmpty) return null;
    return _googleToMoscow(raw, DateTime.now());
  }

  DateTime? _eventEnd(Map<String, dynamic> e) {
    final raw = ((e['end'] as Map?)?['dateTime'] ?? (e['end'] as Map?)?['date'])
        ?.toString();
    if (raw == null || raw.isEmpty) return null;
    return _googleToMoscow(raw, DateTime.now());
  }

  CalendarConflictKind? _calendarConflict(
    DateTime start,
    DateTime end, {
    String? ignoreId,
    String performer = '',
    String vehicleId = '',
    String vehicle = '',
  }) => findCalendarResourceConflict(
    calendarEvents,
    start,
    end,
    ignoreId: ignoreId,
    performer: performer,
    vehicleId: vehicleId,
    vehicle: vehicle,
  );

  String _calendarConflictText(CalendarConflictKind kind) => switch (kind) {
    CalendarConflictKind.performer => 'Этот мастер уже занят в указанное время',
    CalendarConflictKind.vehicle =>
      'Этот автомобиль уже записан на указанное время',
    CalendarConflictKind.time =>
      'Есть пересекающаяся старая запись без мастера или автомобиля',
  };

  String _candidateVehicleId({
    required String name,
    required String phone,
    required String car,
  }) {
    final normalizedPhone = normalizePhone(phone);
    final client = clients.cast<Client?>().firstWhere(
      (item) =>
          item != null &&
          ((normalizedPhone.isNotEmpty &&
                  item.phones.any(
                    (value) => normalizePhone(value) == normalizedPhone,
                  )) ||
              (name.trim().isNotEmpty &&
                  item.name.trim().toLowerCase() == name.trim().toLowerCase())),
      orElse: () => null,
    );
    return client?.vehicleIdFor(car) ?? '';
  }

  DateTime _googleToMoscow(String value, DateTime fallback) =>
      googleToMoscow(value, fallback);

  String _moscowIso(DateTime value) => moscowIso(value);

  String _appointmentDescription({
    required String name,
    required String source,
    required String car,
    required String service,
    required String cost,
    required String phone,
    required String note,
    String performer = '',
  }) {
    final rows = <String>[];
    void add(String title, String value) {
      if (value.trim().isNotEmpty) rows.add('$title: ${value.trim()}');
    }

    add('Клиент', name);
    add('Источник', source);
    add('Автомобиль', car);
    add('Услуга', service);
    add('Стоимость', cost);
    add('Телефон', phone);
    add('Исполнитель', performer);
    add('Заметка', note);
    return rows.isEmpty ? 'Запись из CRM «Чистое место»' : rows.join('\n');
  }

  Future<String?> _notifyVkAboutAppointment({
    required DateTime when,
    required String name,
    required String source,
    required String car,
    required String service,
    required String cost,
    required String phone,
    required String note,
    String performer = '',
    String? items,
  }) async {
    if (messengerConnected['vk'] != true) return null;
    final peerId = prefs.getString('messenger_vk_notify_peer') ?? '';
    if (peerId.isEmpty) return null;
    final text = StringBuffer('📅 Новая запись в «Чистое место»\n\n');
    text.writeln(
      'Дата и время: ${when.day.toString().padLeft(2, '0')}.${when.month.toString().padLeft(2, '0')}.${when.year} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
    );
    if (name.trim().isNotEmpty) text.writeln('Клиент: ${name.trim()}');
    if (phone.trim().isNotEmpty) text.writeln('Телефон: ${phone.trim()}');
    if (car.trim().isNotEmpty) text.writeln('Автомобиль: ${car.trim()}');
    if (performer.trim().isNotEmpty) {
      text.writeln('Исполнитель: ${performer.trim()}');
    }
    if (items != null && items.trim().isNotEmpty) {
      text.writeln('Услуги и товары:');
      text.writeln(items.trim());
      if (cost.trim().isNotEmpty) text.writeln('Итого: ${cost.trim()} ₽');
    } else {
      if (service.trim().isNotEmpty) text.writeln('Услуга: ${service.trim()}');
      if (cost.trim().isNotEmpty) text.writeln('Стоимость: ${cost.trim()} ₽');
    }
    if (source.trim().isNotEmpty) text.writeln('Источник: ${source.trim()}');
    if (note.trim().isNotEmpty) text.writeln('Заметка: ${note.trim()}');
    return _sendVkText(peerId: peerId, text: text.toString().trim());
  }

  Future<void> _sendScheduledAppointmentReminders() async {
    if (!preferencesLoaded || calendarEvents.isEmpty) return;
    final now = DateTime.now();
    var changed = false;
    for (final event in calendarEvents) {
      final eventId = event['id']?.toString();
      final start = _eventStart(event);
      if (eventId == null || start == null) continue;
      if (!isAppointmentReminderDue(start: start, now: now)) continue;
      final private =
          ((event['extendedProperties'] as Map?)?['private'] as Map?) ?? {};
      final name = (private['name'] ?? event['summary'] ?? 'Клиент')
          .toString()
          .trim();
      final service = (private['service'] ?? event['summary'] ?? '').toString();
      final when = calendarEventLocalDate(event) ?? start;
      final time =
          '${when.day.toString().padLeft(2, '0')}.${when.month.toString().padLeft(2, '0')} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
      final staffKey = '$eventId:staff';
      if (!sentAppointmentReminderKeys.contains(staffKey)) {
        final peerId = prefs.getString('messenger_vk_notify_peer') ?? '';
        if (messengerConnected['vk'] == true && peerId.isNotEmpty) {
          final staffText =
              '⏰ Напоминание сотрудникам: через 2 часа запись\n$time — $name${service.trim().isEmpty ? '' : '\nУслуга: $service'}';
          final error = await _sendVkText(peerId: peerId, text: staffText);
          if (error == null) {
            sentAppointmentReminderKeys.add(staffKey);
            changed = true;
          } else {
            CrmLogger.error(
              'Не отправлено напоминание сотрудникам: $error',
              name: 'crm.reminders',
            );
            await _enqueuePendingMessage({
              'channel': 'vk',
              'peer': peerId,
              'text': staffText,
            });
          }
        }
      }
      final clientKey = '$eventId:client';
      if (sentAppointmentReminderKeys.contains(clientKey)) continue;
      final clientId = private['clientId']?.toString() ?? '';
      final client = clients.cast<Client?>().firstWhere(
        (value) => value?.id == clientId,
        orElse: () => null,
      );
      if (client == null) continue;
      final clientText =
          '⏰ Напоминаем о записи в «Чистое место» через 2 часа.\n$time${service.trim().isEmpty ? '' : '\nУслуга: $service'}';
      String? error;
      if (client.telegramChatId.trim().isNotEmpty) {
        error = await _sendTelegramText(
          chatId: client.telegramChatId.trim(),
          text: clientText,
        );
      } else if (client.vkPeerId.trim().isNotEmpty) {
        error = await _sendVkText(
          peerId: client.vkPeerId.trim(),
          text: clientText,
        );
      } else {
        continue;
      }
      if (error == null) {
        sentAppointmentReminderKeys.add(clientKey);
        changed = true;
      } else {
        CrmLogger.error(
          'Не отправлено напоминание клиенту: $error',
          name: 'crm.reminders',
        );
        await _enqueuePendingMessage({
          'channel': client.telegramChatId.trim().isNotEmpty
              ? 'telegram'
              : 'vk',
          if (client.telegramChatId.trim().isNotEmpty)
            'chat': client.telegramChatId.trim()
          else
            'peer': client.vkPeerId.trim(),
          'text': clientText,
        });
      }
    }
    if (changed) {
      await prefs.setStringList(
        'sent_appointment_reminders',
        sentAppointmentReminderKeys.toList(),
      );
    }
  }

  Future<String?> _sendVkAppointmentsSummary() async {
    final peerId = prefs.getString('messenger_vk_notify_peer') ?? '';
    if (peerId.isEmpty || messengerConnected['vk'] != true) return null;
    final nowDate = DateTime.now();
    final until = nowDate.add(const Duration(days: 7));
    final upcoming =
        calendarEvents.where((e) {
          final d = calendarEventLocalDate(e);
          return d != null &&
              d.isAfter(nowDate.subtract(const Duration(minutes: 1))) &&
              d.isBefore(until);
        }).toList()..sort(
          (a, b) => (calendarEventLocalDate(a) ?? nowDate).compareTo(
            calendarEventLocalDate(b) ?? nowDate,
          ),
        );
    final text = StringBuffer('📋 Актуальные записи\n\n');
    if (upcoming.isEmpty) {
      text.write('На ближайшие 7 дней записей нет.');
    } else {
      for (final e in upcoming) {
        final d = calendarEventLocalDate(e)!;
        final p = ((e['extendedProperties'] as Map?)?['private'] as Map?) ?? {};
        const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
        final weekday = weekdays[d.weekday - 1];
        final name = (p['name'] ?? e['summary'] ?? 'Клиент').toString();
        text.writeln(
          '🕒 $weekday ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} — $name',
        );
        if ((p['car'] ?? '').toString().isNotEmpty) {
          text.writeln('🚗 ${p['car']}');
        }
        if ((p['service'] ?? e['summary'] ?? '').toString().isNotEmpty) {
          text.writeln('🧽 ${p['service'] ?? e['summary']}');
        }
        text.writeln();
      }
      text.writeln('Всего записей: ${upcoming.length}');
    }
    final previousId = prefs.getInt('messenger_vk_summary_message_id');
    if (previousId != null) {
      await _deleteVkMessage(previousId.toString());
      await prefs.remove('messenger_vk_summary_message_id');
    }
    final error = await _sendVkText(
      peerId: peerId,
      text: text.toString().trim(),
    );
    if (error != null) return error;
    final newId = _lastVkMessageId;
    if (newId != null) {
      await prefs.setInt('messenger_vk_summary_message_id', newId);
    }
    return null;
  }

  Future<String?> _sendVkText({
    required String peerId,
    required String text,
  }) async {
    try {
      final data = await _vkRequest('messages.send', {
        'peer_id': peerId,
        'random_id': DateTime.now().microsecondsSinceEpoch.toString(),
        'message': text,
      });
      if (data['error'] != null) {
        final error = data['error'] as Map;
        return error['error_msg']?.toString() ?? 'VK не принял уведомление';
      }
      final messageId = data['response'];
      _lastVkMessageId = messageId is int
          ? messageId
          : int.tryParse(messageId?.toString() ?? '');
      return null;
    } catch (_) {
      return 'Не удалось отправить уведомление ВКонтакте';
    }
  }

  Future<String?> _deleteVkMessage(String messageId) async {
    final peerId = prefs.getString('messenger_vk_notify_peer') ?? '';
    if (peerId.isEmpty || messageId.isEmpty) return null;
    try {
      final data = await _vkRequest('messages.delete', {
        'peer_id': peerId,
        'message_ids': messageId,
        'delete_for_all': '1',
      });
      if (data['error'] != null) {
        final error = data['error'] as Map;
        return error['error_msg']?.toString() ?? 'VK не удалил уведомление';
      }
      return null;
    } catch (_) {
      return 'Не удалось удалить уведомление ВКонтакте';
    }
  }

  Future<void> _removeVkAppointmentMessage(String eventId) async {
    final key = 'messenger_vk_appointment_$eventId';
    final messageId = prefs.getInt(key);
    if (messageId != null) {
      await _deleteVkMessage(messageId.toString());
      await prefs.remove(key);
      return;
    }
    // Старые записи могли быть созданы до сохранения ID сообщения.
    // Ищем уведомление по идентификатору записи в истории чата и удаляем его.
    final peerId = prefs.getString('messenger_vk_notify_peer') ?? '';
    if (peerId.isEmpty) return;
    try {
      final data = await _vkRequest('messages.search', {
        'peer_id': peerId,
        'q': eventId,
        'count': '20',
      });
      final items = (data['response']?['items'] as List? ?? const []);
      for (final item in items) {
        final foundId = item is Map ? item['id']?.toString() : null;
        if (foundId != null) await _deleteVkMessage(foundId);
      }
    } catch (_) {}
  }

  String _googleCalendarError(http.Response response) {
    try {
      final error = (jsonDecode(response.body) as Map)['error'];
      final message = error is Map ? error['message']?.toString() : null;
      if (response.statusCode == 401) {
        return 'Доступ к Google Календарю истёк. Подключите календарь заново.';
      }
      if (response.statusCode == 403) {
        return 'Нет права на изменение календаря. Подключите Google Календарь заново и подтвердите полный доступ.';
      }
      if (message != null && message.isNotEmpty) {
        return 'Google Календарь: $message';
      }
    } catch (_) {}
    return 'Не удалось сохранить запись. Код Google: ${response.statusCode}.';
  }

  Future<void> _editCalendarEvent([Map<String, dynamic>? event]) async {
    if (!_canEdit('calendar')) return;
    final private =
        ((event?['extendedProperties'] as Map?)?['private'] as Map?) ?? {};
    final name = TextEditingController(text: private['name']?.toString() ?? '');
    final source = TextEditingController(
      text: private['source']?.toString() ?? '',
    );
    final car = TextEditingController(text: private['car']?.toString() ?? '');
    final performer = TextEditingController(
      text: private['performer']?.toString() ?? '',
    );
    final initialService =
        private['service']?.toString() ?? event?['summary']?.toString() ?? '';
    final service = TextEditingController(text: initialService);
    final cost = TextEditingController(text: private['cost']?.toString() ?? '');
    final duration = TextEditingController(
      text:
          private['duration']?.toString() ??
          _templateDurationText(initialService),
    );
    final phone = TextEditingController(
      text: private['phone']?.toString() ?? '',
    );
    final note = TextEditingController(text: private['note']?.toString() ?? '');
    String status = private['status']?.toString() ?? 'Записан';
    final originalStatus = status;
    final activePerformers = userProfiles
        .where((profile) => profile.active && profile.name.trim().isNotEmpty)
        .toList(growable: false);
    Future<void> selectPerformers(StateSetter refresh) async {
      final chosen = performer.text
          .split(',')
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet();
      final saved = await showDialog<Set<String>>(
        context: context,
        builder: (pickerContext) => StatefulBuilder(
          builder: (pickerContext, setPickerState) => AlertDialog(
            title: const Text('Исполнители'),
            content: SizedBox(
              width: 360,
              child: ListView(
                shrinkWrap: true,
                children: activePerformers
                    .map(
                      (profile) => CheckboxListTile(
                        value: chosen.contains(profile.name),
                        contentPadding: EdgeInsets.zero,
                        title: Text(profile.name),
                        subtitle: Text(profile.role),
                        onChanged: (selected) => setPickerState(() {
                          if (selected == true) {
                            chosen.add(profile.name);
                          } else {
                            chosen.remove(profile.name);
                          }
                        }),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(pickerContext),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(pickerContext, chosen),
                child: const Text('Выбрать'),
              ),
            ],
          ),
        ),
      );
      if (saved != null) {
        refresh(() => performer.text = saved.join(', '));
      }
    }

    final rows = <Map<String, dynamic>>[
      {'type': 'Услуга', 'name': service, 'price': cost},
    ];
    void applyServiceDurationTemplates() {
      final hours = calculateServiceTemplateDuration(
        rows
            .where((row) => row['type'] == 'Услуга')
            .map((row) => (row['name'] as TextEditingController).text),
        serviceDurations,
      );
      if (hours > 0) duration.text = hours.toStringAsFixed(2);
    }

    DateTime when = selectedCalendarDay.add(const Duration(hours: 10));
    final existingStart =
        ((event?['start'] as Map?)?['dateTime'] ??
                (event?['start'] as Map?)?['date'])
            ?.toString();
    if (existingStart != null && existingStart.isNotEmpty) {
      when = _googleToMoscow(existingStart, when);
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(event == null ? 'Новая запись' : 'Изменить запись'),
          content: SizedBox(
            // AlertDialog на macOS ограничивает доступную ширину. Значение
            // 600 выходило за этот предел и обрезало первую колонку услуг.
            width: 500,
            height: (MediaQuery.of(ctx).size.height * .78).clamp(420.0, 650.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: when,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialog(
                                () => when = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                  when.hour,
                                  when.minute,
                                ),
                              );
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Дата',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              '${when.day.toString().padLeft(2, '0')}.${when.month.toString().padLeft(2, '0')}.${when.year}',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(when),
                            );
                            if (picked != null) {
                              setDialog(
                                () => when = DateTime(
                                  when.year,
                                  when.month,
                                  when.day,
                                  picked.hour,
                                  picked.minute,
                                ),
                              );
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Время',
                              prefixIcon: Icon(Icons.access_time_outlined),
                            ),
                            child: Text(
                              '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Имя клиента',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phone,
                          decoration: const InputDecoration(
                            labelText: 'Телефон',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: car,
                    decoration: const InputDecoration(labelText: 'Автомобиль'),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: activePerformers.isEmpty
                        ? null
                        : () => selectPerformers(setDialog),
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Исполнители',
                        helperText: 'Выберите активные аккаунты CRM',
                        suffixIcon: Icon(Icons.expand_more),
                      ),
                      child: Text(
                        performer.text.isEmpty ? 'Не выбраны' : performer.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: duration,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Длительность, часов',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Статус клиента / заказа',
                    ),
                    items: clientStatuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setDialog(() => status = v ?? status),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: source,
                    decoration: const InputDecoration(
                      labelText: 'Откуда записан',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Услуги и товары',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Выберите услугу или товар и укажите цену',
                    style: TextStyle(fontSize: 12),
                  ),
                  ...rows.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 540;
                          final typePicker = DropdownButtonFormField<String>(
                            initialValue: entry.value['type'] as String,
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: 'Тип',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Услуга',
                                child: Text('Услуга'),
                              ),
                              DropdownMenuItem(
                                value: 'Товар',
                                child: Text('Товар'),
                              ),
                            ],
                            onChanged: (v) => setDialog(() {
                              entry.value['type'] = v ?? 'Услуга';
                              applyServiceDurationTemplates();
                            }),
                          );
                          final itemPicker = entry.value['type'] == 'Услуга'
                              ? DropdownButtonFormField<String>(
                                  initialValue: _serviceByName(
                                    (entry.value['name']
                                            as TextEditingController)
                                        .text,
                                  )?.name,
                                  isDense: true,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  hint: const Text('Выберите услугу'),
                                  items: _activeServiceCatalog
                                      .map(
                                        (catalog) => DropdownMenuItem(
                                          value: catalog.name,
                                          child: Text(
                                            catalog.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (selected) => setDialog(() {
                                    final catalog = _serviceByName(
                                      selected ?? '',
                                    );
                                    (entry.value['name']
                                                as TextEditingController)
                                            .text =
                                        catalog?.name ?? '';
                                    applyServiceDurationTemplates();
                                  }),
                                )
                              : DropdownButtonFormField<String>(
                                  initialValue:
                                      stockItems.any(
                                        (stock) =>
                                            stock.name ==
                                            (entry.value['name']
                                                    as TextEditingController)
                                                .text,
                                      )
                                      ? (entry.value['name']
                                                as TextEditingController)
                                            .text
                                      : null,
                                  isDense: true,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  hint: const Text('Выберите товар'),
                                  items: stockItems
                                      .map(
                                        (stock) => DropdownMenuItem(
                                          value: stock.name,
                                          child: Text(stock.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (selected) => setDialog(() {
                                    (entry.value['name']
                                                as TextEditingController)
                                            .text =
                                        selected ?? '';
                                  }),
                                );
                          final priceField = TextField(
                            controller:
                                entry.value['price'] as TextEditingController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Цена, ₽',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (_) => setDialog(() {}),
                          );
                          final addButton = IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFFF28C28),
                              size: 20,
                            ),
                            onPressed: () => setDialog(
                              () => rows.add({
                                'type': 'Услуга',
                                'name': TextEditingController(),
                                'price': TextEditingController(),
                              }),
                            ),
                          );
                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                typePicker,
                                const SizedBox(height: 8),
                                itemPicker,
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: priceField),
                                    const SizedBox(width: 4),
                                    addButton,
                                  ],
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              SizedBox(width: 92, child: typePicker),
                              const SizedBox(width: 8),
                              Expanded(child: itemPicker),
                              const SizedBox(width: 12),
                              SizedBox(width: 130, child: priceField),
                              SizedBox(width: 40, child: addButton),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Заметка'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final invalidService = rows.any(
      (row) =>
          row['type'] == 'Услуга' &&
          (_serviceByName((row['name'] as TextEditingController).text) ==
                  null ||
              _serviceByName(
                (row['name'] as TextEditingController).text,
              )!.archived),
    );
    if (invalidService) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Выберите услугу из активного справочника'),
          ),
        );
      }
      return;
    }
    final serviceWithoutPrice = rows.any((row) {
      if (row['type'] != 'Услуга') return false;
      return _num((row['price'] as TextEditingController).text) <= 0;
    });
    if (serviceWithoutPrice) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите цену услуги вручную')),
        );
      }
      return;
    }
    final durationHours = _num(duration.text).clamp(.25, 24).toDouble();
    final endsAt = when.add(Duration(minutes: (durationHours * 60).round()));
    final candidateVehicleId = _candidateVehicleId(
      name: name.text,
      phone: phone.text,
      car: car.text,
    );
    final conflict = _calendarConflict(
      when,
      endsAt,
      ignoreId: event?['id']?.toString(),
      performer: performer.text,
      vehicleId: candidateVehicleId,
      vehicle: car.text,
    );
    if (conflict != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_calendarConflictText(conflict))),
        );
      }
      return;
    }
    final summary = [
      service.text.trim(),
      name.text.trim(),
    ].where((x) => x.isNotEmpty).join(' — ');
    final totalCost = rows
        .map((r) => _num((r['price'] as TextEditingController).text))
        .fold<double>(0, (a, b) => a + b);
    final servicesText = rows
        .map(
          (r) =>
              '${r['type']}: ${(r['name'] as TextEditingController).text.trim()}',
        )
        .where((x) => x.split(': ').last.isNotEmpty)
        .join(' + ');
    final itemsText = rows
        .map((r) {
          final itemName = (r['name'] as TextEditingController).text.trim();
          final itemPrice = (r['price'] as TextEditingController).text.trim();
          if (itemName.isEmpty) return '';
          return '${r['type']}: $itemName${itemPrice.isNotEmpty ? ' — $itemPrice ₽' : ''}';
        })
        .where((x) => x.isNotEmpty)
        .join('\n');
    final clientId = _upsertClient(
      name: name.text,
      phone: phone.text,
      car: car.text,
      source: source.text,
      note: note.text,
    );
    final appointmentClient = clients.cast<Client?>().firstWhere(
      (client) => client?.id == clientId,
      orElse: () => null,
    );
    final body = jsonEncode({
      'summary': (servicesText.isEmpty ? summary : servicesText).isEmpty
          ? 'Запись'
          : (servicesText.isEmpty ? summary : servicesText),
      'description': _appointmentDescription(
        name: name.text,
        source: source.text,
        car: car.text,
        service: servicesText.isEmpty ? service.text : servicesText,
        cost: totalCost > 0 ? totalCost.toStringAsFixed(0) : cost.text,
        phone: phone.text,
        note: note.text,
        performer: performer.text,
      ),
      'extendedProperties': {
        'private': {
          'clientId': clientId,
          'dealId': event?['extendedProperties'] is Map
              ? (((event?['extendedProperties'] as Map)['private']
                        as Map?)?['dealId'] ??
                    '')
              : '',
          'name': name.text.trim(),
          'source': source.text.trim(),
          'car': car.text.trim(),
          'vehicleId': appointmentClient?.vehicleIdFor(car.text) ?? '',
          'createdBy': private['createdBy']?.toString().isNotEmpty == true
              ? private['createdBy'].toString()
              : currentUserId,
          'createdAt': private['createdAt']?.toString().isNotEmpty == true
              ? private['createdAt'].toString()
              : DateTime.now().toIso8601String(),
          'performer': performer.text.trim(),
          'service': servicesText.isEmpty ? service.text.trim() : servicesText,
          'cost': totalCost > 0
              ? totalCost.toStringAsFixed(0)
              : cost.text.trim(),
          'status': status,
          'bookingType': rows.map((r) => r['type']).join(', '),
          'phone': phone.text.trim(),
          'note': note.text.trim(),
          'duration': duration.text.trim().isEmpty ? '1' : duration.text.trim(),
        },
      },
      'start': {'dateTime': _moscowIso(when), 'timeZone': 'Europe/Moscow'},
      'end': {'dateTime': _moscowIso(endsAt), 'timeZone': 'Europe/Moscow'},
      'reminders': {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 120},
          {'method': 'email', 'minutes': 1440},
        ],
      },
    });
    final id = event?['id']?.toString();
    if (!_usesGoogleCalendar) {
      final saved = Map<String, dynamic>.from(jsonDecode(body) as Map);
      final savedId =
          id ?? 'appointment-${DateTime.now().microsecondsSinceEpoch}';
      saved['id'] = savedId;
      saved['updated'] = DateTime.now().toIso8601String();
      if (mounted) {
        setState(() {
          calendarViewDate = DateTime(when.year, when.month);
          selectedCalendarDay = DateTime(when.year, when.month, when.day);
          final index = calendarEvents.indexWhere(
            (item) => item['id']?.toString() == savedId,
          );
          if (index >= 0) {
            calendarEvents[index] = saved;
          } else {
            calendarEvents.add(saved);
          }
          calendarStatus = 'Запись сохранена в общей CRM.';
        });
      }
      await prefs.setString(
        'calendar_events_cache',
        jsonEncode(calendarEvents),
      );
      await _recordIncomingAppointments(calendarEvents);
      _audit(id == null ? 'Создана' : 'Изменена', 'Запись', name.text.trim());
      _enqueueCloudSnapshot(
        'Запись',
        '${id == null ? 'Создана' : 'Изменена'} запись ${name.text.trim()}',
      );
      String? vkError;
      if (id == null) {
        _lastVkMessageId = null;
        vkError = await _notifyVkAboutAppointment(
          when: when,
          name: name.text,
          source: source.text,
          car: car.text,
          service: service.text,
          cost: totalCost > 0 ? totalCost.toStringAsFixed(0) : cost.text,
          phone: phone.text,
          note: note.text,
          items: itemsText,
          performer: performer.text,
        );
        if (vkError == null && _lastVkMessageId != null) {
          await prefs.setInt(
            'messenger_vk_appointment_$savedId',
            _lastVkMessageId!,
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              vkError == null
                  ? 'Запись сохранена и будет синхронизирована'
                  : 'Запись сохранена, но ВК: $vkError',
            ),
          ),
        );
      }
      return;
    }
    final base =
        'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events';
    final uri = Uri.parse(
      id == null ? base : '$base/${Uri.encodeComponent(id)}',
    );
    try {
      Future<http.Response> saveRequest() => id == null
          ? _apiClient.post(
              uri,
              headers: {
                'Authorization': 'Bearer $calendarAccessToken',
                'Content-Type': 'application/json',
              },
              body: body,
            )
          : _apiClient.patch(
              uri,
              headers: {
                'Authorization': 'Bearer $calendarAccessToken',
                'Content-Type': 'application/json',
              },
              body: body,
            );
      var res = await saveRequest();
      if (res.statusCode == 401 && await _refreshCalendarAccessToken()) {
        res = await saveRequest();
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final saved = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            calendarViewDate = DateTime(when.year, when.month);
            selectedCalendarDay = DateTime(when.year, when.month, when.day);
            final savedId = saved['id']?.toString();
            if (savedId != null) {
              final index = calendarEvents.indexWhere(
                (item) => item['id']?.toString() == savedId,
              );
              if (index >= 0) {
                calendarEvents[index] = saved;
              } else {
                calendarEvents.add(saved);
              }
            }
            calendarStatus =
                'Запись сохранена в «$calendarName». Обновляю календарь…';
          });
        }
        _audit(id == null ? 'Создана' : 'Изменена', 'Запись', name.text.trim());
        await _loadCalendarEvents();
        String? vkError;
        if (id == null) {
          _lastVkMessageId = null;
          vkError = await _notifyVkAboutAppointment(
            when: when,
            name: name.text,
            source: source.text,
            car: car.text,
            service: service.text,
            cost: totalCost > 0 ? totalCost.toStringAsFixed(0) : cost.text,
            phone: phone.text,
            note: note.text,
            items: itemsText,
            performer: performer.text,
          );
          final savedId = saved['id']?.toString();
          if (vkError == null && savedId != null && _lastVkMessageId != null) {
            await prefs.setInt(
              'messenger_vk_appointment_$savedId',
              _lastVkMessageId!,
            );
          }
        } else if (status != 'Записан' && status != originalStatus) {
          await _removeVkAppointmentMessage(id);
        } else if (status == 'Записан') {
          // Перенос/изменение записи: старое уведомление заменяется новым.
          await _removeVkAppointmentMessage(id);
          _lastVkMessageId = null;
          vkError = await _notifyVkAboutAppointment(
            when: when,
            name: name.text,
            source: source.text,
            car: car.text,
            service: service.text,
            cost: totalCost > 0 ? totalCost.toStringAsFixed(0) : cost.text,
            phone: phone.text,
            note: note.text,
            items: itemsText,
            performer: performer.text,
          );
          if (vkError == null && _lastVkMessageId != null) {
            await prefs.setInt(
              'messenger_vk_appointment_$id',
              _lastVkMessageId!,
            );
          }
        }
        await _sendVkAppointmentsSummary();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                vkError == null
                    ? 'Запись добавлена в Google Календарь'
                    : 'Запись сохранена, но ВК: $vkError',
              ),
            ),
          );
        }
      } else {
        final error = _googleCalendarError(res);
        if (mounted) {
          setState(() => calendarStatus = error);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      }
    } catch (_) {
      if (mounted) {
        const error =
            'Нет соединения с Google Календарём. Проверьте интернет и повторите.';
        setState(() => calendarStatus = error);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(error)));
      }
    }
  }

  Future<void> _deleteCalendarEvent(
    Map<String, dynamic> event, {
    required String archivedStatus,
    String reason = '',
  }) async {
    if (!_canEdit('calendar')) return;
    final id = event['id']?.toString();
    if (id == null) return;
    if (!_usesGoogleCalendar) {
      calendarEvents.removeWhere((item) => item['id']?.toString() == id);
      archivedCalendarEvents.add({
        ...event,
        'archivedStatus': archivedStatus,
        'archivedAt': DateTime.now().toIso8601String(),
        'cancellationReason': reason,
      });
      await prefs.setString(
        'calendar_events_cache',
        jsonEncode(calendarEvents),
      );
      _audit(
        archivedStatus == 'Выполнен' ? 'Завершена' : 'Отменена',
        'Запись',
        '${event['summary'] ?? 'Запись'}${reason.isEmpty ? '' : ': $reason'}',
      );
      _enqueueCloudSnapshot(
        'Запись',
        '$archivedStatus: ${event['summary'] ?? 'Запись'}',
      );
      return;
    }
    final base =
        'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events';
    var res = await _apiClient.delete(
      Uri.parse('$base/${Uri.encodeComponent(id)}'),
      headers: {'Authorization': 'Bearer $calendarAccessToken'},
    );
    if (res.statusCode == 401 && await _refreshCalendarAccessToken()) {
      res = await _apiClient.delete(
        Uri.parse('$base/${Uri.encodeComponent(id)}'),
        headers: {'Authorization': 'Bearer $calendarAccessToken'},
      );
    }
    if (res.statusCode == 204) {
      calendarEvents.removeWhere((item) => item['id']?.toString() == id);
      archivedCalendarEvents.add({
        ...event,
        'archivedStatus': archivedStatus,
        'archivedAt': DateTime.now().toIso8601String(),
        'cancellationReason': reason,
      });
      await _removeVkAppointmentMessage(id);
      _audit(
        archivedStatus == 'Выполнен' ? 'Завершена' : 'Отменена',
        'Запись',
        '${event['summary'] ?? 'Запись'}${reason.isEmpty ? '' : ': $reason'}',
      );
      await _loadCalendarEvents();
    }
  }

  Future<void> _cancelCalendarEvent(
    Map<String, dynamic> event, {
    String status = 'Отменена',
  }) async {
    if (!_canEdit('calendar')) return;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text(
            status == 'Не приехал' ? 'Клиент не приехал' : 'Отменить запись?',
          ),
          content: TextField(
            controller: reason,
            autofocus: true,
            maxLines: 2,
            onChanged: (_) => refresh(() {}),
            decoration: const InputDecoration(labelText: 'Причина отмены'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Назад'),
            ),
            ElevatedButton(
              onPressed: isCancellationReasonValid(reason.text)
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Подтвердить'),
            ),
          ],
        ),
      ),
    );
    final value = reason.text.trim();
    reason.dispose();
    if (confirmed != true || value.isEmpty) return;
    await _deleteCalendarEvent(event, archivedStatus: status, reason: value);
  }

  Future<void> _showAppointmentActions(Map<String, dynamic> event) async {
    final action = await showDialog<CalendarAppointmentAction>(
      context: context,
      builder: (_) => CalendarAppointmentDialog(
        event: event,
        timeLabel: _eventTime,
        canEdit: _canEdit('calendar'),
        mainTextColor: _mainTextColor,
        mutedTextColor: _mutedTextColor,
      ),
    );
    if (!mounted || action == null) return;
    if (action == CalendarAppointmentAction.move) {
      await _editCalendarEvent(event);
      return;
    }
    if (action == CalendarAppointmentAction.arrived) {
      final added = await _addManualDeal(event);
      if (added) {
        await _deleteCalendarEvent(
          event,
          archivedStatus: 'Выполнен',
          reason: 'Сделка создана в CRM',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Сделка добавлена, запись и сообщение ВК удалены.'),
            ),
          );
        }
      }
    } else {
      await _cancelCalendarEvent(event, status: 'Не приехал');
    }
  }

  Widget _appointments() {
    return _calendarWorkspace();
  }

  Future<void> _calendarSettings() async {
    final action = await showDialog<CalendarSettingsAction>(
      context: context,
      builder: (_) => CalendarSettingsDialog(
        calendarName: calendarName,
        status: calendarStatus,
        canConfigure: canManageIntegrations,
        hasClientSecret: calendarClientSecret.isNotEmpty,
      ),
    );
    if (!mounted) return;
    switch (action) {
      case CalendarSettingsAction.choose:
        unawaited(_chooseCalendar());
      case CalendarSettingsAction.refresh:
        unawaited(_loadCalendarEvents());
      case CalendarSettingsAction.reconnect:
        unawaited(_connectCalendar());
      case CalendarSettingsAction.configureSecret:
        unawaited(_configureCalendarClientSecret());
      case null:
        break;
    }
  }

  Widget _calendarEventTile(Map<String, dynamic> event) => CalendarEventTile(
    event: event,
    selectedDay: selectedCalendarDay,
    mainTextColor: _mainTextColor,
    mutedTextColor: _mutedTextColor,
    canEdit: _canEdit('calendar'),
    timeLabel: _eventTime,
    onOpen: _showAppointmentActions,
    onEdit: _editCalendarEvent,
    onCancel: _cancelCalendarEvent,
    onRepeat: _repeatCalendarEvent,
    onMoveToDay: _moveEventToDay,
  );

  Future<void> _repeatCalendarEvent(Map<String, dynamic> event) async {
    if (!_canEdit('calendar')) return;
    final start = _eventStart(event);
    if (start == null) return;
    final end = _eventEnd(event) ?? start.add(const Duration(hours: 1));
    final copy = Map<String, dynamic>.from(event)
      ..remove('id')
      ..remove('etag')
      ..remove('htmlLink');
    final shiftedStart = start.add(const Duration(days: 7));
    final shiftedEnd = end.add(const Duration(days: 7));
    copy['start'] = {
      'dateTime': _moscowIso(shiftedStart),
      'timeZone': 'Europe/Moscow',
    };
    copy['end'] = {
      'dateTime': _moscowIso(shiftedEnd),
      'timeZone': 'Europe/Moscow',
    };
    await _editCalendarEvent(copy);
  }

  Future<void> _moveEventToDay(Map<String, dynamic> event, DateTime day) async {
    final start = _eventStart(event);
    if (start == null || !_canEdit('calendar')) return;
    final shifted = DateTime(
      day.year,
      day.month,
      day.day,
      start.hour,
      start.minute,
    );
    final private =
        ((event['extendedProperties'] as Map?)?['private'] as Map?) ?? {};
    final hours = (_num(
      private['duration']?.toString() ?? '1',
    )).clamp(.25, 24).toDouble();
    final conflict = _calendarConflict(
      shifted,
      shifted.add(Duration(minutes: (hours * 60).round())),
      ignoreId: event['id']?.toString(),
      performer: private['performer']?.toString() ?? '',
      vehicleId: private['vehicleId']?.toString() ?? '',
      vehicle: private['car']?.toString() ?? '',
    );
    if (conflict != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_calendarConflictText(conflict))),
        );
      }
      return;
    }
    final id = event['id']?.toString();
    if (id == null || calendarAccessToken == null) return;
    final uri = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events/${Uri.encodeComponent(id)}',
    );
    final response = await _apiClient.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $calendarAccessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'start': {'dateTime': _moscowIso(shifted), 'timeZone': 'Europe/Moscow'},
        'end': {
          'dateTime': _moscowIso(
            shifted.add(Duration(minutes: (hours * 60).round())),
          ),
          'timeZone': 'Europe/Moscow',
        },
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await _loadCalendarEvents();
    }
  }

  List<Map<String, dynamic>> get _visibleCalendarEvents {
    return filterCalendarEvents(calendarEvents, calendarSearch);
  }

  List<Map<String, dynamic>> _eventsFor(DateTime day) =>
      calendarEventsForDay(_visibleCalendarEvents, day);
  void _moveCalendar(int amount) {
    setState(() {
      calendarViewDate = DateTime(
        calendarViewDate.year,
        calendarViewDate.month + amount,
      );
      if (calendarViewMode == 'Месяц') {
        selectedCalendarDay = DateTime(
          calendarViewDate.year,
          calendarViewDate.month,
          1,
        );
      } else {
        selectedCalendarDay = selectedCalendarDay.add(
          Duration(days: amount * (calendarViewMode == 'Неделя' ? 7 : 1)),
        );
      }
    });
  }

  Widget _calendarWorkspace() {
    final selectedEvents = _eventsFor(selectedCalendarDay);
    return CalendarWorkspace(
      calendarName: _usesGoogleCalendar ? calendarName : 'Общие записи CRM',
      viewMode: calendarViewMode,
      viewDate: calendarViewDate,
      selectedDay: selectedCalendarDay,
      selectedDayEventCount: selectedEvents.length,
      canEdit: _canEdit('calendar'),
      surfaceColor: _surfaceColor,
      borderColor: _cardBorderColor,
      mainTextColor: _mainTextColor,
      mutedTextColor: _mutedTextColor,
      calendarBody: switch (calendarViewMode) {
        'Месяц' => _monthCalendar(),
        'Неделя' => _weekCalendar(),
        'День' => _dayCalendar(),
        _ => _calendarList(),
      },
      selectedDayTiles: selectedEvents.map(_calendarEventTile).toList(),
      onNewAppointment: () => _editCalendarEvent(),
      onOpenSettings: _calendarSettings,
      onMove: _moveCalendar,
      onToday: () => setState(() {
        calendarViewDate = DateTime(now.year, now.month);
        selectedCalendarDay = DateTime(now.year, now.month, now.day);
      }),
      onViewModeChanged: (mode) => setState(() => calendarViewMode = mode),
      onSearchChanged: (value) {
        calendarSearchDebounce?.cancel();
        calendarSearchDebounce = Timer(AppConstants.searchDebounce, () {
          if (mounted) setState(() => calendarSearch = value);
        });
      },
    );
  }

  Widget _monthCalendar() {
    final first = DateTime(calendarViewDate.year, calendarViewDate.month, 1);
    final daysInMonth = DateTime(
      calendarViewDate.year,
      calendarViewDate.month + 1,
      0,
    ).day;
    final weekCount = ((first.weekday - 1 + daysInMonth + 6) ~/ 7);
    final cellCount = weekCount * 7;
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return Column(
      children: [
        Row(
          children: [
            for (final day in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      color: _mutedTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // Ограничиваем высоту строки: весь месяц (включая 31 число)
            // должен помещаться в рабочую область без вертикального скролла.
            final cellHeight = ((constraints.maxWidth / 7) / 1.55).clamp(
              54.0,
              76.0,
            );
            final ratio = constraints.maxWidth / 7 / cellHeight;
            return SizedBox(
              height: weekCount * cellHeight + 2,
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 7,
                childAspectRatio: ratio,
                children: [
                  for (var i = 0; i < cellCount; i++)
                    _monthDayCell(
                      i < first.weekday - 1 ||
                              i >= first.weekday - 1 + daysInMonth
                          ? null
                          : DateTime(
                              calendarViewDate.year,
                              calendarViewDate.month,
                              i - (first.weekday - 1) + 1,
                            ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _monthDayCell(DateTime? day) {
    if (day == null) return const SizedBox();
    final events = _eventsFor(day);
    final picked = isSameCalendarDay(day, selectedCalendarDay);
    final today = isSameCalendarDay(day, DateTime.now());
    final compact = MediaQuery.sizeOf(context).width < 600;
    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) => _moveEventToDay(details.data, day),
      builder: (context, candidate, rejected) => InkWell(
        onTap: () => setState(() => selectedCalendarDay = day),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: EdgeInsets.all(compact ? 4 : 6),
          decoration: BoxDecoration(
            color: picked ? const Color(0xFFF28C28) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: picked ? const Color(0xFFF28C28) : _cardBorderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 23,
                  height: 23,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: today ? const Color(0xFFF28C28) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: (today || picked) ? Colors.white : _mainTextColor,
                    ),
                  ),
                ),
              ),
              if (compact && events.isNotEmpty)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF28C28),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                for (final e in events.take(1))
                  InkWell(
                    onTap: () => _showAppointmentActions(e),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF28C28),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        e['summary']?.toString() ?? 'Запись',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              if (!compact && events.length > 2)
                Text(
                  '+ ещё ${events.length - 2}',
                  style: TextStyle(fontSize: 10, color: _mutedTextColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekCalendar() {
    final monday = selectedCalendarDay.subtract(
      Duration(days: selectedCalendarDay.weekday - 1),
    );
    const names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return SizedBox(
      height: 300,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _weekDayCell(monday.add(Duration(days: i)), names[i]),
            ),
        ],
      ),
    );
  }

  Widget _weekDayCell(DateTime day, String name) {
    final events = _eventsFor(day);
    return InkWell(
      onTap: () => setState(() => selectedCalendarDay = day),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSameCalendarDay(day, selectedCalendarDay)
              ? const Color(0xFFF28C28)
              : (widget.darkMode
                    ? const Color(0xFF1C1F25)
                    : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _cardBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name ${day.day}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSameCalendarDay(day, selectedCalendarDay)
                    ? Colors.white
                    : _mainTextColor,
              ),
            ),
            const SizedBox(height: 8),
            for (final e in events)
              InkWell(
                onTap: () => _showAppointmentActions(e),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF28C28),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    e['summary']?.toString() ?? 'Запись',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _calendarList() {
    final events = _visibleCalendarEvents;
    return SizedBox(
      height: 320,
      child: events.isEmpty
          ? const Center(child: Text('Записей по вашему запросу нет.'))
          : ListView(children: events.map(_calendarEventTile).toList()),
    );
  }

  Widget _dayCalendar() {
    final events = _eventsFor(selectedCalendarDay);
    return SizedBox(
      height: 320,
      child: events.isEmpty
          ? const Center(child: Text('На выбранный день записей нет.'))
          : ListView.separated(
              itemCount: events.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) => _calendarEventTile(events[index]),
            ),
    );
  }

  Future<void> _setupMessenger(String channel) async {
    if (!canManageIntegrations) return;
    final names = {
      'telegram': 'Telegram',
      'vk': 'ВКонтакте',
      'instagram': 'Instagram',
    };
    final token = TextEditingController(text: _messengerToken(channel));
    final usesServerToken =
        _session != null &&
        messengerConnected[channel] == true &&
        _messengerToken(channel).isEmpty;
    final account = TextEditingController(
      text: prefs.getString('messenger_${channel}_account') ?? '',
    );
    final vkNotifyPeer = TextEditingController(
      text: prefs.getString('messenger_vk_notify_peer') ?? '',
    );
    void disposeControllers() {
      token.dispose();
      account.dispose();
      vkNotifyPeer.dispose();
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Подключить ${names[channel]}'),
        content: SizedBox(
          width: 470,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channel == 'telegram'
                    ? 'Создайте бота через @BotFather и вставьте его токен.'
                    : channel == 'vk'
                    ? 'Нужен именно ключ доступа сообщества и его числовой ID. В сообществе должны быть включены «Сообщения» и Long Poll API.'
                    : 'Нужны токен доступа и ID профессионального Instagram-аккаунта. Для входящих сообщений дополнительно потребуется сервер с webhook.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: token,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: channel == 'telegram'
                      ? 'Токен бота'
                      : 'Токен доступа',
                  prefixIcon: const Icon(Icons.key_outlined),
                  helperText: usesServerToken
                      ? 'Токен хранится на CRM-сервере. Введите новый только для замены.'
                      : null,
                ),
              ),
              if (channel != 'telegram')
                TextField(
                  controller: account,
                  decoration: InputDecoration(
                    labelText: channel == 'vk'
                        ? 'ID сообщества (только цифры, без club)'
                        : 'Instagram User ID',
                    prefixIcon: const Icon(Icons.tag_outlined),
                  ),
                ),
              if (channel == 'vk')
                TextField(
                  controller: vkNotifyPeer,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ID беседы для уведомлений',
                    hintText: 'Можно выбрать чат ниже после подключения',
                    prefixIcon: Icon(Icons.notifications_active_outlined),
                  ),
                ),
              if (channel == 'instagram')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(
                        'https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login/',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Открыть инструкцию Meta'),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Проверить и подключить'),
          ),
        ],
      ),
    );
    if (accepted != true || (token.text.trim().isEmpty && !usesServerToken)) {
      disposeControllers();
      return;
    }
    if (mounted) {
      setState(() => messengerStatus[channel] = 'Проверяю подключение…');
    }
    bool success = false;
    String status = 'Не удалось проверить доступ. Проверьте токен.';
    try {
      late http.Response res;
      if (usesServerToken) {
        success = true;
        status = 'Подключён через CRM-сервер';
      } else if (channel == 'telegram') {
        res = await _apiClient.get(
          Uri.parse('https://api.telegram.org/bot${token.text.trim()}/getMe'),
        );
      } else if (channel == 'vk') {
        var groupId = account.text.trim();
        groupId = groupId.replaceFirst(
          RegExp(r'^(club|public)', caseSensitive: false),
          '',
        );
        if (groupId.isEmpty || !RegExp(r'^\d+$').hasMatch(groupId)) {
          throw Exception(
            'Укажите числовой ID сообщества, например 123456789.',
          );
        }
        res = await _apiClient.get(
          Uri.https('api.vk.com', '/method/groups.getById', {
            'access_token': token.text.trim(),
            'group_id': groupId,
            'v': '5.199',
          }),
        );
        final groupData = jsonDecode(res.body) as Map<String, dynamic>;
        if (groupData['error'] != null) {
          final error = groupData['error'] as Map;
          throw Exception(
            'VK ${error['error_code'] ?? ''}: ${error['error_msg'] ?? 'доступ запрещён'}',
          );
        }
        final responseGroup = groupData['response'];
        Map? group;
        if (responseGroup is List && responseGroup.isNotEmpty) {
          group = responseGroup.first as Map?;
        } else if (responseGroup is Map && responseGroup['groups'] is List) {
          final groups = responseGroup['groups'] as List;
          group = groups.isNotEmpty ? groups.first as Map? : null;
        } else if (responseGroup is Map) {
          group = responseGroup;
        }
        final longPoll = await _apiClient.get(
          Uri.https('api.vk.com', '/method/groups.getLongPollServer', {
            'access_token': token.text.trim(),
            'group_id': groupId,
            'v': '5.199',
          }),
        );
        final longPollData = jsonDecode(longPoll.body) as Map<String, dynamic>;
        if (longPollData['error'] != null) {
          final error = longPollData['error'] as Map;
          throw Exception(
            'Токен сообщества верный, но Long Poll API недоступен: ${error['error_msg'] ?? 'включите Long Poll API и права «Сообщения сообщества»'}',
          );
        }
        success = longPollData['response']?['server'] != null;
        status = success
            ? 'Подключён: ${group?['name'] ?? 'сообщество VK'}'
            : 'Long Poll API не вернул сервер.';
        if (success && vkNotifyPeer.text.trim().isNotEmpty) {
          status =
              'Подключён: ${group?['name'] ?? 'сообщество VK'}. Чат уведомлений выбран.';
        }
      } else {
        res = await _apiClient.get(
          Uri.https('graph.instagram.com', '/me', {
            'fields': 'id,username',
            'access_token': token.text.trim(),
          }),
        );
      }
      if (!usesServerToken && channel != 'vk') {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        success =
            res.statusCode == 200 &&
            (channel == 'telegram'
                ? data['ok'] == true
                : !data.containsKey('error'));
        status = success
            ? 'Подключён'
            : (data['error']?['message']?.toString() ??
                  'Не удалось проверить доступ. Проверьте токен.');
      }
    } catch (e) {
      status = e.toString().replaceFirst('Exception: ', '');
    }
    try {
      if (token.text.trim().isNotEmpty) {
        messengerSecrets[channel] = token.text.trim();
        await secretStore.write(
          'messenger_${channel}_token',
          token.text.trim(),
        );
      }
      await prefs.remove('messenger_${channel}_token');
      await prefs.setString(
        'messenger_${channel}_account',
        account.text.trim(),
      );
      if (channel == 'vk') {
        await prefs.setString(
          'messenger_vk_notify_peer',
          vkNotifyPeer.text.trim(),
        );
      }
      await prefs.setBool('messenger_$channel', success);
      await _migrateLocalConfiguration(clearLocalSecrets: false, silent: true);
      _audit(
        success ? 'Подключена интеграция' : 'Ошибка подключения интеграции',
        'Интеграция',
        '${names[channel] ?? channel}: $status',
      );
      if (mounted) {
        setState(() {
          messengerConnected[channel] = success;
          messengerStatus[channel] = status;
        });
      }
      if (channel == 'vk' && success) _loadVkConversations();
      if (channel == 'telegram' && success) _loadTelegramUpdates();
      if (channel == 'instagram' && success) _loadInstagramConversations();
    } finally {
      disposeControllers();
    }
  }

  Map<String, String> _avitoHeaders() => {
    'Authorization': 'Bearer ${avitoAccessToken ?? ''}',
    'Content-Type': 'application/json',
    'Accept': 'application/json, audio/mpeg, audio/wav, */*',
  };

  Future<void> _avitoLog(String text) async {
    // Не выводим токены и тела запросов в stdout; developer log можно
    // отключить на production-сборке, а файл ограничивается диагностикой.
    final safeText = CrmLogger.redact(text);
    CrmLogger.info(safeText, name: 'crm.avito');
    try {
      final file = File('${Directory.systemTemp.path}/crm-avito.log');
      await file.writeAsString(
        '[${DateTime.now().toIso8601String()}] $safeText\n',
        mode: FileMode.append,
        flush: true,
      );
      if (await file.length() > 2 * 1024 * 1024) {
        final content = await file.readAsString();
        await file.writeAsString(content.substring(content.length ~/ 2));
      }
    } catch (_) {}
  }

  Future<http.Response> _avitoGet(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    await _avitoLog('GET $uri\nheaders: ${_safeAvitoHeaders(headers)}');
    final response = await _apiClient.get(uri, headers: headers);
    final type = response.headers['content-type'] ?? '';
    final payload = type.startsWith('audio/')
        ? '<аудиофайл: ${response.bodyBytes.length} байт>'
        : _safeAvitoBody(response.body);
    await _avitoLog('RESPONSE ${response.statusCode} $type\n$payload');
    return response;
  }

  Future<http.Response> _avitoPost(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    await _avitoLog(
      'POST $uri\nheaders: ${_safeAvitoHeaders(headers)}\nbody: ${_safeAvitoBody(body?.toString() ?? '')}',
    );
    final response = await _apiClient.post(uri, headers: headers, body: body);
    final type = response.headers['content-type'] ?? '';
    final payload = type.startsWith('audio/')
        ? '<аудиофайл: ${response.bodyBytes.length} байт>'
        : _safeAvitoBody(response.body);
    await _avitoLog('RESPONSE ${response.statusCode} $type\n$payload');
    return response;
  }

  Map<String, String> _safeAvitoHeaders(Map<String, String>? headers) =>
      (headers ?? {}).map(
        (key, value) => MapEntry(
          key,
          key.toLowerCase() == 'authorization' ? 'Bearer ***' : value,
        ),
      );

  String _safeAvitoBody(String body) {
    final hidden = body.replaceAllMapped(
      RegExp(
        r'''(["']?(?:access_token|refresh_token|client_secret)["']?\s*[:=]\s*["']?)([^,"'&}\s]+)''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}***',
    );
    return hidden.length > 10000 ? '${hidden.substring(0, 10000)}…' : hidden;
  }

  List<Map<String, dynamic>> _avitoList(dynamic data, List<String> keys) {
    dynamic value = data;
    for (final key in keys) {
      if (value is Map && value[key] != null) {
        value = value[key];
        break;
      }
    }
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _connectAvito({bool silent = false, bool sync = true}) async {
    final account = _activeAvitoAccount;
    final clientId = account?['clientId']?.toString() ?? '';
    final clientSecret = account?['clientSecret']?.toString() ?? '';
    if (clientId.isEmpty || clientSecret.isEmpty) return;
    if (mounted) setState(() => avitoLoading = true);
    try {
      final tokenResponse = await _avitoPost(
        Uri.parse('https://api.avito.ru/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'client_credentials',
          'client_id': clientId,
          'client_secret': clientSecret,
        },
      );
      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final token = tokenData['access_token']?.toString();
      if (tokenResponse.statusCode != 200 || token == null || token.isEmpty) {
        throw Exception(
          tokenData['error_description'] ?? 'Не удалось получить токен',
        );
      }
      avitoAccessToken = token;
      final me = await _avitoGet(
        Uri.parse('https://api.avito.ru/core/v1/accounts/self'),
        headers: _avitoHeaders(),
      );
      final meData = jsonDecode(me.body) as Map<String, dynamic>;
      final userId = meData['id'] ?? meData['user_id'] ?? meData['user']?['id'];
      if (me.statusCode != 200 || userId == null) {
        throw Exception('Не удалось получить данные профиля Avito');
      }
      avitoUserId = userId.toString();
      avitoConnected = true;
      if (account != null) {
        account['userId'] = avitoUserId!;
        if ((account['name']?.toString().trim() ?? '').isEmpty) {
          account['name'] = 'Аккаунт $avitoUserId';
        }
      }
      avitoStatus = 'Подключён • ${account?['name'] ?? 'аккаунт $avitoUserId'}';
      await _saveAvitoAccounts();
      if (sync) await _syncAvito(silent: silent);
    } catch (e) {
      avitoConnected = false;
      avitoStatus =
          'Ошибка подключения: ${e.toString().replaceFirst('Exception: ', '')}';
      if (mounted && !silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(avitoStatus)));
      }
    } finally {
      if (mounted) setState(() => avitoLoading = false);
    }
  }

  Future<bool> _refreshAvitoTokenOnly() async {
    final account = _activeAvitoAccount;
    final clientId = account?['clientId']?.toString() ?? '';
    final clientSecret = account?['clientSecret']?.toString() ?? '';
    if (clientId.isEmpty || clientSecret.isEmpty) return false;
    final response = await _avitoPost(
      Uri.parse('https://api.avito.ru/token/'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: {
        'grant_type': 'client_credentials',
        'client_id': clientId,
        'client_secret': clientSecret,
      },
    );
    if (response.statusCode != 200) return false;
    final body = jsonDecode(response.body);
    final token = body is Map ? body['access_token']?.toString() : null;
    if (token == null || token.isEmpty) return false;
    avitoAccessToken = token;
    return true;
  }

  Future<void> _syncAvito({bool silent = false}) async {
    if (avitoAccessToken == null || avitoUserId == null) return;
    if (mounted) setState(() => avitoLoading = true);
    try {
      final chatsResponse = await _avitoGet(
        Uri.https('api.avito.ru', '/messenger/v2/accounts/$avitoUserId/chats', {
          'limit': '100',
          'offset': '0',
        }),
        headers: _avitoHeaders(),
      );
      if (chatsResponse.statusCode == 200) {
        final body = jsonDecode(chatsResponse.body);
        avitoChats = _avitoList(body, ['chats']);
      }
      final until = DateTime.now().toUtc();
      final since = until.subtract(const Duration(days: 30));
      final callsResponse = await _avitoPost(
        Uri.parse('https://api.avito.ru/calltracking/v1/getCalls/'),
        headers: _avitoHeaders(),
        body: jsonEncode({
          'dateTimeFrom': since.toIso8601String(),
          'dateTimeTo': until.toIso8601String(),
          'limit': 100,
          'offset': 0,
        }),
      );
      if (callsResponse.statusCode == 200) {
        final body = jsonDecode(callsResponse.body);
        avitoCalls = _avitoList(body, ['calls', 'result']);
        if (aiSettings.enabled && aiApiKey.trim().isNotEmpty) {
          unawaited(_autoProcessAvitoCalls());
        } else {
          unawaited(_cacheAllAvitoCalls());
        }
      }
      if (chatsResponse.statusCode != 200 && callsResponse.statusCode != 200) {
        throw Exception('Avito не дал доступ к чатам и звонкам');
      }
      avitoStatus =
          'Подключён • чатов: ${avitoChats.length} • звонков: ${avitoCalls.length}';
      final account = _activeAvitoAccount;
      if (account != null) account['status'] = avitoStatus;
      await _saveAvitoAccounts();
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avito: данные обновлены')),
        );
      }
    } catch (e) {
      avitoStatus =
          'Ошибка синхронизации: ${e.toString().replaceFirst('Exception: ', '')}';
    } finally {
      if (mounted) setState(() => avitoLoading = false);
    }
  }

  Future<void> _openAvitoChat(Map<String, dynamic> chat) async {
    final id = chat['id']?.toString();
    if (id == null || avitoUserId == null) return;
    readMessageDialogs.add('Avito:$id');
    await _saveMessageMeta();
    if (!mounted) return;
    setState(() {
      selectedAvitoChat = chat;
      avitoChatMessages = [];
      avitoLoading = true;
    });
    try {
      final response = await _avitoGet(
        Uri.https(
          'api.avito.ru',
          '/messenger/v3/accounts/$avitoUserId/chats/$id/messages/',
          {'limit': '100', 'offset': '0'},
        ),
        headers: _avitoHeaders(),
      );
      if (response.statusCode != 200) {
        throw Exception('Не удалось загрузить сообщения');
      }
      final body = jsonDecode(response.body);
      avitoChatMessages = _avitoList(body, ['messages']);
      await _avitoPost(
        Uri.parse(
          'https://api.avito.ru/messenger/v1/accounts/$avitoUserId/chats/$id/read',
        ),
        headers: _avitoHeaders(),
      );
    } catch (e) {
      avitoStatus =
          'Ошибка чата: ${e.toString().replaceFirst('Exception: ', '')}';
    } finally {
      if (mounted) setState(() => avitoLoading = false);
    }
  }

  Future<void> _sendAvitoMessage() async {
    if (!_canEdit('messages')) return;
    final text = avitoReplyController.text.trim();
    final chatId = selectedAvitoChat?['id']?.toString();
    if (text.isEmpty || chatId == null || avitoUserId == null) return;
    try {
      final response = await _withRetry(
        () => _avitoPost(
          Uri.parse(
            'https://api.avito.ru/messenger/v1/accounts/$avitoUserId/chats/$chatId/messages',
          ),
          headers: _avitoHeaders(),
          body: jsonEncode({
            'type': 'text',
            'message': {'text': text},
          }),
        ),
      );
      if (response.statusCode != 200) {
        throw Exception('Avito не принял сообщение');
      }
      avitoReplyController.clear();
      await _openAvitoChat(selectedAvitoChat!);
    } catch (e) {
      await _enqueuePendingMessage({
        'channel': 'avito',
        'account': avitoUserId ?? '',
        'chat': chatId,
        'text': text,
      });
      await _saveMessageMeta();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  String? _avitoCallId(Map<String, dynamic> call) {
    // CallTracking API принимает именно числовой callId (не id объявления,
    // не UUID и не строковый идентификатор другого сервиса).
    for (final key in ['callId', 'call_id', 'id']) {
      final value = call[key]?.toString();
      if (value != null &&
          int.tryParse(value) != null &&
          int.parse(value) > 0) {
        return value;
      }
    }
    final nested = call['call'];
    if (nested is Map) {
      for (final key in ['callId', 'call_id', 'id']) {
        final value = nested[key]?.toString();
        if (value != null &&
            int.tryParse(value) != null &&
            int.parse(value) > 0) {
          return value;
        }
      }
    }
    return null;
  }

  String? _avitoRecordUrl(dynamic value) {
    if (value is Map) {
      for (final key in [
        'url',
        'recordUrl',
        'record_url',
        'downloadUrl',
        'download_url',
      ]) {
        final url = value[key]?.toString();
        if (url != null && Uri.tryParse(url)?.hasScheme == true) return url;
      }
      for (final child in value.values) {
        final url = _avitoRecordUrl(child);
        if (url != null) return url;
      }
    }
    if (value is List) {
      for (final child in value) {
        final url = _avitoRecordUrl(child);
        if (url != null) return url;
      }
    }
    return null;
  }

  String _avitoErrorText(http.Response response) {
    String? internalCode;
    String? message;
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map) {
        internalCode = payload['code']?.toString();
        message = payload['message']?.toString();
        final errorObject = payload['error'];
        if (errorObject is Map) {
          internalCode ??= errorObject['code']?.toString();
          message ??= errorObject['message']?.toString();
        }
        final errors = payload['errors'];
        if (errors is List && errors.isNotEmpty) {
          final listMessage = errors
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .join(', ');
          if (listMessage.isNotEmpty) message ??= listMessage;
        }
        for (final key in [
          'message',
          'error_description',
          'error',
          'description',
          'detail',
        ]) {
          final value = payload[key];
          if (value is String && value.trim().isNotEmpty) {
            message ??= value.trim();
          }
          if (value is Map) {
            final nested =
                value['message']?.toString() ??
                value['description']?.toString();
            if (nested != null && nested.isNotEmpty) message ??= nested;
          }
        }
        final result = payload['result'];
        if (result is Map) {
          final messages = result['messages'];
          if (messages is List && messages.isNotEmpty) {
            message ??= messages.map((item) => item.toString()).join(', ');
          }
        }
      }
    } catch (_) {}
    final details = [
      if (internalCode != null && internalCode.isNotEmpty)
        'внутренний код Avito $internalCode',
      if (message != null && message.trim().isNotEmpty) message.trim(),
    ].join(': ');
    if (response.statusCode == 403) {
      final hint = internalCode == '1002'
          ? 'Ошибка авторизации токена Client Credentials — переподключите аккаунт Avito.'
          : 'Avito запретил запрос; проверьте права приложения и настройки CallTracking.';
      return 'HTTP 403${details.isNotEmpty ? ' — $details' : ''}. $hint';
    }
    return 'HTTP ${response.statusCode}${details.isNotEmpty ? ' — $details' : ''}';
  }

  String _avitoResponseError(dynamic payload) {
    if (payload is Map) {
      final candidates = [
        payload['error'],
        payload['result'] is Map ? payload['result']['error'] : null,
        payload,
      ];
      for (final candidate in candidates) {
        if (candidate is Map) {
          final code = candidate['code']?.toString();
          final message = candidate['message']?.toString();
          if (code != null && code != '0') {
            return 'код $code${message != null && message.isNotEmpty ? ' — $message' : ''}';
          }
        }
      }
    }
    return '';
  }

  Future<Directory> _avitoRecordingDirectory() async {
    final root = await getApplicationSupportDirectory();
    final folder = Directory('${root.path}/avito-recordings');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  Future<File> _avitoRecordingFile(String callId) async {
    final folder = await _avitoRecordingDirectory();
    return File('${folder.path}/$callId.mp3');
  }

  Future<void> _refreshAvitoAudioCacheUsage() async {
    final folder = await _avitoRecordingDirectory();
    var bytes = 0;
    var count = 0;
    await for (final entity in folder.list()) {
      if (entity is! File || !entity.path.endsWith('.mp3')) continue;
      final length = await entity.length();
      if (length <= 0) continue;
      bytes += length;
      count++;
    }
    if (!mounted) return;
    setState(() {
      avitoCachedAudioCount = count;
      avitoCachedAudioBytes = bytes;
    });
  }

  Future<void> _enforceAvitoAudioCacheLimit() async {
    final folder = await _avitoRecordingDirectory();
    final entries = <CachedAudioFile>[];
    await for (final entity in folder.list()) {
      if (entity is! File || !entity.path.endsWith('.mp3')) continue;
      final stat = await entity.stat();
      if (stat.size <= 0) continue;
      entries.add(
        CachedAudioFile(
          path: entity.path,
          byteLength: stat.size,
          modified: stat.modified,
        ),
      );
    }
    final plan = planAvitoCache(
      entries,
      maxFiles: AppConstants.maxCachedCalls,
      maxBytes: AppConstants.maxAvitoAudioCacheBytes,
    );
    for (final entry in plan.evictions) {
      await File(entry.path).delete();
    }
    if (!mounted) return;
    setState(() {
      avitoCachedAudioCount = plan.retainedCount;
      avitoCachedAudioBytes = plan.retainedBytes;
    });
  }

  Future<void> _playLocalAvitoRecording(String callId, File file) async {
    final duration = await avitoAudioPlayer.setFilePath(file.path);
    if (!mounted) return;
    setState(() {
      playingAvitoCallId = callId;
      playingAvitoAudioPath = file.path;
      avitoAudioDuration = duration ?? Duration.zero;
      avitoAudioPosition = Duration.zero;
    });
    await avitoAudioPlayer.play();
  }

  Future<File> _saveAvitoAudio(String callId, http.Response response) async {
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('json')) {
      final url = _avitoRecordUrl(jsonDecode(response.body));
      if (url == null) {
        throw Exception('Avito не передал ссылку на аудиозапись');
      }
      response = await _avitoGet(Uri.parse(url));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Не удалось сохранить запись: ${_avitoErrorText(response)}',
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw Exception('Avito передал пустой аудиофайл');
    }
    if (response.bodyBytes.length > AppConstants.maxAvitoAudioCacheBytes) {
      throw Exception(
        'Аудиозапись превышает допустимый размер локального кэша',
      );
    }
    final file = await _avitoRecordingFile(callId);
    await file.writeAsBytes(response.bodyBytes, flush: true);
    await _enforceAvitoAudioCacheLimit();
    return file;
  }

  String _avitoAudioTime(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _playAvitoCall(
    Map<String, dynamic> call, {
    bool autoplay = true,
  }) async {
    final id = _avitoCallId(call);
    if (id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Avito не передал идентификатор этого звонка — запись недоступна.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => loadingAvitoCallIds.add(id));
    try {
      final cached = await _avitoRecordingFile(id);
      if (await cached.exists() && await cached.length() > 0) {
        if (autoplay) await _playLocalAvitoRecording(id, cached);
        return;
      }
      // В списке звонков Avito иногда уже передаёт временную прямую ссылку.
      // Она приоритетнее отдельного запроса к методу получения записи.
      final directUrl = _avitoRecordUrl(call);
      if (directUrl != null) {
        final file = await _saveAvitoAudio(
          id,
          await _avitoGet(Uri.parse(directUrl)),
        );
        if (autoplay) await _playLocalAvitoRecording(id, file);
        return;
      }
      // По документации CallTracking подробная карточка звонка также может
      // содержать recordUrl, даже если его нет в ответе списка звонков.
      final detailsResponse = await _avitoPost(
        Uri.parse('https://api.avito.ru/calltracking/v1/getCallById/'),
        headers: _avitoHeaders(),
        body: jsonEncode({'callId': int.parse(id)}),
      );
      var details = detailsResponse;
      if (details.statusCode == 200) {
        var detailsBody = jsonDecode(details.body);
        var detailError = _avitoResponseError(detailsBody);
        if (detailError.startsWith('код 1002')) {
          await _refreshAvitoTokenOnly();
          details = await _avitoPost(
            Uri.parse('https://api.avito.ru/calltracking/v1/getCallById/'),
            headers: _avitoHeaders(),
            body: jsonEncode({'callId': int.parse(id)}),
          );
          if (details.statusCode == 200) {
            detailsBody = jsonDecode(details.body);
            detailError = _avitoResponseError(detailsBody);
          }
        }
        if (detailError.isNotEmpty) {
          throw Exception('Avito CallTracking: $detailError (callId $id)');
        }
        final detailsUrl = _avitoRecordUrl(detailsBody);
        if (detailsUrl != null) {
          final file = await _saveAvitoAudio(
            id,
            await _avitoGet(Uri.parse(detailsUrl)),
          );
          if (autoplay) await _playLocalAvitoRecording(id, file);
          return;
        }
      }
      Future<http.Response> requestRecord() => _avitoGet(
        Uri.https('api.avito.ru', '/calltracking/v1/getRecordByCallId/', {
          'callId': id,
        }),
        headers: {
          ..._avitoHeaders(),
          'Accept': 'audio/mpeg, audio/wav, application/json',
        },
      );
      var response = await requestRecord();
      // Access tokens Avito действуют ограниченное время. При коде 1002
      // обновляем Client Credentials и повторяем запрос один раз.
      if (response.statusCode == 403) {
        var authCode = '';
        try {
          final body = jsonDecode(response.body);
          if (body is Map) {
            authCode = (body['code'] ?? body['error']?['code'] ?? '')
                .toString();
          }
        } catch (_) {}
        if (authCode == '1002') {
          await _refreshAvitoTokenOnly();
          response = await requestRecord();
          // Старый CPA-метод помечен Avito как deprecated, но для части
          // аккаунтов запись ещё доступна только через него. Используем его
          // как совместимый fallback после отказа нового CallTracking API.
          if (response.statusCode == 403) {
            try {
              final fallback = await _avitoGet(
                Uri.https('api.avito.ru', '/cpa/v1/call/$id'),
                headers: {
                  ..._avitoHeaders(),
                  'Accept': 'audio/mpeg, audio/wav, application/json',
                },
              );
              if (fallback.statusCode >= 200 && fallback.statusCode < 300) {
                response = fallback;
              }
            } catch (_) {}
          }
        }
      }
      if (response.statusCode == 425) {
        throw Exception(
          'Запись ещё готовится. Повторите через несколько минут.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Avito не отдал запись: ${_avitoErrorText(response)}');
      }
      final file = await _saveAvitoAudio(id, response);
      if (autoplay) await _playLocalAvitoRecording(id, file);
    } catch (e) {
      if (mounted && autoplay) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => loadingAvitoCallIds.remove(id));
    }
  }

  Future<void> _transcribeAvitoCall(Map<String, dynamic> call) async {
    if (!aiSettings.enabled || aiApiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Для расшифровки подключите AI API в «Настройках».'),
          ),
        );
      }
      return;
    }
    final id = _avitoCallId(call);
    if (id == null || transcribingAvitoCallIds.contains(id)) return;
    setState(() => transcribingAvitoCallIds.add(id));
    try {
      var file = await _avitoRecordingFile(id);
      if (!await file.exists() || await file.length() == 0) {
        await _playAvitoCall(call, autoplay: false);
        // Re-resolve the path after downloading: the audio loader may have
        // created/replaced the cache file during the previous await.
        file = await _avitoRecordingFile(id);
      }
      if (!await file.exists() || await file.length() == 0) {
        throw StateError('Не удалось получить аудиозапись звонка Avito');
      }
      final rawText = await _aiProvider.transcribe(
        file,
        settings: aiSettings,
        cancellation: _lifecycleCancellation,
      );
      // Speech recognition often returns a single paragraph. A second,
      // text-only GPT pass adds speaker labels without inventing audio facts.
      final text = await _aiProvider.formatTranscript(
        rawText,
        settings: aiSettings,
        cancellation: _lifecycleCancellation,
      );
      if (!mounted) return;
      setState(() => avitoTranscriptions[id] = text);
      await _saveAvitoAiCache();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Расшифровка звонка Avito'),
          content: SizedBox(
            width: 680,
            height: 520,
            child: _transcriptionChat(text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        _pushNotification(
          CrmNotificationLevel.warning,
          'Не удалось расшифровать звонок Avito',
          CrmLogger.redact(error.toString()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Расшифровка не получена: ${_friendlyTranscriptionError(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => transcribingAvitoCallIds.remove(id));
    }
  }

  void _loadAvitoAiCache() {
    try {
      final encoded = prefs.getString('avito_ai_cache');
      if (encoded == null || encoded.trim().isEmpty) return;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return;
      for (final entry in decoded.entries) {
        final item = entry.value;
        if (item is! Map) continue;
        final id = entry.key.toString();
        final transcript = item['transcript']?.toString().trim() ?? '';
        if (transcript.isNotEmpty) avitoTranscriptions[id] = transcript;
        final analysisJson = item['analysis'];
        if (analysisJson is Map) {
          avitoCallAnalyses[id] = AiTranscriptAnalysis.fromJson(
            Map<String, dynamic>.from(analysisJson),
          );
        }
      }
    } catch (error) {
      CrmLogger.error(
        'Не удалось восстановить кэш расшифровок Avito',
        error: error,
        name: 'crm.avito.ai-cache',
      );
    }
  }

  Future<void> _saveAvitoAiCache() async {
    final ids = <String>{
      ...avitoTranscriptions.keys,
      ...avitoCallAnalyses.keys,
    };
    final payload = <String, dynamic>{};
    for (final id in ids) {
      payload[id] = {
        if (avitoTranscriptions[id] != null)
          'transcript': avitoTranscriptions[id],
        if (avitoCallAnalyses[id] != null)
          'analysis': avitoCallAnalyses[id]!.toJson(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
    }
    await prefs.setString('avito_ai_cache', jsonEncode(payload));
  }

  Future<void> _autoProcessAvitoCalls() async {
    if (!aiSettings.enabled || aiApiKey.trim().isEmpty || avitoCalls.isEmpty) {
      return;
    }
    for (final call in List<Map<String, dynamic>>.from(avitoCalls)) {
      if (!mounted) return;
      final id = _avitoCallId(call);
      if (id == null ||
          analyzingAvitoCallIds.contains(id) ||
          transcribingAvitoCallIds.contains(id) ||
          (avitoTranscriptions.containsKey(id) &&
              avitoCallAnalyses.containsKey(id))) {
        continue;
      }
      setState(() {
        if (!avitoTranscriptions.containsKey(id)) {
          transcribingAvitoCallIds.add(id);
        } else {
          analyzingAvitoCallIds.add(id);
        }
      });
      try {
        var transcript = avitoTranscriptions[id];
        if (transcript == null || transcript.trim().isEmpty) {
          var file = await _avitoRecordingFile(id);
          if (!await file.exists() || await file.length() == 0) {
            await _playAvitoCall(call, autoplay: false);
            file = await _avitoRecordingFile(id);
          }
          if (!await file.exists() || await file.length() == 0) {
            throw StateError('Не удалось получить аудиозапись звонка Avito');
          }
          final raw = await _aiProvider.transcribe(
            file,
            settings: aiSettings,
            cancellation: _lifecycleCancellation,
          );
          transcript = await _aiProvider.formatTranscript(
            raw,
            settings: aiSettings,
            cancellation: _lifecycleCancellation,
          );
          if (!mounted) return;
          avitoTranscriptions[id] = transcript;
          await _saveAvitoAiCache();
          setState(() {
            transcribingAvitoCallIds.remove(id);
            analyzingAvitoCallIds.add(id);
          });
        }
        final analysisText = await _aiProvider.analyzeTranscript(
          transcript,
          settings: aiSettings,
          cancellation: _lifecycleCancellation,
        );
        if (!mounted) return;
        avitoCallAnalyses[id] = parseTranscriptAnalysis(analysisText);
        await _saveAvitoAiCache();
      } catch (error) {
        CrmLogger.error(
          'Автоматическая обработка звонка Avito не завершена',
          error: error,
          name: 'crm.avito.ai-cache',
        );
      } finally {
        if (mounted) {
          setState(() {
            transcribingAvitoCallIds.remove(id);
            analyzingAvitoCallIds.remove(id);
          });
        }
      }
    }
  }

  Future<void> _analyzeAvitoCall(Map<String, dynamic> call) async {
    if (!aiSettings.enabled || aiApiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Для анализа подключите AI API в «Настройках».'),
          ),
        );
      }
      return;
    }
    final id = _avitoCallId(call);
    if (id == null || analyzingAvitoCallIds.contains(id)) return;
    final transcript = avitoTranscriptions[id];
    if (transcript == null || transcript.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сначала нажмите «В текст», дождитесь расшифровки, затем «Анализ».',
            ),
          ),
        );
      }
      return;
    }
    setState(() => analyzingAvitoCallIds.add(id));
    try {
      final rawAnalysis = await _aiProvider.analyzeTranscript(
        transcript,
        settings: aiSettings,
        cancellation: _lifecycleCancellation,
      );
      if (!mounted) return;
      final analysis = parseTranscriptAnalysis(rawAnalysis);
      setState(() => avitoCallAnalyses[id] = analysis);
      await _saveAvitoAiCache();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Анализ звонка Avito'),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    analysis.displayText,
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                  if (analysis.actions.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Рекомендованные действия',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...analysis.actions.asMap().entries.map(
                      (entry) => _analysisActionTile(
                        call: call,
                        action: entry.value,
                        actionKey: '${id}_${entry.key}',
                        dialogContext: context,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        _pushNotification(
          CrmNotificationLevel.warning,
          'Не удалось проанализировать звонок Avito',
          CrmLogger.redact(error.toString()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Анализ не получен: ${_friendlyTranscriptionError(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => analyzingAvitoCallIds.remove(id));
    }
  }

  Widget _analysisActionTile({
    required Map<String, dynamic> call,
    required AiActionRecommendation action,
    required String actionKey,
    required BuildContext dialogContext,
  }) {
    final missing = action.missing;
    final type = switch (action.type) {
      AiActionType.note => 'Заметка',
      AiActionType.appointment => 'Запись',
      AiActionType.deal => 'Сделка',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('$type: ${action.title}'),
        subtitle: Text(
          [
            action.details,
            if (missing.isNotEmpty) 'Нужно уточнить: ${missing.join(', ')}',
          ].where((part) => part.trim().isNotEmpty).join('\n'),
        ),
        trailing: missing.isNotEmpty
            ? const Text('Уточнить')
            : appliedAnalysisActions.contains(actionKey)
            ? const Text('Создано')
            : TextButton(
                onPressed: () async {
                  var created = false;
                  if (action.type == AiActionType.note) {
                    created = await _createAnalysisNote(call, action);
                  } else if (action.type == AiActionType.appointment) {
                    await _createAnalysisAppointment(call, action);
                    created = true;
                  } else {
                    created = await _createAnalysisDeal(call, action);
                  }
                  if (created && dialogContext.mounted) {
                    appliedAnalysisActions.add(actionKey);
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Создать'),
              ),
      ),
    );
  }

  Future<bool> _createAnalysisNote(
    Map<String, dynamic> call,
    AiActionRecommendation action,
  ) async {
    if (!_canEdit('dashboard') || dashboardNotes.length >= 8) return false;
    final phone = call['buyerPhone']?.toString() ?? '';
    final text = [
      if (phone.isNotEmpty) 'Звонок Avito • $phone',
      action.title,
      action.details,
    ].where((part) => part.trim().isNotEmpty).join('\n');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить заметку?'),
        content: SelectableText(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    dashboardNotes.add(
      StickyNote(
        id: stableWorkspaceId('note'),
        text: text,
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
    await _saveWorkspaceData();
    if (mounted) setState(() {});
    return true;
  }

  DateTime? _analysisDateTime(AiActionRecommendation action) {
    final date = action.date?.trim() ?? '';
    final time = action.time?.trim() ?? '10:00';
    if (date.isEmpty) return null;
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return null;
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 10;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(parsed.year, parsed.month, parsed.day, hour, minute);
  }

  Future<void> _createAnalysisAppointment(
    Map<String, dynamic> call,
    AiActionRecommendation action,
  ) async {
    final when = _analysisDateTime(action);
    if (when == null) return;
    final phone = action.clientPhone?.trim().isNotEmpty == true
        ? action.clientPhone!.trim()
        : call['buyerPhone']?.toString() ?? '';
    final event = <String, dynamic>{
      'summary': action.service ?? action.title,
      'start': {'dateTime': _moscowIso(when)},
      'extendedProperties': {
        'private': {
          'name': '',
          'phone': phone,
          'service': action.service ?? action.title,
          'source': 'Avito',
          'note': action.details,
          'status': 'Записан',
        },
      },
    };
    await _editCalendarEvent(event);
  }

  Future<bool> _createAnalysisDeal(
    Map<String, dynamic> call,
    AiActionRecommendation action,
  ) async {
    final phone = action.clientPhone?.trim().isNotEmpty == true
        ? action.clientPhone!.trim()
        : call['buyerPhone']?.toString() ?? '';
    return _addManualDeal({
      'extendedProperties': {
        'private': {
          'name': '',
          'phone': phone,
          'service': action.service ?? action.title,
          'source': 'Avito',
          'note': action.details,
        },
      },
    });
  }

  String _friendlyTranscriptionError(Object error) {
    final value = error.toString().replaceFirst('Exception: ', '').trim();
    if (value.isEmpty) return 'проверьте доступ к записи и AI API';
    return value.length > 240 ? '${value.substring(0, 240)}…' : value;
  }

  Widget _transcriptionChat(String transcript) {
    final lines = parseTranscriptLines(transcript);
    if (lines.isEmpty) return const Text('Расшифровка пуста');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Клиент — слева · Вы — справа',
          style: TextStyle(color: _mutedTextColor, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: lines.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final line = lines[index];
              final isEmployee = line.speaker == TranscriptSpeaker.employee;
              final isUnknown = line.speaker == TranscriptSpeaker.unknown;
              final label = switch (line.speaker) {
                TranscriptSpeaker.client => 'Клиент',
                TranscriptSpeaker.employee => 'Вы',
                TranscriptSpeaker.unknown => 'Говорящий не определён',
              };
              final bubble = Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isUnknown
                      ? _surfaceColor.withValues(alpha: .55)
                      : isEmployee
                      ? const Color(0xFFB86B20)
                      : _surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cardBorderColor),
                ),
                child: SelectableText(
                  '$label\n${line.text}',
                  style: TextStyle(
                    color: isEmployee ? Colors.white : _mainTextColor,
                    height: 1.35,
                  ),
                ),
              );
              return Align(
                alignment: isUnknown
                    ? Alignment.center
                    : isEmployee
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: bubble,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _cacheAllAvitoCalls() async {
    if (avitoCacheLoading || avitoCalls.isEmpty) return;
    setState(() => avitoCacheLoading = true);
    var saved = 0;
    try {
      for (final call in avitoCalls.take(AppConstants.maxCachedCalls)) {
        final id = _avitoCallId(call);
        if (id == null) continue;
        final file = await _avitoRecordingFile(id);
        final existed = await file.exists() && await file.length() > 0;
        await _playAvitoCall(call, autoplay: false);
        if (!existed && await file.exists() && await file.length() > 0) saved++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved == 0
                  ? 'Все доступные записи уже сохранены'
                  : 'Сохранено записей: $saved',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => avitoCacheLoading = false);
    }
  }

  Future<void> _clearAvitoAudioCache() async {
    final dir = await _avitoRecordingDirectory();
    var removed = 0;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.mp3')) {
        await entity.delete();
        removed++;
      }
    }
    if (playingAvitoAudioPath?.startsWith(dir.path) == true) {
      await avitoAudioPlayer.stop();
      playingAvitoCallId = null;
      playingAvitoAudioPath = null;
      avitoAudioPosition = Duration.zero;
      avitoAudioDuration = Duration.zero;
      avitoAudioPlaying = false;
    }
    if (mounted) {
      setState(() {
        avitoCachedAudioCount = 0;
        avitoCachedAudioBytes = 0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Очищено аудиозаписей: $removed')));
    }
  }

  Future<void> _selectAvitoAccount(String key) async {
    if (key == activeAvitoAccountKey) return;
    setState(() {
      activeAvitoAccountKey = key;
      avitoAccessToken = null;
      avitoUserId = null;
      avitoConnected = false;
      avitoChats = [];
      avitoCalls = [];
      avitoChatMessages = [];
      selectedAvitoChat = null;
      avitoStatus = 'Подключаю выбранный аккаунт…';
    });
    await _saveAvitoAccounts();
    await _connectAvito();
  }

  Future<void> _setupAvito() async {
    if (!canManageIntegrations) return;
    final name = TextEditingController(text: '');
    final clientId = TextEditingController();
    final clientSecret = TextEditingController();
    final webhook = TextEditingController();
    void disposeControllers() {
      name.dispose();
      clientId.dispose();
      clientSecret.dispose();
      webhook.dispose();
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить аккаунт Avito'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Название аккаунта',
                  hintText: 'Например: Основной профиль',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: clientId,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: clientSecret,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Client secret',
                  prefixIcon: Icon(Icons.password_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: webhook,
                decoration: const InputDecoration(
                  labelText: 'Webhook URL — необязательно',
                  hintText: 'https://ваш-сервер.ru/avito/webhook',
                  prefixIcon: Icon(Icons.webhook_outlined),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Ключи получите в Avito: «Для профессионалов» → API. Webhook нужен для мгновенных сообщений, когда CRM закрыта.',
                style: TextStyle(fontSize: 12, color: _mutedTextColor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Подключить'),
          ),
        ],
      ),
    );
    if (accepted != true ||
        clientId.text.trim().isEmpty ||
        clientSecret.text.trim().isEmpty) {
      disposeControllers();
      return;
    }
    try {
      final key =
          '${clientId.text.trim()}-${DateTime.now().millisecondsSinceEpoch}';
      avitoAccounts.add({
        'key': key,
        'name': name.text.trim().isEmpty
            ? 'Новый аккаунт Avito'
            : name.text.trim(),
        'clientId': clientId.text.trim(),
        'clientSecret': clientSecret.text.trim(),
        'webhook': webhook.text.trim(),
        'userId': '',
      });
      activeAvitoAccountKey = key;
      await _saveAvitoAccounts();
      await _connectAvito();
      if (avitoConnected &&
          webhook.text.trim().isNotEmpty &&
          avitoAccessToken != null) {
        await _avitoPost(
          Uri.parse('https://api.avito.ru/messenger/v3/webhook'),
          headers: _avitoHeaders(),
          body: jsonEncode({'url': webhook.text.trim()}),
        );
      }
      _audit(
        avitoConnected
            ? 'Подключена интеграция'
            : 'Ошибка подключения интеграции',
        'Интеграция',
        'Avito: ${name.text.trim().isEmpty ? 'Новый аккаунт Avito' : name.text.trim()}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Не удалось подключить Avito: '
              '${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
      CrmLogger.error('Avito setup failed', error: e, name: 'crm.avito');
    } finally {
      disposeControllers();
    }
  }

  String _telegramTitle(Map<String, dynamic> chat) =>
      chat['title']?.toString().trim().isNotEmpty == true
      ? chat['title'].toString()
      : (chat['username']?.toString().isNotEmpty == true
            ? '@${chat['username']}'
            : 'Telegram • ${chat['id']}');

  String _telegramPreview(Map<String, dynamic> chat) {
    final messages = (chat['messages'] as List? ?? const []);
    if (messages.isEmpty) return 'Сообщение';
    final last = messages.last;
    return last is Map && last['text']?.toString().isNotEmpty == true
        ? last['text'].toString()
        : 'Вложение';
  }

  Future<void> _loadTelegramUpdates({bool silent = false}) async {
    final token = _messengerToken('telegram');
    if (token.isEmpty && _session == null) return;
    if (mounted) setState(() => telegramLoading = true);
    try {
      final offset = prefs.getInt('telegram_update_offset');
      final query = <String, String>{'timeout': '1', 'limit': '100'};
      if (offset != null) query['offset'] = offset.toString();
      final data = token.isEmpty
          ? await _proxyIntegration('message.telegram', {
              'method': 'getUpdates',
              'body': query,
            })
          : jsonDecode(
                  (await _apiClient.get(
                    Uri.https(
                      'api.telegram.org',
                      '/bot$token/getUpdates',
                      query,
                    ),
                  )).body,
                )
                as Map<String, dynamic>;
      if (data['ok'] != true) throw Exception('Telegram не вернул обновления');
      final updates = (data['result'] as List? ?? const []).whereType<Map>();
      for (final raw in updates) {
        final update = Map<String, dynamic>.from(raw);
        final updateId = (update['update_id'] as num?)?.toInt();
        if (updateId != null) {
          await prefs.setInt('telegram_update_offset', updateId + 1);
        }
        final message = update['message'];
        if (message is! Map) continue;
        final chat = message['chat'];
        if (chat is! Map) continue;
        final id = chat['id']?.toString();
        if (id == null) continue;
        final existing = telegramChats.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['id']?.toString() == id,
          orElse: () => null,
        );
        final target =
            existing ??
            <String, dynamic>{'id': id, 'messages': <Map<String, dynamic>>[]};
        target['title'] =
            chat['title'] ??
            [
              chat['first_name'],
              chat['last_name'],
            ].whereType<String>().join(' ');
        target['username'] = chat['username'];
        final messages =
            (target['messages'] as List?) ?? <Map<String, dynamic>>[];
        messages.add(Map<String, dynamic>.from(message));
        target['messages'] = messages.take(100).toList();
        if (existing == null) telegramChats.add(target);
      }
      messengerStatus['telegram'] =
          'Обновлено: ${telegramChats.length} диалогов';
      if (mounted && !silent) setState(() {});
    } catch (e) {
      messengerStatus['telegram'] = _integrationErrorText(e);
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => telegramLoading = false);
    }
  }

  void _openTelegramChat(Map<String, dynamic> chat) {
    setState(() => selectedTelegramChat = chat);
  }

  Future<void> _sendTelegramMessage() async {
    if (!_canEdit('messages')) return;
    final text = telegramReplyController.text.trim();
    final chatId = selectedTelegramChat?['id']?.toString();
    if (text.isEmpty || chatId == null) return;
    try {
      final error = await _sendTelegramText(chatId: chatId, text: text);
      if (error != null) throw Exception(error);
      final messages = (selectedTelegramChat?['messages'] as List?) ?? [];
      messages.add({
        'text': text,
        'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'out': true,
      });
      selectedTelegramChat?['messages'] = messages;
      telegramReplyController.clear();
      if (mounted) setState(() {});
    } catch (e) {
      await _enqueuePendingMessage({
        'channel': 'telegram',
        'chat': chatId,
        'text': text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<String?> _sendTelegramText({
    required String chatId,
    required String text,
  }) async {
    final token = _messengerToken('telegram');
    if (token.isEmpty) return 'Не найден токен Telegram.';
    try {
      final response = await _apiClient.post(
        Uri.https('api.telegram.org', '/bot$token/sendMessage'),
        body: {'chat_id': chatId, 'text': text},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['ok'] != true) {
        return data['description']?.toString() ??
            'Telegram не принял сообщение';
      }
      return null;
    } catch (_) {
      return 'Не удалось отправить сообщение Telegram';
    }
  }

  Widget _telegramInbox() => TelegramInbox(
    chats: telegramChats,
    selectedChat: selectedTelegramChat,
    loading: telegramLoading,
    replyController: telegramReplyController,
    canEdit: _canEdit('messages'),
    surfaceColor: _surfaceColor,
    borderColor: _cardBorderColor,
    mainTextColor: _mainTextColor,
    mutedTextColor: _mutedTextColor,
    titleOf: _telegramTitle,
    onOpenChat: _openTelegramChat,
    onSend: _sendTelegramMessage,
  );

  String _instagramConversationTitle(Map<String, dynamic> item) {
    final participants = item['participants']?['data'];
    if (participants is List && participants.isNotEmpty) {
      final names = participants
          .whereType<Map>()
          .map((p) => p['username']?.toString() ?? p['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    return 'Instagram • ${item['id'] ?? 'диалог'}';
  }

  Future<void> _loadInstagramConversations({bool silent = false}) async {
    final token = _messengerToken('instagram');
    final account = prefs.getString('messenger_instagram_account') ?? '';
    if (token.isEmpty || account.isEmpty) return;
    final requestId = ++_instagramRequestId;
    if (mounted) setState(() => instagramLoading = true);
    try {
      final response = await _apiClient.get(
        Uri.https('graph.facebook.com', '/v20.0/$account/conversations', {
          'platform': 'instagram',
          'fields':
              'id,participants,updated_time,messages.limit(1){message,from,created_time}',
          'access_token': token,
        }),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (requestId != _instagramRequestId) return;
      if (data['error'] != null) {
        final error = data['error'] as Map;
        throw Exception(
          error['message']?.toString() ?? 'Instagram API недоступен',
        );
      }
      instagramConversations = (data['data'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      messengerStatus['instagram'] =
          'Обновлено: ${instagramConversations.length} диалогов';
      if (mounted && !silent) setState(() {});
    } catch (e) {
      messengerStatus['instagram'] = _integrationErrorText(e);
      if (mounted && requestId == _instagramRequestId && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted && requestId == _instagramRequestId) {
        setState(() => instagramLoading = false);
      }
    }
  }

  Future<void> _openInstagramConversation(
    Map<String, dynamic> conversation,
  ) async {
    final id = conversation['id']?.toString();
    final token = _messengerToken('instagram');
    if (id == null || token.isEmpty) return;
    final requestId = ++_instagramRequestId;
    selectedInstagramConversation = conversation;
    instagramMessages = [];
    if (mounted) setState(() => instagramLoading = true);
    try {
      final response = await _apiClient.get(
        Uri.https('graph.facebook.com', '/v20.0/$id/messages', {
          'fields': 'message,from,created_time',
          'access_token': token,
        }),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (requestId != _instagramRequestId) return;
      if (data['error'] != null) {
        throw Exception(
          (data['error'] as Map)['message']?.toString() ??
              'Не удалось загрузить Instagram Direct',
        );
      }
      instagramMessages = (data['data'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      if (mounted && requestId == _instagramRequestId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted && requestId == _instagramRequestId) {
        setState(() => instagramLoading = false);
      }
    }
  }

  Future<void> _sendInstagramMessage() async {
    if (!_canEdit('messages')) return;
    final id = selectedInstagramConversation?['id']?.toString();
    final account = prefs.getString('messenger_instagram_account') ?? '';
    final token = _messengerToken('instagram');
    final text = instagramReplyController.text.trim();
    if (id == null || account.isEmpty || token.isEmpty || text.isEmpty) return;
    try {
      final response = await _apiClient.post(
        Uri.https('graph.facebook.com', '/v20.0/$account/messages', {
          'access_token': token,
        }),
        body: jsonEncode({
          'recipient': {'id': id},
          'message': {'text': text},
        }),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['error'] != null) {
        throw Exception(
          (data['error'] as Map)['message']?.toString() ??
              'Instagram не принял сообщение',
        );
      }
      instagramReplyController.clear();
      await _openInstagramConversation(selectedInstagramConversation!);
    } catch (e) {
      await _enqueuePendingMessage({
        'channel': 'instagram',
        'chat': id,
        'text': text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Widget _instagramInbox() => InstagramInbox(
    conversations: instagramConversations,
    selectedConversation: selectedInstagramConversation,
    messages: instagramMessages,
    loading: instagramLoading,
    replyController: instagramReplyController,
    canEdit: _canEdit('messages'),
    surfaceColor: _surfaceColor,
    borderColor: _cardBorderColor,
    mainTextColor: _mainTextColor,
    mutedTextColor: _mutedTextColor,
    titleOf: _instagramConversationTitle,
    onOpenConversation: _openInstagramConversation,
    onSend: _sendInstagramMessage,
  );

  Map<String, String> _vkParams(Map<String, String> values) => {
    ...values,
    'access_token': _messengerToken('vk'),
    'v': '5.199',
  };

  Future<Map<String, dynamic>> _vkRequest(
    String method,
    Map<String, String> body,
  ) async {
    if (_messengerToken('vk').isEmpty) {
      return _proxyIntegration('message.vk', {'method': method, 'body': body});
    }
    final response = await _apiClient.post(
      Uri.parse('https://api.vk.com/method/$method'),
      body: _vkParams(body),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _setVkNotificationPeer(String peerId) async {
    await prefs.setString('messenger_vk_notify_peer', peerId);
    if (canManageIntegrations) {
      await _migrateLocalConfiguration(clearLocalSecrets: false, silent: true);
    }
  }

  Future<void> _loadVkConversations({bool silent = false}) async {
    final token = _messengerToken('vk');
    if (token.isEmpty && _session == null) return;
    if (mounted) setState(() => vkLoading = true);
    try {
      final data = await _vkRequest('messages.getConversations', {
        'count': '100',
        'extended': '1',
      });
      if (data['error'] != null) {
        final error = data['error'] as Map;
        throw Exception(
          'VK ${error['error_code'] ?? ''}: ${error['error_msg'] ?? 'нет доступа к чатам'}',
        );
      }
      final items = data['response']?['items'];
      vkConversations = items is List
          ? items
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : [];
      messengerStatus['vk'] = 'Обновлено: ${vkConversations.length} диалогов';
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ВК: загружено диалогов ${vkConversations.length}'),
          ),
        );
      }
    } catch (e) {
      messengerStatus['vk'] = _integrationErrorText(e);
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => vkLoading = false);
    }
  }

  String _integrationErrorText(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) return 'Не удалось обновить данные';
    return message.length > 90 ? '${message.substring(0, 90)}…' : message;
  }

  Future<void> _openVkConversation(Map<String, dynamic> conversation) async {
    final peerId = conversation['conversation']?['peer']?['id']?.toString();
    if (peerId == null) return;
    readMessageDialogs.add('VK:$peerId');
    await _saveMessageMeta();
    if (!mounted) return;
    setState(() {
      selectedVkConversation = conversation;
      vkMessages = [];
      vkLoading = true;
    });
    try {
      final data = await _vkRequest('messages.getHistory', {
        'peer_id': peerId,
        'count': '100',
        'rev': '1',
      });
      if (data['error'] != null) {
        final error = data['error'] as Map;
        throw Exception(
          error['error_msg']?.toString() ?? 'Не удалось загрузить историю',
        );
      }
      final items = data['response']?['items'];
      vkMessages = items is List
          ? items
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => vkLoading = false);
    }
  }

  Future<void> _sendVkMessage() async {
    if (!_canEdit('messages')) return;
    final text = vkReplyController.text.trim();
    final peerId = selectedVkConversation?['conversation']?['peer']?['id']
        ?.toString();
    if (text.isEmpty || peerId == null) return;
    try {
      final data = await _vkRequest('messages.send', {
        'peer_id': peerId,
        'random_id': DateTime.now().microsecondsSinceEpoch.toString(),
        'message': text,
      });
      if (data['error'] != null) {
        final error = data['error'] as Map;
        throw Exception(
          error['error_msg']?.toString() ?? 'VK не принял сообщение',
        );
      }
      vkReplyController.clear();
      await _openVkConversation(selectedVkConversation!);
    } catch (e) {
      await _enqueuePendingMessage({
        'channel': 'vk',
        'peer': peerId,
        'text': text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  String _vkConversationTitle(Map<String, dynamic> item) {
    final peer = item['conversation']?['peer'];
    final last = item['last_message'];
    final title = item['conversation']?['chat_settings']?['title']?.toString();
    if (title != null && title.isNotEmpty) return title;
    final id = peer?['id']?.toString() ?? last?['from_id']?.toString() ?? '';
    return id.isEmpty ? 'Диалог ВКонтакте' : 'Клиент VK • $id';
  }

  String _vkText(Map<String, dynamic> item) {
    final text = item['text']?.toString() ?? '';
    if (text.isNotEmpty) return text;
    if (item['attachments'] is List &&
        (item['attachments'] as List).isNotEmpty) {
      return 'Вложение';
    }
    return 'Сообщение';
  }

  Widget _vkInbox() => VkInbox(
    conversations: vkConversations,
    selectedConversation: selectedVkConversation,
    messages: vkMessages,
    loading: vkLoading,
    darkMode: widget.darkMode,
    canEdit: _canEdit('messages'),
    canConfigure: canManageIntegrations,
    replyController: vkReplyController,
    quickReplyTemplates: quickReplyTemplates,
    surfaceColor: _surfaceColor,
    borderColor: _cardBorderColor,
    mainTextColor: _mainTextColor,
    mutedTextColor: _mutedTextColor,
    titleOf: _vkConversationTitle,
    textOf: _vkText,
    onRefresh: () => unawaited(_loadVkConversations()),
    onOpenConversation: (conversation) =>
        unawaited(_openVkConversation(conversation)),
    isNotificationChat:
        selectedVkConversation?['conversation']?['peer']?['id']?.toString() !=
            null &&
        prefs.getString('messenger_vk_notify_peer') ==
            selectedVkConversation?['conversation']?['peer']?['id']?.toString(),
    onSelectNotificationChat: (peerId) async {
      await _setVkNotificationPeer(peerId);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Новые записи будут отправляться в этот чат ВКонтакте'),
        ),
      );
    },
    onSendTest: () => _sendVkText(
      peerId:
          selectedVkConversation?['conversation']?['peer']?['id']?.toString() ??
          '',
      text:
          '✅ Проверка связи: CRM «Чистое место» может отправлять уведомления в этот чат.',
    ),
    onSend: _sendVkMessage,
  );

  /* Legacy VK UI retained temporarily for migration reference; active UI lives
   * in widgets/vk_inbox.dart. */
  /* Widget _legacyVkInbox() => Container(
    width: 980,
    height: 520,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _cardBorderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.alternate_email, color: Color(0xFFF28C28)),
            const SizedBox(width: 8),
            Text(
              'Диалоги ВКонтакте',
              style: TextStyle(
                color: _mainTextColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: vkLoading ? null : () => _loadVkConversations(),
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Обновить'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 310,
                child: vkConversations.isEmpty
                    ? Center(
                        child: Text(
                          vkLoading ? 'Загружаем…' : 'Диалогов пока нет',
                          style: TextStyle(color: _mutedTextColor),
                        ),
                      )
                    : ListView.separated(
                        itemCount: vkConversations.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: _cardBorderColor),
                        itemBuilder: (_, i) {
                          final item = vkConversations[i];
                          final last = item['last_message'] is Map
                              ? Map<String, dynamic>.from(item['last_message'])
                              : <String, dynamic>{};
                          final selectedItem =
                              selectedVkConversation?['conversation']?['peer']?['id'] ==
                              item['conversation']?['peer']?['id'];
                          return InkWell(
                            onTap: () => _openVkConversation(item),
                            child: Container(
                              color: selectedItem
                                  ? const Color(0xFFF28C28).withValues(
                                      alpha: widget.darkMode ? .18 : .1,
                                    )
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _vkConversationTitle(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _mainTextColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _vkText(last),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _mutedTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              VerticalDivider(width: 26, color: _cardBorderColor),
              Expanded(child: _vkConversationView()),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _vkConversationView() {
    if (selectedVkConversation == null) {
      return Center(
        child: Text(
          'Выберите диалог слева',
          style: TextStyle(color: _mutedTextColor),
        ),
      );
    }
    final peerId = selectedVkConversation?['conversation']?['peer']?['id']
        ?.toString();
    final isNotificationChat =
        peerId != null && prefs.getString('messenger_vk_notify_peer') == peerId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _vkConversationTitle(selectedVkConversation!),
                style: TextStyle(
                  color: _mainTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: peerId == null || !canManageIntegrations
                  ? null
                  : () async {
                      await prefs.setString('messenger_vk_notify_peer', peerId);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Новые записи будут отправляться в этот чат ВКонтакте',
                            ),
                          ),
                        );
                      }
                    },
              icon: Icon(
                isNotificationChat
                    ? Icons.notifications_active
                    : Icons.notifications_none,
              ),
              label: Text(
                isNotificationChat
                    ? 'Уведомления включены'
                    : 'Отправлять новые записи сюда',
              ),
            ),
            if (isNotificationChat)
              IconButton(
                tooltip: 'Отправить тест уведомлений',
                icon: const Icon(Icons.send_outlined),
                onPressed: !_canEdit('messages')
                    ? null
                    : () async {
                        final error = await _sendVkText(
                          peerId: peerId,
                          text:
                              '✅ Проверка связи: CRM «Чистое место» может отправлять уведомления в этот чат.',
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error ?? 'Тестовое уведомление отправлено в чат.',
                            ),
                          ),
                        );
                      },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: vkMessages.length,
            itemBuilder: (_, i) {
              final message = vkMessages[i];
              final outgoing = message['out'] == 1 || message['out'] == true;
              return Align(
                alignment: outgoing
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: outgoing
                        ? const Color(0xFFF28C28)
                        : (widget.darkMode
                              ? const Color(0xFF30343B)
                              : const Color(0xFFF0F2F5)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _vkText(message),
                    style: TextStyle(
                      color: outgoing ? Colors.white : _mainTextColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            PopupMenuButton<String>(
              tooltip: 'Быстрый ответ',
              icon: const Icon(Icons.flash_on_outlined),
              onSelected: (value) => vkReplyController.text = value,
              itemBuilder: (_) => quickReplyTemplates
                  .map(
                    (t) => PopupMenuItem(
                      value: t,
                      child: SizedBox(
                        width: 320,
                        child: Text(
                          t,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            Expanded(
              child: TextField(
                controller: vkReplyController,
                onSubmitted: (_) => _sendVkMessage(),
                decoration: const InputDecoration(
                  hintText: 'Ответить клиенту ВКонтакте…',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _canEdit('messages') ? _sendVkMessage : null,
              color: const Color(0xFFF28C28),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }

  */

  /* Legacy messages page layout retained for reference; active layout lives
   * in widgets/messages_page.dart. */
  /* Widget _legacyMessages() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            'Сообщения',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _mainTextColor,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _showIntegrationDiagnostics,
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Диагностика интеграций'),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        'Все обращения клиентов в одном окне.',
        style: TextStyle(color: _mutedTextColor),
      ),
      const SizedBox(height: 10),
      if (pendingMessages.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_send, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'В очереди на отправку: ${pendingMessages.length}',
                style: TextStyle(color: _mainTextColor),
              ),
              const Spacer(),
              TextButton(
                onPressed: _retryPendingMessages,
                child: const Text('Повторить сейчас'),
              ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      _unifiedMessagesBlock(),
      const SizedBox(height: 18),
      if (messengerConnected['instagram'] == true) ...[
        _instagramInbox(),
        const SizedBox(height: 18),
      ],
      if (messengerConnected['telegram'] == true) ...[
        _telegramInbox(),
        const SizedBox(height: 18),
      ],
      _avitoCard(),
      const SizedBox(height: 12),
      if (avitoConnected) ...[_avitoWorkspace(), const SizedBox(height: 18)],
      if (messengerConnected['vk'] == true) ...[
        _vkInbox(),
        const SizedBox(height: 18),
      ],
      if (messengerConnected['vk'] == true) ...[
        Text(
          'Чат сотрудников ВКонтакте',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _mainTextColor,
          ),
        ),
        const SizedBox(height: 8),
        _vkNotificationChatPanel(),
        const SizedBox(height: 18),
      ],
      _callsBlock(),
      const SizedBox(height: 18),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _messengerCard(
            'telegram',
            'Telegram',
            Icons.send_outlined,
            'Сообщения через бота Telegram',
          ),
          _messengerCard(
            'vk',
            'ВКонтакте',
            Icons.alternate_email,
            'Сообщения сообщества ВК',
          ),
          _messengerCard(
            'instagram',
            'Instagram',
            Icons.camera_alt_outlined,
            'Direct профессионального аккаунта',
          ),
        ],
      ),
    ],
  );

  */

  Widget _messages() {
    final sections = <Widget>[
      _unifiedMessagesBlock(),
      const SizedBox(height: 18),
      if (messengerConnected['instagram'] == true) ...[
        _instagramInbox(),
        const SizedBox(height: 18),
      ],
      if (messengerConnected['telegram'] == true) ...[
        _telegramInbox(),
        const SizedBox(height: 18),
      ],
      _avitoCard(),
      const SizedBox(height: 12),
      if (avitoConnected) ...[_avitoWorkspace(), const SizedBox(height: 18)],
      if (messengerConnected['vk'] == true) ...[
        _vkInbox(),
        const SizedBox(height: 18),
      ],
      if (messengerConnected['vk'] == true) ...[
        Text(
          'Чат сотрудников ВКонтакте',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _mainTextColor,
          ),
        ),
        const SizedBox(height: 8),
        _vkNotificationChatPanel(),
        const SizedBox(height: 18),
      ],
      _callsBlock(),
    ];
    return MessagesPage(
      sections: sections,
      connectionCards: [
        _messengerCard(
          'telegram',
          'Telegram',
          Icons.send_outlined,
          'Сообщения через бота Telegram',
        ),
        _messengerCard(
          'vk',
          'ВКонтакте',
          Icons.alternate_email,
          'Сообщения сообщества ВК',
        ),
        _messengerCard(
          'instagram',
          'Instagram',
          Icons.camera_alt_outlined,
          'Direct профессионального аккаунта',
        ),
      ],
      pendingCount: pendingMessages.length,
      mainTextColor: _mainTextColor,
      mutedTextColor: _mutedTextColor,
      canRetry: _canEdit('messages'),
      onRetry: () => unawaited(_retryPendingMessages()),
      onDiagnostics: () => unawaited(_showIntegrationDiagnostics()),
      onRefresh: _refreshMessageSources,
    );
  }

  Widget _unifiedMessagesBlock() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 620;
      final hasDialogs =
          instagramConversations.isNotEmpty ||
          telegramChats.isNotEmpty ||
          avitoChats.isNotEmpty ||
          vkConversations.isNotEmpty;
      return Container(
        width: double.infinity,
        height: compact ? (hasDialogs ? 440 : 260) : 470,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _cardBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Общий чат',
              style: TextStyle(
                color: _mainTextColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: messagesSearchController,
              onChanged: (v) {
                messagesSearchDebounce?.cancel();
                messagesSearchDebounce = Timer(AppConstants.searchDebounce, () {
                  if (mounted) setState(() => messagesSearch = v);
                });
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Поиск диалогов',
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  return Row(
                    children: [
                      SizedBox(
                        width: compact ? constraints.maxWidth : 330,
                        child: UnifiedInboxList(
                          dialogs: [
                            ...instagramConversations
                                .where(
                                  (c) => _instagramConversationTitle(c)
                                      .toLowerCase()
                                      .contains(messagesSearch.toLowerCase()),
                                )
                                .map(
                                  (c) => UnifiedDialog(
                                    platform: 'Instagram',
                                    id:
                                        c['id']?.toString() ??
                                        _instagramConversationTitle(c),
                                    name: _instagramConversationTitle(c),
                                    preview: 'Direct Instagram',
                                    unread: false,
                                    onTap: () => _openInstagramConversation(c),
                                    onLongPress: _canEdit('messages')
                                        ? () => _editMessageMeta(
                                            'Instagram:${c['id']}',
                                          )
                                        : null,
                                    assignee:
                                        messageAssignees['Instagram:${c['id']}'],
                                    tags:
                                        messageTags['Instagram:${c['id']}'] ??
                                        const [],
                                  ),
                                ),
                            ...telegramChats
                                .where(
                                  (c) => _telegramTitle(c)
                                      .toLowerCase()
                                      .contains(messagesSearch.toLowerCase()),
                                )
                                .map(
                                  (c) => UnifiedDialog(
                                    platform: 'Telegram',
                                    id:
                                        c['id']?.toString() ??
                                        _telegramTitle(c),
                                    name: _telegramTitle(c),
                                    preview: _telegramPreview(c),
                                    unread: false,
                                    onTap: () => _openTelegramChat(c),
                                    onLongPress: _canEdit('messages')
                                        ? () => _editMessageMeta(
                                            'Telegram:${c['id']}',
                                          )
                                        : null,
                                    assignee:
                                        messageAssignees['Telegram:${c['id']}'],
                                    tags:
                                        messageTags['Telegram:${c['id']}'] ??
                                        const [],
                                  ),
                                ),
                            ...avitoChats
                                .where(
                                  (c) => _avitoChatTitle(c)
                                      .toLowerCase()
                                      .contains(messagesSearch.toLowerCase()),
                                )
                                .map(
                                  (c) => UnifiedDialog(
                                    platform: 'Avito',
                                    id:
                                        c['id']?.toString() ??
                                        _avitoChatTitle(c),
                                    name: _avitoChatTitle(c),
                                    preview: _avitoText(
                                      c['last_message'] is Map
                                          ? Map<String, dynamic>.from(
                                              c['last_message'],
                                            )
                                          : const {},
                                    ),
                                    unread: !readMessageDialogs.contains(
                                      'Avito:${c['id']}',
                                    ),
                                    onTap: () => _openAvitoChat(c),
                                    onLongPress: _canEdit('messages')
                                        ? () => _editMessageMeta(
                                            'Avito:${c['id']}',
                                          )
                                        : null,
                                    assignee:
                                        messageAssignees['Avito:${c['id']}'],
                                    tags:
                                        messageTags['Avito:${c['id']}'] ??
                                        const [],
                                  ),
                                ),
                            ...vkConversations
                                .where(
                                  (c) => _vkConversationTitle(c)
                                      .toLowerCase()
                                      .contains(messagesSearch.toLowerCase()),
                                )
                                .map((c) {
                                  final id =
                                      c['conversation']?['peer']?['id']
                                          ?.toString() ??
                                      _vkConversationTitle(c);
                                  return UnifiedDialog(
                                    platform: 'ВКонтакте',
                                    id: id,
                                    name: _vkConversationTitle(c),
                                    preview: _vkText(
                                      c['last_message'] is Map
                                          ? Map<String, dynamic>.from(
                                              c['last_message'],
                                            )
                                          : const {},
                                    ),
                                    unread: !readMessageDialogs.contains(
                                      'VK:$id',
                                    ),
                                    onTap: () => _openVkConversation(c),
                                    onLongPress: _canEdit('messages')
                                        ? () => _editMessageMeta('VK:$id')
                                        : null,
                                    assignee: messageAssignees['VK:$id'],
                                    tags: messageTags['VK:$id'] ?? const [],
                                  );
                                }),
                          ],
                          mainTextColor: _mainTextColor,
                          mutedTextColor: _mutedTextColor,
                          cardBorderColor: _cardBorderColor,
                        ),
                      ),
                      if (!compact) ...[
                        VerticalDivider(width: 24, color: _cardBorderColor),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Выберите диалог слева',
                              style: TextStyle(color: _mutedTextColor),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _editMessageMeta(String id) async {
    if (!_canEdit('messages')) return;
    final assignee = TextEditingController(text: messageAssignees[id] ?? '');
    final tags = TextEditingController(
      text: (messageTags[id] ?? []).join(', '),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Карточка диалога'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: assignee,
              decoration: const InputDecoration(labelText: 'Ответственный'),
            ),
            TextField(
              controller: tags,
              decoration: const InputDecoration(
                labelText: 'Теги через запятую',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      messageAssignees[id] = assignee.text.trim();
      messageTags[id] = tags.text
          .split(',')
          .map((x) => x.trim())
          .where((x) => x.isNotEmpty)
          .toList();
      await _saveMessageMeta();
      if (mounted) setState(() {});
    }
    assignee.dispose();
    tags.dispose();
  }

  Future<void> _showIntegrationDiagnostics() async {
    final labels = {
      'telegram': 'Telegram',
      'vk': 'ВКонтакте',
      'instagram': 'Instagram',
    };
    await showDialog<void>(
      context: context,
      builder: (_) => IntegrationDiagnosticsDialog(
        canConfigure: canManageIntegrations,
        diagnostics: [
          for (final channel in ['telegram', 'vk', 'instagram'])
            IntegrationDiagnostic(
              name: labels[channel] ?? channel,
              connected: messengerConnected[channel] == true,
              status: messengerStatus[channel] ?? 'Статус неизвестен',
              accountConfigured:
                  prefs
                      .getString('messenger_${channel}_account')
                      ?.trim()
                      .isNotEmpty ==
                  true,
              configureTooltip: 'Проверить снова',
              configureIcon: Icons.refresh,
              onConfigure: () => unawaited(_setupMessenger(channel)),
            ),
          IntegrationDiagnostic(
            name: 'Avito',
            connected: avitoConnected,
            status: avitoStatus,
            accountConfigured: avitoAccounts.isNotEmpty,
            configureTooltip: 'Настроить Avito',
            configureIcon: Icons.settings_outlined,
            onConfigure: () => unawaited(_setupAvito()),
          ),
        ],
      ),
    );
  }

  Widget _callsBlock() => AvitoCallsPanel(
    calls: avitoCalls,
    surfaceColor: _surfaceColor,
    borderColor: _cardBorderColor,
    mainTextColor: _mainTextColor,
    mutedTextColor: _mutedTextColor,
    formatDate: _avitoDate,
  );

  Widget _vkNotificationChatPanel() {
    final peerId = prefs.getString('messenger_vk_notify_peer') ?? '';
    return VkNotificationChatPanel(
      peerId: peerId,
      surfaceColor: _surfaceColor,
      borderColor: _cardBorderColor,
      mainTextColor: _mainTextColor,
      mutedTextColor: _mutedTextColor,
      canEdit: _canEdit('messages'),
      onSendSummary: _sendVkAppointmentsSummary,
      onSendTest: () => _sendVkText(
        peerId: peerId,
        text:
            '✅ Проверка связи: CRM «Чистое место» может отправлять уведомления в этот чат.',
      ),
    );
  }

  Widget _avitoCard() => AvitoConnectionCard(
    accounts: avitoAccounts,
    activeAccountKey: activeAvitoAccountKey,
    connected: avitoConnected,
    loading: avitoLoading,
    status: avitoStatus,
    surfaceColor: _surfaceColor,
    borderColor: _cardBorderColor,
    mainTextColor: _mainTextColor,
    mutedTextColor: _mutedTextColor,
    onRefresh: () => unawaited(_syncAvito()),
    canConfigure: canManageIntegrations,
    onConfigure: () => unawaited(_setupAvito()),
    onSelectAccount: (key) => unawaited(_selectAvitoAccount(key)),
  );

  String _avitoChatTitle(Map<String, dynamic> chat) {
    final users = chat['users'];
    if (users is List) {
      final names = users
          .whereType<Map>()
          .map((u) => u['name']?.toString())
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    return 'Диалог Avito';
  }

  String _avitoText(Map<String, dynamic> message) {
    final content = message['content'];
    if (content is Map) {
      final text = content['text']?.toString();
      if (text != null && text.isNotEmpty) return text;
      if (content['voice'] != null) return 'Голосовое сообщение';
      if (content['image'] != null) return 'Изображение';
    }
    return message['type'] == 'system' ? 'Системное сообщение' : 'Сообщение';
  }

  String _avitoDate(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      final d = DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * 1000,
      ).toLocal();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    final d = DateTime.tryParse(value.toString())?.toLocal();
    return d == null
        ? value.toString()
        : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _avitoWorkspace() => Container(
    constraints: const BoxConstraints(maxWidth: 980),
    height: 540,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _cardBorderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final tabs = [
              _avitoTab('Чаты', Icons.forum_outlined),
              _avitoTab('Звонки', Icons.call_outlined),
            ];
            if (constraints.maxWidth < 620) {
              return Wrap(spacing: 8, runSpacing: 8, children: tabs);
            }
            return Row(
              children: [
                tabs.first,
                const SizedBox(width: 8),
                tabs.last,
                const Spacer(),
                Text(
                  'Данные Avito за последние 30 дней',
                  style: TextStyle(color: _mutedTextColor, fontSize: 12),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: avitoSection == 'Чаты' ? _avitoChatsView() : _avitoCallsView(),
        ),
      ],
    ),
  );

  Widget _avitoTab(String title, IconData icon) {
    final active = avitoSection == title;
    return InkWell(
      onTap: () => setState(() => avitoSection = title),
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF28C28) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: active ? const Color(0xFFF28C28) : _cardBorderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: active ? Colors.white : _mutedTextColor,
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: active ? Colors.white : _mainTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avitoChatsView() => LayoutBuilder(
    builder: (context, constraints) {
      final chatList = avitoChats.isEmpty
          ? Center(
              child: Text(
                'Чатов пока нет',
                style: TextStyle(color: _mutedTextColor),
              ),
            )
          : ListView.separated(
              itemCount: avitoChats.length,
              separatorBuilder: (_, _) =>
                  Divider(color: _cardBorderColor, height: 1),
              itemBuilder: (_, i) {
                final chat = avitoChats[i];
                final selectedChat =
                    selectedAvitoChat?['id']?.toString() ==
                    chat['id']?.toString();
                final last = chat['last_message'] is Map
                    ? Map<String, dynamic>.from(chat['last_message'])
                    : <String, dynamic>{};
                return InkWell(
                  onTap: () => _openAvitoChat(chat),
                  child: Container(
                    color: selectedChat
                        ? const Color(
                            0xFFF28C28,
                          ).withValues(alpha: widget.darkMode ? .18 : .10)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _avitoChatTitle(chat),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _mainTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _avitoText(last),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _mutedTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
      if (constraints.maxWidth < 680) {
        return Column(
          children: [
            SizedBox(height: 120, child: chatList),
            Divider(height: 20, color: _cardBorderColor),
            Expanded(child: _avitoChatView()),
          ],
        );
      }
      return Row(
        children: [
          SizedBox(width: 310, child: chatList),
          VerticalDivider(color: _cardBorderColor, width: 26),
          Expanded(child: _avitoChatView()),
        ],
      );
    },
  );

  Widget _avitoChatView() {
    if (selectedAvitoChat == null) {
      return Center(
        child: Text(
          'Выберите диалог слева',
          style: TextStyle(color: _mutedTextColor),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _avitoChatTitle(selectedAvitoChat!),
          style: TextStyle(
            color: _mainTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: avitoChatMessages.length,
            itemBuilder: (_, i) {
              final message = avitoChatMessages[i];
              final outgoing = message['direction'] == 'out';
              return Align(
                alignment: outgoing
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: outgoing
                        ? const Color(0xFFF28C28)
                        : (widget.darkMode
                              ? const Color(0xFF30343B)
                              : const Color(0xFFF0F2F5)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _avitoText(message),
                        style: TextStyle(
                          color: outgoing ? Colors.white : _mainTextColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _avitoDate(message['created']),
                        style: TextStyle(
                          color: outgoing ? Colors.white70 : _mutedTextColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            PopupMenuButton<String>(
              tooltip: 'Быстрый ответ',
              icon: const Icon(Icons.flash_on_outlined),
              onSelected: (value) => avitoReplyController.text = value,
              itemBuilder: (_) => quickReplyTemplates
                  .map(
                    (t) => PopupMenuItem(
                      value: t,
                      child: SizedBox(
                        width: 320,
                        child: Text(
                          t,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            Expanded(
              child: TextField(
                controller: avitoReplyController,
                maxLength: 1000,
                onSubmitted: (_) => _sendAvitoMessage(),
                decoration: const InputDecoration(
                  hintText: 'Напишите ответ клиенту Avito…',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _canEdit('messages') ? _sendAvitoMessage : null,
              color: const Color(0xFFF28C28),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }

  Widget _avitoAudioPlayer() {
    if (playingAvitoCallId == null || playingAvitoAudioPath == null) {
      return const SizedBox.shrink();
    }
    final maximum = avitoAudioDuration.inMilliseconds.toDouble();
    final current = avitoAudioPosition.inMilliseconds
        .clamp(0, avitoAudioDuration.inMilliseconds)
        .toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF242931),
        border: Border.all(color: const Color(0xFFF28C28)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: avitoAudioPlaying ? 'Пауза' : 'Продолжить',
            color: const Color(0xFFF28C28),
            onPressed: () async {
              if (avitoAudioPlaying) {
                await avitoAudioPlayer.pause();
              } else {
                await avitoAudioPlayer.play();
              }
            },
            icon: Icon(
              avitoAudioPlaying ? Icons.pause_circle : Icons.play_circle,
            ),
          ),
          Expanded(
            child: Slider(
              value: maximum == 0 ? 0 : current,
              max: maximum == 0 ? 1 : maximum,
              activeColor: const Color(0xFFF28C28),
              onChanged: maximum == 0
                  ? null
                  : (value) => avitoAudioPlayer.seek(
                      Duration(milliseconds: value.round()),
                    ),
            ),
          ),
          Text(
            '${_avitoAudioTime(avitoAudioPosition)} / ${_avitoAudioTime(avitoAudioDuration)}',
            style: TextStyle(
              color: _mainTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.cloud_done_outlined,
            color: Color(0xFFF28C28),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _avitoCallsView() => avitoCalls.isEmpty
      ? Center(
          child: Text(
            'Звонков Avito за выбранный период нет',
            style: TextStyle(color: _mutedTextColor),
          ),
        )
      : Column(
          children: [
            _avitoAudioPlayer(),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Кэш: $avitoCachedAudioCount • ${formatAvitoCacheSize(avitoCachedAudioBytes)}',
                    style: TextStyle(color: _mutedTextColor, fontSize: 12),
                  ),
                  TextButton.icon(
                    onPressed: avitoCacheLoading ? null : _cacheAllAvitoCalls,
                    icon: avitoCacheLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_for_offline_outlined),
                    label: Text(
                      avitoCacheLoading
                          ? 'Сохраняю записи…'
                          : 'Скачать все записи',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearAvitoAudioCache,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Очистить кэш'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: avitoCalls.length,
                separatorBuilder: (_, _) =>
                    Divider(color: _cardBorderColor, height: 1),
                itemBuilder: (_, i) {
                  final call = avitoCalls[i];
                  final seconds =
                      int.tryParse(
                        (call['duration'] ??
                                call['talkDuration'] ??
                                call['durationSeconds'] ??
                                call['duration_seconds'] ??
                                '')
                            .toString(),
                      ) ??
                      0;
                  final duration =
                      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
                  final id = _avitoCallId(call);
                  final loading =
                      id != null && loadingAvitoCallIds.contains(id);
                  final transcribing =
                      id != null && transcribingAvitoCallIds.contains(id);
                  final analyzing =
                      id != null && analyzingAvitoCallIds.contains(id);
                  final transcription = id == null
                      ? null
                      : avitoTranscriptions[id];
                  final analysis = id == null ? null : avitoCallAnalyses[id];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const Icon(Icons.call, color: Color(0xFFF28C28)),
                    title: Text(
                      call['buyerPhone']?.toString() ?? 'Клиент Avito',
                      style: TextStyle(
                        color: _mainTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${_avitoDate(call['callTime'] ?? call['createTime'] ?? call['startTime'])} • $duration${call['itemId'] != null ? ' • Объявление ${call['itemId']}' : ''}',
                      style: TextStyle(color: _mutedTextColor),
                    ),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        Tooltip(
                          message: 'Открыть запись в аудиоплеере',
                          child: OutlinedButton.icon(
                            onPressed: loading
                                ? null
                                : () => _playAvitoCall(call),
                            icon: loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.play_circle_outline,
                                    size: 18,
                                  ),
                            label: Text(loading ? 'Открываю…' : 'Прослушать'),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: transcribing
                              ? null
                              : () => _transcribeAvitoCall(call),
                          icon: transcribing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  transcription == null
                                      ? Icons.subtitles_outlined
                                      : Icons.article_outlined,
                                  size: 18,
                                ),
                          label: Text(
                            transcribing
                                ? 'Расшифровка…'
                                : transcription == null
                                ? 'В текст'
                                : 'Текст',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              id == null || transcription == null || analyzing
                              ? null
                              : () => _analyzeAvitoCall(call),
                          icon: analyzing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  analysis == null
                                      ? Icons.analytics_outlined
                                      : Icons.insights_outlined,
                                  size: 18,
                                ),
                          label: Text(analyzing ? 'Анализ…' : 'Анализ'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
  Widget _messengerCard(
    String key,
    String title,
    IconData icon,
    String description,
  ) => MessengerConnectionCard(
    title: title,
    icon: icon,
    description: description,
    status: messengerStatus[key] ?? '',
    connected: messengerConnected[key] ?? false,
    canConfigure: canManageIntegrations,
    surfaceColor: _surfaceColor,
    borderColor: _cardBorderColor,
    mainTextColor: _mainTextColor,
    mutedTextColor: _mutedTextColor,
    onConfigure: () => _setupMessenger(key),
  );

  Future<void> _manageUserProfiles() async {
    if (currentRole != 'Владелец' || _session == null || _authService == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: const Text('Профили пользователей'),
          content: SizedBox(
            width: 520,
            height: 360,
            child: ListView.separated(
              itemCount: userProfiles.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final profile = userProfiles[index];
                final onlyOwner =
                    profile.role == 'Владелец' &&
                    userProfiles
                            .where(
                              (item) => item.role == 'Владелец' && item.active,
                            )
                            .length ==
                        1;
                final canDelete = !onlyOwner && profile.id != currentUserId;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      profile.name.isEmpty
                          ? '?'
                          : profile.name[0].toUpperCase(),
                    ),
                  ),
                  title: Text(profile.name),
                  subtitle: Text(
                    '${profile.role} · ${profile.active ? 'активен' : 'отключён'}',
                  ),
                  onTap: () async {
                    final updated = await _editServerUser(profile);
                    if (updated != null) refresh(() {});
                  },
                  trailing: IconButton(
                    tooltip: canDelete
                        ? 'Отключить пользователя'
                        : 'Нельзя отключить текущего или единственного владельца',
                    onPressed: canDelete
                        ? () async {
                            try {
                              final users = await _authService!.deactivateUser(
                                _session!.token,
                                profile.id,
                              );
                              _serverUsers = users;
                              userProfiles = users
                                  .map(
                                    (user) => UserProfile(
                                      id: user.id,
                                      name: user.name,
                                      role: user.role,
                                      active: user.active,
                                      permissions: user.permissions,
                                    ),
                                  )
                                  .toList();
                              refresh(() {});
                            } catch (error) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_safeAuthError(error)),
                                  ),
                                );
                              }
                            }
                          }
                        : null,
                    icon: const Icon(Icons.person_off_outlined),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final profile = await _editServerUser(null);
                if (profile == null) return;
                refresh(() {});
              },
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Добавить'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }

  Future<CrmUser?> _editServerUser(UserProfile? existing) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final pin = TextEditingController();
    var role = existing?.role ?? 'Мастер';
    var active = existing?.active ?? true;
    final permissions = Map<String, String>.from(
      existing?.permissions ?? defaultPermissionsForRole(role),
    );
    CrmUser? result;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refresh) => AlertDialog(
          title: Text(
            existing == null ? 'Новый пользователь' : 'Права пользователя',
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Имя сотрудника',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pin,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? 'PIN из 4 цифр'
                          : 'Новый PIN (оставьте пустым, чтобы не менять)',
                      counterText: '',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Роль'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Владелец',
                        child: Text('Владелец'),
                      ),
                      DropdownMenuItem(
                        value: 'Администратор',
                        child: Text('Администратор'),
                      ),
                      DropdownMenuItem(value: 'Мастер', child: Text('Мастер')),
                      DropdownMenuItem(
                        value: 'Бухгалтер',
                        child: Text('Бухгалтер'),
                      ),
                      DropdownMenuItem(
                        value: 'Сотрудник',
                        child: Text('Сотрудник'),
                      ),
                    ],
                    onChanged: (value) => refresh(() {
                      role = value ?? role;
                      if (existing == null) {
                        permissions
                          ..clear()
                          ..addAll(defaultPermissionsForRole(role));
                      }
                    }),
                  ),
                  SwitchListTile(
                    value: active,
                    onChanged: (value) => refresh(() => active = value),
                    title: const Text('Активный пользователь'),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Индивидуальные права'),
                  ),
                  const SizedBox(height: 6),
                  ...crmPermissionAreas.map(
                    (area) => DropdownButtonFormField<String>(
                      initialValue: permissions[area] ?? 'hidden',
                      decoration: InputDecoration(
                        labelText: crmPermissionLabels[area],
                      ),
                      items: PermissionLevel.values
                          .map(
                            (level) => DropdownMenuItem(
                              value: level.value,
                              child: Text(level.label),
                            ),
                          )
                          .toList(),
                      onChanged: role == 'Владелец'
                          ? null
                          : (value) => refresh(
                              () => permissions[area] = value ?? 'hidden',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && _session != null && _authService != null) {
      final value = name.text.trim();
      if (value.isEmpty || (existing == null && !isValidPin(pin.text))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Укажите имя и PIN из 4 цифр.')),
          );
        }
      } else {
        try {
          final candidate = CrmUser(
            id: existing?.id ?? '',
            name: value,
            role: role,
            active: active,
            permissions: role == 'Владелец'
                ? defaultPermissionsForRole(role)
                : permissions,
          );
          final users = await _authService!.saveUser(
            _session!.token,
            candidate,
            pin: pin.text.trim().isEmpty ? null : pin.text.trim(),
          );
          _serverUsers = users;
          userProfiles = users
              .map(
                (user) => UserProfile(
                  id: user.id,
                  name: user.name,
                  role: user.role,
                  active: user.active,
                  permissions: user.permissions,
                ),
              )
              .toList();
          result = users.cast<CrmUser?>().firstWhere(
            (user) => user?.name == value,
            orElse: () => null,
          );
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_safeAuthError(error))));
          }
        }
      }
    }
    name.dispose();
    pin.dispose();
    return result;
  }

  CrmSyncStatus get _syncStatus => CrmSyncStatus(
    serverConnected: _session != null && syncEndpoint.isNotEmpty,
    sheetsOffline: sheetsOfflineMode,
    syncing: pendingChangesSyncing || loading,
    pendingChanges: localChangeQueue.items.length,
    lastSuccessfulSync: lastPendingChangesSync ?? lastSheetsSync,
    error: pendingChangesSyncError ?? sheetError,
  );

  List<IntegrationHealth> get _integrationHealth => [
    IntegrationHealth(
      name: 'CRM-сервер',
      state: _session != null && syncEndpoint.isNotEmpty
          ? CrmHealthState.connected
          : CrmHealthState.notConfigured,
      detail: _session == null ? 'Требуется вход по PIN' : 'Сессия активна',
    ),
    IntegrationHealth(
      name: 'Google Sheets',
      state: sheetsOfflineMode
          ? CrmHealthState.offline
          : currentSheetId.isEmpty && !_hasProtectedSheetAccess
          ? CrmHealthState.notConfigured
          : loading
          ? CrmHealthState.pending
          : CrmHealthState.connected,
      detail: sheetsOfflineMode
          ? (sheetError ?? 'Показан сохранённый кэш')
          : 'Источники: ${_dataSource('deals', SheetsSchema.dealsSheet)}, ${_dataSource('accounting', SheetsSchema.accountingSheet)}',
    ),
    IntegrationHealth(
      name: 'Google Календарь',
      state: calendarLoading
          ? CrmHealthState.pending
          : calendarConnected
          ? CrmHealthState.connected
          : CrmHealthState.notConfigured,
      detail: calendarStatus ?? 'Не подключён',
    ),
    IntegrationHealth(
      name: 'Avito',
      state: avitoLoading
          ? CrmHealthState.pending
          : avitoConnected
          ? CrmHealthState.connected
          : avitoAccounts.isEmpty
          ? CrmHealthState.notConfigured
          : CrmHealthState.error,
      detail: avitoStatus,
    ),
    for (final channel in const ['telegram', 'vk', 'instagram'])
      IntegrationHealth(
        name: switch (channel) {
          'telegram' => 'Telegram',
          'vk' => 'VK',
          _ => 'Instagram',
        },
        state: messengerConnected[channel] == true
            ? CrmHealthState.connected
            : CrmHealthState.notConfigured,
        detail: messengerStatus[channel] ?? 'Не подключён',
      ),
    IntegrationHealth(
      name: 'AI',
      state: aiSettings.enabled
          ? CrmHealthState.connected
          : CrmHealthState.notConfigured,
      detail: aiSettings.enabled ? 'Настроен владельцем' : 'Не подключён',
    ),
  ];

  Future<void> _refreshEverything() async {
    if (_session == null) return;
    await Future.wait([_loadDeals(), _loadAccounting()]);
    await _refreshWorkspaceFromCloud();
    if (calendarConnected) await _loadCalendarEvents();
    if (avitoAccounts.isNotEmpty) await _connectAvito(silent: true);
    if (messengerConnected['vk'] == true) {
      await _loadVkConversations(silent: true);
    }
    if (messengerConnected['telegram'] == true) {
      await _loadTelegramUpdates(silent: true);
    }
    if (messengerConnected['instagram'] == true) {
      await _loadInstagramConversations(silent: true);
    }
    await _syncPendingChanges();
  }

  Widget _settings() => SettingsPage(
    currentUserId: currentUserId,
    userProfiles: userProfiles,
    onSelectUser: (_) => unawaited(_switchUser()),
    sheetController: sheetController,
    canManageIntegrations: canManageIntegrations,
    canBackup: _canEdit('admin'),
    canRestore: _canEdit('admin'),
    canEditMessages: _canEdit('messages'),
    isOwner: currentRole == 'Владелец',
    onSaveAndCheckSheet: () async {
      await _saveSheetUrl();
      if (mounted) setState(() {});
      await _loadAccounting();
    },
    onManageServices: _manageServices,
    onBackup: _backupLocalData,
    onRestore: _restoreLocalData,
    onManageQuickReplies: _manageQuickReplies,
    onSetupSync: _setupSyncEndpoint,
    onSetupAi: _setupAi,
    aiConfigured: aiSettings.enabled && aiApiKey.isNotEmpty,
    onManageUsers: _manageUserProfiles,
    onMigrateConfiguration: () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Перенести ключи в общий CRM-сервер?'),
          content: const Text(
            'Ключи таблиц, календаря, мессенджеров, Avito и AI будут сохранены в Script Properties и удалены с этого компьютера после подтверждённого переноса. Сотрудники их не увидят.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Перенести'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _migrateLocalConfiguration(clearLocalSecrets: true);
        await prefs.setBool('crm_server_managed_secrets', true);
      }
    },
    onFullSync: _syncAllCrmData,
    onSwitchUser: _switchUser,
    onLogout: _confirmLogout,
    hasSyncCredentials: syncEndpoint.isNotEmpty && syncToken.isNotEmpty,
    pendingChangesCount: localChangeQueue.items.length,
    pendingChangesSyncing: pendingChangesSyncing,
    pendingChangesSyncError: pendingChangesSyncError,
    lastPendingChangesSync: lastPendingChangesSync,
    syncStatus: _syncStatus,
    integrationHealth: _integrationHealth,
    onRefreshEverything: _refreshEverything,
    onSyncPendingChanges: _syncPendingChanges,
    onExportPendingChanges: _exportPendingChanges,
    auditEntries: auditEntries,
  );

  Future<void> _syncAllCrmData() async {
    if (currentRole != 'Владелец' ||
        syncEndpoint.isEmpty ||
        syncToken.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выгрузить все данные CRM?'),
        content: const Text(
          'Текущие клиенты, сделки, склад, финансы, записи, услуги, заметки, база знаний и общие настройки сообщений будут сохранены на общем CRM-сервере. Выполняйте это с компьютера владельца с актуальными данными.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Выгрузить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    const snapshots = [
      ('Клиент', 'Полная выгрузка клиентов'),
      ('Товар', 'Полная выгрузка склада'),
      ('Сделка', 'Полная выгрузка сделок'),
      ('Бухгалтерия', 'Полная выгрузка бухгалтерии'),
      ('Запись', 'Полная выгрузка записей'),
      ('Справочник услуг', 'Полная выгрузка услуг'),
      ('Рабочее пространство', 'Полная выгрузка заметок и планов'),
      ('База знаний', 'Полная выгрузка базы знаний'),
      ('Сообщения', 'Полная выгрузка общих сообщений'),
      ('Журнал CRM', 'Полная выгрузка журнала'),
    ];
    for (final snapshot in snapshots) {
      localChangeQueue.enqueue(
        entity: snapshot.$1,
        details: snapshot.$2,
        payload: _syncPayload(snapshot.$1),
      );
    }
    await _saveCrmData();
    await _syncPendingChanges();
  }

  Future<void> _setupAi() async {
    if (!canManageIntegrations) return;
    final endpoint = TextEditingController(text: aiSettings.baseUrl);
    final model = TextEditingController(text: aiSettings.model);
    final maxTokens = TextEditingController(
      text: aiSettings.maxTokens.toString(),
    );
    final temperature = TextEditingController(
      text: aiSettings.temperature.toString(),
    );
    final instruction = TextEditingController(
      text: aiSettings.systemInstruction,
    );
    final key = TextEditingController(text: aiApiKey);
    var enabled = aiSettings.enabled;
    var storeHistory = aiSettings.storeConversationText;
    var checkingConnection = false;
    String? connectionResult;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('AI для тест-бота'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    value: enabled,
                    onChanged: (value) => refresh(() => enabled = value),
                    title: const Text('Использовать внешний AI'),
                  ),
                  TextField(
                    controller: endpoint,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      helperText: 'Codex Sale: https://codex.sale/v1',
                    ),
                    enabled: enabled,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: key,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API-ключ (хранится в защищённом хранилище)',
                    ),
                    enabled: enabled,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: model,
                    decoration: const InputDecoration(
                      labelText: 'Модель',
                      hintText: 'gpt-5.4',
                    ),
                    enabled: enabled,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: !enabled || checkingConnection
                          ? null
                          : () async {
                              final parsedEndpoint = Uri.tryParse(
                                endpoint.text.trim(),
                              );
                              final enteredKey = key.text.trim();
                              if (parsedEndpoint == null ||
                                  parsedEndpoint.scheme != 'https' ||
                                  enteredKey.isEmpty) {
                                refresh(
                                  () => connectionResult =
                                      'Укажите HTTPS Base URL и API-ключ.',
                                );
                                return;
                              }
                              refresh(() {
                                checkingConnection = true;
                                connectionResult = null;
                              });
                              try {
                                final check =
                                    await OpenAiCompatibleProvider(
                                      apiKey: enteredKey,
                                      client: _apiClient,
                                    ).verifyConnection(
                                      settings: AiSettings(
                                        baseUrl: endpoint.text
                                            .trim()
                                            .replaceAll(RegExp(r'/+$'), ''),
                                        model: model.text.trim().isEmpty
                                            ? AiSettings.defaultModel
                                            : model.text.trim(),
                                      ),
                                    );
                                if (!context.mounted) return;
                                refresh(() {
                                  checkingConnection = false;
                                  connectionResult =
                                      check.availableModels.isEmpty
                                      ? 'Подключение успешно. Модель ${check.model} отвечает.'
                                      : 'Подключение успешно. Доступно моделей: ${check.availableModels.length}.';
                                });
                              } catch (error) {
                                if (!context.mounted) return;
                                refresh(() {
                                  checkingConnection = false;
                                  connectionResult =
                                      'Ошибка подключения: $error';
                                });
                              }
                            },
                      icon: checkingConnection
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering, size: 18),
                      label: const Text('Проверить подключение'),
                    ),
                  ),
                  if (connectionResult != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        connectionResult!,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              connectionResult!.startsWith(
                                'Подключение успешно',
                              )
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: maxTokens,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Лимит токенов',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: temperature,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Температура (0–1)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: instruction,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Системная инструкция',
                    ),
                  ),
                  SwitchListTile(
                    value: storeHistory,
                    onChanged: (value) => refresh(() => storeHistory = value),
                    title: const Text(
                      'Хранить текст тестовых диалогов локально',
                    ),
                  ),
                  const Text(
                    'Ключ не отправляется в Google Sheets, CSV, резервную копию или журналы.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final parsedEndpoint = Uri.tryParse(endpoint.text.trim());
      if (enabled &&
          (parsedEndpoint == null ||
              parsedEndpoint.scheme != 'https' ||
              key.text.trim().isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Для внешнего AI укажите HTTPS endpoint и API-ключ',
              ),
            ),
          );
        }
      } else {
        aiSettings = AiSettings(
          enabled: enabled,
          baseUrl: endpoint.text.trim().replaceAll(RegExp(r'/+$'), ''),
          model: model.text.trim().isEmpty
              ? AiSettings.defaultModel
              : model.text.trim(),
          maxTokens: _num(maxTokens.text).round().clamp(64, 2000),
          temperature: _num(temperature.text).clamp(0, 1),
          systemInstruction: instruction.text.trim(),
          storeConversationText: storeHistory,
        );
        aiApiKey = enabled ? key.text.trim() : '';
        await prefs.setString('ai_settings', aiSettings.encode());
        if (aiApiKey.isNotEmpty) {
          await secretStore.write('ai_api_key', aiApiKey);
        } else {
          await secretStore.delete('ai_api_key');
        }
        if (!storeHistory) await prefs.remove('bot_test_conversations');
        if (mounted) setState(() {});
        if (enabled && aiApiKey.trim().isNotEmpty && avitoCalls.isNotEmpty) {
          unawaited(_autoProcessAvitoCalls());
        }
      }
    }
    for (final controller in [
      endpoint,
      model,
      maxTokens,
      temperature,
      instruction,
      key,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _showKnowledgeBaseVersions() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('История базы знаний'),
        content: SizedBox(
          width: 680,
          height: 440,
          child: knowledgeVersions.isEmpty
              ? const Center(child: Text('Версий пока нет'))
              : ListView.builder(
                  itemCount: knowledgeVersions.length,
                  itemBuilder: (context, index) {
                    final version = knowledgeVersions.reversed.elementAt(index);
                    return ListTile(
                      title: Text('${version.source} • ${version.createdAt}'),
                      subtitle: Text(
                        version.comment.isEmpty
                            ? version.content.replaceAll('\n', ' ').trim()
                            : version.comment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        child: const Text('Открыть'),
                        onPressed: () async {
                          final restore = await showDialog<bool>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                              title: const Text('Версия базы знаний'),
                              content: SingleChildScrollView(
                                child: SelectableText(version.content),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog, false),
                                  child: const Text('Закрыть'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(dialog, true),
                                  child: const Text('Восстановить'),
                                ),
                              ],
                            ),
                          );
                          if (restore == true) {
                            knowledgeBase = version.content;
                            await _saveKnowledgeBase(
                              source: 'восстановление версии',
                              comment: version.createdAt,
                            );
                            if (context.mounted) Navigator.pop(context);
                            if (mounted) setState(() {});
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _manageQuickReplies() async {
    if (!_canEdit('messages')) return;
    await showDialog<void>(
      context: context,
      builder: (_) => QuickRepliesDialog(
        templates: quickReplyTemplates,
        onSave: (templates) async {
          quickReplyTemplates
            ..clear()
            ..addAll(templates);
          await _saveMessageMeta();
        },
      ),
    );
  }

  Widget _crm() {
    final search = crmSearchController;
    var sourceFilter = 'Все источники';
    var responsibleFilter = 'Все ответственные';
    var contactPeriodFilter = 'Все контакты';
    var crmPage = 0;
    const pageSize = 50;
    return StatefulBuilder(
      builder: (context, refresh) {
        final filtered = clients
            .where(
              (c) => clientMatchesQuery(
                query: search.text,
                name: c.name,
                phone: c.phone,
                car: c.car,
                source: c.source,
                status: c.status,
                phones: c.phones,
                cars: c.cars,
              ),
            )
            .where(
              (c) =>
                  sourceFilter == 'Все источники' || c.source == sourceFilter,
            )
            .where(
              (c) =>
                  clientStatusFilter == 'Все статусы' ||
                  c.status == clientStatusFilter,
            )
            .where(
              (c) =>
                  responsibleFilter == 'Все ответственные' ||
                  c.responsible == responsibleFilter,
            )
            .where((c) {
              final days = contactPeriodFilter == 'Все контакты'
                  ? null
                  : contactPeriodFilter == 'Последняя неделя'
                  ? 7
                  : 30;
              return clientContactInPeriod(
                c.lastContact,
                now: DateTime.now(),
                days: days,
              );
            })
            .toList();
        final pageCount = filtered.isEmpty
            ? 1
            : (filtered.length / pageSize).ceil();
        if (crmPage >= pageCount) crmPage = pageCount - 1;
        final pageItems = filtered
            .skip(crmPage * pageSize)
            .take(pageSize)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Клиенты и автомобили',
              style: TextStyle(
                color: _mainTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: TextField(
                    controller: search,
                    onChanged: (_) {
                      crmSearchDebounce?.cancel();
                      crmSearchDebounce = Timer(
                        AppConstants.searchDebounce,
                        () {
                          if (mounted) refresh(() => crmPage = 0);
                        },
                      );
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Поиск клиентов',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: sourceFilter,
                  items: [
                    const DropdownMenuItem(
                      value: 'Все источники',
                      child: Text('Все источники'),
                    ),
                    ...clients
                        .map((c) => c.source)
                        .where((s) => s.trim().isNotEmpty)
                        .toSet()
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (value) => refresh(() {
                    sourceFilter = value ?? 'Все источники';
                    crmPage = 0;
                  }),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: clientStatusFilter,
                  items: [
                    const DropdownMenuItem(
                      value: 'Все статусы',
                      child: Text('Все статусы'),
                    ),
                    ...clientStatuses.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: (value) => refresh(() {
                    clientStatusFilter = value ?? 'Все статусы';
                    crmPage = 0;
                  }),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: responsibleFilter,
                  items: [
                    const DropdownMenuItem(
                      value: 'Все ответственные',
                      child: Text('Все ответственные'),
                    ),
                    ...clients
                        .map((c) => c.responsible)
                        .where((s) => s.trim().isNotEmpty)
                        .toSet()
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (value) => refresh(() {
                    responsibleFilter = value ?? 'Все ответственные';
                    crmPage = 0;
                  }),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: contactPeriodFilter,
                  items: const [
                    DropdownMenuItem(
                      value: 'Все контакты',
                      child: Text('Все контакты'),
                    ),
                    DropdownMenuItem(
                      value: 'Последняя неделя',
                      child: Text('Контакт: 7 дней'),
                    ),
                    DropdownMenuItem(
                      value: 'Последний месяц',
                      child: Text('Контакт: 30 дней'),
                    ),
                  ],
                  onChanged: (value) => refresh(() {
                    contactPeriodFilter = value ?? 'Все контакты';
                    crmPage = 0;
                  }),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: !_canEdit('clients')
                      ? null
                      : () async {
                          final name = TextEditingController();
                          final phone = TextEditingController();
                          final car = TextEditingController();
                          final responsible = TextEditingController();
                          final telegramChatId = TextEditingController();
                          final vkPeerId = TextEditingController();
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              insetPadding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              title: const Text('Новый клиент'),
                              content: SizedBox(
                                width: 520,
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        controller: name,
                                        decoration: const InputDecoration(
                                          labelText: 'Имя',
                                        ),
                                      ),
                                      TextField(
                                        controller: phone,
                                        decoration: const InputDecoration(
                                          labelText: 'Телефон',
                                        ),
                                      ),
                                      TextField(
                                        controller: car,
                                        decoration: const InputDecoration(
                                          labelText: 'Автомобиль',
                                        ),
                                      ),
                                      TextField(
                                        controller: responsible,
                                        decoration: const InputDecoration(
                                          labelText: 'Ответственный',
                                        ),
                                      ),
                                      TextField(
                                        controller: telegramChatId,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Telegram chat ID (необязательно)',
                                        ),
                                      ),
                                      TextField(
                                        controller: vkPeerId,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'VK peer ID (необязательно)',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d),
                                  child: const Text('Отмена'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(
                                    d,
                                    name.text.trim().isNotEmpty,
                                  ),
                                  child: const Text('Сохранить'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            final duplicate = isDuplicatePhone(
                              phone.text,
                              clients.map((c) => c.phone),
                            );
                            if (duplicate && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Клиент с таким телефоном уже существует',
                                  ),
                                ),
                              );
                            } else {
                              clients.add(
                                Client(
                                  id: stableClientId(
                                    phone: phone.text,
                                    name: name.text,
                                  ),
                                  name: name.text.trim(),
                                  phone: phone.text.trim(),
                                  car: car.text.trim(),
                                  responsible: responsible.text.trim(),
                                  telegramChatId: telegramChatId.text.trim(),
                                  vkPeerId: vkPeerId.text.trim(),
                                ),
                              );
                              _audit('Создан', 'Клиент', name.text.trim());
                              await _saveCrmData();
                              refresh(() {});
                            }
                          }
                          for (var c in [
                            name,
                            phone,
                            car,
                            responsible,
                            telegramChatId,
                            vkPeerId,
                          ]) {
                            c.dispose();
                          }
                        },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Новый клиент'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF28C28),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClientResultsList(
              clients: pageItems,
              totalCount: filtered.length,
              page: crmPage,
              pageCount: pageCount,
              canEdit: _canEdit('clients'),
              onOpen: (client) => _showClientCard(client, refresh),
              onDelete: (client) => _deleteClient(client, refresh),
              onPageChanged: (page) => refresh(() => crmPage = page),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteClient(Client client, StateSetter refresh) async {
    if (!_canEdit('clients')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить клиента?'),
        content: Text('«${client.name}» будет удалён из локальной CRM.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    clients.remove(client);
    await _saveCrmData();
    _audit('Удалён', 'Клиент', client.name);
    refresh(() {});
  }

  Future<void> _editClient(Client client, StateSetter refresh) async {
    if (!_canEdit('clients')) return;
    final name = TextEditingController(text: client.name),
        phone = TextEditingController(text: client.phone),
        car = TextEditingController(text: client.car),
        note = TextEditingController(text: client.note),
        responsible = TextEditingController(text: client.responsible),
        telegramChatId = TextEditingController(text: client.telegramChatId),
        vkPeerId = TextEditingController(text: client.vkPeerId),
        phones = TextEditingController(text: client.phones.join(', ')),
        cars = TextEditingController(text: client.cars.join(', '));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Карточка клиента'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Имя'),
              ),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Телефон'),
              ),
              TextField(
                controller: car,
                decoration: const InputDecoration(labelText: 'Автомобиль'),
              ),
              TextField(
                controller: phones,
                decoration: const InputDecoration(
                  labelText: 'Все телефоны (через запятую)',
                ),
              ),
              TextField(
                controller: cars,
                decoration: const InputDecoration(
                  labelText: 'Все автомобили (через запятую)',
                ),
              ),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Комментарий'),
              ),
              TextField(
                controller: responsible,
                decoration: const InputDecoration(labelText: 'Ответственный'),
              ),
              TextField(
                controller: telegramChatId,
                decoration: const InputDecoration(
                  labelText: 'Telegram chat ID для напоминаний',
                ),
              ),
              TextField(
                controller: vkPeerId,
                decoration: const InputDecoration(
                  labelText: 'VK peer ID для напоминаний',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, name.text.trim().isNotEmpty),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final oldCar = client.car;
      client.name = name.text.trim();
      client.phone = phone.text.trim();
      client.car = car.text.trim();
      client.note = note.text.trim();
      client.responsible = responsible.text.trim();
      client.telegramChatId = telegramChatId.text.trim();
      client.vkPeerId = vkPeerId.text.trim();
      client.phones
        ..clear()
        ..addAll(_splitClientValues(phones.text, client.phone));
      client.cars
        ..clear()
        ..addAll(_splitClientValues(cars.text, client.car));
      client.syncVehicleIds();
      client.lastContact = DateTime.now().toIso8601String();
      if (client.car != oldCar && client.car.trim().isNotEmpty) {
        client.carHistory.add(
          '${DateTime.now().toIso8601String()}: ${client.car}',
        );
      }
      client.interactionHistory.add(
        '${DateTime.now().toIso8601String()}: Изменена карточка',
      );
      await _saveCrmData();
      _audit('Изменён', 'Клиент', client.name);
      if (mounted) refresh(() {});
    }
    for (final c in [
      name,
      phone,
      car,
      note,
      responsible,
      telegramChatId,
      vkPeerId,
      phones,
      cars,
    ]) {
      c.dispose();
    }
  }

  List<String> _splitClientValues(String raw, String primary) {
    final values = raw
        .split(RegExp(r'[,;\\n]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (primary.trim().isNotEmpty && !values.contains(primary.trim())) {
      values.insert(0, primary.trim());
    }
    return values.toSet().toList();
  }

  Future<void> _showClientCard(Client client, StateSetter refresh) async {
    final relatedDeals = dealRows
        .skip(1)
        .where(
          (row) =>
              row.length > 17 &&
              (row[17] == client.name ||
                  (client.phones.isNotEmpty &&
                      row.length > 2 &&
                      client.phones.contains(row[2]))),
        )
        .toList();
    final relatedAppointments = calendarEvents.where((event) {
      final private =
          ((event['extendedProperties'] as Map?)?['private'] as Map?) ?? {};
      return private['clientId']?.toString() == client.id ||
          private['name']?.toString() == client.name;
    }).toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ClientDetailDialog(
        client: client,
        relatedDeals: relatedDeals,
        relatedAppointments: relatedAppointments,
        statuses: clientStatuses,
        appointmentTime: _eventTime,
        canEditDeals: _canEdit('deals'),
        canEditCalendar: _canEdit('calendar'),
        canEditClients: _canEdit('clients'),
        canContact: _canEdit('clients') || _canEdit('messages'),
        onStatusChanged: (status) async {
          if (!_canEdit('clients')) return;
          client.status = status;
          await _saveCrmData();
          _audit('Статус изменён', 'Клиент', '${client.name}: $status');
          if (mounted) setState(() {});
        },
        onCall: () => launchUrl(Uri.parse('tel:${client.phone.trim()}')),
        onMessage: () => launchUrl(Uri.parse('sms:${client.phone.trim()}')),
        onCreateDeal: () {
          Navigator.pop(dialogContext);
          _addManualDeal({
            'extendedProperties': {
              'private': {
                'name': client.name,
                'phone': client.phone,
                'car': client.car,
                'vehicleId': client.vehicleIdFor(client.car) ?? '',
                'source': client.source,
              },
            },
          });
        },
        onCreateAppointment: () {
          Navigator.pop(dialogContext);
          _editCalendarEvent({
            'extendedProperties': {
              'private': {
                'clientId': client.id,
                'name': client.name,
                'phone': client.phone,
                'car': client.car,
                'source': client.source,
              },
            },
          });
        },
        onEdit: () {
          Navigator.pop(dialogContext);
          _editClient(client, refresh);
        },
      ),
    );
  }

  Widget _stock() => StockPage(
    items: stockItems,
    movementCount: (item) =>
        stockMovements.where((movement) => movement.itemId == item.id).length,
    query: stockSearch,
    page: stockPage,
    pageSize: stockPageSize,
    canEdit: _canEdit('stock'),
    onAdd: () {
      if (!_canEdit('stock')) return;
      setState(() {
        stockItems.add(
          StockItem(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: 'Новый товар',
          ),
        );
        stockPage = 0;
      });
      unawaited(_saveCrmData());
    },
    onSearchChanged: (value) {
      stockSearchDebounce?.cancel();
      stockSearchDebounce = Timer(AppConstants.searchDebounce, () {
        if (mounted) {
          setState(() {
            stockSearch = value;
            stockPage = 0;
          });
        }
      });
    },
    onPageChanged: (page) => setState(() => stockPage = page),
    onEdit: _editStock,
    onMovement: _stockMovement,
    onShowMovements: _showStockMovements,
    onDelete: _deleteStockItem,
    categories:
        stockItems
            .map((item) => item.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort(),
    categoryFilter: stockCategoryFilter,
    onCategoryChanged: (value) => setState(() {
      stockCategoryFilter = value;
      stockPage = 0;
    }),
    totalValue: stockItems.fold(
      0,
      (sum, item) => sum + item.quantity * item.purchasePrice,
    ),
    lowStockCount: stockItems
        .where((item) => item.quantity <= item.minQuantity)
        .length,
  );

  Future<void> _deleteStockItem(StockItem item) async {
    if (!_canEdit('stock')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: Text('«${item.name}» и его карточка будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => stockItems.remove(item));
    await _saveCrmData();
    _audit('Удалён', 'Товар', item.name);
  }

  Future<void> _editStock(StockItem item) async {
    if (!_canEdit('stock')) return;
    final name = TextEditingController(text: item.name),
        unit = TextEditingController(text: item.unit),
        category = TextEditingController(text: item.category),
        qty = TextEditingController(text: item.quantity.toString()),
        min = TextEditingController(text: item.minQuantity.toString()),
        price = TextEditingController(text: item.purchasePrice.toString()),
        supplier = TextEditingController(text: item.supplier);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Товар'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Остаток'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: min,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Минимум'),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: unit,
                decoration: const InputDecoration(labelText: 'Единица'),
              ),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Категория'),
              ),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Закупочная цена'),
              ),
              TextField(
                controller: supplier,
                decoration: const InputDecoration(labelText: 'Поставщик'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, name.text.trim().isNotEmpty),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final parsedQty = double.tryParse(qty.text.replaceAll(',', '.'));
      final parsedMin = double.tryParse(min.text.replaceAll(',', '.'));
      final parsedPrice = double.tryParse(price.text.replaceAll(',', '.'));
      if (parsedQty == null ||
          parsedQty < 0 ||
          parsedMin == null ||
          parsedMin < 0 ||
          parsedPrice == null ||
          parsedPrice < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Количество, минимум и цена должны быть неотрицательными числами',
              ),
            ),
          );
        }
        for (final c in [name, unit, category, qty, min, price, supplier]) {
          c.dispose();
        }
        return;
      }
      item.name = name.text.trim();
      item.unit = unit.text.trim().isEmpty ? 'шт.' : unit.text.trim();
      item.category = category.text.trim().isEmpty
          ? 'Без категории'
          : category.text.trim();
      item.quantity = parsedQty;
      item.minQuantity = parsedMin;
      item.purchasePrice = parsedPrice;
      item.supplier = supplier.text.trim();
      await _saveCrmData();
      _audit('Изменён', 'Товар', item.name);
      if (mounted) setState(() {});
    }
    for (final c in [name, unit, category, qty, min, price, supplier]) {
      c.dispose();
    }
  }

  Future<void> _stockMovement(StockItem item) async {
    if (!_canEdit('stock')) return;
    final amount = TextEditingController();
    final receiptPrice = TextEditingController(
      text: item.purchasePrice.toString(),
    );
    final note = TextEditingController();
    String type = 'Приход';
    String selectedDealId = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text('Движение: ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'Приход', child: Text('Приход')),
                  DropdownMenuItem(value: 'Расход', child: Text('Расход')),
                  DropdownMenuItem(value: 'Списание', child: Text('Списание')),
                  DropdownMenuItem(
                    value: 'Инвентаризация',
                    child: Text('Инвентаризация'),
                  ),
                ],
                onChanged: (v) => setD(() {
                  type = v ?? type;
                  if (type != 'Расход') selectedDealId = '';
                }),
              ),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: type == 'Инвентаризация'
                      ? 'Фактический остаток'
                      : 'Количество',
                ),
              ),
              if (type == 'Приход')
                TextField(
                  controller: receiptPrice,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Цена закупки за единицу',
                  ),
                ),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Комментарий'),
              ),
              if (type == 'Расход' && typedDeals.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedDealId,
                  decoration: const InputDecoration(
                    labelText: 'Связать со сделкой (необязательно)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Без сделки'),
                    ),
                    ...typedDeals
                        .where((deal) => !_isDateLocked(deal.date))
                        .map(
                          (deal) => DropdownMenuItem(
                            value: deal.id,
                            child: Text(
                              '${deal.clientName} • ${deal.service.isEmpty ? 'Сделка' : deal.service}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  ],
                  onChanged: (value) =>
                      setD(() => selectedDealId = value ?? ''),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                d,
                double.tryParse(amount.text.replaceAll(',', '.')) != null,
              ),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (ok == true &&
        value != null &&
        (type == 'Инвентаризация' ? value >= 0 : value > 0)) {
      final incomingPrice = type == 'Приход'
          ? double.tryParse(receiptPrice.text.replaceAll(',', '.'))
          : null;
      if (type == 'Приход' && (incomingPrice == null || incomingPrice < 0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Укажите корректную цену закупки')),
          );
        }
        amount.dispose();
        receiptPrice.dispose();
        note.dispose();
        return;
      }
      final linkedDeal = typedDeals.cast<Deal?>().firstWhere(
        (deal) => deal?.id == selectedDealId,
        orElse: () => null,
      );
      if (type == 'Расход' &&
          linkedDeal != null &&
          _isDateLocked(linkedDeal.date)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Нельзя списать материал на сделку в закрытом периоде',
              ),
            ),
          );
        }
        amount.dispose();
        receiptPrice.dispose();
        note.dispose();
        return;
      }
      final adjustment = calculateStockAdjustment(
        type: type,
        currentQuantity: item.quantity,
        enteredQuantity: value,
      );
      if (!adjustment.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                adjustment.error == 'Недостаточно остатка'
                    ? 'Недостаточно остатка: ${item.quantity} ${item.unit}'
                    : adjustment.error ?? 'Не удалось изменить остаток',
              ),
            ),
          );
        }
        amount.dispose();
        receiptPrice.dispose();
        note.dispose();
        return;
      }
      item.quantity = adjustment.resultingQuantity;
      if (type == 'Приход' && incomingPrice != null) {
        item.purchasePrice = weightedAveragePrice(
          currentQuantity: item.quantity - value,
          currentPrice: item.purchasePrice,
          receivedQuantity: value,
          receivedPrice: incomingPrice,
        );
      }
      stockMovements.add(
        StockMovement(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          itemId: item.id,
          type: type,
          quantity: value,
          date: DateTime.now().toIso8601String(),
          note: note.text.trim(),
          unitPrice: item.purchasePrice,
          dealId: type == 'Расход' ? selectedDealId : '',
          service: type == 'Расход'
              ? typedDeals
                        .cast<Deal?>()
                        .firstWhere(
                          (deal) => deal?.id == selectedDealId,
                          orElse: () => null,
                        )
                        ?.service ??
                    ''
              : '',
        ),
      );
      _audit(type, 'Склад', '${item.name}: $value ${item.unit}');
      await _saveCrmData();
      if (mounted) setState(() {});
    }
    amount.dispose();
    receiptPrice.dispose();
    note.dispose();
  }

  Future<void> _showStockMovements(StockItem item) async {
    final movements =
        stockMovements.where((movement) => movement.itemId == item.id).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final dealNames = {for (final deal in typedDeals) deal.id: deal.clientName};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Движения: ${item.name}'),
        content: SizedBox(
          width: 560,
          height: 360,
          child: movements.isEmpty
              ? const Center(child: Text('Движений пока нет'))
              : ListView.separated(
                  itemCount: movements.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final movement = movements[index];
                    final deal = movement.dealId.isEmpty
                        ? ''
                        : ' • ${dealNames[movement.dealId] ?? movement.dealId}';
                    final cost = movement.type != 'Расход'
                        ? ''
                        : ' • ${_money(movement.costAt(movement.unitPrice > 0 ? movement.unitPrice : item.purchasePrice))}';
                    return ListTile(
                      dense: true,
                      title: Text(
                        movement.type == 'Инвентаризация'
                            ? 'Инвентаризация: факт ${movement.quantity} ${item.unit}'
                            : '${movement.type}: ${movement.quantity} ${item.unit}',
                      ),
                      subtitle: Text(
                        '${movement.date.replaceFirst('T', ' ').split('.').first}$deal${movement.service.isEmpty ? '' : ' • ${movement.service}'}$cost',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  double _num(String v) =>
      double.tryParse(v.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

  RequestCancellation _beginDealsRequest() {
    _dealsCancellation?.cancel();
    final cancellation = RequestCancellation();
    _dealsCancellation = cancellation;
    return cancellation;
  }

  RequestCancellation _beginAccountingRequest() {
    _accountingCancellation?.cancel();
    final cancellation = RequestCancellation();
    _accountingCancellation = cancellation;
    return cancellation;
  }

  void _startSheetLoad({bool clearError = false}) {
    _activeSheetLoads++;
    if (mounted) {
      setState(() {
        loading = true;
        if (clearError) sheetError = null;
      });
    }
  }

  void _finishSheetLoad() {
    _activeSheetLoads = (_activeSheetLoads - 1).clamp(0, 1 << 20);
    if (mounted) setState(() => loading = _activeSheetLoads > 0);
  }

  Future<void> _loadDeals() async {
    final requestId = ++_dealsRequestId;
    final cancellation = _beginDealsRequest();
    _startSheetLoad();
    try {
      if (currentSheetId.isEmpty && !_hasProtectedSheetAccess) {
        throw Exception('Не задан ID Google Sheets');
      }
      final rowsFromSheet = await _sheets.readSheet(
        _dataSource('deals', SheetsSchema.dealsSheet),
        cancellation: cancellation,
      );
      if (requestId != _dealsRequestId) return;
      // Рабочий лист «Август» может содержать несколько блоков с датами,
      // строками «Авто»/«ИТОГО» и параллельными финансовыми колонками. Нельзя
      // валидировать только первую строку как единую таблицу: это удаляло бы
      // все корректные сделки из legacy-листа ещё до импорта.
      final imported = importLegacyDealRows(rowsFromSheet);
      syncedDealRows = imported.rows;
      dealImportErrors = imported.errors;
      sheetsOfflineMode = false;
      await prefs.setString('cached_deals', jsonEncode(syncedDealRows));
      lastSheetsSync = DateTime.now();
      await prefs.setString(
        'sheets_last_sync',
        lastSheetsSync!.toIso8601String(),
      );
      _rebuildDealRows();
    } catch (e) {
      if (e is RequestCancelledException || requestId != _dealsRequestId) {
        return;
      }
      sheetsOfflineMode = true;
      try {
        final cached = prefs.getString('cached_deals');
        if (cached != null) {
          syncedDealRows = (jsonDecode(cached) as List)
              .whereType<List>()
              .map((r) => r.map((x) => x.toString()).toList())
              .toList();
          _rebuildDealRows();
        }
      } catch (_) {}
      sheetError = currentSheetId.isEmpty && !_hasProtectedSheetAccess
          ? 'Укажите ID или ссылку Google Sheets в настройках.'
          : syncedDealRows.isEmpty
          ? 'Не удалось загрузить сделки из Google Sheets.'
          : 'Google Sheets недоступна. Показаны последние сохранённые данные.';
    } finally {
      _finishSheetLoad();
    }
  }

  String _weekday(String d) {
    final p = d.split('.');
    if (p.length != 3) return '';
    final dt = DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}');
    if (dt == null) return '';
    return [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ][dt.weekday - 1];
  }

  bool _inPeriod(String date) => matchesDealPeriod(
    date,
    filter: periodFilter,
    now: now,
    from: customFrom,
    to: customTo,
  );

  Future<void> _selectCustomDealPeriod() async {
    final today = DateTime(now.year, now.month, now.day);
    final selectedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year + 10),
      initialDateRange: customFrom != null && customTo != null
          ? DateTimeRange(start: customFrom!, end: customTo!)
          : DateTimeRange(
              start: DateTime(today.year, today.month, 1),
              end: today,
            ),
    );
    if (selectedRange == null || !mounted) return;
    setState(() {
      periodFilter = 'Диапазон';
      customFrom = selectedRange.start;
      customTo = selectedRange.end;
      dealsPage = 0;
    });
  }

  Future<bool> _addManualDeal([Map<String, dynamic>? appointment]) async {
    if (!_canEdit('deals')) return false;
    final private =
        ((appointment?['extendedProperties'] as Map?)?['private'] as Map?) ??
        {};
    String preset(String key) => private[key]?.toString() ?? '';
    String two(int value) => value.toString().padLeft(2, '0');
    final today = DateTime.now();
    final date = TextEditingController(
      text: '${two(today.day)}.${two(today.month)}.${today.year}',
    );
    final client = TextEditingController(text: preset('name'));
    final phone = TextEditingController(text: preset('phone'));
    final car = TextEditingController(text: preset('car'));
    final service = TextEditingController(text: preset('service'));
    final serviceRows = <Map<String, TextEditingController>>[
      {
        'name': service,
        'price': TextEditingController(text: preset('cost')),
        'executor': TextEditingController(),
        'expense': TextEditingController(text: '0'),
        'workerPay': TextEditingController(),
        'businessPay': TextEditingController(),
        'dimaPay': TextEditingController(),
        'artemPay': TextEditingController(),
        'workerPct': TextEditingController(text: '0'),
        'businessPct': TextEditingController(text: '20'),
      },
    ];
    final executor = TextEditingController();
    final revenue = TextEditingController(text: preset('cost'));
    final expenses = TextEditingController(text: '0');
    final manualWorkerPay = TextEditingController();
    final manualBusiness = TextEditingController();
    final manualDima = TextEditingController();
    final manualArtem = TextEditingController();
    final source = TextEditingController(text: preset('source'));
    final note = TextEditingController(text: preset('note'));
    String status = 'Выполнен';
    final controllers = [
      date,
      client,
      phone,
      car,
      service,
      executor,
      revenue,
      expenses,
      manualWorkerPay,
      manualBusiness,
      manualDima,
      manualArtem,
      source,
      note,
    ];

    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) {
          final compact = MediaQuery.sizeOf(dialogContext).width < 600;
          final income = serviceRows.fold<double>(
            0,
            (sum, row) => sum + _num(row['price']!.text),
          );
          // Расходы теперь вводятся в каждой строке услуги и суммируются
          // автоматически для общей сделки.
          final rowExpenses = serviceRows.fold<double>(
            0,
            (sum, row) => sum + _num(row['expense']?.text ?? '0'),
          );
          expenses.text = rowExpenses.toStringAsFixed(0);
          if (income > 0) revenue.text = income.toStringAsFixed(0);
          final hasManualWorker = manualWorkerPay.text.trim().isNotEmpty;
          final hasManualBusiness = manualBusiness.text.trim().isNotEmpty;
          final hasManualDima = manualDima.text.trim().isNotEmpty;
          final hasManualArtem = manualArtem.text.trim().isNotEmpty;
          final isManual =
              hasManualWorker ||
              hasManualBusiness ||
              hasManualDima ||
              hasManualArtem;
          double totalBy(String key) => serviceRows.fold<double>(0, (sum, row) {
            final price = _num(row['price']!.text);
            final exp = _num(row['expense']!.text);
            final n = price - exp;
            final w = _num(row['workerPay']!.text);
            final b = _num(row['businessPay']!.text);
            final o = (n - w - b).clamp(0, double.infinity).toDouble();
            final d = row['dimaPay']!.text.trim().isNotEmpty
                ? _num(row['dimaPay']!.text)
                : o / 2;
            final a = row['artemPay']!.text.trim().isNotEmpty
                ? _num(row['artemPay']!.text)
                : o / 2;
            return sum +
                (key == 'worker'
                    ? w
                    : key == 'business'
                    ? b
                    : key == 'dima'
                    ? d
                    : key == 'artem'
                    ? a
                    : n);
          });
          Widget field(
            String label,
            TextEditingController controller, {
            bool number = false,
            int minLines = 1,
          }) => SizedBox(
            width: compact ? double.infinity : 270,
            child: TextField(
              controller: controller,
              minLines: minLines,
              maxLines: minLines > 1 ? 3 : 1,
              keyboardType: number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              onChanged: (_) => setDialog(() {}),
              decoration: InputDecoration(labelText: label),
            ),
          );
          return AlertDialog(
            // Keep the system dialog constraints on phones. Removing them made
            // the form's scroll area collapse on iOS.
            insetPadding: compact
                ? const EdgeInsets.all(12)
                : const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 8 : 12),
            ),
            title: const Text('Новая сделка'),
            content: SizedBox(
              width: compact ? 520 : 590,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Суммы выплат и бизнес-счёта вносятся вручную.',
                      style: TextStyle(color: _mutedTextColor),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 14,
                      runSpacing: 12,
                      children: [
                        if (appointment == null) field('Дата', date),
                        field('Клиент', client),
                        field('Телефон', phone),
                        field('Автомобиль', car),
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Работы и услуги',
                                style: TextStyle(
                                  color: _mainTextColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              ...serviceRows.map(
                                (row) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final narrow =
                                              constraints.maxWidth < 440;
                                          final picker =
                                              DropdownButtonFormField<String>(
                                                initialValue: _serviceByName(
                                                  row['name']!.text,
                                                )?.name,
                                                isExpanded: true,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Услуга *',
                                                    ),
                                                items: _activeServiceCatalog
                                                    .map(
                                                      (catalog) =>
                                                          DropdownMenuItem(
                                                            value: catalog.name,
                                                            child: Text(
                                                              catalog.name,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                    )
                                                    .toList(),
                                                onChanged: (selected) =>
                                                    setDialog(() {
                                                      final catalog =
                                                          _serviceByName(
                                                            selected ?? '',
                                                          );
                                                      row['name']!.text =
                                                          catalog?.name ?? '';
                                                    }),
                                              );
                                          final price = TextField(
                                            controller: row['price'],
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            onChanged: (_) => setDialog(() {}),
                                            decoration: const InputDecoration(
                                              labelText: 'Цена, ₽',
                                            ),
                                          );
                                          final remove = IconButton(
                                            tooltip: 'Убрать работу',
                                            onPressed: () => setDialog(() {
                                              if (serviceRows.length > 1) {
                                                serviceRows.remove(row);
                                              }
                                            }),
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                            ),
                                          );
                                          if (narrow) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                picker,
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(child: price),
                                                    remove,
                                                  ],
                                                ),
                                              ],
                                            );
                                          }
                                          return Row(
                                            children: [
                                              Expanded(child: picker),
                                              const SizedBox(width: 10),
                                              SizedBox(
                                                width: 150,
                                                child: price,
                                              ),
                                              remove,
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: field(
                                              'Работнику, ₽',
                                              row['workerPay']!,
                                              number: true,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: field(
                                              'Бизнес-счёт, ₽',
                                              row['businessPay']!,
                                              number: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: field(
                                              'Дима, ₽',
                                              row['dimaPay']!,
                                              number: true,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: field(
                                              'Артём, ₽',
                                              row['artemPay']!,
                                              number: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: field(
                                              'Исполнитель',
                                              row['executor']!,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          SizedBox(
                                            width: 150,
                                            child: TextField(
                                              controller: row['expense'],
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              onChanged: (_) =>
                                                  setDialog(() {}),
                                              decoration: const InputDecoration(
                                                labelText: 'Расход, ₽',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => setDialog(
                                  () => serviceRows.add({
                                    'name': TextEditingController(),
                                    'price': TextEditingController(),
                                    'executor': TextEditingController(),
                                    'expense': TextEditingController(text: '0'),
                                    'workerPay': TextEditingController(),
                                    'businessPay': TextEditingController(),
                                    'dimaPay': TextEditingController(),
                                    'artemPay': TextEditingController(),
                                  }),
                                ),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Добавить работу'),
                              ),
                            ],
                          ),
                        ),
                        if (appointment == null) field('Источник', source),
                        if (appointment == null) const SizedBox.shrink(),
                        if (appointment == null)
                          field('Комментарий', note, minLines: 2),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF28C28).withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 6,
                        children: [
                          Text(
                            'Итого по услугам: ${serviceRows.fold<double>(0, (s, r) => s + _num(r['price']!.text)).toStringAsFixed(0)} ₽',
                            style: TextStyle(
                              color: _mainTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Работникам по услугам: ${totalBy('worker').toStringAsFixed(0)} ₽',
                            style: TextStyle(color: _mainTextColor),
                          ),
                          Text(
                            'На бизнес-счёт по услугам: ${totalBy('business').toStringAsFixed(0)} ₽',
                            style: TextStyle(color: _mainTextColor),
                          ),
                          Text(
                            'Дима: ${totalBy('dima').toStringAsFixed(0)} ₽  •  Артём: ${totalBy('artem').toStringAsFixed(0)} ₽',
                            style: TextStyle(color: _mainTextColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              ElevatedButton.icon(
                onPressed: income <= 0
                    ? null
                    : () async {
                        if (_isDateLocked(date.text.trim())) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Нельзя добавить сделку в закрытый период',
                              ),
                            ),
                          );
                          return;
                        }
                        final total = income <= 0 ? 1 : income;
                        final invalidService = serviceRows.any(
                          (item) =>
                              _serviceByName(item['name']!.text) == null ||
                              _serviceByName(item['name']!.text)!.archived,
                        );
                        if (invalidService) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Выберите услугу из активного справочника для каждой строки',
                              ),
                            ),
                          );
                          return;
                        }
                        for (final item in serviceRows) {
                          final itemName = item['name']!.text.trim();
                          final itemIncome = _num(item['price']!.text);
                          if (itemName.isEmpty || itemIncome <= 0) continue;
                          final itemExpense = _num(item['expense']!.text);
                          final itemNet = itemIncome - itemExpense;
                          final itemWorker = _num(item['workerPay']!.text);
                          final itemBusiness = _num(item['businessPay']!.text);
                          final itemOwners =
                              (itemNet - itemWorker - itemBusiness)
                                  .clamp(0, double.infinity)
                                  .toDouble();
                          final itemDima =
                              item['dimaPay']!.text.trim().isNotEmpty
                              ? _num(item['dimaPay']!.text)
                              : (hasManualDima
                                    ? _num(manualDima.text) *
                                          (itemIncome / total)
                                    : itemOwners / 2);
                          final itemArtem =
                              item['artemPay']!.text.trim().isNotEmpty
                              ? _num(item['artemPay']!.text)
                              : (hasManualArtem
                                    ? _num(manualArtem.text) *
                                          (itemIncome / total)
                                    : itemOwners / 2);
                          final itemExecutor =
                              item['executor']!.text.trim().isEmpty
                              ? executor.text.trim()
                              : item['executor']!.text.trim();
                          final isEgor = itemExecutor.toLowerCase().contains(
                            'егор',
                          );
                          manualDealRows.add([
                            date.text.trim(),
                            car.text.trim(),
                            phone.text.trim(),
                            itemName,
                            itemExecutor,
                            formatDealNumber(itemIncome),
                            formatDealNumber(itemExpense),
                            formatDealNumber(itemNet),
                            '0',
                            formatDealNumber(itemWorker),
                            '0',
                            formatDealNumber(itemBusiness),
                            formatDealNumber(itemOwners),
                            formatDealNumber(itemDima),
                            formatDealNumber(itemArtem),
                            formatDealNumber(isEgor ? itemWorker : 0),
                            status,
                            client.text.trim(),
                            source.text.trim(),
                            note.text.trim(),
                            isManual ? 'Да' : 'Нет',
                            'deal-${DateTime.now().microsecondsSinceEpoch}',
                          ]);
                        }
                        setState(_rebuildDealRows);
                        await _saveManualDeals();
                        _audit(
                          'Создана',
                          'Сделка',
                          '${client.text.trim()}: ${serviceRows.length} усл.',
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      },
                icon: const Icon(Icons.add),
                label: const Text('Добавить сделку'),
              ),
            ],
          );
        },
      ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    return added == true;
  }

  Widget _deals() {
    final headers = dealRows.isNotEmpty ? dealRows.first : <String>[];
    final groups = <String, List<List<String>>>{};
    for (final row in dealRows.skip(1)) {
      if (!_inPeriod(row.isNotEmpty ? row[0] : '')) continue;
      if (dealStatusFilter != null &&
          (row.length <= 16 || row[16] != dealStatusFilter)) {
        continue;
      }
      if (row.any((x) => x.isNotEmpty)) {
        final key = row.isNotEmpty && row[0].isNotEmpty ? row[0] : 'Без даты';
        groups.putIfAbsent(key, () => <List<String>>[]).add(row);
      }
    }
    final sortedEntries = groups.entries.toList()
      ..sort((a, b) {
        DateTime parse(String value) {
          final p = value.split('.');
          return p.length == 3
              ? (DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}') ?? DateTime(2100))
              : DateTime(2100);
        }

        final cmp = parse(a.key).compareTo(parse(b.key));
        return dealsOldestFirst ? cmp : -cmp;
      });
    if (dealsKanban) return _dealsKanban();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сделки',
          style: TextStyle(
            color: _mainTextColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (sheetsOfflineMode) OfflineStatusBanner(lastSynced: lastSheetsSync),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: periodFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Период',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Август',
                              child: Text('Август'),
                            ),
                            DropdownMenuItem(
                              value: 'Неделя',
                              child: Text('Неделя'),
                            ),
                            DropdownMenuItem(
                              value: 'Месяц',
                              child: Text('Месяц'),
                            ),
                            DropdownMenuItem(
                              value: 'Диапазон',
                              child: Text('Диапазон'),
                            ),
                            DropdownMenuItem(
                              value: 'Все',
                              child: Text('Все данные'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == 'Диапазон') {
                              _selectCustomDealPeriod();
                            } else if (value != null) {
                              setState(() {
                                periodFilter = value;
                                dealsPage = 0;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: dealStatusFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Статус',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Все статусы'),
                            ),
                            ...clientStatuses.map(
                              (status) => DropdownMenuItem<String?>(
                                value: status,
                                child: Text(status),
                              ),
                            ),
                          ],
                          onChanged: (value) => setState(() {
                            dealStatusFilter = value;
                            dealsPage = 0;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _canEdit('deals') ? _addManualDeal : null,
                          icon: const Icon(Icons.add),
                          label: const Text('Новая сделка'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF28C28),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Синхронизировать сделки',
                        onPressed: loading ? null : _loadDeals,
                        icon: const Icon(Icons.sync),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Дополнительные действия',
                        icon: const Icon(Icons.more_horiz),
                        onSelected: (action) async {
                          switch (action) {
                            case 'sort':
                              setState(
                                () => dealsOldestFirst = !dealsOldestFirst,
                              );
                              break;
                            case 'restore':
                              final count =
                                  await _restoreManualDealsFromExport();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    count == 0
                                        ? 'Резервный CSV с локальными сделками не найден'
                                        : 'Восстановлено локальных сделок: $count',
                                  ),
                                ),
                              );
                              break;
                            case 'csv':
                              await _exportDealsCsv();
                              break;
                            case 'xlsx':
                              await _exportDealsXlsx();
                              break;
                            case 'columns':
                              await _chooseColumns();
                              break;
                            case 'widths':
                              await _columnWidths();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'sort',
                            child: ListTile(
                              leading: Icon(
                                dealsOldestFirst
                                    ? Icons.south_outlined
                                    : Icons.north_outlined,
                              ),
                              title: Text(
                                dealsOldestFirst
                                    ? 'Сначала новые'
                                    : 'Сначала старые',
                              ),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'restore',
                            child: ListTile(
                              leading: Icon(Icons.restore),
                              title: Text('Восстановить локальные'),
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'csv',
                            child: ListTile(
                              leading: Icon(Icons.download_outlined),
                              title: Text('Экспорт CSV'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'xlsx',
                            child: ListTile(
                              leading: Icon(Icons.table_view_outlined),
                              title: Text('Экспорт Excel'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'columns',
                            child: ListTile(
                              leading: Icon(Icons.view_column_outlined),
                              title: Text('Поля таблицы'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'widths',
                            child: ListTile(
                              leading: Icon(Icons.tune),
                              title: Text('Ширина столбцов'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('Воронка сделок'),
                      selected: dealsKanban,
                      onSelected: (value) =>
                          setState(() => dealsKanban = value),
                    ),
                  ),
                ],
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<String>(
                  value: periodFilter,
                  items: const [
                    DropdownMenuItem(value: "Август", child: Text("Август")),
                    DropdownMenuItem(
                      value: "Неделя",
                      child: Text("Последняя неделя"),
                    ),
                    DropdownMenuItem(
                      value: "Месяц",
                      child: Text("Последний месяц"),
                    ),
                    DropdownMenuItem(
                      value: "Диапазон",
                      child: Text("Произвольный период"),
                    ),
                    DropdownMenuItem(value: "Все", child: Text("Все данные")),
                  ],
                  onChanged: (v) {
                    if (v == 'Диапазон') {
                      _selectCustomDealPeriod();
                    } else if (v != null) {
                      setState(() {
                        periodFilter = v;
                        dealsPage = 0;
                      });
                    }
                  },
                ),
                const SizedBox(width: 16),
                DropdownButton<bool>(
                  value: dealsOldestFirst,
                  items: const [
                    DropdownMenuItem(
                      value: false,
                      child: Text('Сначала новые'),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text('Сначала старые'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => dealsOldestFirst = v);
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: loading ? null : _loadDeals,
                  icon: const Icon(Icons.sync),
                  label: const Text('Синхронизировать'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : () async {
                          final count = await _restoreManualDealsFromExport();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                count == 0
                                    ? 'Резервный CSV с локальными сделками не найден'
                                    : 'Восстановлено локальных сделок: $count',
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.restore),
                  label: const Text('Восстановить локальные'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: !_canEdit('deals') ? null : _addManualDeal,
                  icon: const Icon(Icons.add),
                  label: const Text('Новая сделка'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF28C28),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportDealsCsv,
                  icon: const Icon(Icons.download),
                  label: const Text('Экспорт CSV'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportDealsXlsx,
                  icon: const Icon(Icons.table_view),
                  label: const Text('Экспорт Excel'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: dealRows.isEmpty ? null : _chooseColumns,
                  icon: const Icon(Icons.view_column),
                  label: const Text('Поля'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: dealRows.isEmpty ? null : _columnWidths,
                  icon: const Icon(Icons.tune),
                  label: const Text('Ширина'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Перенос текста'),
                  selected: wrapDealText,
                  onSelected: (v) {
                    setState(() => wrapDealText = v);
                    unawaited(_savePrefs());
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Kanban'),
                  selected: dealsKanban,
                  onSelected: (v) => setState(() => dealsKanban = v),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: dealStatusFilter,
                  hint: const Text('Все статусы'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Все статусы'),
                    ),
                    ...clientStatuses.map(
                      (s) =>
                          DropdownMenuItem<String?>(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    dealStatusFilter = v;
                    dealsPage = 0;
                  }),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (dealImportErrors.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Ошибки импорта (${dealImportErrors.length}): ${dealImportErrors.take(3).join('; ')}${dealImportErrors.length > 3 ? '…' : ''}',
              style: TextStyle(color: _mainTextColor),
            ),
          ),
        DealsGroupedTable(
          headers: headers,
          entries: sortedEntries,
          page: dealsPage,
          pageSize: dealGroupsPageSize,
          visibleColumns: visibleDealCols,
          columnWidths: dealColWidths,
          defaultColumnWidth: dealColWidth,
          wrapText: wrapDealText,
          canEdit: _canEdit('deals'),
          weekdayForDate: _weekday,
          onPageChanged: (page) => setState(() => dealsPage = page),
          onOpenDeal: _editDealRow,
        ),
      ],
    );
  }

  Widget _dealsKanban() => DealsKanbanBoard(
    rows: dealRows
        .skip(1)
        .where(
          (row) =>
              _inPeriod(row.isNotEmpty ? row[0] : '') &&
              (dealStatusFilter == null ||
                  (row.length > 16 && row[16] == dealStatusFilter)),
        ),
    canEdit: _canEdit('deals'),
    onShowTable: () => setState(() => dealsKanban = false),
    onAddDeal: () => unawaited(_addManualDeal()),
    onOpenDeal: _editDealRow,
  );

  Future<void> _editDealRow(List<String> row) async {
    if (row.isNotEmpty && _isDateLocked(row.first)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сделка относится к закрытому периоду и недоступна для изменения',
            ),
          ),
        );
      }
      return;
    }
    if (row.length < dealHeaders.length) {
      row.addAll(List.filled(dealHeaders.length - row.length, ''));
    }
    String displayValue(int index) {
      final value = row[index].trim();
      if (value.isEmpty || index < 5 || index > 15) return value;
      return formatDealNumber(_num(value));
    }

    final fields = List.generate(
      dealHeaders.length,
      (i) => TextEditingController(text: displayValue(i)),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать сделку'),
        content: SizedBox(
          width: 620,
          height: 520,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (var i = 0; i < dealHeaders.length; i++)
                  if (!_hiddenDealColumns.contains(i))
                    SizedBox(
                      width: 285,
                      child: i == 21
                          ? TextField(
                              controller: fields[i],
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: dealHeaders[i],
                              ),
                            )
                          : i == 16
                          ? DropdownButtonFormField<String>(
                              initialValue:
                                  clientStatuses.contains(fields[i].text)
                                  ? fields[i].text
                                  : clientStatuses.first,
                              decoration: InputDecoration(
                                labelText: dealHeaders[i],
                              ),
                              items: clientStatuses
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) fields[i].text = v;
                              },
                            )
                          : i == 3
                          ? DropdownButtonFormField<String>(
                              initialValue: _serviceByName(
                                fields[i].text,
                              )?.name,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: '${dealHeaders[i]} *',
                                helperText:
                                    fields[i].text.isNotEmpty &&
                                        _serviceByName(fields[i].text) == null
                                    ? 'Историческая услуга отсутствует в справочнике: выберите актуальную'
                                    : null,
                              ),
                              hint: const Text('Выберите услугу'),
                              items: _activeServiceCatalog
                                  .map(
                                    (service) => DropdownMenuItem(
                                      value: service.name,
                                      child: Text(service.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  fields[i].text = value ?? '',
                            )
                          : TextField(
                              controller: fields[i],
                              decoration: InputDecoration(
                                labelText: dealHeaders[i],
                              ),
                            ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final entered = fields.map((f) => f.text.trim()).toList();
      final updated = recalculateDealRow(entered);
      if (updated.length < dealHeaders.length) {
        updated.addAll(List.filled(dealHeaders.length - updated.length, ''));
      }
      if (updated[21].isEmpty) {
        updated[21] = 'deal-${DateTime.now().microsecondsSinceEpoch}';
      }
      final index = manualDealRows.indexOf(row);
      final calculationChanged = dealCalculationChanged(row, updated);
      final oldStatus = row.length > 16 ? row[16] : '';
      if (index >= 0) {
        manualDealRows[index] = updated;
      } else {
        manualDealRows.add(updated);
      }
      _rebuildDealRows();
      await _saveManualDeals();
      if (oldStatus != updated[16]) {
        _audit(
          'Статус изменён',
          'Сделка',
          '${updated[17]}: $oldStatus → ${updated[16]}',
        );
      } else if (calculationChanged) {
        _audit(
          'Перерасчёт',
          'Сделка',
          '${updated[17]}: выручка ${_money(_num(updated[5]))}, прибыль владельцев ${_money(_num(updated[12]))}',
        );
      } else {
        _audit('Изменена', 'Сделка', updated[17]);
      }
      if (mounted) setState(() {});
    }
    for (final f in fields) {
      f.dispose();
    }
  }

  Future<void> _exportDealsCsv() async {
    final visible = filterDeals(
      dealRows.skip(1),
      matchesPeriod: _inPeriod,
      status: dealStatusFilter,
    );
    final csv = dealsToCsv(dealHeaders, visible);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/crm-deals-${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv, flush: true);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Экспортировано: ${file.path}')));
    }
  }

  Future<void> _exportDealsXlsx() async {
    final visible = filterDeals(
      dealRows.skip(1),
      matchesPeriod: _inPeriod,
      status: dealStatusFilter,
    );
    final bytes = buildXlsx(
      sheetName: 'Сделки',
      rows: [
        dealHeaders,
        ...visible.map(
          (r) => List.generate(
            dealHeaders.length,
            (i) => i < r.length ? r[i] : '',
          ),
        ),
      ],
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/crm-deals-${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await file.writeAsBytes(bytes, flush: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Файл Excel сохранён: ${file.path}')),
      );
    }
  }

  Future<void> _columnWidths() async {
    final vals = Map<int, double>.from(dealColWidths);
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ширина столбцов'),
        content: SizedBox(
          width: 460,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 0; i < dealRows.first.length; i++)
                if (visibleDealCols.contains(i))
                  Row(
                    children: [
                      SizedBox(width: 150, child: Text(dealRows.first[i])),
                      Expanded(
                        child: Slider(
                          value: vals[i] ?? dealColWidth,
                          min: 80,
                          max: 280,
                          divisions: 20,
                          onChanged: (v) {
                            vals[i] = v;
                            (c as Element).markNeedsBuild();
                          },
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => dealColWidths = vals);
              await prefs.setString(
                "widths",
                jsonEncode(vals.map((k, v) => MapEntry(k.toString(), v))),
              );
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseColumns() async {
    final chosen = Set<int>.from(visibleDealCols);
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Поля сделок'),
        content: SizedBox(
          width: 420,
          child: StatefulBuilder(
            builder: (c, setD) => ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < dealRows.first.length; i++)
                  if (!_hiddenDealColumns.contains(i))
                    CheckboxListTile(
                      value: chosen.contains(i),
                      title: Text(dealRows.first[i]),
                      onChanged: (v) => setD(
                        () => v == true ? chosen.add(i) : chosen.remove(i),
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => visibleDealCols = chosen);
              unawaited(_savePrefs());
              Navigator.pop(c);
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAccounting() async {
    final requestId = ++_accountingRequestId;
    final cancellation = _beginAccountingRequest();
    _startSheetLoad(clearError: true);
    try {
      if (currentSheetId.isEmpty && !_hasProtectedSheetAccess) {
        throw Exception('Не задан ID Google Sheets');
      }
      accountingRows = await _sheets.readSheet(
        _dataSource('accounting', SheetsSchema.accountingSheet),
        cancellation: cancellation,
      );
      if (requestId != _accountingRequestId) return;
      if (accountingRows.isNotEmpty && accountingRows.first.isEmpty) {
        throw Exception('Пустая строка заголовков');
      }
      sheetsOfflineMode = false;
      accountingPage = 0;
      await prefs.setString('cached_accounting', jsonEncode(accountingRows));
      lastSheetsSync = DateTime.now();
      await prefs.setString(
        'sheets_last_sync',
        lastSheetsSync!.toIso8601String(),
      );
      // Лист «Расходы» содержит отдельные движения счёта: дата (5-я колонка),
      // описание (7-я) и сумма (8-я). Подтягиваем их в историю бизнес-счёта.
      try {
        final expRows = await _sheets.readSheet(
          _dataSource('expenses', SheetsSchema.expensesSheet),
          cancellation: cancellation,
        );
        businessTransactions.addAll(
          importSheetExpenses(expRows, existing: businessTransactions),
        );
        await prefs.setString(
          'business_transactions',
          jsonEncode(businessTransactions),
        );
      } catch (_) {}
    } catch (e) {
      if (e is RequestCancelledException || requestId != _accountingRequestId) {
        return;
      }
      sheetsOfflineMode = true;
      try {
        final cached = prefs.getString('cached_accounting');
        if (cached != null) {
          accountingRows = (jsonDecode(cached) as List)
              .whereType<List>()
              .map((r) => r.map((x) => x.toString()).toList())
              .toList();
          accountingPage = 0;
        }
      } catch (_) {}
      sheetError = currentSheetId.isEmpty && !_hasProtectedSheetAccess
          ? 'Укажите ID или ссылку Google Sheets в настройках.'
          : accountingRows.isEmpty
          ? 'Не удалось загрузить таблицу. Проверьте доступ по ссылке.'
          : 'Google Sheets недоступна. Показаны последние сохранённые данные.';
    } finally {
      _finishSheetLoad();
    }
  }

  Future<void> _closeAccountingPeriod() async {
    if (!_canEdit('finance')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Закрыть период?'),
        content: const Text(
          'Итоги будут сохранены как контрольный снимок. Новые операции не изменят этот снимок.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final today = DateTime.now();
    final from = accountingFrom ?? DateTime(today.year, today.month, 1);
    final to = accountingTo ?? DateTime(today.year, today.month + 1, 0);
    final summary = summarizeDeals(
      typedDeals.where(
        (deal) => isDateWithinPeriod(deal.date, from: from, to: to),
      ),
    );
    final revenue = summary.revenue;
    final expenses = summary.expenses;
    final period = <String, dynamic>{
      'closedAt': DateTime.now().toIso8601String(),
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
      'revenue': revenue,
      'expenses': expenses,
      'profit': revenue - expenses,
      'workerPayout': summary.workerPayout,
      'businessReserve': summary.businessReserve,
      'ownerProfit': summary.effectiveOwnerProfit,
      'dealCount': summary.dealCount,
    };
    closedAccountingPeriods.add(period);
    closedAccountingPeriod = period;
    await prefs.setString(
      'closed_accounting_periods',
      jsonEncode(closedAccountingPeriods),
    );
    await prefs.setString(
      'closed_accounting_period',
      jsonEncode(closedAccountingPeriod),
    );
    if (!mounted) return;
    _audit(
      'Закрытие периода',
      'Бухгалтерия',
      'Владельцам: ${_money(summary.effectiveOwnerProfit)}',
    );
    setState(() {});
  }

  Widget _accounting() => AccountingPage(
    lastSheetsSync: lastSheetsSync,
    sheetsOfflineMode: sheetsOfflineMode,
    loading: loading,
    canEditFinance: _canEdit('finance'),
    onSync: _loadAccounting,
    onClosePeriod: _closeAccountingPeriod,
    from: accountingFrom,
    to: accountingTo,
    onPeriodChanged: (range) => setState(() {
      accountingFrom = range?.start;
      accountingTo = range?.end;
    }),
    categoryFilter: accountingCategoryFilter,
    categories: accountingCategories,
    onCategoryChanged: (category) =>
        setState(() => accountingCategoryFilter = category),
    onManageCategories: _manageAccountingCategories,
    sheetError: sheetError,
    hasRows: accountingRows.isNotEmpty,
    table: accountingRows.isEmpty
        ? null
        : AccountingTable(
            rows: accountingRows,
            page: accountingPage,
            pageSize: accountingPageSize,
            onPageChanged: (page) => setState(() => accountingPage = page),
          ),
    localOperations: _localOperations(),
    reconciliationReport: _reconciliationReport(),
    closedPeriodSummary: closedAccountingPeriod == null
        ? null
        : 'Последнее закрытие: ${(closedAccountingPeriod!['closedAt'] ?? '').toString().replaceFirst('T', ' ').split('.').first} • '
              'прибыль ${_money((closedAccountingPeriod!['profit'] as num?)?.toDouble() ?? 0)}',
  );

  Future<void> _manageAccountingCategories() async {
    if (!_canEdit('finance')) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AccountingCategoriesDialog(
        categories: accountingCategories,
        onSave: (categories) async {
          accountingCategories
            ..clear()
            ..addAll(categories);
          await _saveAccountingCategories();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _overview() => OverviewDashboard(
    metrics: [
      OverviewMetric(
        title: 'Выручка',
        value: _money(_dashboardSum((deal) => deal.revenue)),
        icon: Icons.payments_outlined,
        accentColor: const Color(0xFF1FA971),
      ),
      OverviewMetric(
        title: 'Расходы',
        value: _money(_dashboardSum((deal) => deal.expenses)),
        icon: Icons.receipt_long_outlined,
        accentColor: const Color(0xFFE06C75),
      ),
      OverviewMetric(
        title: 'Чистая прибыль',
        value: _money(_dashboardSum((deal) => deal.ownerProfit)),
        icon: Icons.trending_up,
        accentColor: const Color(0xFF4A90E2),
      ),
      OverviewMetric(
        title: 'Бизнес-счёт',
        value: _money(_businessBalance()),
        icon: Icons.account_balance_outlined,
        accentColor: const Color(0xFFF28C28),
        onTap: _openBusinessAccount,
      ),
      OverviewMetric(
        title: 'Работникам',
        value: _money(_dashboardSum((deal) => deal.workerPayout)),
        icon: Icons.groups_outlined,
        accentColor: const Color(0xFF8B6FE8),
      ),
      OverviewMetric(
        title: 'Артём',
        value: _money(_dashboardSum((deal) => deal.ownerProfit / 2)),
        icon: Icons.person_outline,
        accentColor: const Color(0xFF4A90E2),
      ),
      OverviewMetric(
        title: 'Дмитрий',
        value: _money(_dashboardSum((deal) => deal.ownerProfit / 2)),
        icon: Icons.person_outline,
        accentColor: const Color(0xFF4A90E2),
      ),
      OverviewMetric(
        title: 'Егор',
        value: _money(
          _dashboardSum(
            (deal) => deal.performers.toLowerCase().contains('егор')
                ? deal.workerPayout
                : 0,
          ),
        ),
        icon: Icons.engineering_outlined,
        accentColor: const Color(0xFF1FA971),
      ),
      OverviewMetric(
        title: 'Средний чек',
        value: _money(_dashboardAverageCheck()),
        icon: Icons.calculate_outlined,
        accentColor: const Color(0xFFF28C28),
      ),
      OverviewMetric(
        title: 'Средняя выручка в день',
        value: _money(_dashboardAverageDaily()),
        icon: Icons.date_range_outlined,
        accentColor: const Color(0xFF8B6FE8),
      ),
    ],
    loadedDeals: typedDeals.where(_dashboardDealMatches).length,
    loading: loading,
    surfaceColor: _surfaceColor,
    borderColor: _cardBorderColor,
    mainTextColor: _mainTextColor,
    mutedTextColor: _mutedTextColor,
    workspace: DashboardWorkspace(
      periodLabel: dashboardPeriod,
      periodOptions: _dashboardPeriods,
      onPeriodChanged: (value) async {
        if (value == 'Диапазон') {
          await _selectDashboardRange();
          return;
        }
        dashboardPeriod = value;
        await _saveWorkspaceData();
        if (mounted) setState(() {});
      },
      notes: dashboardNotes,
      canEditNotes: _canEdit('dashboard'),
      onEditNote: (note) => unawaited(_editDashboardNote(note)),
      onDeleteNote: (note) => unawaited(_deleteDashboardNote(note)),
      onAddNote: () => unawaited(_editDashboardNote()),
      plan: _activeDashboardPlan,
      actualRevenue: _activeDashboardPlan == null
          ? _dashboardRevenue
          : _revenueForRange(
              _activeDashboardPlan!.from,
              _activeDashboardPlan!.to,
            ),
      onEditPlan: () => unawaited(_editRevenuePlan()),
      surfaceColor: _surfaceColor,
      borderColor: _cardBorderColor,
      mainTextColor: _mainTextColor,
      mutedTextColor: _mutedTextColor,
    ),
  );

  double _dashboardSum(double Function(Deal deal) selector) => typedDeals
      .where(_dashboardDealMatches)
      .fold(0, (sum, deal) => sum + selector(deal));

  double _dashboardAverageCheck() {
    final selectedDeals = typedDeals.where(_dashboardDealMatches).toList();
    return selectedDeals.isEmpty
        ? 0
        : selectedDeals.fold(0.0, (sum, deal) => sum + deal.revenue) /
              selectedDeals.length;
  }

  double _dashboardAverageDaily() {
    final from = _dashboardAverageFrom;
    final to = _dashboardAverageTo;
    if (from == null || to == null) return 0;
    final days = elapsedCalendarDaysInPeriod(
      from: from,
      to: to,
      now: DateTime.now(),
    );
    return days == 0 ? 0 : _dashboardRevenue / days;
  }

  DateTime? get _dashboardAverageFrom {
    final selectedFrom = _dashboardFrom;
    if (selectedFrom != null) return selectedFrom;
    // «Все время»: считаем дни с первой корректно датированной сделки,
    // включая дни без выручки.
    final dates =
        typedDeals
            .map(
              (deal) => DateTime.tryParse(deal.date) ?? _parseRuDate(deal.date),
            )
            .whereType<DateTime>()
            .toList()
          ..sort();
    return dates.isEmpty ? null : dates.first;
  }

  DateTime? get _dashboardAverageTo => _dashboardTo ?? DateTime.now();

  DateTime? get _dashboardFrom {
    if (dashboardPeriod == 'Текущий месяц') {
      final now = DateTime.now();
      return DateTime(now.year, now.month, 1);
    }
    if (dashboardPeriod == 'Диапазон') return dashboardCustomFrom;
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(dashboardPeriod);
    return match == null
        ? null
        : DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), 1);
  }

  DateTime? get _dashboardTo {
    if (dashboardPeriod == 'Текущий месяц') {
      final now = DateTime.now();
      return DateTime(now.year, now.month + 1, 0);
    }
    if (dashboardPeriod == 'Диапазон') return dashboardCustomTo;
    final from = _dashboardFrom;
    return from == null ? null : DateTime(from.year, from.month + 1, 0);
  }

  Widget _botTest() => BotTestWorkspace(
    conversations: botConversations,
    selectedConversationId: selectedBotConversationId,
    knowledgeBase: knowledgeBase,
    aiConfigured: aiSettings.enabled && aiApiKey.isNotEmpty,
    busy: botRequestInProgress,
    onCreateConversation: _createBotConversation,
    onSelectConversation: (id) async {
      selectedBotConversationId = id;
      await _saveBotConversations();
      if (mounted) setState(() {});
    },
    onRenameConversation: (conversation) =>
        unawaited(_renameBotConversation(conversation)),
    onDeleteConversation: (conversation) =>
        unawaited(_deleteBotConversation(conversation)),
    onClearConversation: (conversation) =>
        unawaited(_clearBotConversation(conversation)),
    onSend: _sendBotTestMessage,
    onMarkGood: _markBotReplyGood,
    onMarkBad: _markBotReplyBad,
    onRetryReply: _retryBotReply,
    onEditKnowledgeBase: () => unawaited(_editKnowledgeBase()),
    onAnalyzeAvito: () => unawaited(_analyzeAvitoForKnowledge()),
  );

  String _money(num value) => '${value.toStringAsFixed(0)} ₽';

  Widget _reconciliationReport() {
    final report = reconcileFinanceSources(
      deals: typedDeals.where(_dashboardDealMatches),
      accountingRows: accountingRows,
      transactions: businessTransactions,
      from: _dashboardFrom,
      to: _dashboardTo,
    );
    return FinanceReconciliationCard(
      report: report,
      surfaceColor: _surfaceColor,
      borderColor: _cardBorderColor,
      mainTextColor: _mainTextColor,
      mutedTextColor: _mutedTextColor,
    );
  }

  double _businessBalance() =>
      businessAccountBalance(typedDeals, businessTransactions);

  bool _transactionMatches(Map<String, dynamic> item) {
    if (accountingCategoryFilter != 'Все категории' &&
        item['category']?.toString() != accountingCategoryFilter) {
      return false;
    }
    if (accountingFrom == null || accountingTo == null) return true;
    final rawDate = item['date']?.toString() ?? '';
    final date = DateTime.tryParse(rawDate) ?? _parseRuDate(rawDate);
    if (date == null) return true;
    return !date.isBefore(accountingFrom!) &&
        !date.isAfter(accountingTo!.add(const Duration(days: 1)));
  }

  DateTime? _parseRuDate(String value) {
    final match = RegExp(
      r'^(\d{1,2})[.]([0-9]{1,2})[.]([0-9]{4})',
    ).firstMatch(value.trim());
    if (match == null) return null;
    return DateTime.tryParse(
      '${match.group(3)}-${match.group(2)!.padLeft(2, '0')}-${match.group(1)!.padLeft(2, '0')}',
    );
  }

  bool _isDateLocked(String date) => closedAccountingPeriods.any(
    (period) => isDateWithinClosedPeriod(date, period),
  );

  bool _isFinancialOperationEditable(String date) =>
      isFinancialOperationEditable(date, closedAccountingPeriods);

  String _formatCrmDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  void _showClosedOperationWarning(String date) {
    const message = 'Нельзя менять операцию в закрытом периоде';
    _pushNotification(CrmNotificationLevel.warning, 'Период закрыт', message);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$message: $date')));
    }
  }

  Widget _localOperations() => LocalOperationsList(
    operations: businessTransactions
        .where(_transactionMatches)
        .toList()
        .reversed
        .toList(),
  );

  Future<void> _openBusinessAccount() async {
    // Перед открытием окна всегда обновляем данные из листа «Расходы».
    await _loadAccounting();
    if (!mounted) return;
    final amount = TextEditingController();
    final note = TextEditingController();
    final operationDate = TextEditingController(
      text: _formatCrmDate(DateTime.now()),
    );
    var category = accountingCategories.first;
    Widget dateField(BuildContext dialogContext) => TextField(
      controller: operationDate,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: 'Дата операции',
        hintText: 'ДД.ММ.ГГГГ',
        suffixIcon: IconButton(
          tooltip: 'Выбрать дату',
          icon: const Icon(Icons.calendar_today_outlined),
          onPressed: () async {
            final initial = parseCrmDate(operationDate.text) ?? DateTime.now();
            final selected = await showDatePicker(
              context: dialogContext,
              initialDate: initial,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (selected != null) operationDate.text = _formatCrmDate(selected);
          },
        ),
      ),
    );
    List<Map<String, dynamic>> sheetTransactions() => dealRows
        .skip(1)
        .where((r) => r.length > 11 && _num(r[11]) != 0)
        .map(
          (r) => <String, dynamic>{
            'amount': _num(r[11]),
            'comment': 'Отложено с сделки: ${dealReserveLabel(r)}',
            'date': r.isNotEmpty ? r[0] : '',
            'source': 'deal',
          },
        )
        .toList();
    final allBusinessTransactions = sortBusinessTransactionsByDate([
      ...businessTransactions,
      ...sheetTransactions(),
    ]);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Движения по бизнес-счёту'),
        content: SizedBox(
          width: 650,
          height: 500,
          child: Column(
            children: [
              Text(
                'Баланс за всё время: ${_businessBalance().toStringAsFixed(0)} ₽',
                style: TextStyle(
                  fontSize: 18,
                  color: _mainTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Divider(),
              Expanded(
                child: allBusinessTransactions.isEmpty
                    ? Center(
                        child: Text(
                          'Операций пока нет',
                          style: TextStyle(color: _mutedTextColor),
                        ),
                      )
                    : ListView.builder(
                        itemCount: allBusinessTransactions.length,
                        itemBuilder: (_, i) {
                          final x = allBusinessTransactions[i];
                          final v = (x['amount'] as num).toDouble();
                          return ListTile(
                            leading: Icon(
                              v >= 0
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: v >= 0 ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              x['comment'].toString(),
                              style: TextStyle(color: _mainTextColor),
                            ),
                            subtitle: Text(
                              '${x['date']} • ${x['source'] == 'google_sheets'
                                  ? 'Google Sheets'
                                  : x['source'] == 'deal'
                                  ? 'Сделка'
                                  : 'Локально'}',
                              style: TextStyle(color: _mutedTextColor),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)} ₽',
                                ),
                                if (_canEdit('finance') &&
                                    x['source'] == 'local' &&
                                    _isFinancialOperationEditable(
                                      x['date']?.toString() ?? '',
                                    ))
                                  IconButton(
                                    tooltip: 'Удалить операцию',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (d) => AlertDialog(
                                          title: const Text(
                                            'Удалить операцию?',
                                          ),
                                          content: Text(
                                            x['comment']?.toString() ??
                                                'Операция',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(d, false),
                                              child: const Text('Отмена'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(d, true),
                                              child: const Text('Удалить'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true && mounted) {
                                        businessTransactions.remove(x);
                                        await prefs.setString(
                                          'business_transactions',
                                          jsonEncode(businessTransactions),
                                        );
                                        if (mounted) setState(() {});
                                        _audit(
                                          'Удалён',
                                          'Финансовая операция',
                                          x['comment']?.toString() ?? '',
                                        );
                                      }
                                    },
                                  ),
                                if (_canEdit('finance') &&
                                    x['source'] == 'local' &&
                                    !_isFinancialOperationEditable(
                                      x['date']?.toString() ?? '',
                                    ))
                                  const Tooltip(
                                    message:
                                        'Операция находится в закрытом периоде',
                                    child: Icon(Icons.lock_outline, size: 18),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
          ElevatedButton.icon(
            onPressed: !_canEdit('finance')
                ? null
                : () async {
                    final v = await showDialog<double>(
                      context: ctx,
                      builder: (d) => AlertDialog(
                        title: const Text('Новый расход'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: note,
                              decoration: const InputDecoration(
                                labelText: 'Название расхода',
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: category,
                              items: accountingCategories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => category = v ?? category,
                              decoration: const InputDecoration(
                                labelText: 'Категория',
                              ),
                            ),
                            TextField(
                              controller: amount,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Сумма, ₽',
                              ),
                            ),
                            const SizedBox(height: 10),
                            dateField(d),
                          ],
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(
                              d,
                              double.tryParse(amount.text.replaceAll(',', '.')),
                            ),
                            child: const Text('Сохранить'),
                          ),
                        ],
                      ),
                    );
                    if (!mounted) return;
                    final date = operationDate.text.trim();
                    if (v != null && v > 0 && parseCrmDate(date) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Укажите дату в формате ДД.ММ.ГГГГ'),
                        ),
                      );
                      return;
                    }
                    if (v != null &&
                        v > 0 &&
                        !_isFinancialOperationEditable(date)) {
                      _showClosedOperationWarning(date);
                      return;
                    }
                    if (v != null && v > 0) {
                      businessTransactions.add({
                        'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
                        'amount': -v,
                        'comment': note.text.trim().isEmpty
                            ? 'Расход'
                            : note.text.trim(),
                        'category': category,
                        'date': date,
                        'source': 'local',
                      });
                      await prefs.setString(
                        'business_transactions',
                        jsonEncode(businessTransactions),
                      );
                      if (mounted) setState(() {});
                      _audit('Добавлен', 'Расход', note.text.trim());
                      amount.clear();
                      note.clear();
                    }
                  },
            icon: const Icon(Icons.add),
            label: const Text('Добавить расход'),
          ),
          ElevatedButton.icon(
            onPressed: !_canEdit('finance')
                ? null
                : () async {
                    final v = await showDialog<double>(
                      context: ctx,
                      builder: (d) => AlertDialog(
                        title: const Text('Новое пополнение'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: note,
                              decoration: const InputDecoration(
                                labelText: 'Название дохода',
                              ),
                            ),
                            TextField(
                              controller: amount,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Сумма, ₽',
                              ),
                            ),
                            const SizedBox(height: 10),
                            dateField(d),
                            DropdownButtonFormField<String>(
                              initialValue: category,
                              items: accountingCategories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => category = v ?? category,
                              decoration: const InputDecoration(
                                labelText: 'Категория',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(
                              d,
                              double.tryParse(amount.text.replaceAll(',', '.')),
                            ),
                            child: const Text('Сохранить'),
                          ),
                        ],
                      ),
                    );
                    if (!mounted) return;
                    final date = operationDate.text.trim();
                    if (v != null && v > 0 && parseCrmDate(date) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Укажите дату в формате ДД.ММ.ГГГГ'),
                        ),
                      );
                      return;
                    }
                    if (v != null &&
                        v > 0 &&
                        !_isFinancialOperationEditable(date)) {
                      _showClosedOperationWarning(date);
                      return;
                    }
                    if (v != null && v > 0) {
                      businessTransactions.add({
                        'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
                        'amount': v,
                        'comment': note.text.trim().isEmpty
                            ? 'Пополнение'
                            : note.text.trim(),
                        'category': category,
                        'date': date,
                        'source': 'local',
                      });
                      await prefs.setString(
                        'business_transactions',
                        jsonEncode(businessTransactions),
                      );
                      if (mounted) setState(() {});
                      _audit('Добавлен', 'Доход', note.text.trim());
                      amount.clear();
                      note.clear();
                    }
                  },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Добавить доход'),
          ),
        ],
      ),
    );
    amount.dispose();
    note.dispose();
    operationDate.dispose();
  }
}
