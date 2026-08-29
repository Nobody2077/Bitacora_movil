import 'app_route_contract.dart';

abstract final class AppRoutes {
  static const String lock = '/lock';
  static const String lockRecovery = '/lock/recovery';
  static const String home = '/home';
  static const String more = '/more';
  static const String missionsToday = '/missions/today';
  static const String journal = '/journal';
  static const String finance = '/finance';
  static const String dashboardDaily = '/dashboard/daily';
  static const String settings = '/settings';
  static const String settingsAppearance = '/settings/appearance';
  static const String settingsPrivacy = '/settings/privacy';
  static const String settingsPrivacyPin = '/settings/privacy/pin';
  static const String settingsPrivacyBiometrics =
      '/settings/privacy/biometrics';
  static const String settingsNotifications = '/settings/notifications';

  /// El mapa definitivo contiene 58 identificadores NAV y 60 patrones URI.
  /// `/more` es el único contenedor de navegación, no una superficie funcional.
  static const List<AppRouteContract> all = <AppRouteContract>[
    AppRouteContract(
      name: 'lock',
      path: lock,
      title: 'Desbloquear',
      area: AppArea.access,
    ),
    AppRouteContract(
      name: 'lockRecovery',
      path: lockRecovery,
      title: 'Recuperar acceso',
      area: AppArea.access,
    ),
    AppRouteContract(
      name: 'home',
      path: home,
      title: 'Inicio',
      area: AppArea.home,
    ),
    AppRouteContract(
      name: 'more',
      path: more,
      title: 'Más',
      area: AppArea.navigation,
      isFunctionalSurface: false,
    ),
    AppRouteContract(
      name: 'missionsToday',
      path: missionsToday,
      title: 'Misiones de hoy',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionsUpcoming',
      path: '/missions/upcoming',
      title: 'Próximas misiones',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionsAll',
      path: '/missions/all',
      title: 'Todas las misiones',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionsRecurring',
      path: '/missions/recurring',
      title: 'Misiones recurrentes',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionsCalendar',
      path: '/missions/calendar',
      title: 'Calendario de misiones',
      area: AppArea.missions,
      queryParameters: <String>{'date'},
    ),
    AppRouteContract(
      name: 'missionNew',
      path: '/missions/new',
      title: 'Crear misión',
      area: AppArea.missions,
      queryParameters: <String>{'origin', 'date'},
    ),
    AppRouteContract(
      name: 'missionTemplateNew',
      path: '/mission-templates/new',
      title: 'Crear plantilla recurrente',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionTemplateEdit',
      path: '/mission-templates/:templateId/edit',
      title: 'Editar plantilla recurrente',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionTemplatePause',
      path: '/mission-templates/:templateId/pause',
      title: 'Pausar plantilla recurrente',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionEdit',
      path: '/missions/:missionId/edit',
      title: 'Editar misión',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionActive',
      path: '/missions/:missionId/active',
      title: 'Misión activa',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionReview',
      path: '/missions/:missionId/review',
      title: 'Revisar misión',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionResult',
      path: '/missions/:missionId/result',
      title: 'Resultado de misión',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionSwitchTimer',
      path: '/missions/:missionId/switch-timer',
      title: 'Cambiar cronómetro',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionReschedule',
      path: '/missions/:missionId/reschedule',
      title: 'Reprogramar misión',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'missionConfirmResolution',
      path: '/missions/:missionId/confirm-resolution',
      title: 'Confirmar resolución',
      area: AppArea.missions,
      queryParameters: <String>{'mode'},
    ),
    AppRouteContract(
      name: 'missionDetail',
      path: '/missions/:missionId',
      title: 'Detalle de misión',
      area: AppArea.missions,
    ),
    AppRouteContract(
      name: 'journalNew',
      path: '/journal/new',
      title: 'Nueva entrada',
      area: AppArea.journal,
      queryParameters: <String>{'origin'},
    ),
    AppRouteContract(
      name: 'journalSearch',
      path: '/journal/search',
      title: 'Buscar en Bitácora',
      area: AppArea.journal,
    ),
    AppRouteContract(
      name: 'journalArchive',
      path: '/journal/archive',
      title: 'Archivo de Bitácora',
      area: AppArea.journal,
    ),
    AppRouteContract(
      name: 'journalDailyClose',
      path: '/journal/daily-close/:date',
      title: 'Cierre diario',
      area: AppArea.journal,
    ),
    AppRouteContract(
      name: 'journalEdit',
      path: '/journal/:entryId/edit',
      title: 'Editar entrada',
      area: AppArea.journal,
    ),
    AppRouteContract(
      name: 'journalDetail',
      path: '/journal/:entryId',
      title: 'Detalle de Bitácora',
      area: AppArea.journal,
    ),
    AppRouteContract(
      name: 'journal',
      path: journal,
      title: 'Bitácora',
      area: AppArea.journal,
    ),
    AppRouteContract(
      name: 'financeTransactions',
      path: '/finance/transactions',
      title: 'Movimientos',
      area: AppArea.finance,
    ),
    AppRouteContract(
      name: 'financeNewExpense',
      path: '/finance/transactions/new-expense',
      title: 'Registrar gasto',
      area: AppArea.finance,
      queryParameters: <String>{'missionId'},
    ),
    AppRouteContract(
      name: 'financeNewIncome',
      path: '/finance/transactions/new-income',
      title: 'Registrar ingreso',
      area: AppArea.finance,
      queryParameters: <String>{'missionId', 'refundOf'},
    ),
    AppRouteContract(
      name: 'financeNewAdjustment',
      path: '/finance/transactions/new-adjustment',
      title: 'Registrar ajuste',
      area: AppArea.finance,
    ),
    AppRouteContract(
      name: 'financeTransactionCorrect',
      path: '/finance/transactions/:transactionId/correct',
      title: 'Corregir movimiento',
      area: AppArea.finance,
    ),
    AppRouteContract(
      name: 'financeTransactionVoid',
      path: '/finance/transactions/:transactionId/void',
      title: 'Anular movimiento',
      area: AppArea.finance,
    ),
    AppRouteContract(
      name: 'financeTransactionDetail',
      path: '/finance/transactions/:transactionId',
      title: 'Detalle de movimiento',
      area: AppArea.finance,
    ),
    AppRouteContract(
      name: 'financeSavingsNew',
      path: '/finance/savings/new',
      title: 'Crear meta de ahorro',
      area: AppArea.finance,
    ),
    AppRouteContract(
      name: 'financeSavingsEdit',
      path: '/finance/savings/:goalId/edit',
      title: 'Editar meta de ahorro',
      area: AppArea.finance,
    ),
    AppRouteContract(
      name: 'financeSavingsDetail',
      path: '/finance/savings/:goalId',
      title: 'Detalle de ahorro',
      area: AppArea.finance,
    ),
    AppRouteContract(
      name: 'financeSavings',
      path: '/finance/savings',
      title: 'Ahorro y reservas',
      area: AppArea.finance,
    ),
    AppRouteContract(
      name: 'financeAnalysis',
      path: '/finance/analysis',
      title: 'Análisis financiero',
      area: AppArea.finance,
    ),
    AppRouteContract(
      name: 'finance',
      path: finance,
      title: 'Economía',
      area: AppArea.finance,
    ),
    AppRouteContract(
      name: 'dashboardDaily',
      path: dashboardDaily,
      title: 'Dashboard diario',
      area: AppArea.dashboard,
      queryParameters: <String>{'date'},
    ),
    AppRouteContract(
      name: 'dashboardWeekly',
      path: '/dashboard/weekly',
      title: 'Dashboard semanal',
      area: AppArea.dashboard,
      queryParameters: <String>{'week'},
    ),
    AppRouteContract(
      name: 'dashboardProgress',
      path: '/dashboard/progress',
      title: 'Progreso',
      area: AppArea.dashboard,
    ),
    AppRouteContract(
      name: 'settingsAppearance',
      path: settingsAppearance,
      title: 'Apariencia',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsPrivacyPin',
      path: settingsPrivacyPin,
      title: 'PIN',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsPrivacyBiometrics',
      path: settingsPrivacyBiometrics,
      title: 'Biometría',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsPrivacy',
      path: settingsPrivacy,
      title: 'Privacidad',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsNotifications',
      path: settingsNotifications,
      title: 'Notificaciones',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsMissionsProgress',
      path: '/settings/missions-progress',
      title: 'Misiones y progreso',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsFinance',
      path: '/settings/finance',
      title: 'Ajustes de economía',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsJournal',
      path: '/settings/journal',
      title: 'Ajustes de Bitácora',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsDashboard',
      path: '/settings/dashboard',
      title: 'Ajustes de Dashboard',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsDataExport',
      path: '/settings/data/export',
      title: 'Exportar datos',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsDataImportConfirm',
      path: '/settings/data/import/confirm',
      title: 'Confirmar importación',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsDataImport',
      path: '/settings/data/import',
      title: 'Importar datos',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsDataTrash',
      path: '/settings/data/trash',
      title: 'Papelera de datos',
      area: AppArea.settings,
    ),
    AppRouteContract(
      name: 'settingsData',
      path: '/settings/data',
      title: 'Datos y continuidad',
      area: AppArea.settings,
    ),
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
    ),
  ];

  static Iterable<AppRouteContract> forArea(AppArea area) =>
      all.where((AppRouteContract route) => route.area == area);
}
