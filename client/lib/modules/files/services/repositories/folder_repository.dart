import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/folder.dart';

class FolderDesktopRepository {
  AppLogger logger = AppLogger(null);
  final AppDatabase? _injectedDatabase;

  FolderDesktopRepository([this._injectedDatabase]);

  /// Helper to get the correct database instance.
  /// Prefers the one injected (for isolates), falls back to singleton.
  AppDatabase get _db =>
      _injectedDatabase ?? DatabaseManager.instance.appDatabase!;

  Future<Folder?> getByPath(Folder f) async {
    Folder? folder =
        await (_db.select(_db.folders)
          ..where((t) => t.path.equals(f.path))).getSingleOrNull();

    return Future(() => folder);
  }

  Future<List<Folder>> getByParentPath(String path) async {
    List<Folder> folders =
        await (_db.select(_db.folders)
          ..where((t) => t.parent.equals(path))).get();

    return Future(() => folders);
  }

  Future<Folder?> create(Folder f) async {
    await _db.into(_db.folders).insert(f);
    //grab latest
    Folder? folder =
        await (_db.select(_db.folders)
          ..where((t) => t.path.equals(f.path))).getSingleOrNull();

    return Future(() => folder);
  }

  Future<Folder?> update(Folder f) async {
    await _db.update(_db.folders).replace(f);
    //grab latest
    Folder? folder =
        await (_db.select(_db.folders)
          ..where((t) => t.path.equals(f.path))).getSingleOrNull();

    return Future(() => folder);
  }

  Future<Folder?> delete(Folder f) async {
    await _db.delete(_db.folders).delete(f);
    return Future(() => null);
  }
}
