import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:isolate';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:mydatatools/app_constants.dart';
import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/repositories/database_repository.dart';
import 'package:mydatatools/repositories/db_isolate_writer.dart';
import 'package:mydatatools/scanners/scanner_manager.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mydatatools/main.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:mydatatools/models/tables/album.dart';
import 'package:mydatatools/models/tables/app.dart';
import 'package:mydatatools/models/tables/app_user.dart';
import 'package:mydatatools/models/tables/collection.dart';
import 'package:mydatatools/models/tables/converters/string_array_convertor.dart';
import 'package:mydatatools/models/tables/email.dart';
import 'package:mydatatools/models/tables/file.dart';
import 'package:mydatatools/models/tables/folder.dart';
import 'package:uuid/uuid.dart';

part 'database_manager.g.dart';

class DatabaseManager {
  static final DatabaseManager _singleton = DatabaseManager._();

  /// Singleton instance of [DatabaseManager]
  static DatabaseManager get instance => _singleton;

  /// Notifies listeners when the database initialization is complete
  static ValueNotifier<bool> isInitializedNotifier = ValueNotifier(false);

  /// Flag to determine if an in-memory database should be used (for testing)
  bool useMemoryDb = false;
  AppDatabase? appDatabase;
  DbIsolateWriterClient? _writerIsolateClient;
  SendPort? _writerPort;
  DatabaseRepository? _repository;

  DatabaseManager._();

  /// Returns the [DatabaseRepository] instance
  DatabaseRepository? get repository {
    return _repository;
  }

  /// Returns the [AppDatabase] instance
  AppDatabase? get database {
    return appDatabase;
  }

  Future<String> _getConfigPath() async {
    var supportPath = await getApplicationSupportDirectory();
    MainApp.supportDirectory.add(supportPath);

    // Look for config file with user selected path for DB and Files
    io.File file = io.File(
      p.join(supportPath.path, AppConstants.configFileName),
    );
    return file.absolute.path;
  }

  /// Checks if the database configuration file exists
  Future<bool> isDatabaseConfigured() async {
    // Look for config file with user selected path for DB and Files
    io.File file = io.File(await _getConfigPath());
    return file.existsSync();
  }

  /// Initializes the database, repository, writer isolate, and scanners
  Future<AppDatabase> initializeDatabase() async {
    io.File file = io.File(await _getConfigPath());
    var config = jsonDecode(file.readAsStringSync());
    String path = config['path'];

    // start database
    appDatabase = await _openDatabase(path);

    // start database repository
    _repository = DatabaseRepository(appDatabase!);

    // start writer isolate
    await _startWriterIsolate(appDatabase!, path);

    // start scanners
    await _startScanners();

    isInitializedNotifier.value = true;
    return appDatabase!;
  }

  Future<AppDatabase> _openDatabase(String storagePath) async {
    try {
      if (this.database != null) {
        return this.database!;
      }

      //make sure root dir exists
      io.Directory(storagePath).createSync(recursive: true);
      //make sure data, files, and keys sub dirs have been created
      var dbDir = io.Directory(p.join(storagePath, 'data'));
      io.Directory(dbDir.path).createSync(recursive: true);
      var keyDir = io.Directory(p.join(storagePath, 'keys'));
      io.Directory(keyDir.path).createSync(recursive: true);
      var fileDir = io.Directory(p.join(storagePath, 'files'));
      io.Directory(fileDir.path).createSync(recursive: true);

      //on app startup, start db.
      AppDatabase database = AppDatabase(
        null,
        storagePath,
        AppConstants.dbName,
        useMemoryDb,
      );
      print("DB Started | schema version=${database.schemaVersion}");

      return database;
    } catch (err) {
      //unknown error
      print(err);
      throw Exception(err);
    }
  }

  Future<void> _startWriterIsolate(
    AppDatabase database,
    String storagePath,
  ) async {
    _writerIsolateClient = DbIsolateWriterClient();
    await _writerIsolateClient!.start(
      storagePath,
      AppConstants.dbName,
      useMemoryDb: false,
    );
    _writerPort = _writerIsolateClient!.getSendPort();
  }

  /// Returns the [SendPort] for the writer isolate
  Future<SendPort> get writerPort async {
    if (_writerPort == null) {
      throw Exception(
        "Unkown error initializing Database and/or writer isolate",
      );
    }
    return Future(() => _writerPort!);
  }

