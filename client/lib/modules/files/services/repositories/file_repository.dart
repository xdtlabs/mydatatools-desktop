import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/file.dart';

class FileDesktopRepository {
  AppLogger logger = AppLogger(null);
  AppDatabase db;

  FileDesktopRepository(this.db);

  Future<File?> getByPath(File f) async {
    File? file =
        await (db.select(db.files)
          ..where((t) => t.path.equals(f.path))).getSingleOrNull();

    return Future(() => file);
  }

  Future<List<File>> getByParentPath(String path) async {
    List<File> files =
        await (db.select(db.files)
          ..where((t) => t.parent.equals(path))).get();

    return Future(() => files);
  }

  Future<File?> create(File f) async {
    await db.into(db.files).insert(f);
    //grab latest
    File? file =
        await (db.select(db.files)
          ..where((t) => t.path.equals(f.path))).getSingle();

    return Future(() => file);
  }

  Future<File?> update(File f) async {
    await db.update(db.files).replace(f);
    //grab latest
    File? file =
        await (db.select(db.files)
          ..where((t) => t.path.equals(f.path))).getSingleOrNull();

    return file;
  }

  Future<File?> delete(File f) async {
    await db.delete(db.files).delete(f);
    return Future(() => null);
  }
}
