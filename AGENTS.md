# PROJECT KNOWLEDGE BASE

**Updated:** 2026-05-08
**Commit:** (pending)
**Branch:** main

## OVERVIEW

Check In Memo — Cross-platform habit check-in app. Flutter 3.38 + Dart 3.10.
Targets: Android ARM64 + Web. No iOS/macOS.

## STRUCTURE

```
lib/
├── main.dart              # Entry: Hive + intl init
├── app.dart               # MaterialApp3 theme + bottom nav shell
├── models/                # toMap/fromMap serialization, no Hive TypeAdapters
├── services/              # Hive CRUD + stats (O(n) scans, fine <1k records)
├── providers/             # Riverpod AsyncNotifier pattern
├── pages/                 # 3 tabs: home, stats, settings
└── widgets/               # TaskCard (animated), HeatmapCalendar (with daily counts)
```

## WHERE TO LOOK

| Task | File | Key Symbol |
|------|------|------------|
| Add a new data field | `lib/models/task.dart` | `CheckInTask.toMap()` / `fromMap()` |
| Add a storage query | `lib/services/storage_service.dart` | `StorageService` |
| Add a new provider | `lib/providers/app_providers.dart` | Follow existing `*Provider` pattern |
| Change theme colors | `lib/app.dart` | `_buildTheme()` in `CheckInApp` |
| Add a new tab page | `lib/app.dart` → `_pages` list | `_AppShellState` |
| Modify task card UI | `lib/widgets/task_card.dart` | `TaskCard` + `_CheckInButton` |
| Change heatmap colors | `lib/widgets/heatmap_calendar.dart` | `_cellColor()` |
| Add task form field | `lib/pages/settings_page.dart` | `_TaskFormState._save()` + form widgets |
| Export/import options | `lib/pages/settings_page.dart` | `_ExportDialog`, `_ImportDialog` |
| Cycle period config | `lib/pages/settings_page.dart` | `_TaskFormState — cycleDays/cycleTarget steppers |

## CODE MAP

| Symbol | Type | File | Role |
|--------|------|------|------|
| `CheckInTask` | model | `models/task.dart` | Task config with `cycleDays`, `cycleTarget`, `cycleStartDate`; `cyclePeriod()`, `currentCycleIndex`; `copyWith` with sentinel pattern |
| `CheckInRecord` | model | `models/record.dart` | Check-in event, nullable `taskId`/`topic`/`note`, `date` getter normalizes to midnight |
| `StorageService` | service | `services/storage_service.dart` | All Hive CRUD, streak/stats calculations, cycle/daily history, one-time check-in CRUD, topic aggregation, `deleteRecord`, `exportData({includeRecords})`, `importData(json, {includeRecords})` |
| `tasksProvider` | AsyncNotifier | `providers/app_providers.dart` | Task CRUD, cross-invalidates `todayRecordsProvider` |
| `todayRecordsProvider` | AsyncNotifier | `providers/app_providers.dart` | Today's records, check-in/undo/delete operations with cascade invalidation |
| `todayTasksProvider` | derived Provider | `providers/app_providers.dart` | Filters tasks by `shouldCheckIn(DateTime.now())` |
| `streakProvider` | FutureProvider.family | `providers/app_providers.dart` | Per-task streak count |
| `CheckInApp` | widget | `app.dart` | Theme builder (coral `#FF6B6B` + teal `#4ECDC4`) |
| `_AppShell` | widget | `app.dart` | Bottom nav with `AnimatedSwitcher` |
| `TaskCard` | widget | `widgets/task_card.dart` | Card + animated check-in button |
| `HeatmapCalendar` | widget | `widgets/heatmap_calendar.dart` | Monthly grid with navigation, `onDayTap` callback, today highlight |
| `cycleProgressProvider` | FutureProvider.family | `providers/app_providers.dart` | Returns (completed, remaining, periodStart, periodEnd) for current cycle |
| `cycleHistoryProvider` | FutureProvider.family | `providers/app_providers.dart` | Per-task cycle history list |
| `dailyHistoryProvider` | FutureProvider.family | `providers/app_providers.dart` | Per-task daily check-in date list |
| `oneTimeRecordsProvider` | FutureProvider | `providers/app_providers.dart` | All one-time check-in records |
| `pastTopicsProvider` | FutureProvider | `providers/app_providers.dart` | Distinct past topics for autocomplete |
| `topicsAggregatedProvider` | FutureProvider | `providers/app_providers.dart` | Topics grouped with count and latest date |
| `taskRecordsProvider` | FutureProvider.family | `providers/app_providers.dart` | All records for a task (with ID, for delete operations) |
| `_TaskForm` | widget | `pages/settings_page.dart` | Bottom sheet: name, emoji, weekday, time picker, cycleDays/cycleTarget steppers, cycleStartDate auto-set |