  /// Stop helper to be called from app shell
  /// Stops the database writer isolate
  Future<void> stopDbWriterIsolate() async {
    try {
      if (_writerIsolateClient != null) {
        await _writerIsolateClient!.stop();
        _writerIsolateClient = null;
      }
    } catch (_) {}
  }

  Future<void> _startScanners() async {
    ScannerManager.getInstance().startScanners(appDatabase!);
  }

  /// Backups the database to the specified path using VACUUM INTO.
  /// This creates a transactionally consistent copy of the database.
  Future<void> backupDatabase(String path) async {
    /*
      Restoration Steps
      You will see three files in your application data folder:

      1. app.db (The main data)
      2. app.db-wal (The Write-Ahead Log)
      3. app.db-shm (Shared Memory file)
      To restore backup_2025-01-01.db:

      1. Close the Application (or fully close the database connection). Never replace the file while the app is running.
      2.Delete all three live files: app.db, app.db-wal, and app.db-shm.
        Why? If you replace app.db but leave an old app.db-wal sitting there, SQLite might see the WAL file, think "Oh, I have unsaved changes in this log," and try to "replay" them into your restored backup. This will corrupt your database instantly because the log doesn't match the file anymore.
      3. Copy backup_2025.db to app.db.
      4. Restart the Application.
      
      SQLite will see a fresh db with no WAL file, and it will cleanly create new ones.
    */
    if (appDatabase == null) {
      throw Exception("Database not initialized");
    }
    await appDatabase!.backup(path);
  }

  /// Creates a daily backup in the 'backups' subdirectory of the data location.
  /// It is safe to call this on every startup; it will only perform the backup
  /// if one has not already been created for the current day.
  Future<void> createDailyBackup() async {
    // Determine backup directory
    String configPath = await _getConfigPath();
    // configPath points to the config file (e.g. .../config.json).
    // We want the directory containing the actual data, which we read from the config.
    io.File file = io.File(configPath);
    var config = jsonDecode(file.readAsStringSync());
    String dbRootPath = config['path'];

    // Backup folder: <dbRootPath>/backups
    final backupDir = io.Directory(p.join(dbRootPath, 'backups'));
    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }

    // Filename: backup_YYYY-MM-DD.db
    final now = DateTime.now();
    final dateString = now.toIso8601DateString();
    final backupFileName = 'backup_$dateString.db';
    final backupFile = io.File(p.join(backupDir.path, backupFileName));

    if (!backupFile.existsSync()) {
      print("Creating daily backup: ${backupFile.path}");
      await backupDatabase(backupFile.path);
    } else {
      print("Daily backup already exists: ${backupFile.path}");
    }

    // Cleanup old backups (keep last 7)
    await _cleanupOldBackups(backupDir);
  }

  /// Removes old backups, keeping only the 7 most recent ones.
  Future<void> _cleanupOldBackups(io.Directory backupDir) async {
    try {
      final List<io.FileSystemEntity> files = backupDir.listSync();
      final List<io.File> backups =
          files
              .whereType<io.File>()
              .where(
                (file) =>
                    p.basename(file.path).startsWith('backup_') &&
                    p.basename(file.path).endsWith('.db'),
              )
              .toList();

      if (backups.length <= 7) {
        return;
      }

      // Sort by modification time (descending), so newest is first
      // Alternatively, we can rely on filename sorting since it is ISO8601 YYYY-MM-DD
      backups.sort((a, b) {
        return b.path.compareTo(
          a.path,
        ); // Lexicographical sort on path (filename date)
      });

      // Keep first 7, delete the rest
      final backupsToDelete = backups.sublist(7);
      for (final file in backupsToDelete) {
        print("Deleting old backup: ${file.path}");
        await file.delete();
      }
    } catch (e) {
      print("Error cleaning up old backups: $e");
    }
  }

  /// Send a message to the isolate and await a response.
  Future<dynamic> send(Map<String, dynamic> message) async {
    if (_writerPort == null) {
      throw Exception(
        "DbIsolateWriterClient not started or writer port not available",
      );
    }

    final ReceivePort responsePort = ReceivePort();
    try {
      message['replyTo'] = responsePort.sendPort;
      //send object to writer isolate
      _writerPort!.send(message);
      final response = await responsePort.first;

      if (response is Map && response.containsKey('error')) {
        throw Exception(response['error']);
      }
      return response;
    } finally {
      responsePort.close();
    }
  }
}

@DriftDatabase(
  tables: [Apps, AppUsers, Collections, Emails, Files, Folders, Albums],
)
class AppDatabase extends _$AppDatabase {
  final AppLogger logger = AppLogger(null);

