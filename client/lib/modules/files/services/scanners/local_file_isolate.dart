import 'dart:async';
import 'dart:io' as io;
import 'dart:isolate';
import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/models/tables/collection.dart';
import 'package:mydatatools/models/tables/file.dart';
import 'package:mydatatools/models/tables/folder.dart';
import 'package:mydatatools/modules/files/files_constants.dart';
import 'package:flutter/services.dart';
import 'package:mydatatools/scanners/collection_scanner.dart';

class LocalFileIsolate implements CollectionScanner {
  RootIsolateToken? token;
  SendPort? loggerIsolatePort;
  SendPort? dbWriterIsolatePort;
  Isolate? isolate;
  AppLogger? logger;

  LocalFileIsolate(this.loggerIsolatePort, this.dbWriterIsolatePort) : super() {
    logger = AppLogger(loggerIsolatePort);
  }

  @override
  Future<int> start(
    Collection collection,
    String? path,
    recursive,
    bool force,
  ) async {
    // A Stream that handles communication between isolates
    ReceivePort p = ReceivePort();
    RootIsolateToken? token = RootIsolateToken.instance;
    Map<String, dynamic> args = {
      'path': path,
      'recursive': recursive,
      'collectionId': collection.id,
    };

    //// Invoked the _scan() method in an isolate thread
    LocalFileIsolateWorker worker = LocalFileIsolateWorker(
      token!,
      p.sendPort,
      dbWriterIsolatePort!,
      loggerIsolatePort,
    );
    isolate = await Isolate.spawn<Map<String, dynamic>>(worker._scan, args);
    isolate!.addOnExitListener(p.sendPort);

    await for (var message in p) {
      if (message is SendPort) {
        // connected
        logger?.s(message);
      } else if (message == null) {
        //logger.i("Scan Complete");
        return Future(() => -1);
      }
    }

    return Future(() => 0);
  }

  @override
  void stop() async {
    //clear any isolates
    if (isolate != null) {
      isolate!.kill(priority: Isolate.beforeNextEvent);
      logger?.w('Killed local file scanner');
    }
  }
}

//// Method will run in Isolate
class LocalFileIsolateWorker {
  RootIsolateToken token;
  SendPort receiverPort;
  SendPort dbWriterPort;
  SendPort? loggerPort;
  AppLogger? logger;

  //constructor
  LocalFileIsolateWorker(
    this.token,
    this.receiverPort,
    this.dbWriterPort,
    this.loggerPort,
  ) {
    // Ensure the background binary messenger is initialized so plugins/platform channels work
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  }

  // start scanning
  void _scan(Map<String, dynamic> args) async {
    //print(args);
    logger = AppLogger(loggerPort);

    String path = args['path'];
    bool recursive = args['recursive'];
    String collectionId = args['collectionId'];

    // start scanner on first directory
    logger?.i('Scanning: $path');
    var fileCount = await _scanDir(collectionId, path, recursive);

    // return file count
    Isolate.exit(receiverPort, fileCount);
  }

  Future<int> _scanDir(String collectionId, String path, recursive) async {
    int count = 0;
    AppLogger logger = AppLogger(loggerPort);

    var dir = io.Directory(path);
    logger.s('Scanning ${dir.path}');

    var dirList = dir.listSync(recursive: false, followLinks: false);

    for (var asset in dirList) {
      if (asset is io.File) {
        logger.s('file: ${asset.path}');
        count++;
        //save file
        File? file = _validateFile({}, collectionId, asset);
        if (file != null) {
          dbWriterPort.send({'type': 'file', 'object': file});
        }
      } else if (asset is io.Directory) {
        //send status message back
        logger.s('Scanning: ${asset.path}');
        //save directory
        Folder? folder = _validateFolder({}, collectionId, asset);
        if (folder != null) {
          dbWriterPort.send({'type': 'folder', 'object': folder});
        }

        try {
          if (recursive) {
            int fileCount = await _scanDir(collectionId, asset.path, recursive);
            count += fileCount;
          }
        } catch (err) {
          logger.w(err);
        }
      } else {
        logger.w("unknown type");
      }
    }

    return Future(() => count);
  }

