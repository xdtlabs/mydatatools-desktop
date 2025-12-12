import 'package:mydatatools/database_manager.dart';
import 'package:drift/drift.dart';
import 'package:mydatatools/models/tables/chat_session.dart';

@UseRowClass(ChatMessage, constructor: 'fromDb')
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(ChatSessions, #id)();
  TextColumn get role => text()(); // 'user' or 'model'
  TextColumn get content => text()();
  TextColumn get data => text().nullable()(); // JSON string for GenUI data
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ChatMessage implements Insertable<ChatMessage> {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final String? data;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.data,
    required this.createdAt,
  });

  ChatMessage.fromDb({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.data,
    required this.createdAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      role: Value(role),
      content: Value(content),
      data: Value(data),
      createdAt: Value(createdAt),
    ).toColumns(nullToAbsent);
  }
}
