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
import 'package:path/path.dart' as p;


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
  Future<int> start(Collection collection,
      String? path,
      recursive,
      bool force,) async {
    // A Stream that handles communication between isolates
    ReceivePort p = ReceivePort();
    RootIsolateToken? token = RootIsolateToken.instance;
    Map<String, dynamic> args = {
      'path': path,
      'recursive': recursive,
      'collectionId': collection.id,
    };

    //// Invoked the _scan() method in an isolate thread
    LocalFileIsolateWorker worker = LocalFileIsolateWorker(token!, p.sendPort, dbWriterIsolatePort!, loggerIsolatePort);
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
class LocalFileIsolateWorker{

  RootIsolateToken token;
  SendPort receiverPort;
  SendPort dbWriterPort;
  SendPort? loggerPort;
  AppLogger? logger;

  final hiddenFolderRegex = RegExp(
    r'/[.].*/?',
    multiLine: false,
    caseSensitive: true,
    unicode: true,
  );

  // TODO: add this list to a global config / UI page
  final skipFolderRegex = RegExp(
    r'/(go|node_modules|Pods|\.git)+/?',
    multiLine: false,
    caseSensitive: true,
    unicode: true,
  );

  //constructor
  LocalFileIsolateWorker(this.token, this.receiverPort, this.dbWriterPort, this.loggerPort){
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
    DateTime scanStartTime = DateTime.now();

    var fileCount = await _scanDir(
      collectionId,
      path,
      recursive,
      scanStartTime,
    );

    dbWriterPort.send({
      'type': 'cleanup_deleted',
      'collectionId': collectionId,
      'path': path,
      'scanStartTime': scanStartTime,
    });

    // return file count
    Isolate.exit(receiverPort, fileCount);
  }

  Future<int> _scanDir(
    String collectionId,
    String path,
    recursive,
    DateTime scanStartTime,
  ) async {
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
        File? file = _validateFile(collectionId, asset, scanStartTime);
        if( file != null ) {
          dbWriterPort.send({
            'type': 'file',
            'file': file
          });
        }
      } else if (asset is io.Directory) {
        //send status message back
        logger.s('Scanning: ${asset.path}');
        //save directory
        Folder? folder = _validateFolder(collectionId, asset, scanStartTime);
        if( folder != null ) {
          dbWriterPort.send({
            'type': 'folder',
            'folder': folder
          });

          try {
            if (recursive) {
              int fileCount = await _scanDir(
                collectionId,
                asset.path,
                recursive,
                scanStartTime,
              );
              count += fileCount;
            }
          } catch (err) {
            logger.w(err);
          }
        }
      } else {
        logger.w("unknown type");
      }
    }

    return Future(() => count);
  }

  //

  /// Validate directories against the know paths we want to skip.
  /// Convert dart.io to a local model object
  Folder? _validateFolder(
    String collectionId_,
    io.Directory dir_,
    DateTime scanStartTime,
  ) {
    //skip any hidden or system folders
    bool hidden = hiddenFolderRegex.hasMatch(dir_.path);
    bool skipFolder = skipFolderRegex.hasMatch(dir_.path);
    if( hidden || skipFolder ){
      return null;
    }

    String name = p.basename(dir_.path);
    String parentPath = p.dirname(dir_.path);

    return Folder(
        id: '$collectionId_:${dir_.path.hashCode}',
        name: name,
        path: dir_.path,
        parent: parentPath,
        dateCreated: DateTime.now(),
        dateLastModified: DateTime.now(),
        lastScannedDate: scanStartTime,
        collectionId: collectionId_,
    );
  }

  /// Validate directories against the know paths we want to skip.
  /// Convert dart.io to a local model object
  File? _validateFile(
    String collectionId_,
    io.File file_,
    DateTime scanStartTime,
  ) {
    //skip any fines in a hidden or system folder
    bool hidden = hiddenFolderRegex.hasMatch(file_.path);
    bool skipFolder = skipFolderRegex.hasMatch(file_.path);
    if( hidden || skipFolder ){
      return null;
    }


    //Check if it exists, skip it if it does
    DateTime lmDate = file_.lastModifiedSync();
    //todo: add date check to if statement
    String name = p.basename(file_.path);
    String parentPath = p.dirname(file_.path);

    return File(
      id: '$collectionId_:${file_.path.hashCode}',
      collectionId: collectionId_,
      name: name,
      path: file_.path,
      parent: parentPath,
      dateCreated: lmDate,
      dateLastModified: lmDate,
      lastScannedDate: scanStartTime,
      isDeleted: false,
      size: file_.lengthSync(),
      contentType: getMimeType(name),
    );
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
