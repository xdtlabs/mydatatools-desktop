import 'dart:io' as io;

import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/file.dart';
import 'package:mydatatools/models/tables/folder.dart';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

@Deprecated("Use the individual File/Folder repositories")
// TODO: create Unit Test for this
class FileSystemRepository {
  AppLogger logger = AppLogger(null);

  //list of file paths and their size, so we can compare when looking for new or changed files.
  Map<String, DateTime> existingFiles = <String, DateTime>{};
  Map<String, DateTime> existingFolders = <String, DateTime>{};

  ///
  /// Folder Specific Methods
  ///

  Future<List<Folder>> folders(String collectionId, String parentPath) async {
    AppDatabase? db = DatabaseManager.instance.database;

    return await ((db?.select(db.folders)
            ?..where((e) => e.collectionId.equals(collectionId)))
          ?..where((e) => e.parent.equals(parentPath)))?.get() ??
        [];
    // TODO: add back  SORT(name asc);
  }

  Future<List<Folder>> foldersByCollection(String collectionId) async {
    AppDatabase? db = DatabaseManager.instance.database;

    // TODO: add collectionId to filter
    return await (db?.select(db.folders)
          ?..where((e) => e.collectionId.equals(collectionId)))?.get() ??
        [];
    // TODO add back  SORT(path asc)
  }

  void addFolder(Folder folder) async {
    AppDatabase? db = DatabaseManager.instance.database;
    db?.into(db.folders).insertOnConflictUpdate(folder);
  }

  Future<int> addFolders(List<Folder> folders) async {
    AppDatabase? db = DatabaseManager.instance.database;

    List<Folder> newFolders = [];
    for (var f in folders) {
      if (!existingFolders.containsKey(f.path)) {
        existingFolders.remove(f.path);
        newFolders.add(f);
      } else {
        existingFolders.remove(f.path);
      }
    }

    if (newFolders.isNotEmpty) {
      try {
        for (var f in newFolders) {
          await db?.into(db.folders).insertOnConflictUpdate(f);
        }
      } catch (error) {
        logger.e(error);
        logger.s(error);
      }
    }
    return Future(() {
      return newFolders.length;
    });
  }

  Future<bool> deleteFolders(
    String collectionId,
    String parent,
    List<String> paths,
  ) async {
    AppDatabase? db = DatabaseManager.instance.database;

    //find folders not in list
    for (var p in paths) {
      List<Folder> pendingFoldersToDelete =
          await (db?.select(db.folders)?..where(
            (e) => Expression.and([e.parent.equals(parent), e.path.equals(p)]),
          ))?.get() ??
          [];

      //find all files in deleted folders & sub-folders, using a start with check
      if (pendingFoldersToDelete.isNotEmpty) {
        List<File> filesInDeletedFolders = [];
        for (var pf in pendingFoldersToDelete) {
          List<File> files =
              await (db?.select(db.files)
                ?..where((e) => e.parent.like("${pf.path}%")))?.get() ??
              [];
          filesInDeletedFolders.addAll(files);
        }

        // TODO can we do this in a batch statement instead of a loop?
        for (var file in filesInDeletedFolders) {
          await db?.delete(db.files).delete(file);
        }
        for (var folder in pendingFoldersToDelete) {
          await db?.delete(db.folders).delete(folder);
        }
      }
    }

    return Future(() => true);
  }

  ///
  /// File Specific Methods
  ///

  Future<File?> getFileById(String id) async {
    AppDatabase? db = DatabaseManager.instance.database;

    // TODO: add collectionId to filter
    return await (db?.select(db.files)
      ?..where((e) => e.id.equals(id)))?.getSingleOrNull();
  }

  Future<List<File>> files(String collectionId, String parentPath) async {
    AppDatabase? db = DatabaseManager.instance.database;

    // TODO: add collectionId to filter
    return await (db?.select(db.files)?..where(
          (e) => Expression.and([
            e.collectionId.equals(collectionId),
            e.parent.equals(parentPath),
          ]),
        ))?.get() ??
        [];
    // TODO: add SORT(path asc)
  }

  Future<List<File>> filesByCollection(String collectionId) async {
    AppDatabase? db = DatabaseManager.instance.database;
    // TODO: add collectionId to filter
    return await (db?.select(db.files)
          ?..where((e) => e.collectionId.equals(collectionId)))?.get() ??
        [];
    // TODO: add SORT(path asc)
  }

  Future<io.File?> downloadFile(File f) async {
    io.Directory? downloadFolder = await getDownloadsDirectory();

    debugPrint('${f.name} to ${downloadFolder?.path}/${f.name}');
    return io.File(f.path).copy('${downloadFolder?.path}/${f.name}');
  }

  void addFile(File file) async {
    AppDatabase? db = DatabaseManager.instance.database;
    db?.into(db.files).insertOnConflictUpdate(file);
  }

  Future<int> addFiles(List<File> files) async {
    AppDatabase? db = DatabaseManager.instance.database;

    if (files.isNotEmpty) {
      try {
        // TODO can this be done in a batch statment
        for (var file in files) {
          await db?.into(db.files).insertOnConflictUpdate(file);
        }
      } catch (error) {
        logger.e(error);
        logger.s(error);
      }
    }
    return Future(() {
      return files.length;
    });
  }

  void updateProperty(File file, String prop, dynamic value) async {
    switch (prop) {
      case "thumbnail":
        file.thumbnail = value;
        break;
      case "latitude":
        file.latitude = value;
        break;
      case "longitude":
        file.longitude = value;
        break;
    }

    AppDatabase? db = DatabaseManager.instance.database;
    await db?.update(db.files).write(file);
  }

  void updatePropertyMap(File file, Map<String, dynamic> props) async {
    for (var key in props.keys) {
      switch (key) {
        case "thumbnail":
          file.thumbnail = props[key];
          break;
        case "latitude":
          file.latitude = props[key];
          break;
        case "longitude":
          file.longitude = props[key];
          break;
      }

      AppDatabase? db = DatabaseManager.instance.database;
      await db?.update(db.files).write(file);
    }

    Future<bool> deleteFiles(
      String collectionId,
      String parent,
      List<String> paths,
    ) async {
      AppDatabase? db = DatabaseManager.instance.database;

      //find all files not in list of current files
      for (var p in paths) {
        List<File> files =
            await (db?.select(db.files)?..where(
              (e) =>
                  Expression.and([e.parent.equals(parent), e.path.equals(p)]),
            ))?.get() ??
            [];
        if (files.isNotEmpty) {
          for (var file in files) {
            await db?.delete(db.files).delete(file);
          }
        }
      }
      return Future(() => true);
    }
  }
}