  //
  // Future<int> _saveResults(
  //   SendPort dbWriterPort,
  //   String collectionId,
  //   List<io.FileSystemEntity> files,
  //   String parent,
  // ) async {
  //   int batchFolderSize = 100;
  //   int batchFileSize = 100;
  //   int count = 0;
  //   //create repository & load list of all existing files
  //   FileSystemRepository repo = FileSystemRepository();
  //   Map<String, DateTime> existingFolders = {};
  //   for (var e in (await repo.folders(collectionId, parent))) {
  //     existingFolders.putIfAbsent(
  //       '${e.collectionId}:${e.path}',
  //       () => e.dateLastModified,
  //     );
  //   }
  //
  //   Map<String, DateTime> existingFiles = {};
  //   for (var e in (await repo.files(collectionId, parent))) {
  //     existingFiles.putIfAbsent(
  //       '${e.collectionId}:${e.path}',
  //       () => e.dateLastModified,
  //     );
  //   }
  //
  //   //First Save all the Directories
  //   List<io.Directory> dirList = files.whereType<io.Directory>().toList();
  //   while (dirList.isNotEmpty) {
  //     //var start = DateTime.now().millisecondsSinceEpoch;
  //     //pull out batch, so we don't lock ui trying to save too many folders
  //     batchFolderSize = min(batchFolderSize, dirList.length);
  //     List<io.Directory> range = dirList.sublist(0, batchFolderSize);
  //     if (range.isEmpty) break;
  //
  //     //remove files from larger list
  //     dirList.removeRange(0, batchFolderSize);
  //
  //     //valid files (not system, hidden, duplicates)
  //     var validFolders = await _validateFolders(
  //       existingFolders,
  //       collectionId,
  //       range,
  //     );
  //
  //     //save files w/pause
  //     if (validFolders.isNotEmpty) {
  //       logger.s("Saving Directories");
  //       int saveCount = await repo.addFolders(validFolders);
  //       count += saveCount;
  //     }
  //     //logger.d('[${DateTime.now().millisecondsSinceEpoch - st1art}ms] Saving Dir Complete: ${validFolders.length}');
  //   }
  //
  //   //Save Files
  //   List<io.File> fileList = files.whereType<io.File>().toList();
  //   int total = fileList.length;
  //   int completed = 0;
  //   while (fileList.isNotEmpty) {
  //     //var start = DateTime.now().millisecondsSinceEpoch;
  //     //pull out batch, so we don't lock ui trying to save too many files
  //     batchFileSize = min(batchFileSize, fileList.length);
  //     List<io.File> range = fileList.sublist(0, batchFileSize);
  //     if (range.isEmpty) break;
  //
  //     //Future.delayed(const Duration(seconds: 10), () async {
  //     //remove files from larger list
  //     batchFileSize = min(batchFileSize, fileList.length);
  //     fileList.removeRange(0, batchFileSize);
  //
  //     //valid files (not system, hidden, duplicates)
  //     var validFiles = await _validateFiles(existingFiles, collectionId, range);
  //     if (validFiles.isEmpty) break;
  //
  //     //save files w/pause
  //     if (validFiles.isNotEmpty) {
  //       completed += validFiles.length;
  //       logger.s("Saving $completed / $total files");
  //       int saveCount = await repo.addFiles(validFiles);
  //       count += saveCount;
  //     }
  //     //logger.s('[${DateTime.now().millisecondsSinceEpoch - start}ms] Saving Files Complete: ${validFiles.length}');
  //   }
  //   logger.s(""); //clear status
  //   return Future(() => count);
  // }

  /// Validate directories against the know paths we want to skip.
  /// Convert dart.io to a local model object
  Folder? _validateFolder(
    Map<String, DateTime> existingFolders_,
    String collectionId_,
    io.Directory dir_,
  ) {
    final hiddenFolderRegex = RegExp(
      '/[.].*/?',
      multiLine: false,
      caseSensitive: true,
      unicode: true,
    );

    // TODO: add this list to a global config / UI page
    final skipFolderRegex = RegExp(
      '/(go|node_modules|Pods|.git)+/?',
      multiLine: false,
      caseSensitive: true,
      unicode: true,
    );

    //skip any hidden or system folders
    bool hidden = hiddenFolderRegex.hasMatch(dir_.path);
    bool skipFolder = skipFolderRegex.hasMatch(dir_.path);
    if (hidden || skipFolder) {
      return null;
    }

    if (existingFolders_["$collectionId_:${dir_.path}"] == null) {
      String name = dir_.path.split("/").last;
      String parentPath = dir_.path
          .split("/")
          .sublist(0, dir_.path.split("/").length - 1)
          .join("/");

      return Folder(
        id: '$collectionId_:${dir_.path.hashCode}',
        name: name,
        path: dir_.path,
        parent: parentPath,
        dateCreated: DateTime.now(),
        dateLastModified: DateTime.now(),
        collectionId: collectionId_,
      );
    }

    return null;
  }

