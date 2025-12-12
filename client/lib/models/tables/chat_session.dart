import 'package:mydatatools/database_manager.dart';
import 'package:drift/drift.dart';

@UseRowClass(ChatSession, constructor: 'fromDb')
class ChatSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().nullable()();
  TextColumn get model => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ChatSession implements Insertable<ChatSession> {
  final String id;
  final String? title;
  final String? model;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    this.title,
    this.model,
    required this.createdAt,
    required this.updatedAt,
  });

  ChatSession.fromDb({
    required this.id,
    this.title,
    this.model,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    return ChatSessionsCompanion(
      id: Value(id),
      title: Value(title),
      model: Value(model),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    ).toColumns(nullToAbsent);
  }
}
