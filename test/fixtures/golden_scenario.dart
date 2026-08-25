import 'package:bitacora_rpg_personal/infrastructure/database/app_database.dart';

/// Dataset canónico de A1.
///
/// Todos los identificadores, instantes y valores son fijos. El fixture no usa
/// el reloj del sistema, red ni generadores aleatorios.
final class GoldenScenario {
  const GoldenScenario._({
    required this.nowUtcMs,
    required this.timezoneId,
    required this.locale,
    required this.currencyCode,
  });

  static const GoldenScenario standard = GoldenScenario._(
    nowUtcMs: 1787521320000, // 2026-08-23T21:42:00Z / 17:42 Bolivia.
    timezoneId: 'America/La_Paz',
    locale: 'es_BO',
    currencyCode: 'BOB',
  );

  static const int localDayStartUtcMs = 1787457600000;
  static const int localDayEndUtcMs = 1787544000000;
  static const int localWeekStartUtcMs = 1786939200000;
  static const int localMonthStartUtcMs = 1785556800000;
  static const int localMonthEndUtcMs = 1788235200000;

  static const String studiesAreaId = '00000000-0000-4000-8000-000000000001';
  static const String healthAreaId = '00000000-0000-4000-8000-000000000002';
  static const String projectsAreaId = '00000000-0000-4000-8000-000000000003';
  static const String homeAreaId = '00000000-0000-4000-8000-000000000004';
  static const String personalAreaId = '00000000-0000-4000-8000-000000000005';

  static const String laboratoryMissionId =
      '20000000-0000-4000-8000-000000000001';
  static const String healthMissionId = '20000000-0000-4000-8000-000000000002';
  static const String personalMissionId =
      '20000000-0000-4000-8000-000000000003';
  static const String homeMissionId = '20000000-0000-4000-8000-000000000004';
  static const String pendingMissionId = '20000000-0000-4000-8000-000000000005';

  final int nowUtcMs;
  final String timezoneId;
  final String locale;
  final String currencyCode;

  /// Inserta el escenario completo en una base v1 recién creada.
  Future<void> seed(AppDatabase database) => database.transaction(() async {
    await _insertMissions(database);
    await _insertLaboratoryObjectives(database);
    await _insertTransactions(database);
    await _insertSavings(database);
    await _insertJournal(database);
    await _insertXp(database);
  });

