import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/file.dart';
import 'package:drift/drift.dart' as drift;

class FileDesktopRepository {
  AppLogger logger = AppLogger(null);
  AppDatabase db;

  FileDesktopRepository(this.db);

  Future<File?> getByPath(File f) async {
    File? file =
        await (db.select(db.files)
          ..where((t) => t.id.equals(f.id))).getSingleOrNull();

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
          ..where((t) => t.id.equals(f.id))).getSingleOrNull();

    return Future(() => file);
  }

  Future<File?> update(File f) async {
    await db.update(db.files).replace(f);
    //grab latest
    File? file =
        await (db.select(db.files)
          ..where((t) => t.id.equals(f.id))).getSingleOrNull();

    return file;
  }

  Future<File?> delete(File f) async {
    await db.delete(db.files).delete(f);
    return Future(() => null);
  }

  Future<void> markMissingAsDeleted(String collectionId, String scannedPath, DateTime scanStartTime) async {
    String searchPath = scannedPath;
    if (!searchPath.endsWith('/')) {
      searchPath += '/';
    }
    
    await (db.update(db.files)
          ..where((t) =>
              t.collectionId.equals(collectionId) &
              (t.parent.equals(scannedPath) | t.parent.like('$searchPath%')) &
              (t.lastScannedDate.isNull() | t.lastScannedDate.isSmallerThanValue(scanStartTime))))
        .write(const FilesCompanion(isDeleted: drift.Value(true)));
  }

  Future<void> upsertAll(List<File> fileList) async {
    if (fileList.isEmpty) return;

    List<String> allIds = fileList.map((f) => f.id).toList();

    // Find which IDs already exist in the database
    List<String> existingIds = await (db.select(db.files)
          ..where((t) => t.id.isIn(allIds)))
        .map((row) => row.id)
        .get();

    // Separate into new files (to insert) and existing files (to update)
    List<File> newFiles = fileList.where((f) => !existingIds.contains(f.id)).toList();
    
    // 1. Batch insert the new files
    if (newFiles.isNotEmpty) {
      await db.batch((batch) {
        batch.insertAll(db.files, newFiles);
      });
    }

    // 2. Perform a lightweight targeted update just for the lastScannedDate on existing files
    if (existingIds.isNotEmpty) {
      // Use the max scan date from the batch (they should generally all be the same scan run anyway)
      DateTime? scanDate = fileList.firstWhere((f) => existingIds.contains(f.id)).lastScannedDate;
      if (scanDate != null) {
        await (db.update(db.files)..where((t) => t.id.isIn(existingIds)))
            .write(FilesCompanion(lastScannedDate: drift.Value(scanDate)));
      }
    }
  }

  Future<void> deleteAllByCollectionId(String collectionId) async {
    await (db.delete(db.files)..where((t) => t.collectionId.equals(collectionId))).go();
  }
}
