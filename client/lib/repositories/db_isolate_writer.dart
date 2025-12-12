// dart
import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/app_user.dart';
import 'package:mydatatools/modules/files/services/file_upsert_service.dart';
import 'package:mydatatools/modules/files/services/folder_upsert_service.dart';
import 'package:mydatatools/repositories/user_repository.dart';
import 'package:mydatatools/models/tables/chat_session.dart';
import 'package:mydatatools/models/tables/chat_message.dart';

class DbIsolateWriterClient {
  Isolate? _isolate;
  SendPort? _sendPort;
  SendPort? _writerPort;
  ReceivePort? _receivePort;

  SendPort? getSendPort() {
    return _writerPort;
  }

  /// Start the DB isolate. Pass the same storagePath and dbName used by the app.
  Future<void> start(
    String storagePath,
    String dbName, {
    bool useMemoryDb = false,
  }) async {
    if (_isolate != null) return;
    _receivePort = ReceivePort("DbIsolateWriterClient");
    Completer<void> completer = Completer<void>();

    RootIsolateToken? token = RootIsolateToken.instance;
    Map<String, dynamic> cfg = {
      'token': token,
      'replyTo': _receivePort!.sendPort,
      'path': storagePath,
      'name': dbName,
      'useMemoryDb': useMemoryDb,
    };

    _isolate = await Isolate.spawn(
      _isolateEntry,
      cfg,
      debugName: 'DbIsolateWriterClientIsolate',
    );

    // list for port to be sent back from isolate
    _receivePort?.listen((data) {
      if (data is SendPort) {
        _writerPort = data;
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    return completer.future;
  }

  Future<void> stop() async {
    if (_sendPort == null) return;
    _sendPort!.send({'type': 'close'});
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _writerPort = null;
  }

  Future<Map<dynamic, dynamic>> save(String type_, Object object_) async {
    //save user to database
    final receivePort = ReceivePort();
    _writerPort?.send({
      'type': type_,
      'object': object_,
      'replyTo': receivePort.sendPort,
    });

    final response = await receivePort.first;
    if (response == null) {
      throw Exception('Failed to save user');
    } else {
      receivePort.close();
      return Future(() => {'type': type_, 'object': object_});
    }
  }

  // Isolate entry-point. Must be a top-level function.
  static Future<void> _isolateEntry(Map<String, dynamic> cfg) async {
    final port = ReceivePort();
    BackgroundIsolateBinaryMessenger.ensureInitialized(cfg['token']);

    final SendPort initialReplyTo = cfg['replyTo'] as SendPort;
    final path = cfg['path'] as String?;
    final name = cfg['name'] as String?;
    final useMemoryDb = cfg['useMemoryDb'] as bool? ?? false;

    // Send control port back to the spawner
    initialReplyTo.send(port.sendPort);

    // create the AppDatabase inside the isolate
    AppDatabase db = AppDatabase(null, path, name, useMemoryDb);

    port.listen((data) async {
      if (data is! Map) return;

      SendPort? replyTo = data['replyTo'] as SendPort?;

      try {
        if (data['type'] == 'file') {
          await FileUpsertService.instance.invoke(
            FileUpsertServiceCommand(data['object'], db),
          );
          replyTo?.send({'status': 'ok'});
        } else if (data['type'] == 'folder') {
          await FolderUpsertService.instance.invoke(
            FolderUpsertServiceCommand(data['object'], db),
          );
          replyTo?.send({'status': 'ok'});
        } else if (data['type'] == 'user') {
          // Handle user save
          UserRepository(db).saveUser(data['object'] as AppUser).then((
            v,
          ) async {
            replyTo?.send({'status': 'ok', 'id': v?.id});
          });
        } else if (data['type'] == 'chat_session') {
          await db
              .into(db.chatSessions)
              .insertOnConflictUpdate(data['object'] as ChatSession);
          replyTo?.send({'status': 'ok'});
        } else if (data['type'] == 'chat_message') {
          await db
              .into(db.chatMessages)
              .insertOnConflictUpdate(data['object'] as ChatMessage);
          replyTo?.send({'status': 'ok'});
        } else {
          print("Unknown message type: ${data['type']}");
          replyTo?.send({'error': 'Unknown message type: ${data['type']}'});
        }
      } catch (e) {
        print("Error in DbIsolateWriter: $e");
        replyTo?.send({'error': e.toString()});
      }
    });
  }
}