  Future<void> _insertMissions(AppDatabase database) async {
    const sql = '''
      INSERT INTO missions (
        id, template_id, area_id, title, description, mission_type,
        importance, priority, difficulty, is_required, status, scheduled_at,
        available_from, expires_at, estimated_minutes, budget_minor,
        xp_planned, actual_result, convenience_rating, completed_at,
        archived_at, row_version
      ) VALUES (
        ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
        NULL, 1
      )
    ''';

    final missions = <List<Object?>>[
      <Object?>[
        laboratoryMissionId,
        studiesAreaId,
        'Completar laboratorio de redes',
        'Configurar, verificar y documentar el laboratorio práctico.',
        'PRIMARY',
        'IMPORTANT',
        'HIGH',
        'HARD',
        1,
        'ACTIVE',
        _utcMs(2026, 8, 23, 18),
        _utcMs(2026, 8, 23, 17, 30),
        _utcMs(2026, 8, 24, 2),
        90,
        3500,
        50,
        null,
        null,
        null,
      ],
      <Object?>[
        healthMissionId,
        healthAreaId,
        'Entrenar 30 minutos',
        'Sesión breve de movilidad y resistencia.',
        'DAILY',
        'NORMAL',
        'NORMAL',
        'EASY',
        0,
        'COMPLETED',
        _utcMs(2026, 8, 23, 11, 30),
        _utcMs(2026, 8, 23, 11),
        _utcMs(2026, 8, 23, 13),
        30,
        null,
        40,
        'Rutina terminada.',
        'TOTALLY_WORTH_IT',
        _utcMs(2026, 8, 23, 12, 5),
      ],
      <Object?>[
        personalMissionId,
        personalAreaId,
        'Revisar presupuesto semanal',
        'Conciliar movimientos y ajustar el plan de la semana.',
        'ERRAND',
        'IMPORTANT',
        'NORMAL',
        'MEDIUM',
        1,
        'COMPLETED',
        _utcMs(2026, 8, 23, 13),
        _utcMs(2026, 8, 23, 12, 30),
        _utcMs(2026, 8, 23, 15),
        20,
        null,
        25,
        'Presupuesto actualizado.',
        'WORTH_IT_BUT_COSTLY',
        _utcMs(2026, 8, 23, 13, 24),
      ],
      <Object?>[
        homeMissionId,
        homeAreaId,
        'Ordenar escritorio',
        'Dejar el espacio listo para la siguiente semana.',
        'SECONDARY',
        'NORMAL',
        'LOW',
        'EASY',
        0,
        'COMPLETED',
        _utcMs(2026, 8, 23, 16),
        _utcMs(2026, 8, 23, 15, 30),
        _utcMs(2026, 8, 23, 18),
        25,
        null,
        60,
        'Espacio despejado.',
        'TOTALLY_WORTH_IT',
        _utcMs(2026, 8, 23, 16, 31),
      ],
      <Object?>[
        pendingMissionId,
        personalAreaId,
        'Preparar cena saludable',
        'Organizar ingredientes antes de cocinar.',
        'DAILY',
        'NORMAL',
        'NORMAL',
        'EASY',
        0,
        'AVAILABLE',
        _utcMs(2026, 8, 23, 23),
        _utcMs(2026, 8, 23, 22, 30),
        _utcMs(2026, 8, 24, 1),
        45,
        6000,
        30,
        null,
        null,
        null,
      ],
      <Object?>[
        '20000000-0000-4000-8000-000000000006',
        projectsAreaId,
        'Entregar informe Flutter',
        'Cerrar la revisión técnica antes de publicar.',
        'PRIMARY',
        'VERY_IMPORTANT',
        'HIGH',
        'HARD',
        1,
        'SCHEDULED',
        _utcMs(2026, 8, 24, 15),
        _utcMs(2026, 8, 24, 13),
        _utcMs(2026, 8, 24, 21),
        120,
        null,
        100,
        null,
        null,
        null,
      ],
      <Object?>[
        '20000000-0000-4000-8000-000000000007',
        healthAreaId,
        'Cita médica preventiva',
        'Preparar preguntas y antecedentes relevantes.',
        'EVENT',
        'IMPORTANT',
        'HIGH',
        null,
        1,
        'SCHEDULED',
        _utcMs(2026, 8, 25, 14),
        _utcMs(2026, 8, 25, 13),
        _utcMs(2026, 8, 25, 16),
        60,
        10000,
        80,
        null,
        null,
        null,
      ],
      <Object?>[
        '20000000-0000-4000-8000-000000000008',
        personalAreaId,
        'Organizar respaldo personal',
        'Revisar los archivos que entrarán en la copia local.',
        'SECONDARY',
        'NORMAL',
        'LOW',
        'MEDIUM',
        0,
        'SCHEDULED',
        _utcMs(2026, 8, 26, 1),
        _utcMs(2026, 8, 25, 22),
        _utcMs(2026, 8, 26, 3),
        40,
        null,
        35,
        null,
        null,
        null,
      ],
    ];

    for (final mission in missions) {
      await database.customStatement(sql, mission);
    }
  }

  Future<void> _insertLaboratoryObjectives(AppDatabase database) async {
    const sql = '''
      INSERT INTO mission_objectives (
        id, mission_id, description, position, completed_at, created_at
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''';
    final createdAt = _utcMs(2026, 8, 23, 17, 30);
    final objectives = <List<Object?>>[
      <Object?>[
        '21000000-0000-4000-8000-000000000001',
        laboratoryMissionId,
        'Configurar la topología',
        0,
        _utcMs(2026, 8, 23, 19),
        createdAt,
      ],
      <Object?>[
        '21000000-0000-4000-8000-000000000002',
        laboratoryMissionId,
        'Verificar la conectividad',
        1,
        null,
        createdAt,
      ],
      <Object?>[
        '21000000-0000-4000-8000-000000000003',
        laboratoryMissionId,
        'Documentar los resultados',
        2,
        null,
        createdAt,
      ],
    ];

    for (final objective in objectives) {
      await database.customStatement(sql, objective);
    }
  }

