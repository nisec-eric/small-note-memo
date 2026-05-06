# AGENTS.md — Project Knowledge Base

## Project Overview

Check In Memo — A cross-platform habit tracking / check-in app built with Flutter.
Primary targets: Android (ARM64) and Web.

## Tech Stack

- **Flutter 3.38** / **Dart 3.10**
- **Riverpod** for state management (AsyncNotifier pattern)
- **Hive** for local storage (Map-based serialization, no code generation)
- **fl_chart** for charts (BarChart API: `tooltipRoundedRadius`, `SideTitleWidget(axisSide:)`)
- **intl** for Chinese date formatting (requires `initializeDateFormatting('zh_CN')` in main)

## Architecture

```
main.dart → app.dart (MaterialApp3 + bottom nav)
                ├── HomePage (today's tasks)
                ├── StatsPage (charts/streaks)
                └── SettingsPage (task CRUD)

Data flow: UI → Riverpod Providers → StorageService → Hive
```

## Key Patterns

- Models use `toMap()` / `fromMap()` serialization (no Hive TypeAdapters)
- Models override `==` / `hashCode` by `id` field for correct Set/Map behavior
- `CheckInTask.copyWith()` uses sentinel pattern for nullable fields (can set back to null)
- Provider invalidation: `ref.invalidateSelf()` after mutations, cross-invalidate `todayRecordsProvider` on task deletion
- Theme: primary `#FF6B6B`, accent `#4ECDC4`, Material 3 with dark mode support

## Platform Notes

- Only **Android** and **Web** platforms are configured (ios/macos removed)
- Android SDK 36 + Build-Tools 36 required by Flutter 3.38
- Gradle needs proxy config in `~/.gradle/gradle.properties` for CN networks
- Web build: `flutter build web --release` → serve with any static server

## File Ownership

| Directory | Purpose |
|---|---|
| `lib/models/` | Data models (task, record) |
| `lib/services/` | Storage layer (Hive CRUD + stats) |
| `lib/providers/` | Riverpod state management |
| `lib/pages/` | 3 tab pages (home, stats, settings) |
| `lib/widgets/` | Reusable UI components (task_card, charts, heatmap) |
| `lib/app.dart` | Theme + navigation shell |
| `lib/main.dart` | Entry point (Hive + intl init) |

## Known Limitations

- `DateTime.now()` in providers won't auto-refresh at midnight
- Storage does O(n) full-table scans on each query (fine for <1000 records)
- No data export/import yet
- No push notification reminders yet
