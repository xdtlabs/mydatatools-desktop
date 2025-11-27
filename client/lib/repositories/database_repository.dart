import 'dart:async';
import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/database_manager.dart';

class DatabaseRepository {
  AppDatabase db;
  final AppLogger logger = AppLogger(null);

  // A private constructor. Allows us to create instances of AppDatabase
  // only from within the AppDatabase class itself.
  DatabaseRepository(this.db);

  ///
  /// Helper SQL Methods
  ///

  // All of the rows are returned as a list of maps, where each map is
  // a key-value list of columns.
  Future<int> countAllRows(String table) async {
    var rows = db.customSelect("select count(*) as count from $table;");
    return (await rows.getSingle()).read("count");
  }
}
