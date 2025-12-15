import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/chat_message.dart';
import 'package:mydatatools/models/tables/chat_session.dart';

class ChatRepository {
  final AppDatabase db;

  ChatRepository(this.db);

  Future<void> saveSession(ChatSession session) {
    return db.into(db.chatSessions).insertOnConflictUpdate(session);
  }

  Future<void> saveMessage(ChatMessage message) {
    return db.into(db.chatMessages).insertOnConflictUpdate(message);
  }
}
