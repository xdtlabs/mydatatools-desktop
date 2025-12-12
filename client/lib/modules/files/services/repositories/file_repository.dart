import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/file.dart';

class FileDesktopRepository {
  AppLogger logger = AppLogger(null);
  final AppDatabase? _injectedDatabase;

  FileDesktopRepository([this._injectedDatabase]);

  /// Helper to get the correct database instance.
  /// Prefers the one injected (for isolates), falls back to singleton (for main UI).
  AppDatabase get _db =>
      _injectedDatabase ?? DatabaseManager.instance.appDatabase!;

  Future<File?> getByPath(File f) async {
    File? file =
        await (_db.select(_db.files)
          ..where((t) => t.path.equals(f.path))).getSingleOrNull();

    return Future(() => file);
  }

  Future<List<File>> getByParentPath(String path) async {
    List<File> files =
        await (_db.select(_db.files)
          ..where((t) => t.parent.equals(path))).get();

    return Future(() => files);
  }

  Future<File?> create(File f) async {
    await _db.into(_db.files).insert(f);
    //grab latest
    File? file =
        await (_db.select(_db.files)
          ..where((t) => t.path.equals(f.path))).getSingle();

    return Future(() => file);
  }

  Future<File?> update(File f) async {
    await _db.update(_db.files).replace(f);
    //grab latest
    File? file =
        await (_db.select(_db.files)
          ..where((t) => t.path.equals(f.path))).getSingleOrNull();

    return file;
  }

  Future<File?> delete(File f) async {
    await _db.delete(_db.files).delete(f);
    return Future(() => null);
  }
}
