import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/folder.dart';
import 'package:drift/drift.dart' as drift;

class FolderDesktopRepository {
  AppLogger logger = AppLogger(null);
  AppDatabase db;

  FolderDesktopRepository(this.db);

  Future<Folder?> getByPath(Folder f) async {
    Folder? folder =
        await (db.select(db.folders)
          ..where((t) => t.id.equals(f.id))).getSingleOrNull();

    return Future(() => folder);
  }

  Future<List<Folder>> getByParentPath(String path) async {
    List<Folder> folders =
        await (db.select(db.folders)
          ..where((t) => t.parent.equals(path))).get();

    return Future(() => folders);
  }

  Future<Folder?> create(Folder f) async {
    await db.into(db.folders).insert(f);
    //grab latest
    Folder? folder =
        await (db.select(db.folders)
          ..where((t) => t.id.equals(f.id))).getSingleOrNull();

    return Future(() => folder);
  }

  Future<Folder?> update(Folder f) async {
    await db.update(db.folders).replace(f);
    //grab latest
    Folder? folder =
        await (db.select(db.folders)
          ..where((t) => t.id.equals(f.id))).getSingleOrNull();

    return Future(() => folder);
  }

  Future<Folder?> delete(Folder f) async {
    await db.delete(db.folders).delete(f);
    return Future(() => null);
  }

  Future<void> deleteMissing(String collectionId, String scannedPath, DateTime scanStartTime) async {
    String searchPath = scannedPath;
    if (!searchPath.endsWith('/')) {
      searchPath += '/';
    }

    await (db.delete(db.folders)
          ..where((t) =>
              t.collectionId.equals(collectionId) &
              (t.parent.equals(scannedPath) | t.parent.like('$searchPath%')) &
              (t.lastScannedDate.isNull() | t.lastScannedDate.isSmallerThanValue(scanStartTime))))
        .go();
  }
}
