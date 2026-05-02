# production_app

Operonix Production (MES). **Zastoji** (`downtime_events`): mutacije preko `mutateDowntimeEvent`. **Nalozi** (`production_orders`, `production_order_snapshots`, `production_order_audit_logs`) i transakcije s `production_execution` (`mesExecutionStart`, `mesExecutionComplete`, `mutateProductionOrder`) — `europe-west1`. Build **≥ 1.0.1+6** ako su na produkciji Faza 3a pravila za `production_execution` (client create/update isključen; `mesExecutionUpdate` za save/pause/resume). **≥ 1.0.1+3** za Fazu 2B (`production_orders` / snapshot / audit). Stariji build **≥ 1.0.1+2** za `downtime_events` s istim obrascem.

## Modul Razvoj / NPI / Projekti

Kanonska arhitektura (MVP redoslijed, RBAC, shema `development_projects`, pravila za AI/Gate/Release): **`maintenance_app/docs/architecture/DEVELOPMENT_MODULE_ARCHITECTURE.md`**. Kod modula: **`lib/modules/development/`**. SaaS ključ u `enabledModules`: **`development`** (`ProductionModuleKeys.development`).

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
