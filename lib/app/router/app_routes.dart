import '../../features/access/presentation/access_gate_page.dart';
import '../../features/access/presentation/privacy_settings_pages.dart';
import '../../features/access/presentation/recovery_page.dart';
import '../../features/character/presentation/character_menu_page.dart';
import '../../features/contacts/presentation/contact_pages.dart';
import '../../features/economy/domain/models/economy_models.dart';
import '../../features/economy/presentation/economy_analysis_page.dart';
import '../../features/economy/presentation/economy_overview_page.dart';
import '../../features/economy/presentation/economy_savings_pages.dart';
import '../../features/economy/presentation/economy_transaction_pages.dart';
import '../../features/home/presentation/home_operations_page.dart';
import '../../features/journal/application/daily_close_application_service.dart';
import '../../features/journal/presentation/daily_close_page.dart';
import '../../features/journal/presentation/journal_entry_detail_page.dart';
import '../../features/journal/presentation/journal_entry_form_page.dart';
import '../../features/journal/presentation/journal_search_archive_pages.dart';
import '../../features/journal/presentation/journal_timeline_page.dart';
import '../../features/missions/presentation/mission_active_page.dart';
import '../../features/missions/presentation/mission_board_page.dart';
import '../../features/missions/presentation/mission_calendar_page.dart';
import '../../features/missions/presentation/mission_collection_page.dart';
import '../../features/missions/presentation/mission_completion_pages.dart';
import '../../features/missions/presentation/mission_detail_page.dart';
import '../../features/missions/presentation/mission_form_page.dart';
import '../../features/missions/presentation/mission_switch_timer_page.dart';
import '../../features/missions/presentation/missions_today_page.dart';
import '../../features/notifications/presentation/notification_settings_page.dart';
import '../../features/progress/presentation/dashboard_daily_page.dart';
import '../../features/progress/presentation/dashboard_progress_page.dart';
import '../../features/progress/presentation/dashboard_weekly_page.dart';
import '../../features/recurrences/presentation/recurrence_form_page.dart';
import '../../features/recurrences/presentation/recurrence_list_page.dart';
import '../../features/settings/presentation/appearance_settings_page.dart';
import '../../features/settings/presentation/more_page.dart';
import '../../features/settings/presentation/sound_settings_page.dart';
import '../../features/shop/presentation/shop_pages.dart';
import 'app_route_contract.dart';

abstract final class AppRoutes {
  static const String lock = '/lock';
  static const String lockRecovery = '/lock/recovery';
  static const String home = '/home';
  static const String more = '/more';
  static const String missionsToday = '/missions/today';
  static const String missionsBoard = '/missions/board';
  static const String journal = '/journal';
  static const String character = '/character';
  static const String finance = '/finance';
  static const String dashboardDaily = '/dashboard/daily';
  static const String settings = '/settings';
  static const String settingsAppearance = '/settings/appearance';
  static const String settingsPrivacy = '/settings/privacy';
  static const String settingsPrivacyPin = '/settings/privacy/pin';
  static const String settingsPrivacyBiometrics =
      '/settings/privacy/biometrics';
  static const String settingsNotifications = '/settings/notifications';
  static const String settingsSound = '/settings/sound';

