import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/folder.dart';

class FolderDesktopRepository {
  AppLogger logger = AppLogger(null);
  AppDatabase db;

  FolderDesktopRepository(this.db);

  Future<Folder?> getByPath(Folder f) async {
    Folder? folder =
        await (db.select(db.folders)
          ..where((t) => t.path.equals(f.path))).getSingleOrNull();

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
          ..where((t) => t.path.equals(f.path))).getSingleOrNull();

    return Future(() => folder);
  }

  Future<Folder?> update(Folder f) async {
    await db.update(db.folders).replace(f);
    //grab latest
    Folder? folder =
        await (db.select(db.folders)
          ..where((t) => t.path.equals(f.path))).getSingleOrNull();

    return Future(() => folder);
  }

  Future<Folder?> delete(Folder f) async {
    await db.delete(db.folders).delete(f);
    return Future(() => null);
  }
}
