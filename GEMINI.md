# GEMINI.MD: AI Collaboration Guide

This document provides essential context for AI models interacting with this project. Adhering to these guidelines will ensure consistency and maintain code quality.

## 1. Project Overview & Purpose

* **Primary Goal:** To provide a personal data manager, organizer, and backup tool. The application allows users to keep a local copy of their online data (cloud drives, emails, social media) and interact with it using local AI models.
* **Business Domain:** Personal Data Management, Digital Archiving, and Local AI.

## 2. Core Technologies & Stack

* **Languages:**
    *   Dart (Flutter SDK ^3.7.0)
    *   Python 3.11 (Local AI Service)
* **Frameworks & Runtimes:**
    *   **Frontend:** Flutter (Desktop - macOS, Windows, Linux)
    *   **Backend (Local):** FastAPI (Python), Uvicorn
    *   **AI/ML:** LangChain, Transformers, Google GenAI, HuggingFace Hub, PyTorch
* **Databases:**
    *   SQLite (via `drift` and `sqlite3` packages in Flutter)
* **Key Libraries/Dependencies:**
    *   **Flutter:** `go_router`, `flutter_secure_storage`, `drift`, `googleapis`, `flutter_login`, `reactive_forms`.
    *   **Python:** `pydantic`, `fastapi`, `langchain-core`, `transformers`, `sentencepiece`, `Pillow`.
* **Package Manager(s):**
    *   `flutter pub` (Dart)
    *   `pip` / `pdm` (Python)

## 3. Architectural Patterns

* **Overall Architecture:** **Hybrid Desktop Application (Sidecar Pattern)**.
    *   The frontend is a Flutter Desktop application responsible for UI, local database management, and user interaction.
    *   A local Python server (`aichat`) is bundled with the application and runs as a background process (sidecar) to handle heavy AI/ML tasks, model inference, and embeddings.
    *   Cloud services (Google Cloud Run) are used for auxiliary tasks like serving model downloads.
* **Directory Structure Philosophy:**
    *   `/client`: Contains the main Flutter application code.
        *   `/client/lib`: Dart source code.
        *   `/client/assets/python/aichat`: Source code for the local Python AI service.
    *   `/services`: Contains backend microservices (e.g., `download-models` for GCS).
    *   `/.github/workflows`: CI/CD pipelines for building and releasing the application.

## 4. Coding Conventions & Style Guide

* **Formatting:**
    *   **Dart:** Follows standard Dart formatting (`dart format`). Linter rules are defined in `client/analysis_options.yaml` (extends `package:flutter_lints/flutter.yaml`).
    *   **Python:** Follows PEP 8 and Python best practices. The Python codebase is modularized into `routes`, `models`, `services`, etc.
* **Naming Conventions:**
    *   **Dart:** `camelCase` for variables/functions, `PascalCase` for classes/widgets, `snake_case` for file names.
    *   **Python:** `snake_case` for variables/functions/modules, `PascalCase` for classes.
* **API Design:**
    *   The local Python service exposes a RESTful API (FastAPI).
    *   Endpoints use standard HTTP verbs.
    *   Request/Response bodies are JSON, validated by Pydantic models.
* **Error Handling:**
    *   **Dart:** Uses `try...catch` blocks. `Logger` package is used for logging (`Logger().e(...)`).
    *   **Python:** Exception handling within route handlers, returning appropriate HTTP error codes.

## 5. Key Files & Entrypoints

* **Main Entrypoint(s):**
    *   **Flutter:** `client/lib/main.dart` (`main()` function initializes `windowManager`, database, and starts the Python service).
    *   **Python Service:** `client/assets/python/aichat/main.py` (launches `src.aichat.main:main`).
* **Configuration:**
    *   **Flutter:** `client/pubspec.yaml` (dependencies), `client/analysis_options.yaml` (linting).
    *   **Python:** `client/assets/python/aichat/pyproject.toml` (dependencies), `client/assets/python/aichat/config.py` (app config).
    *   **Build:** `Makefile` (root) for build automation and deployment commands.
* **CI/CD Pipeline:**
    *   `.github/workflows/commit_actions.yaml`: Main workflow for building, signing (macOS), and releasing the desktop app.
    *   `.github/workflows/build_python.yml`: Workflow specifically for building the Python executable.

## 6. Development & Testing Workflow

* **Local Development Environment:**
    *   **Flutter:** Run via `flutter run -d macos` (or windows/linux).
    *   **Python:** Can be run independently for testing via `python main.py` or `uvicorn main:app --reload` within `client/assets/python/aichat`.
    *   **Dependencies:** Install Dart deps with `flutter pub get`. Install Python deps with `pip install -r requirements.txt`.
* **Testing:**
    *   **Dart:** Run unit/widget tests via `flutter test`.
    *   **Python:** Run tests via `pytest` or `./run_tests.sh` in the `aichat` directory. The Python project has high test coverage requirements.
* **CI/CD Process:**
    *   On push to `main` or `develop`:
        1.  Python executable is built using PyInstaller.
        2.  Models are downloaded.
        3.  Flutter app is built and bundled with the Python executable and models.
        4.  (macOS) Application is code-signed and notarized.
        5.  Artifacts are uploaded/released.

## 7. Specific Instructions for AI Collaboration

* **Contribution Guidelines:**
    *   Follow the existing modular structure in Python (separate routes, models, services).
    *   Ensure new Python dependencies are added to both `requirements.txt` and `pyproject.toml`.
    *   When modifying the Python service, ensure the `main.spec` (PyInstaller config) is updated if new hidden imports are introduced.
* **Infrastructure (IaC):**
    *   The `services/download-models` directory contains Cloud Run deployment config (`cloudbuild.yaml`). Use the `Makefile` in the root to deploy: `make deploy-download-service`.
* **Security:**
    *   Use `flutter_secure_storage` for storing sensitive user data (tokens, passwords).
    *   Do not commit secrets. The CI/CD pipeline uses GitHub Secrets for signing keys and certificates.
* **Dependencies:**
    *   **Dart:** Add via `flutter pub add [package]`.
    *   **Python:** Add via `pip install [package]` AND update `requirements.txt` / `pyproject.toml`.
* **Commit Messages:**
    *   The project appears to follow standard commit practices. Ensure messages are descriptive.
