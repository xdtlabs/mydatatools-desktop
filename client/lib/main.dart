import 'dart:io';
import 'dart:ui';

import 'package:mydatatools/app_constants.dart';
import 'package:mydatatools/app_router.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/family_dam_app.dart';
import 'package:mydatatools/pages/splash.dart';
import 'package:mydatatools/python_manager.dart';

import 'package:mydatatools/repositories/watchers/database_change_watcher.dart';
import 'package:mydatatools/scanners/scanner_manager.dart';
import 'package:mydatatools/services/get_user_service.dart';
import 'package:mydatatools/widgets/auth_dialog_manager.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:password_dart/password_dart.dart';
import 'package:window_manager/window_manager.dart';

/// The main() function is the starting point of the application. It first ensures that the Flutter binding is initialized.
/// Then, it checks if the platform is Windows, Linux or macOS. If it is, it gets the current screen and sets the window title, minimum size and maximum size.
/// Finally, it runs the FamilyDamApp widget wrapped in a ProviderScope using the runApp function.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
  await windowManager.ensureInitialized();
  //set log level
  Logger.level = Level.debug;

  // Start desktop client
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  // Moved static subjects/keys here so they can be referenced as MainApp.xxx
  // Default system directory for app config
  static final BehaviorSubject<Directory?> supportDirectory =
      BehaviorSubject<Directory?>();
  // User selected directory to store files and metadata db.
  static final BehaviorSubject<String?> appDataDirectory =
      BehaviorSubject<String?>();
  // Flutter key for router
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  // Url for local LLM service
  static final BehaviorSubject<String?> llmServiceUrl =
      BehaviorSubject<String?>();

  //Database repository
  static DatabaseManager? databaseManager;
  //Manage DB watchers
  static DatabaseChangeWatcher? collectionWatcher;
  // Manage all module scanners
  static ScannerManager? scannerManager;

  @override
  MainAppState createState() => MainAppState();
}

// In your top-level app widget (MainApp State) call stop when the app is disposed:
class MainAppState extends State<MainApp> with WidgetsBindingObserver {
  bool _needsSetup = false;
  bool _isSetupComplete = false;
  PythonManager? pythonManager;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize a global dialog manager
    _initDialogManager();

    // Initialize the Database and Python Server
    _initStartup();

    _lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        // This callback is invoked when the application is requested to exit.
        // You can perform cleanup or prompt the user for confirmation here.
        // Return AppExitResponse.exit to allow exit, or AppExitResponse.cancel to prevent it.
        print('Exit requested!');
        pythonManager?.stopAiChatService();
        return AppExitResponse.exit;
      },
      onStateChange: (AppLifecycleState state) {
        // This callback is invoked for all lifecycle state changes.
        // print('AppLifecycleState changed: $state');
        switch (state) {
          case AppLifecycleState.detached:
            // Application is detached from any host view. This typically means the app is closed.
            break;
          case AppLifecycleState.inactive:
            // Application is in an inactive state (e.g., system dialog open, app losing focus).
            break;
          case AppLifecycleState.paused:
            // Application is in the background.
            break;
          case AppLifecycleState.resumed:
            // Application is in the foreground and active.
            break;
          case AppLifecycleState.hidden:
            // Application is hidden (e.g., minimized on desktop).
            break;
        }
      },
      // You can also provide specific callbacks for individual state transitions:
      // onResume: () => print('Resumed'),
      // onInactive: () => print('Inactive'),
      // onPaused: () => print('Paused'),
      // onDetached: () => print('Detached'),
      // onHide: () => print('Hidden'),
    );
  }

  Future<void> _initStartup() async {
    if (!await DatabaseManager.instance.isDatabaseConfigured()) {
      setState(() {
        _needsSetup = true;
      });
    } else {
      // 1. Initialize local Database
      var dbFuture = DatabaseManager.instance.initializeDatabase();

      // 2. Initialize Python Manager
      final pythonFuture =
          (() async {
            final pythonMgr = await PythonManager.forAppSupport();
            await pythonMgr.startAiChatService();
            return pythonMgr;
          })();

      // Wait for both to finish
      await Future.wait([pythonFuture, dbFuture]);

      // set database repository
      MainApp.databaseManager = DatabaseManager.instance;

      // Attempt daily backup
      // We run this without awaiting so it doesn't block UI startup if it takes a few seconds
      DatabaseManager.instance.createDailyBackup().catchError((e) {
        Logger().e("Failed to create daily backup", error: e);
      });
      //set python manager
      pythonManager = await pythonFuture;

      // 3. Attempt Auto-Login
      await _attemptAutoLogin();

      // 4. Signal ready
      if (mounted) {
        setState(() {
          _isSetupComplete = MainApp.databaseManager != null;
        });
      }
    }
  }

  Future<void> _attemptAutoLogin() async {
    try {
      const storage = FlutterSecureStorage(
        iOptions: IOSOptions(
          groupId: AppConstants.appName,
          synchronizable: true,
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );

      if (await storage.containsKey(key: AppConstants.securePassword)) {
        // Check remember me preference
        String? rememberMe = await storage.read(
          key: AppConstants.secureRememberMe,
        );
        if (rememberMe != 'true') {
          return;
        }

        String? pwd = await storage.read(key: AppConstants.securePassword);
        if (pwd != null && pwd.isNotEmpty) {
          var algorithm = PBKDF2(
            blockLength: 64,
            iterationCount: 10000,
            desiredKeyLength: 64,
          );
          var hash = Password.hash(pwd, algorithm);

          await GetUserService.instance.invoke(GetUserServiceCommand(hash));
        }
      }
    } catch (e) {
      // Log error but don't block startup
      Logger().e("Auto-login failed", error: e);
    }
  }

  // Initialize a global Dialog Manager so any screen can launch global dialogs, such as oauth expired alerts
  void _initDialogManager() =>
      AuthDialogManager(AppRouter.rootNavigatorKey).init();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleListener.dispose();
    super.dispose();
  }

  Widget _initSplashScreen() {
    // Show splash screen
    () async {
      await windowManager.setSize(const Size(800, 600));
      await windowManager.center();
      await windowManager.setTitle('MyData Tools - Loading...');
    }();
    return const MaterialApp(
      home: SplashPage(),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _initSetupScreen() {
    // Handle case where database initialization fails but we want to show the main app anyway
    // Or perhaps navigate to a setup screen.
    // For now, just launch the main app and let the router go to setup.
    () async {
      await windowManager.setTitle('MyData Tools');
      await windowManager.setSize(const Size(1200, 800));
      await windowManager.center();
    }();
    return const MaterialApp(
      home: FamilyDamApp(),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _initAppScreen() {
    // Handle case where database initialization fails but we want to show the main app anyway
    // Or perhaps navigate to a setup screen.
    // For now, just launch the main app and let the router go to setup.
    () async {
      await windowManager.setTitle('MyData Tools');
      await windowManager.setSize(const Size(1200, 800));
      await windowManager.center();
    }();
    return const MaterialApp(
      home: FamilyDamApp(),
      debugShowCheckedModeBanner: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_needsSetup) {
      return _initSetupScreen();
    }
    if (_isSetupComplete) {
      return _initAppScreen();
    }
    return _initSplashScreen();
  }
}
