import 'dart:async';
import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:drift/drift.dart';
import 'package:mydatatools/models/tables/chat_session.dart';
import 'package:mydatatools/models/tables/chat_message.dart';

class DatabaseRepository {
  AppDatabase db;
  final AppLogger logger = AppLogger(null);

  // A private constructor. Allows us to create instances of AppDatabase
  // only from within the AppDatabase class itself.
  DatabaseRepository(this.db);

  ///
  /// Helper SQL Methods
  ///

  // All of the rows are returned as a list of maps, where each map is
  // a key-value list of columns.
  Future<int> countAllRows(String table) async {
    var rows = db.customSelect("select count(*) as count from $table;");
    return (await rows.getSingle()).read("count");
  }

  Future<List<ChatSession>> getSessionsWithMessages() async {
    final query = db.select(db.chatSessions).join([
      innerJoin(
        db.chatMessages,
        db.chatMessages.sessionId.equalsExp(db.chatSessions.id),
      ),
    ]);
    query.groupBy([db.chatSessions.id]);
    query.orderBy([OrderingTerm.desc(db.chatSessions.updatedAt)]);

    return query.map((row) => row.readTable(db.chatSessions)).get();
  }

  Future<List<ChatMessage>> getChatMessages(String sessionId) async {
    return (db.select(db.chatMessages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> updateSessionTitle(String sessionId, String title) async {
    await (db.update(db.chatSessions)..where(
      (t) => t.id.equals(sessionId),
    )).write(ChatSessionsCompanion(title: Value(title)));
  }
}
