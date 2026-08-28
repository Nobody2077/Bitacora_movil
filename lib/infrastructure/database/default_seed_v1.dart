import 'package:drift/drift.dart';

abstract final class DefaultSeedV1 {
  static const studiesAreaId = '00000000-0000-4000-8000-000000000001';
  static const healthAreaId = '00000000-0000-4000-8000-000000000002';
  static const projectsAreaId = '00000000-0000-4000-8000-000000000003';
  static const homeAreaId = '00000000-0000-4000-8000-000000000004';
  static const personalAreaId = '00000000-0000-4000-8000-000000000005';
  static const homeCentinelTitleId = '10000000-0000-4000-8000-000000000001';
  static const dailyStreakTitleId = '10000000-0000-4000-8000-000000000002';
}

/// Inserts the mandatory, deterministic records for a fresh schema v1.
///
/// The caller provides [nowUtcMs] so tests and schema snapshots never depend on
/// the wall clock. Feature demonstration data does not belong in this seed.
Future<void> insertDefaultSeedV1(
  GeneratedDatabase database, {
  required int nowUtcMs,
}) async {
  const defaultAreas =
      <
        ({
          String id,
          String name,
          String iconKey,
          String colorHex,
          int isDefault,
          int sortOrder,
        })
      >[
        (
          id: DefaultSeedV1.studiesAreaId,
          name: 'Estudios',
          iconKey: 'school',
          colorHex: '#38BDF8',
          isDefault: 0,
          sortOrder: 0,
        ),
        (
          id: DefaultSeedV1.healthAreaId,
          name: 'Salud',
          iconKey: 'favorite',
          colorHex: '#22C55E',
          isDefault: 0,
          sortOrder: 1,
        ),
        (
          id: DefaultSeedV1.projectsAreaId,
          name: 'Proyectos',
          iconKey: 'code',
          colorHex: '#A855F7',
          isDefault: 0,
          sortOrder: 2,
        ),
        (
          id: DefaultSeedV1.homeAreaId,
          name: 'Hogar',
          iconKey: 'home',
          colorHex: '#F59E0B',
          isDefault: 0,
          sortOrder: 3,
        ),
        (
          id: DefaultSeedV1.personalAreaId,
          name: 'Personal',
          iconKey: 'person',
          colorHex: '#FF3B3B',
          isDefault: 1,
          sortOrder: 4,
        ),
      ];

  for (final area in defaultAreas) {
    await database.customStatement(
      '''
        INSERT OR IGNORE INTO life_areas (
          id,
          name,
          icon_key,
          color_hex,
          is_default,
          is_visible,
          sort_order,
          archived_at
        ) VALUES (?, ?, ?, ?, ?, 1, ?, NULL)
      ''',
      <Object?>[
        area.id,
        area.name,
        area.iconKey,
        area.colorHex,
        area.isDefault,
        area.sortOrder,
      ],
    );
  }

  const defaultTitles =
      <
        ({
          String id,
          String name,
          String description,
          String kind,
          String ruleKey,
          int threshold,
        })
      >[
        (
          id: DefaultSeedV1.homeCentinelTitleId,
          name: 'Centinela del hogar',
          description: 'Completa 100 misiones del área Hogar.',
          kind: 'PERMANENT',
          ruleKey: 'missions.completed.area.hogar',
          threshold: 100,
        ),
        (
          id: DefaultSeedV1.dailyStreakTitleId,
          name: 'Ritmo constante',
          description: 'Completa al menos una misión durante 7 días seguidos.',
          kind: 'DYNAMIC',
          ruleKey: 'missions.completed.daily_streak',
          threshold: 7,
        ),
      ];

  for (final title in defaultTitles) {
    await database.customStatement(
      '''
        INSERT OR IGNORE INTO title_definitions (
          id,
          name,
          description,
          title_kind,
          rule_key,
          threshold,
          is_active
        ) VALUES (?, ?, ?, ?, ?, ?, 1)
      ''',
      <Object?>[
        title.id,
        title.name,
        title.description,
        title.kind,
        title.ruleKey,
        title.threshold,
      ],
    );
  }

  await database.customStatement(
    '''
      INSERT OR IGNORE INTO app_settings (
        id,
        theme_key,
        primary_color,
        large_text,
        reduce_motion,
        high_contrast,
        hide_amounts,
        mission_notifications,
        daily_summary,
        sound_enabled,
        auto_lock_minutes,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    <Object?>[
      1,
      'terminal_reinforced',
      '#FF3B3B',
      0,
      0,
      0,
      0,
      1,
      1,
      1,
      5,
      nowUtcMs,
    ],
  );

  await database.customStatement(
    '''
      INSERT INTO schema_metadata ("key", value, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT("key") DO UPDATE SET
        value = excluded.value,
        updated_at = excluded.updated_at
      WHERE schema_metadata.value <> excluded.value
    ''',
    <Object?>['schema_version', '1', nowUtcMs],
  );

  await database.customStatement(
    '''
      INSERT INTO schema_metadata ("key", value, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT("key") DO UPDATE SET
        value = excluded.value,
        updated_at = excluded.updated_at
      WHERE schema_metadata.value <> excluded.value
    ''',
    <Object?>['seed_version', '1', nowUtcMs],
  );

  await database.customStatement(
    '''
      INSERT OR IGNORE INTO schema_metadata ("key", value, updated_at)
      VALUES (?, ?, ?)
    ''',
    <Object?>['created_with', '0.1.0+1', nowUtcMs],
  );
}
