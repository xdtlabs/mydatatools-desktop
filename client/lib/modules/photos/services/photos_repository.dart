import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/file.dart';
import 'package:mydatatools/modules/files/files_constants.dart';

import 'package:intl/intl.dart';

class PhotosRepository {
  AppLogger logger = AppLogger(null);

  Future<List<File>> photos() async {
    AppDatabase? db = DatabaseManager.instance.database;

    return await (db?.select(db.files)?..where(
          (e) => e.contentType.equals(FilesConstants.mimeTypeImage),
        ))?.get() ??
        [];
    // TODO add sort  SORT(dateCreated DESC)
  }

  Future<Map<String, List<File>>> photosByDate() async {
    AppDatabase? db = DatabaseManager.instance.database;
    DateFormat dateFormat = DateFormat("yyyy-MM-dd");
    Map<String, List<File>> groupedImages = {};
    List<File> p =
        await (db?.select(db.files)?..where(
          (e) => e.contentType.equals(FilesConstants.mimeTypeImage),
        ))?.get() ??
        [];

    // TODO add sort SORT(dateCreated ASC)

    for (var f in p) {
      String group = dateFormat.format(f.dateCreated);

      if (groupedImages[group] == null) {
        groupedImages[group] = [];
      }
      List<File>? groupList = groupedImages[group];
      groupList?.add(f);
    }

    return groupedImages;
  }
}