  /// Validate directories against the know paths we want to skip.
  /// Convert dart.io to a local model object
  File? _validateFile(
    Map<String, DateTime> existingFiles_,
    String collectionId_,
    io.File file_,
  ) {
    final hiddenFolderRegex = RegExp(
      '/[.].*/?',
      multiLine: false,
      caseSensitive: true,
      unicode: true,
    );

    // TODO: add this list to a global config / UI page
    final skipFolderRegex = RegExp(
      '/(go|node_modules|Pods|.git)+/?',
      multiLine: false,
      caseSensitive: true,
      unicode: true,
    );

    //skip any fines in a hidden or system folder
    bool hidden = hiddenFolderRegex.hasMatch(file_.path);
    bool skipFolder = skipFolderRegex.hasMatch(file_.path);
    if (hidden || skipFolder) {
      return null;
    }

    //Check if it exists, skip it if it does
    DateTime lmDate = file_.lastModifiedSync();
    //todo: add date check to if statement
    if (existingFiles_["$collectionId_:${file_.path}"] == null) {
      String name = file_.path.split("/").last;
      String parentPath = file_.path
          .split("/")
          .sublist(0, file_.path.split("/").length - 1)
          .join("/");

      return File(
        id: '$collectionId_:${file_.path.hashCode}',
        collectionId: collectionId_,
        name: name,
        path: file_.path,
        parent: parentPath,
        dateCreated: lmDate,
        dateLastModified: lmDate,
        isDeleted: false,
        size: file_.lengthSync(),
        contentType: getMimeType(name),
      );
    }

    return null;
  }

  String getMimeType(String name) {
    String extension = name.split(".").last;
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'png':
      case 'tif':
      case 'psd':
        return FilesConstants.mimeTypeImage;
      case 'pdf':
        return FilesConstants.mimeTypePdf;
      case 'mp4':
      case 'm4v':
      case 'mpeg':
      case 'mov':
        return FilesConstants.mimeTypeMovie;
      case 'mp3':
        return FilesConstants.mimeTypeMusic;
      default:
        return FilesConstants.mimeTypeUnKnown;
    }
  }
}

/** TODO map extra types and move to helper class
    {
    {".3gp",    "video/3gpp"},
    {".torrent","application/x-bittorrent"},
    {".kml",    "application/vnd.google-earth.kml+xml"},
    {".gpx",    "application/gpx+xml"},
    {".csv",    "application/vnd.ms-excel"},
    {".apk",    "application/vnd.android.package-archive"},
    {".asf",    "video/x-ms-asf"},
    {".avi",    "video/x-msvideo"},
    {".bin",    "application/octet-stream"},
    {".bmp",    "image/bmp"},
    {".c",      "text/plain"},
    {".class",  "application/octet-stream"},
    {".conf",   "text/plain"},
    {".cpp",    "text/plain"},
    {".doc",    "application/msword"},
    {".docx",   "application/vnd.openxmlformats-officedocument.wordprocessingml.document"},
    {".xls",    "application/vnd.ms-excel"},
    {".xlsx",   "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"},
    {".exe",    "application/octet-stream"},
    {".gif",    "image/gif"},
    {".gtar",   "application/x-gtar"},
    {".gz",     "application/x-gzip"},
    {".h",      "text/plain"},
    {".htm",    "text/html"},
    {".html",   "text/html"},
    {".jar",    "application/java-archive"},
    {".java",   "text/plain"},
    {".jpeg",   "image/jpeg"},
    {".jpg",    "image/jpeg"},
    {".js",     "application/x-javascript"},
    {".log",    "text/plain"},
    {".m3u",    "audio/x-mpegurl"},
    {".m4a",    "audio/mp4a-latm"},
    {".m4b",    "audio/mp4a-latm"},
    {".m4p",    "audio/mp4a-latm"},
    {".m4u",    "video/vnd.mpegurl"},
    {".m4v",    "video/x-m4v"},
    {".mov",    "video/quicktime"},
    {".mp2",    "audio/x-mpeg"},
    {".mp3",    "audio/x-mpeg"},
   
    {".mpc",    "application/vnd.mpohun.certificate"},
    {".mpe",    "video/mpeg"},
   
    {".mpg",    "video/mpeg"},
    {".mpg4",   "video/mp4"},
    {".mpga",   "audio/mpeg"},
    {".msg",    "application/vnd.ms-outlook"},
    {".ogg",    "audio/ogg"},
    {".pdf",    "application/pdf"},
    {".png",    "image/png"},
    {".pps",    "application/vnd.ms-powerpoint"},
    {".ppt",    "application/vnd.ms-powerpoint"},
    {".pptx",   "application/vnd.openxmlformats-officedocument.presentationml.presentation"},
    {".prop",   "text/plain"},
    {".rc",     "text/plain"},
    {".rmvb",   "audio/x-pn-realaudio"},
    {".rtf",    "application/rtf"},
    {".sh",     "text/plain"},
    {".tar",    "application/x-tar"},
    {".tgz",    "application/x-compressed"},
    {".txt",    "text/plain"},
    {".wav",    "audio/x-wav"},
    {".wma",    "audio/x-ms-wma"},
    {".wmv",    "audio/x-ms-wmv"},
    {".wps",    "application/vnd.ms-works"},
    {".xml",    "text/plain"},
    {".z",      "application/x-compress"},
    {".zip",    "application/x-zip-compressed"},
}
 */
