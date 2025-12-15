/// Base class for all items in the chat list.
sealed class ChatItem {}

/// Represents a text message in the chat (user or assistant).
class TextMessageItem extends ChatItem {
  final String role;
  final String text;

  TextMessageItem({required this.role, required this.text});
}

/// Represents a GenUI surface area in the chat.
class GenUiSurfaceItem extends ChatItem {
  final String surfaceId;

  GenUiSurfaceItem({required this.surfaceId});
}