## CONVENTIONS

- **Map-based Hive serialization** — `toMap()` / `fromMap()` on models, no code generation, no TypeAdapters
- **Equality by `id`** — Both models override `==` / `hashCode` using `id` field
- **Sentinel `copyWith`** — `CheckInTask.copyWith()` uses `Object? _sentinel` to allow clearing nullable fields (`startMinutes`, `endMinutes`, `reminderMinutes`) back to null. Pass explicitly: `task.copyWith(startMinutes: null)` clears it; omit param keeps old value
- **Defensive list copy** — `_selectedDays.toList()` when passing mutable lists from UI to storage
- **Provider self-invalidation** — `ref.invalidateSelf()` after all mutations; cross-invalidate `todayRecordsProvider` when tasks are deleted
- **Theme-derived colors** — Read `Theme.of(context).colorScheme.primary` in widgets, don't hardcode hex values
- **fl_chart 0.69.x API** — `tooltipRoundedRadius` (not `tooltipBorderRadius`), `SideTitleWidget(axisSide: meta.axisSide, child:)` (not `meta:`)
- **Fixed cycle periods** — Cycles use `cycleStartDate` as anchor, periods are `[start + N*cycleDays, start + (N+1)*cycleDays - 1]`, NOT rolling windows
- **Backward-compatible defaults** — `cycleDays`/`cycleTarget` default to 1, `cycleStartDate` falls back to `createdAt` when missing from stored data
- **One-time check-ins** — `CheckInRecord` with `taskId == null` and `topic != null`; regular records have `taskId != null` and `topic == null`

## ANTI-PATTERNS (DO NOT)

- **DO NOT** add `hive_generator` / `build_runner` — incompatible with Dart 3.10
- **DO NOT** use `as any`, `@ts-ignore` equivalents — suppress no type errors in Dart
- **DO NOT** hardcode weekday labels in charts — use `DateTime.weekday` dynamically (was a bug, fixed)
- **DO NOT** use `Colors.grey[200]!` — use `Colors.grey.shade200` instead
- **DO NOT** use `??` for nullable fields in `copyWith` — use the sentinel pattern
- **DO NOT** add ios/ or macos/ platforms — intentionally removed, web + android only
- **DO NOT** use rolling window for cycle calculation — use `task.cyclePeriod(index)` for fixed boundaries

## PLATFORM GOTCHAS

- Android SDK **36** required (Flutter 3.38 enforces this, not 34)
- Gradle needs proxy in `~/.gradle/gradle.properties` (`systemProp.https.proxyHost/Port`)
- First Gradle build auto-installs NDK 28, Build-Tools 35, Platform 35, CMake (~3.5 GB extra)
- `Hive.initFlutter()` works on both web (IndexedDB) and Android (file system)
- `intl` Chinese locale requires `await initializeDateFormatting('zh_CN')` in `main()` before any `DateFormat` call
- Web: `flutter build web --release` produces static files, serve with any HTTP server

## COMMANDS

```bash
flutter pub get                    # Install dependencies
flutter analyze                    # Lint (0 issues expected)
flutter build web --release        # Web build → build/web/
flutter build apk --release --target-platform android-arm64  # ARM64 APK → build/app/outputs/flutter-apk/
npx serve build/web -l 8080        # Quick web preview
adb install build/app/outputs/flutter-apk/app-release.apk    # Install to device
```

## KNOWN LIMITATIONS

- `DateTime.now()` captured in provider `build()` — stale after midnight, no auto-refresh
- Storage O(n) full scans — acceptable for <1000 records
- Export/import uses JSON format with version stamp; old data auto-migrates with safe defaults
- No push notification reminders
- `CardThemeData` (not `CardTheme`) required in Flutter 3.38