  Future<void> _insertTransactions(AppDatabase database) async {
    const sql = '''
      INSERT INTO transactions (
        id, operation_id, mission_id, related_transaction_id,
        transaction_type, amount_minor, payment_method, category, note,
        occurred_at, created_at, reversed_at
      ) VALUES (?, ?, NULL, NULL, ?, ?, ?, ?, ?, ?, ?, NULL)
    ''';
    final transactions = <List<Object?>>[
      <Object?>[
        '30000000-0000-4000-8000-000000000001',
        'golden-tx-previous-balance',
        'ADJUSTMENT_CREDIT',
        30000,
        null,
        'Saldo inicial',
        'Saldo anterior al mes canónico.',
        _utcMs(2026, 7, 31, 20),
        _utcMs(2026, 7, 31, 20),
      ],
      <Object?>[
        '30000000-0000-4000-8000-000000000002',
        'golden-tx-month-income',
        'INCOME',
        170000,
        'BANK',
        'Ingresos',
        'Ingreso mensual canónico.',
        _utcMs(2026, 8, 1, 13),
        _utcMs(2026, 8, 1, 13),
      ],
      <Object?>[
        '30000000-0000-4000-8000-000000000003',
        'golden-tx-month-expense',
        'EXPENSE',
        41800,
        'BANK',
        'Servicios',
        'Gastos del mes antes del día canónico.',
        _utcMs(2026, 8, 5, 15),
        _utcMs(2026, 8, 5, 15),
      ],
      <Object?>[
        '30000000-0000-4000-8000-000000000004',
        'golden-tx-day-income',
        'INCOME',
        15000,
        'WALLET',
        'Ingresos',
        'Ingreso del día canónico.',
        _utcMs(2026, 8, 23, 14),
        _utcMs(2026, 8, 23, 14),
      ],
      <Object?>[
        '30000000-0000-4000-8000-000000000005',
        'golden-tx-day-expense-food',
        'EXPENSE',
        3500,
        'CASH',
        'Alimentación',
        'Compra menor del día canónico.',
        _utcMs(2026, 8, 23, 16),
        _utcMs(2026, 8, 23, 16),
      ],
      <Object?>[
        '30000000-0000-4000-8000-000000000006',
        'golden-tx-day-expense-supplies',
        'EXPENSE',
        15700,
        'WALLET',
        'Materiales',
        'Segundo gasto del día canónico.',
        _utcMs(2026, 8, 23, 20),
        _utcMs(2026, 8, 23, 20),
      ],
    ];

    for (final transaction in transactions) {
      await database.customStatement(sql, transaction);
    }
  }

  Future<void> _insertSavings(AppDatabase database) async {
    await database.customStatement(
      '''
        INSERT INTO savings_goals (
          id, title, target_minor, status, due_date, created_at, archived_at
        ) VALUES (?, ?, ?, 'ACTIVE', ?, ?, NULL)
      ''',
      <Object?>[
        '40000000-0000-4000-8000-000000000001',
        'Fondo de emergencia',
        100000,
        '2026-12-31',
        _utcMs(2026, 7, 1, 12),
      ],
    );
    await database.customStatement(
      '''
        INSERT INTO goal_allocations (
          id, operation_id, goal_id, direction, amount_minor, note,
          occurred_at, created_at
        ) VALUES (?, ?, ?, 'RESERVE', ?, ?, ?, ?)
      ''',
      <Object?>[
        '41000000-0000-4000-8000-000000000001',
        'golden-allocation-reserve',
        '40000000-0000-4000-8000-000000000001',
        30000,
        'Reserva del escenario canónico.',
        _utcMs(2026, 8, 10, 16),
        _utcMs(2026, 8, 10, 16),
      ],
    );
  }

