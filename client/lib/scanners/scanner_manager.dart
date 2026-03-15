import 'dart:async';
import 'dart:isolate';

import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/collection.dart';
import 'package:mydatatools/modules/files/services/scanners/local_file_isolate.dart';

import 'package:mydatatools/scanners/collection_scanner.dart';
import 'package:logger/logger.dart';

class ScannerManager {
  final Logger logger = Logger();
  static final ScannerManager _instance = ScannerManager._internal();
  List<Collection> collections = [];
  Map<String, CollectionScanner> scanners = {};

  late AppDatabase database;
  //class reference to keep change listeners running
  StreamSubscription<List<Collection>>? collectionSubs;

  // todo: pass in a dedicated writer thread
  factory ScannerManager(AppDatabase database) {
    _instance.database = database;
    return _instance;
  }

  static ScannerManager getInstance() {
    return _instance;
  }

  ScannerManager._internal() {
    // initialization logic
    //_instance.startScanners();
  }

  void startScanners() async {
    // Delay scanner startup to let the app UI finish initializing and prevent startup lockups
    await Future.delayed(const Duration(seconds: 5));

    //start scanner for all existing collections
    var collections = await database.select(database.collections).get();
    for (var c in collections) {
      await Future.delayed(const Duration(seconds: 5));
      logger.d('${c.id} | ${c.path}');
      _registerSingleScanner(c);
    }

    //listen for new collections and add them at runtime
    Stream<List<Collection>> collectionWatch =
        database.select(database.collections).watch();

    collectionWatch.listen((changes) {
      print('Value from controller: $changes');

      for (var c in changes) {
        if (getScanner(c) == null) {
          _registerSingleScanner(c);
        }
      }
    });
  }

  void stopScanners() {
    try {
      for (var key in scanners.keys) {
        scanners[key]!.stop();
        scanners.remove(key);
      }
    } catch (error) {
      //print(error);
    }
  }

  void startScanner(Collection c) {
    // TODO, not implemented yet
  }

  CollectionScanner? getScanner(Collection c) {
    return scanners[c.id];
  }

  void _registerSingleScanner(Collection c) async {
    //go up 2 folders from db folder
    /** TODO: implement this with sqlite */
    //String? dir = MainApp.appDataDirectory.value;

    switch (c.scanner) {
      case "file.local":
        print("Register '${c.scanner}' scanner for ${c.name} | ${c.path}");
        SendPort? writerPort = await DatabaseManager.instance.writerPort;
        CollectionScanner s = LocalFileIsolate(
          null,
          writerPort,
        ); // todo: pass in dedicated db write thread
        scanners.putIfAbsent(c.id, () => s);
        break;
      case "email.gmail":
        print("Register '${c.scanner}' scanner for ${c.name} | ${c.path}");
        //CollectionScanner s = GmailScanner(database.config.path, c, fileDir.path);
        //s.start(c, c.path, true, false);
        //scanners.putIfAbsent(c.id, () => s);
        break;
      default:
        print("Scanner type '${c.scanner}' not recognized.");
        break;
    }
  }
}
