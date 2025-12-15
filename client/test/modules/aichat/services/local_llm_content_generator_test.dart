import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mydatatools/main.dart';
import 'package:genui/genui.dart';
import 'package:mydatatools/modules/aichat/services/local_llm_content_generator.dart';

void main() {
  group('LocalLlmContentGenerator', () {
    const sessionId = 'test-session-id';
    const serviceUrl = 'http://localhost:8000';

    setUpAll(() {
      MainApp.llmServiceUrl.add(serviceUrl);
    });

    test('startSession sends correct request', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/start-session') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['session_id'] == sessionId &&
              body['model_name'] == 'google/gemma-3-4b-it') {
            return http.Response(jsonEncode({'status': 'ok'}), 200);
          }
        }
        return http.Response('Error', 400);
      });

      final generator = LocalLlmContentGenerator(
        systemInstruction: 'sys',
        sessionId: sessionId,
        httpClient: client,
      );

      await generator.startSession(sessionId: sessionId);
    });

    test('startSession throws on error', () async {
      final client = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final generator = LocalLlmContentGenerator(
        systemInstruction: 'sys',
        sessionId: sessionId,
        httpClient: client,
      );

      expect(
        () => generator.startSession(sessionId: sessionId),
        throwsException,
      );
    });

    test('sendRequest emits text response on successful text chat', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/chat') {
          return http.Response(
            jsonEncode({'ai_response': 'Hello, world!'}),
            200,
          );
        }
        return http.Response('Error', 404);
      });

      final generator = LocalLlmContentGenerator(
        systemInstruction: 'sys',
        sessionId: sessionId,
        httpClient: client,
      );

      expectLater(generator.textResponseStream, emitsThrough('Hello, world!'));

      await generator.sendRequest(UserMessage.text('Hi'));
    });

    test('sendRequest emits A2uiMessage on GenUI array response', () async {
      final genUiJson = [
        {
          "surfaceUpdate": {
            "surfaceId": "surface-123",
            "components": [
              {
                "id": "comp-1",
                "component": {
                  "Text": {
                    "text": {"literalString": "Hello"},
                  },
                },
              },
            ],
          },
        },
      ];
      final responseBody = jsonEncode(genUiJson);

      final client = MockClient((request) async {
        if (request.url.path == '/chat') {
          return http.Response(jsonEncode({'ai_response': responseBody}), 200);
        }
        return http.Response('Error', 404);
      });

      final generator = LocalLlmContentGenerator(
        systemInstruction: 'sys',
        sessionId: sessionId,
        httpClient: client,
      );

      expectLater(generator.a2uiMessageStream, emits(isA<dynamic>()));

      await generator.sendRequest(UserMessage.text('Make UI'));
    });
  });
}