  Future<void> _insertJournal(AppDatabase database) async {
    const sql = '''
      INSERT INTO journal_entries (
        id, origin_type, mission_id, transaction_id, title, body, mood,
        is_private, occurred_at, created_at, updated_at, archived_at
      ) VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, NULL)
    ''';
    final entries = <List<Object?>>[
      <Object?>[
        '50000000-0000-4000-8000-000000000001',
        'MANUAL',
        null,
        'Avance del día',
        'La mañana dejó tres tareas terminadas y un ritmo sostenible.',
        'FOCUSED',
        0,
        _utcMs(2026, 8, 23, 16, 40),
        _utcMs(2026, 8, 23, 16, 40),
        _utcMs(2026, 8, 23, 16, 40),
      ],
      <Object?>[
        '50000000-0000-4000-8000-000000000002',
        'MANUAL',
        null,
        'Reflexión de salud',
        'La rutina corta funcionó mejor que posponer el entrenamiento.',
        'NORMAL',
        1,
        _utcMs(2026, 8, 22, 23),
        _utcMs(2026, 8, 22, 23),
        _utcMs(2026, 8, 22, 23),
      ],
      <Object?>[
        '50000000-0000-4000-8000-000000000003',
        'MISSION',
        laboratoryMissionId,
        'Evidencia del laboratorio',
        'Topología lista; queda verificar y documentar.',
        'FOCUSED',
        0,
        _utcMs(2026, 8, 23, 19, 5),
        _utcMs(2026, 8, 23, 19, 5),
        _utcMs(2026, 8, 23, 19, 5),
      ],
    ];

    for (final entry in entries) {
      await database.customStatement(sql, entry);
    }

    await database.customStatement(
      '''
        INSERT INTO journal_attachments (
          id, journal_entry_id, kind, storage_name, mime_type, byte_length,
          cipher_sha256, width_px, height_px, position, created_at,
          archived_at
        ) VALUES (?, ?, 'PHOTO', ?, 'image/jpeg', ?, ?, ?, ?, 0, ?, NULL)
      ''',
      <Object?>[
        '51000000-0000-4000-8000-000000000001',
        '50000000-0000-4000-8000-000000000003',
        'golden-laboratorio-v1.enc',
        184320,
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        1280,
        960,
        _utcMs(2026, 8, 23, 19, 5),
      ],
    );
  }

  Future<void> _insertXp(AppDatabase database) async {
    const sql = '''
      INSERT INTO xp_transactions (
        id, area_id, mission_id, journal_entry_id, source_type, amount,
        reason, occurred_at
      ) VALUES (?, ?, ?, NULL, ?, ?, ?, ?)
    ''';
    final xp = <List<Object?>>[
      <Object?>[
        '60000000-0000-4000-8000-000000000001',
        studiesAreaId,
        null,
        'MANUAL_ADJUSTMENT',
        1100,
        'Saldo XP Estudios anterior al período canónico.',
        _utcMs(2026, 7, 15, 12),
      ],
      <Object?>[
        '60000000-0000-4000-8000-000000000002',
        studiesAreaId,
        null,
        'MANUAL_ADJUSTMENT',
        100,
        'XP Estudios de la semana canónica.',
        _utcMs(2026, 8, 18, 15),
      ],
      <Object?>[
        '60000000-0000-4000-8000-000000000003',
        healthAreaId,
        null,
        'MANUAL_ADJUSTMENT',
        720,
        'Saldo XP Salud anterior al período canónico.',
        _utcMs(2026, 7, 16, 12),
      ],
      <Object?>[
        '60000000-0000-4000-8000-000000000004',
        healthAreaId,
        healthMissionId,
        'MISSION',
        40,
        null,
        _utcMs(2026, 8, 23, 12, 5),
      ],
      <Object?>[
        '60000000-0000-4000-8000-000000000005',
        projectsAreaId,
        null,
        'MANUAL_ADJUSTMENT',
        2050,
        'Saldo XP Proyectos anterior al período canónico.',
        _utcMs(2026, 7, 17, 12),
      ],
      <Object?>[
        '60000000-0000-4000-8000-000000000006',
        projectsAreaId,
        null,
        'MANUAL_ADJUSTMENT',
        100,
        'XP Proyectos de la semana canónica.',
        _utcMs(2026, 8, 20, 15),
      ],
      <Object?>[
        '60000000-0000-4000-8000-000000000007',
        homeAreaId,
        null,
        'MANUAL_ADJUSTMENT',
        155,
        'Saldo XP Hogar anterior al período canónico.',
        _utcMs(2026, 7, 18, 12),
      ],
      <Object?>[
        '60000000-0000-4000-8000-000000000008',
        homeAreaId,
        homeMissionId,
        'MISSION',
        60,
        null,
        _utcMs(2026, 8, 23, 16, 31),
      ],
      <Object?>[
        '60000000-0000-4000-8000-000000000009',
        personalAreaId,
        null,
        'MANUAL_ADJUSTMENT',
        100,
        'Saldo XP Personal anterior al período canónico.',
        _utcMs(2026, 7, 19, 12),
      ],
      <Object?>[
        '60000000-0000-4000-8000-000000000010',
        personalAreaId,
        personalMissionId,
        'MISSION',
        25,
        null,
        _utcMs(2026, 8, 23, 13, 24),
      ],
    ];

    for (final transaction in xp) {
      await database.customStatement(sql, transaction);
    }
  }

  static int _utcMs(int year, int month, int day, int hour, [int minute = 0]) =>
      DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;
}
