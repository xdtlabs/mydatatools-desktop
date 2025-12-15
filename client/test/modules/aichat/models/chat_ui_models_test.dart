import 'package:flutter_test/flutter_test.dart';
import 'package:mydatatools/modules/aichat/models/chat_ui_models.dart';

void main() {
  group('ChatUiModels', () {
    test('TextMessageItem initialization', () {
      final item = TextMessageItem(role: 'user', text: 'Hello');
      expect(item, isA<ChatItem>());
      expect(item.role, 'user');
      expect(item.text, 'Hello');
    });

    test('GenUiSurfaceItem initialization', () {
      final item = GenUiSurfaceItem(surfaceId: 'surface-123');
      expect(item, isA<ChatItem>());
      expect(item.surfaceId, 'surface-123');
    });
  });
}