  AppDatabase([
    QueryExecutor? executor,
    String? path,
    String? name,
    bool useMemoryDb = false,
  ]) : super(executor ?? _openConnection(path, name, useMemoryDb));

  String? path;
  String? name;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        print("Creating all Tables");
        await m.createAll();
        print("Load initial data");
        await _loadInitialData(m);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          print("Upgrade to v2");
        }
        if (from < 3) {
          print("Upgrade tables to v3");
        }
        //continue
      },
    );
  }

  /// Make sure each app is in database
  Future<int> _loadInitialData(Migrator m) async {
    try {
      int appsAdded = 0;
      //Load initial data
      TableInfo<Table, dynamic>? appsTable = m.database.allTables
          .firstWhereOrNull((e) => e.actualTableName == 'apps');
      //List<dynamic> apps = await m.database.select(appsTable!).get();
      //apps
      await m.database
          .into(appsTable!)
          .insertOnConflictUpdate(
            App(
              id: const Uuid().v4().toString(),
              name: "Files",
              slug: 'files',
              group: "collections",
              order: 10,
              icon: 0xe2a3,
              route: "/files",
            ),
          );
      appsAdded++;

      await m.database
          .into(appsTable)
          .insertOnConflictUpdate(
            App(
              id: const Uuid().v4().toString(),
              name: "Email",
              slug: 'email',
              group: "collections",
              order: 30,
              icon: 0xf705,
              route: "/email",
            ),
          );
      appsAdded++;

      await m.database
          .into(appsTable)
          .insertOnConflictUpdate(
            App(
              id: const Uuid().v4().toString(),
              name: "Social Networks",
              slug: 'social',
              group: "collections",
              order: 50,
              icon: 0xe486,
              route: "/social",
            ),
          );
      appsAdded++;

      await m.database
          .into(appsTable)
          .insertOnConflictUpdate(
            App(
              id: const Uuid().v4().toString(),
              name: "Photos",
              slug: 'photos',
              group: "app",
              order: 20,
              icon: 0xf80d,
              route: "/photos",
            ),
          );
      appsAdded++;

      await m.database
          .into(appsTable)
          .insertOnConflictUpdate(
            App(
              id: const Uuid().v4().toString(),
              name: "AI Chat",
              slug: 'aichat',
              group: "app",
              order: 15,
              icon: 0xe0b7,
              route: "/aichat",
            ),
          );
      appsAdded++;

      return Future(() => appsAdded);
    } catch (err) {
      logger.e(err);
      rethrow;
    }
  }

  /// Creates a backup of the database at the specified [path].
  /// Uses SQLite `VACUUM INTO` to create a safe, consistent backup
  /// even while the database is being written to (in WAL mode).
  Future<void> backup(String path) async {
    // VACUUM INTO fails if the target file already exists
    final file = io.File(path);
    if (file.existsSync()) {
      await file.delete();
    }
    await customStatement('VACUUM INTO ?', [path]);
  }
}

extension DateTimeFormat on DateTime {
  String toIso8601DateString() {
    return toIso8601String().split('T')[0];
  }
}

LazyDatabase _openConnection(String? path, String? name, bool useMemoryDb) {
  if (path == null || name == null) {
    throw ("Path or Name not provided, can not start scanner");
  }
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    print('Initialize Database | path=$path');
    //check app startup initialization
    io.File file = io.File(p.join(path!, 'data', name));
    path = file.path;

    // Make sqlite3 pick a more suitable location for temporary files - the
    // one from the system may be inaccessible due to ios/mac app sandbox.
    // We can't access /tmp on Android, which sqlite3 would try by default.
    // Explicitly tell it about the correct temporary directory.
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    print("Opening Database | $path");
    if (!useMemoryDb) {
      return NativeDatabase(
        file,
        logStatements: true,
        cachePreparedStatements: true,
        setup: (database) {
          database.execute('PRAGMA journal_mode=WAL;');
          database.execute('PRAGMA busy_timeout=5000;');
          database.execute('PRAGMA synchronous = NORMAL;');
          database.execute('PRAGMA cache_size = -20000;'); // ~20MB
          database.execute('PRAGMA foreign_keys = ON;');
          database.execute('PRAGMA temp_store = MEMORY;');
          database.execute('PRAGMA mmap_size = 30000000000;');
        },
      );
      //return NativeDatabase.createInBackground(file, logStatements: true, cachePreparedStatements: true, setup: null);
    } else {
      return NativeDatabase.memory(
        logStatements: true,
        setup: null,
        cachePreparedStatements: false,
      );
    }
  });
}