  /// El mapa contiene 61 patrones URI (60 superficies funcionales).
  /// `/more` es el único contenedor de navegación, no una superficie funcional.
  ///
  /// Cada contrato lleva su propia página en `builder`. Las superficies que aún
  /// no tienen página (builder `null`) caen al placeholder; ese conjunto está
  /// fijado por prueba para evitar rutas huérfanas silenciosas.
  static final List<AppRouteContract> all = <AppRouteContract>[
    AppRouteContract(
      name: 'lock',
      path: lock,
      title: 'Desbloquear',
      area: AppArea.access,
      builder: (context, state) => const AccessGatePage(),
    ),
    AppRouteContract(
      name: 'lockRecovery',
      path: lockRecovery,
      title: 'Recuperar acceso',
      area: AppArea.access,
      builder: (context, state) => const RecoveryPage(),
    ),
    AppRouteContract(
      name: 'home',
      path: home,
      title: 'Inicio',
      area: AppArea.home,
      builder: (context, state) => const HomeOperationsPage(),
    ),
    AppRouteContract(
      name: 'more',
      path: more,
      title: 'Más',
      area: AppArea.navigation,
      isFunctionalSurface: false,
      builder: (context, state) => const MorePage(),
    ),
    AppRouteContract(
      name: 'missionsToday',
      path: missionsToday,
      title: 'Misiones de hoy',
      area: AppArea.missions,
      queryParameters: const <String>{'filter'},
      builder: (context, state) => MissionsTodayPage(
        initialFilter: _parseTodayFilter(state.uri.queryParameters['filter']),
      ),
    ),
    AppRouteContract(
      name: 'missionsBoard',
      path: missionsBoard,
      title: 'Tablón de misiones',
      area: AppArea.missions,
      builder: (context, state) => const MissionBoardPage(),
    ),
    AppRouteContract(
      name: 'missionsUpcoming',
      path: '/missions/upcoming',
      title: 'Próximas misiones',
      area: AppArea.missions,
      builder: (context, state) =>
          const MissionCollectionPage(collection: MissionCollection.upcoming),
    ),
    AppRouteContract(
      name: 'missionsAll',
      path: '/missions/all',
      title: 'Todas las misiones',
      area: AppArea.missions,
      builder: (context, state) =>
          const MissionCollectionPage(collection: MissionCollection.all),
    ),
    AppRouteContract(
      name: 'missionsRecurring',
      path: '/missions/recurring',
      title: 'Misiones recurrentes',
      area: AppArea.missions,
      builder: (context, state) => const RecurrenceListPage(),
    ),
    AppRouteContract(
      name: 'missionsCalendar',
      path: '/missions/calendar',
      title: 'Calendario de misiones',
      area: AppArea.missions,
      queryParameters: const <String>{'date'},
      builder: (context, state) => MissionCalendarPage(
        initialDay: _parseLocalDate(state.uri.queryParameters['date']),
      ),
    ),
    AppRouteContract(
      name: 'missionNew',
      path: '/missions/new',
      title: 'Crear misión',
      area: AppArea.missions,
      queryParameters: const <String>{'origin', 'date', 'board'},
      builder: (context, state) => MissionFormPage(
        initialScheduledLocal: _parseLocalDate(
          state.uri.queryParameters['date'],
        ),
        origin: state.uri.queryParameters['origin'],
        initialBoard: state.uri.queryParameters['board'] == '1',
      ),
    ),
    AppRouteContract(
      name: 'missionTemplateNew',
      path: '/mission-templates/new',
      title: 'Crear plantilla recurrente',
      area: AppArea.missions,
      builder: (context, state) => const RecurrenceFormPage(),
    ),
    AppRouteContract(
      name: 'missionTemplateEdit',
      path: '/mission-templates/:templateId/edit',
      title: 'Editar plantilla recurrente',
      area: AppArea.missions,
      builder: (context, state) {
        final String? templateId = state.pathParameters['templateId'];
        return templateId != null
            ? RecurrenceFormPage(templateId: templateId)
            : null;
      },
    ),
    AppRouteContract(
      name: 'missionTemplatePause',
      path: '/mission-templates/:templateId/pause',
      title: 'Pausar plantilla recurrente',
      area: AppArea.missions,
      builder: (context, state) => const RecurrenceListPage(),
    ),
    AppRouteContract(
      name: 'missionEdit',
      path: '/missions/:missionId/edit',
      title: 'Editar misión',
      area: AppArea.missions,
      builder: (context, state) =>
          MissionFormPage(missionId: state.pathParameters['missionId']),
    ),
    AppRouteContract(
      name: 'missionActive',
      path: '/missions/:missionId/active',
      title: 'Misión activa',
      area: AppArea.missions,
      builder: (context, state) {
        final String? missionId = state.pathParameters['missionId'];
        return missionId != null
            ? MissionActivePage(missionId: missionId)
            : null;
      },
    ),
    AppRouteContract(
      name: 'missionReview',
      path: '/missions/:missionId/review',
      title: 'Revisar misión',
      area: AppArea.missions,
      builder: (context, state) {
        final String? missionId = state.pathParameters['missionId'];
        return missionId != null
            ? MissionReviewPage(missionId: missionId)
            : null;
      },
    ),
    AppRouteContract(
      name: 'missionResult',
      path: '/missions/:missionId/result',
      title: 'Resultado de misión',
      area: AppArea.missions,
      builder: (context, state) {
        final String? missionId = state.pathParameters['missionId'];
        return missionId != null
            ? MissionResultPage(missionId: missionId)
            : null;
      },
    ),
    AppRouteContract(
      name: 'missionSwitchTimer',
      path: '/missions/:missionId/switch-timer',
      title: 'Cambiar cronómetro',
      area: AppArea.missions,
      builder: (context, state) {
        final String? missionId = state.pathParameters['missionId'];
        return missionId != null
            ? MissionSwitchTimerPage(missionId: missionId)
            : null;
      },
    ),
    // Superficie diferida: sin página real todavía, cae al placeholder.
    AppRouteContract(
      name: 'missionReschedule',
      path: '/missions/:missionId/reschedule',
      title: 'Reprogramar misión',
      area: AppArea.missions,
    ),
    // Superficie diferida: sin página real todavía, cae al placeholder.
    AppRouteContract(
      name: 'missionConfirmResolution',
      path: '/missions/:missionId/confirm-resolution',
      title: 'Confirmar resolución',
      area: AppArea.missions,
      queryParameters: const <String>{'mode'},
    ),
    AppRouteContract(
      name: 'missionDetail',
      path: '/missions/:missionId',
      title: 'Detalle de misión',
      area: AppArea.missions,
      builder: (context, state) {
        final String? missionId = state.pathParameters['missionId'];
        return missionId != null
            ? MissionDetailPage(missionId: missionId)
            : null;
      },
    ),
    AppRouteContract(
      name: 'journalNew',
      path: '/journal/new',
      title: 'Nueva entrada',
      area: AppArea.journal,
      queryParameters: const <String>{'origin'},
      builder: (context, state) =>
          JournalEntryFormPage(originHint: state.uri.queryParameters['origin']),
    ),
    AppRouteContract(
      name: 'journalSearch',
      path: '/journal/search',
      title: 'Buscar en Bitácora',
      area: AppArea.journal,
      builder: (context, state) => const JournalSearchPage(),
    ),
    AppRouteContract(
      name: 'journalArchive',
      path: '/journal/archive',
      title: 'Archivo de Bitácora',
      area: AppArea.journal,
      builder: (context, state) => const JournalArchivePage(),
    ),
    AppRouteContract(
      name: 'journalDailyClose',
      path: '/journal/daily-close/:date',
      title: 'Cierre diario',
      area: AppArea.journal,
      builder: (context, state) {
        final String? date = state.pathParameters['date'];
        final DateTime? parsedDate = date != null
            ? parseDailyCloseDate(date)
            : null;
        return parsedDate != null ? DailyClosePage(localDay: parsedDate) : null;
      },
    ),
    AppRouteContract(
      name: 'journalEdit',
      path: '/journal/:entryId/edit',
      title: 'Editar entrada',
      area: AppArea.journal,
      builder: (context, state) {
        final String? entryId = state.pathParameters['entryId'];
        return entryId != null ? JournalEntryFormPage(entryId: entryId) : null;
      },
    ),
    AppRouteContract(
      name: 'journalDetail',
      path: '/journal/:entryId',
      title: 'Detalle de Bitácora',
      area: AppArea.journal,
      builder: (context, state) {
        final String? entryId = state.pathParameters['entryId'];
        return entryId != null
            ? JournalEntryDetailPage(entryId: entryId)
            : null;
      },
    ),
    AppRouteContract(
      name: 'journal',
      path: journal,
      title: 'Bitácora',
      area: AppArea.journal,
      builder: (context, state) => const JournalTimelinePage(),
    ),
    AppRouteContract(
      name: 'contactNew',
      path: '/character/contacts/new',
      title: 'Crear personaje',
      area: AppArea.character,
      builder: (context, state) => const ContactFormPage(),
    ),
    AppRouteContract(
      name: 'contactEdit',
      path: '/character/contacts/:contactId/edit',
      title: 'Editar personaje',
      area: AppArea.character,
      builder: (context, state) {
        final String? contactId = state.pathParameters['contactId'];
        return contactId != null ? ContactFormPage(contactId: contactId) : null;
      },
    ),
    AppRouteContract(
      name: 'contactDetail',
      path: '/character/contacts/:contactId',
      title: 'Ficha de personaje',
      area: AppArea.character,
      builder: (context, state) {
        final String? contactId = state.pathParameters['contactId'];
        return contactId != null
            ? ContactDetailPage(contactId: contactId)
            : null;
      },
    ),
    AppRouteContract(
      name: 'wishNew',
      path: '/character/shop/new',
      title: 'Añadir deseo',
      area: AppArea.character,
      builder: (context, state) => const WishFormPage(),
    ),
    AppRouteContract(
      name: 'wishEdit',
      path: '/character/shop/:wishId/edit',
      title: 'Editar deseo',
      area: AppArea.character,
      builder: (context, state) {
        final String? wishId = state.pathParameters['wishId'];
        return wishId != null ? WishFormPage(wishId: wishId) : null;
      },
    ),
    AppRouteContract(
      name: 'wishDetail',
      path: '/character/shop/:wishId',
      title: 'Deseo',
      area: AppArea.character,
      builder: (context, state) {
        final String? wishId = state.pathParameters['wishId'];
        return wishId != null ? WishDetailPage(wishId: wishId) : null;
      },
    ),
    AppRouteContract(
      name: 'character',
      path: character,
      title: 'Personaje',
      area: AppArea.character,
      queryParameters: const <String>{'tab'},
      builder: (context, state) => CharacterMenuPage(
        initialTab: CharacterTab.fromQuery(state.uri.queryParameters['tab']),
      ),
    ),
    AppRouteContract(
      name: 'financeTransactions',
      path: '/finance/transactions',
      title: 'Movimientos',
      area: AppArea.finance,
      builder: (context, state) => const EconomyTransactionsPage(),
    ),
    AppRouteContract(
      name: 'financeNewExpense',
      path: '/finance/transactions/new-expense',
      title: 'Registrar gasto',
      area: AppArea.finance,
      queryParameters: const <String>{'missionId'},
      builder: (context, state) => EconomyTransactionFormPage(
        initialType: EconomyTransactionType.expense,
        missionId: state.uri.queryParameters['missionId'],
      ),
    ),
    AppRouteContract(
      name: 'financeNewIncome',
      path: '/finance/transactions/new-income',
      title: 'Registrar ingreso',
      area: AppArea.finance,
      queryParameters: const <String>{'missionId', 'refundOf'},
      builder: (context, state) => EconomyTransactionFormPage(
        initialType: EconomyTransactionType.income,
        missionId: state.uri.queryParameters['missionId'],
      ),
    ),
    AppRouteContract(
      name: 'financeNewAdjustment',
      path: '/finance/transactions/new-adjustment',
      title: 'Registrar ajuste',
      area: AppArea.finance,
      builder: (context, state) => const EconomyTransactionFormPage(
        initialType: EconomyTransactionType.adjustmentCredit,
      ),
    ),
    AppRouteContract(
      name: 'financeTransactionCorrect',
      path: '/finance/transactions/:transactionId/correct',
      title: 'Corregir movimiento',
      area: AppArea.finance,
      builder: (context, state) {
        final String? transactionId = state.pathParameters['transactionId'];
        return transactionId != null
            ? EconomyTransactionFormPage(
                initialType: EconomyTransactionType.adjustmentCredit,
                transactionId: transactionId,
              )
            : null;
      },
    ),
    AppRouteContract(
      name: 'financeTransactionVoid',
      path: '/finance/transactions/:transactionId/void',
      title: 'Anular movimiento',
      area: AppArea.finance,
      builder: (context, state) {
        final String? transactionId = state.pathParameters['transactionId'];
        return transactionId != null
            ? EconomyTransactionDetailPage(
                transactionId: transactionId,
                requestVoid: true,
              )
            : null;
      },
    ),
    AppRouteContract(
      name: 'financeTransactionDetail',
      path: '/finance/transactions/:transactionId',
      title: 'Detalle de movimiento',
      area: AppArea.finance,
      builder: (context, state) {
        final String? transactionId = state.pathParameters['transactionId'];
        return transactionId != null
            ? EconomyTransactionDetailPage(transactionId: transactionId)
            : null;
      },
    ),
    AppRouteContract(
      name: 'financeSavingsNew',
      path: '/finance/savings/new',
      title: 'Crear meta de ahorro',
      area: AppArea.finance,
      builder: (context, state) => const EconomyGoalFormPage(),
    ),
    AppRouteContract(
      name: 'financeSavingsEdit',
      path: '/finance/savings/:goalId/edit',
      title: 'Editar meta de ahorro',
      area: AppArea.finance,
      builder: (context, state) {
        final String? goalId = state.pathParameters['goalId'];
        return goalId != null ? EconomyGoalFormPage(goalId: goalId) : null;
      },
    ),
    AppRouteContract(
      name: 'financeSavingsDetail',
      path: '/finance/savings/:goalId',
      title: 'Detalle de ahorro',
      area: AppArea.finance,
      builder: (context, state) {
        final String? goalId = state.pathParameters['goalId'];
        return goalId != null ? EconomyGoalDetailPage(goalId: goalId) : null;
      },
    ),
    AppRouteContract(
      name: 'financeSavings',
      path: '/finance/savings',
      title: 'Ahorro y reservas',
      area: AppArea.finance,
      builder: (context, state) => const EconomySavingsPage(),
    ),
    AppRouteContract(
      name: 'financeAnalysis',
      path: '/finance/analysis',
      title: 'Análisis financiero',
      area: AppArea.finance,
      builder: (context, state) => const EconomyAnalysisPage(),
    ),
    AppRouteContract(
      name: 'finance',
      path: finance,
      title: 'Economía',
      area: AppArea.finance,
      builder: (context, state) => const EconomyOverviewPage(),
    ),
    AppRouteContract(
      name: 'dashboardDaily',
      path: dashboardDaily,
      title: 'Dashboard diario',
      area: AppArea.dashboard,
      queryParameters: const <String>{'date'},
      builder: (context, state) => const DashboardDailyPage(),
    ),
    AppRouteContract(
      name: 'dashboardWeekly',
      path: '/dashboard/weekly',
      title: 'Dashboard semanal',
      area: AppArea.dashboard,
      queryParameters: const <String>{'week'},
      builder: (context, state) => const DashboardWeeklyPage(),
    ),
    AppRouteContract(
      name: 'dashboardProgress',
      path: '/dashboard/progress',
      title: 'Progreso',
      area: AppArea.dashboard,
      builder: (context, state) => const DashboardProgressPage(),
    ),
    AppRouteContract(
      name: 'settingsAppearance',
      path: settingsAppearance,
      title: 'Apariencia',
      area: AppArea.settings,
      builder: (context, state) => const AppearanceSettingsPage(),
    ),
    AppRouteContract(
      name: 'settingsPrivacyPin',
      path: settingsPrivacyPin,
      title: 'PIN',
      area: AppArea.settings,
      builder: (context, state) => const ChangePinPage(),
    ),
    AppRouteContract(
      name: 'settingsPrivacyBiometrics',
      path: settingsPrivacyBiometrics,
      title: 'Biometría',
      area: AppArea.settings,
      builder: (context, state) => const BiometricsSettingsPage(),
    ),
    AppRouteContract(
      name: 'settingsPrivacy',
      path: settingsPrivacy,
      title: 'Privacidad',
      area: AppArea.settings,
      builder: (context, state) => const PrivacySettingsPage(),
    ),
    AppRouteContract(
      name: 'settingsNotifications',
      path: settingsNotifications,
      title: 'Notificaciones',
      area: AppArea.settings,
      builder: (context, state) => const NotificationSettingsPage(),
    ),
    AppRouteContract(
      name: 'settingsSound',
      path: settingsSound,
      title: 'Sonido',
      area: AppArea.settings,
      builder: (context, state) => const SoundSettingsPage(),
    ),
    // Superficie diferida: sin página real todavía, cae al placeholder.
    AppRouteContract(
      name: 'settingsMissionsProgress',
      path: '/settings/missions-progress',
      title: 'Misiones y progreso',
      area: AppArea.settings,
    ),
    // Superficie diferida: sin página real todavía, cae al placeholder.
    AppRouteContract(
      name: 'settingsFinance',
      path: '/settings/finance',
      title: 'Ajustes de economía',
      area: AppArea.settings,
    ),
    // Superficie diferida: sin página real todavía, cae al placeholder.
    AppRouteContract(
      name: 'settingsJournal',
      path: '/settings/journal',
      title: 'Ajustes de Bitácora',
      area: AppArea.settings,
    ),
    // Superficie diferida: sin página real todavía, cae al placeholder.
    AppRouteContract(
      name: 'settingsDashboard',
      path: '/settings/dashboard',
      title: 'Ajustes de Dashboard',
      area: AppArea.settings,
    ),
    // Las rutas de datos y continuidad (settingsData, settingsDataExport,
    // settingsDataImport, settingsDataImportConfirm, settingsDataTrash) fueron
    // retiradas: A6 (copia/restauración/exportación) salió del MVP por ADR-005.
    // No re-añadir sin reabrir ese ADR.
    // Superficie diferida: sin página real todavía, cae al placeholder.
    AppRouteContract(
      name: 'settingsAdvanced',
      path: '/settings/advanced',
      title: 'Ajustes avanzados',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settings',
      path: settings,
      title: 'Ajustes',
      area: AppArea.settings,
      builder: (context, state) => const SettingsLandingPage(),
    ),
  ];

  static Iterable<AppRouteContract> forArea(AppArea area) =>
      all.where((AppRouteContract route) => route.area == area);
}

MissionsTodayFilter? _parseTodayFilter(String? value) => switch (value) {
  'all' => MissionsTodayFilter.all,
  'today' => MissionsTodayFilter.today,
  'active' => MissionsTodayFilter.active,
  'completed' => MissionsTodayFilter.completed,
  _ => null,
};

DateTime? _parseLocalDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null ||
      '${parsed.year.toString().padLeft(4, '0')}-'
              '${parsed.month.toString().padLeft(2, '0')}-'
              '${parsed.day.toString().padLeft(2, '0')}' !=
          value) {
    return null;
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}
