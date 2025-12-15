import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;
import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/main.dart';

/// A content generator that communicates with a local LLM service via HTTP.
///
/// This service handles:
/// - Sending chat messages to the Python backend.
/// - receiving streaming text responses.
/// - Receiving and parsing GenUI messages.
/// - Managing the LLM session state on the backend.
class LocalLlmContentGenerator implements ContentGenerator {
  final String systemInstruction;
  final AppLogger logger = AppLogger(null);
  final http.Client _client;

  LocalLlmContentGenerator({
    required this.systemInstruction,
    required String sessionId,
    http.Client? httpClient,
  }) : _sessionId = sessionId,
       _client = httpClient ?? http.Client();

  final _a2uiMessageController = StreamController<A2uiMessage>.broadcast();
  final _rawGenUiMessageController = StreamController<dynamic>.broadcast();
  final _textResponseController = StreamController<String>.broadcast();
  final _errorController = StreamController<ContentGeneratorError>.broadcast();
  final _isProcessing = ValueNotifier<bool>(false);

  // Generate a unique session ID for this instance
  String _sessionId;

  @override
  Stream<A2uiMessage> get a2uiMessageStream => _a2uiMessageController.stream;

  Stream<dynamic> get rawGenUiMessageStream =>
      _rawGenUiMessageController.stream;

  @override
  Stream<ContentGeneratorError> get errorStream => _errorController.stream;

  @override
  ValueListenable<bool> get isProcessing => _isProcessing;

  @override
  Stream<String> get textResponseStream => _textResponseController.stream;

  @override
  void dispose() {
    _a2uiMessageController.close();
    _rawGenUiMessageController.close();
    _textResponseController.close();
    _errorController.close();
    _isProcessing.dispose();
  }

  @override
  Future<void> sendRequest(
    ChatMessage message, {
    Iterable<ChatMessage>? history,
  }) async {
    _isProcessing.value = true;
    try {
      String? llmServiceUrl = MainApp.llmServiceUrl.valueOrNull;
      if (llmServiceUrl == null || llmServiceUrl.isEmpty) {
        throw Exception('LLM Service is not running.');
      }

      // We now rely on server-side history. Only send the new user message.
      String prompt = '';

      // Add current message
      if (message is UserMessage) {
        prompt = message.text.trim();
      }

      final response = await _client.post(
        Uri.parse("$llmServiceUrl/chat"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          "prompt": prompt,
          "system_instruction": systemInstruction,
          "use_genui": true,
          "session_id": _sessionId, // Send session ID
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final aiResponse = responseData['ai_response'];

        // logger.d('Received aiResponse type: ${aiResponse.runtimeType}');
        // logger.d('Received aiResponse: $aiResponse');

        if (aiResponse.trim().startsWith('[') &&
            aiResponse.trim().endsWith(']')) {
          // GenUI message array
          try {
            final List<dynamic> messagesJson = jsonDecode(aiResponse);
            //logger.d('Parsed ${messagesJson.length} GenUI messages');

            // Emit each message to the stream
            for (final messageJson in messagesJson) {
              _rawGenUiMessageController.add(messageJson);
              final message = A2uiMessage.fromJson(messageJson);
              //logger.d('Emitting message: ${message.runtimeType}');
              _a2uiMessageController.add(message);
            }
          } catch (e) {
            logger.e('Failed to parse GenUI message array: $e');
            _textResponseController.add(aiResponse);
          }
        } else if (aiResponse.trim().startsWith('{') &&
            aiResponse.trim().endsWith('}')) {
          // Single GenUI message (legacy format)
          try {
            final jsonResponse = jsonDecode(aiResponse);
            logger.d('Parsed JSON successfully: $jsonResponse');
            _rawGenUiMessageController.add(jsonResponse);
            final message = A2uiMessage.fromJson(jsonResponse);
            logger.d('Created A2uiMessage, emitting to stream...');
            _a2uiMessageController.add(message);
            //logger.d('A2uiMessage emitted to stream');
          } catch (e) {
            logger.e('Failed to parse as GenUI JSON: $e');
            _textResponseController.add(aiResponse);
          }
        } else {
          // Plain text response
          //logger.d('Emitting plain text response');
          _textResponseController.add(aiResponse);
        }
      } else {
        _errorController.add(
          ContentGeneratorError(
            'Failed to get response: ${response.statusCode}',
            StackTrace.current,
          ),
        );
      }
    } catch (e, stackTrace) {
      _errorController.add(ContentGeneratorError(e.toString(), stackTrace));
    } finally {
      _isProcessing.value = false;
    }
  }

  /// Starts a new session with the LLM backend.
  ///
  /// [sessionId] is the unique ID for the session.
  /// [modelName] is the name of the model to use (e.g., 'google/gemma-3-4b-it').
  /// [history] is an optional list of previous messages to restore context.
  Future<void> startSession({
    required String sessionId,
    String modelName = 'google/gemma-3-4b-it',
    List<String>? history,
  }) async {
    try {
      String? llmServiceUrl = MainApp.llmServiceUrl.valueOrNull;
      if (llmServiceUrl == null || llmServiceUrl.isEmpty) {
        throw Exception('LLM Service is not running.');
      }

      // Update the internal session ID
      _sessionId = sessionId;

      final Map<String, dynamic> body = {
        "model_name": modelName,
        "session_id": sessionId,
      };

      if (history != null) {
        body["history"] = history;
      }

      final response = await _client.post(
        Uri.parse("$llmServiceUrl/start-session"),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        logger.e('Failed to start session: ${response.body}');
        throw Exception('Failed to start session: ${response.statusCode}');
      }

      logger.d('Session started successfully: $_sessionId');
    } catch (e) {
      logger.e('Error starting session: $e');
      rethrow;
    }
  }

  /// Restores GenUI history by re-emitting GenUI messages.
  ///
  /// This allows the UI to rebuild the state of GenUI components when reloading a session.
  void restoreHistory(List<dynamic> messageJsons) {
    for (final messageJson in messageJsons) {
      try {
        if (messageJson is Map && messageJson.containsKey('surfaceUpdate')) {
          // It's likely a raw update, wrapper it or treat as is depending on A2uiMessage expectations
          // But A2uiMessage.fromJson expects the full packet usually.
          // Let's assume messageJson is the full object saved in DB.
        }
        final message = A2uiMessage.fromJson(messageJson);
        _a2uiMessageController.add(message);
      } catch (e) {
        logger.e('Failed to restore GenUI message: $e');
      }
    }
  }
}
