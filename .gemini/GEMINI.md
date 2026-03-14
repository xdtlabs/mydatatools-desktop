# MyDataTools Desktop - Development Guidelines (AI Context)

This file provides critical context for AI assistants to maintain the architectural integrity and development standards of the MyDataTools Desktop project.

## 1. Project Goal
"Share It - Save It" (Smart Bucket): A desktop application that acts as a central hub for saved content from various sources, using Multimodal AI (Gemini) for analysis and organization.

---

## 2. Architectural Patterns

### Single-Writer Isolate Pattern (CRITICAL)
- **Database**: Drift (SQLite).
- **Writes**: ALL write operations (inserts, updates, deletes) MUST be dispatched to the `DbIsolateWriter` via its `writerPort`.
- **Reads**: Perform reads on the main thread via `AppDatabase` or `DatabaseRepository`.
- **Reason**: Prevents database locking on the UI thread and ensures thread safety during heavy data ingestion (scanning).

### Modular MVVM
- Feature code belongs in `lib/modules/[feature_name]`.
- Keep business logic in `services/` and UI in `pages/` or `widgets/`.
- Avoid leaking module-specific logic into the global `lib/` directory.

---

## 3. Directory Structure & Conventions

### `lib/modules/`
- **aichat**: Local and remote LLM interactions.
- **files**: Local filesystem management and scanning.
- **photos**: Image-specific workflows.
- **email**: Integration with email providers.

### `lib/scanners/`
- New scanners should implement the `CollectionScanner` interface.
- Heavy scanning logic (filesystem traversal, network requests) MUST be offloaded to a background `Isolate`.

### `lib/repositories/`
- Centralized data access. Use these as abstraction layers over the database.

---

## 4. Development Rules
- **Testing**: Always write unit tests for core services and repository logic.
- **Logging**: Use `AppLogger` for all application logging.
- **State Management**: Usually we can pass properties down the widget tree and Events back up.  When we need global state, use `Provider` as appropriate for the module.
- **Python Services**: Managed via `PythonManager`. Native bundling logic is sensitive; coordinate with `Makefile` for build-time dependencies.

