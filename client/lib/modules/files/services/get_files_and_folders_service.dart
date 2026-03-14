import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/models/tables/collection.dart';
import 'package:mydatatools/models/tables/file_asset.dart';
import 'package:mydatatools/modules/files/services/repositories/file_repository.dart';
import 'package:mydatatools/modules/files/services/repositories/folder_repository.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/services/rx_service.dart';

class GetFileAndFoldersService
    extends RxService<GetFileAndFoldersServiceCommand, List<FileAsset>> {
  static final GetFileAndFoldersService _singleton = GetFileAndFoldersService();
  static get instance => _singleton;
  AppLogger logger = AppLogger(null);

  @override
  Future<List<FileAsset>> invoke(
    GetFileAndFoldersServiceCommand command,
  ) async {
    isLoading.add(true);
    AppDatabase? db = DatabaseManager.instance.database;
    FileDesktopRepository fileRepo = FileDesktopRepository(db!);
    FolderDesktopRepository folderRepo = FolderDesktopRepository(db);

    // TODO: first refresh files & folders under path
    //ScannerManager.getInstance().getScanner(command.collection).

    List<FileAsset> files = await fileRepo.getByParentPath(command.path);
    List<FileAsset> folders = await folderRepo.getByParentPath(command.path);

    List<FileAsset> assets = [...files, ...folders];

    sink.add(assets);
    isLoading.add(false);

    return Future(() => files);
  }
}

class GetFileAndFoldersServiceCommand implements RxCommand {
  Collection collection;
  String path;

  GetFileAndFoldersServiceCommand(this.collection, this.path);
}
