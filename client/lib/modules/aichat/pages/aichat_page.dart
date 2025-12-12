import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/modules/aichat/services/local_llm_content_generator.dart';
import 'package:mydatatools/modules/aichat/ui/genui_image.dart';
import 'package:mydatatools/python_manager.dart';
import 'package:uuid/v4.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/chat_session.dart';
import 'package:mydatatools/models/tables/chat_message.dart' as db_model;
import 'dart:convert'; // For jsonEncode

class AichatPage extends StatefulWidget {
  const AichatPage({super.key});

  @override
  State<AichatPage> createState() => _AichatPage();
}

sealed class ChatItem {}

class TextMessageItem extends ChatItem {
  final String role;
  final String text;
  TextMessageItem({required this.role, required this.text});
}

class GenUiSurfaceItem extends ChatItem {
  final String surfaceId;
  GenUiSurfaceItem({required this.surfaceId});
}

class _AichatPage extends State<AichatPage> {
  AppLogger logger = AppLogger(null);
  bool _isLLMServiceRunning = PythonManager.isLLMServiceRunning.value;
  String _selectedModel = 'google/gemma-3-4b-it';
  final List<Map<String, String>> _models = [
    {'label': 'Local LLM', 'value': 'google/gemma-3-4b-it'},
    {'label': 'Gemini Flash (web)', 'value': 'gemini-2.5-flash'},
    {'label': 'Gemini Pro (web)', 'value': 'gemini-2.5-pro'},
    {'label': 'Gemini 3 Pro (Image)', 'value': 'gemini-3-pro-images'},
  ];
  final _textController = TextEditingController();

  late final LocalLlmContentGenerator _contentGenerator;
  bool _isGenerating = false;
  late final GenUiManager _genUiManager;
  late final GenUiConversation _genUiConversation;
  final List<ChatItem> _chatItems = [];
  String sessionId = UuidV4().generate().replaceAll('-', '');

  @override
  void initState() {
    super.initState();

    // Save initial session
    _saveSession();

    // listen for changes
    PythonManager.isLLMServiceRunning.addListener(() {
      if (mounted) {
        _contentGenerator
            .startSession(
              sessionId: sessionId,
              modelName: _selectedModel,
              history: [],
            )
            .then((_) {
              setState(() {
                _isLLMServiceRunning = PythonManager.isLLMServiceRunning.value;
              });
            })
            .catchError((error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to start new session: $error')),
              );
            });
      }
    });

    _genUiManager = GenUiManager(
      catalog: CoreCatalogItems.asCatalog().copyWith([
        CatalogItem(
          name: 'Image',
          dataSchema: S.object(),
          widgetBuilder: (context) {
            return GenUiImage(component: context.data as Map<String, dynamic>);
          },
        ),
      ]),
    );

    _contentGenerator = LocalLlmContentGenerator(
      systemInstruction: 'You are a helpful assistant.',
      sessionId: sessionId,
    );

    _contentGenerator.isProcessing.addListener(() {
      if (mounted) {
        setState(() {
          _isGenerating = _contentGenerator.isProcessing.value;
        });
      }
    });

    // Listen to raw GenUI messages for saving to DB
    _contentGenerator.rawGenUiMessageStream.listen(
      (messageJson) {
        //logger.d('DEBUG: rawGenUiMessageStream received: $messageJson');
        _saveGenUiMessage(messageJson);
      },
      onError: (error) {
        //logger.e('DEBUG: rawGenUiMessageStream error: $error');
      },
    );

    // Listen to text responses from the generator for non-UI messages
    _contentGenerator.textResponseStream.listen((text) {
      logger.d('DEBUG: textResponseStream received: $text');
      if (mounted) {
        setState(() {
          _chatItems.add(TextMessageItem(role: 'assistant', text: text));
        });
        _saveTextMessage('assistant', text);
      }
    });

    // Debug: Listen to surfaceUpdates directly
    _genUiManager.surfaceUpdates.listen((event) {
      //logger.d('DEBUG: GenUiManager emitted event: $event');
    });

    // logger.d('Creating GenUiConversation...');
    _genUiConversation = GenUiConversation(
      genUiManager: _genUiManager,
      contentGenerator: _contentGenerator,
      onSurfaceAdded: _onSurfaceAdded,
      onSurfaceUpdated: (event) {
        //logger.d('SurfaceUpdated event: ${event.surfaceId}');
        _addSurfaceId(event.surfaceId);
      },
      onSurfaceDeleted: _onSurfaceDeleted,
      onError: (error) {
        logger.e('GenUiConversation error: $error');
      },
    );
    // logger.d('GenUiConversation created');
  }

  Future<void> _saveSession() async {
    final session = ChatSession(
      id: sessionId,
      model: _selectedModel,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await DatabaseManager.instance.send({
      'type': 'chat_session',
      'object': session,
    });
  }

  Future<void> _saveTextMessage(String role, String text) async {
    final message = db_model.ChatMessage(
      id: UuidV4().generate(),
      sessionId: sessionId,
      role: role,
      content: text,
      createdAt: DateTime.now(),
    );
    await DatabaseManager.instance.send({
      'type': 'chat_message',
      'object': message,
    });
  }

  Future<void> _saveGenUiMessage(dynamic messageData) async {
    // messageData is likely the raw message from LLM or backend.
    // We save it as a message with role 'genui_data' or similar if it's not a standard role,
    // or just 'model' with data payload.
    // Assuming messageData can be JSON encoded.
    final message = db_model.ChatMessage(
      id: UuidV4().generate(),
      sessionId: sessionId,
      role: 'model_genui', // Distinguish from plain text
      content: 'GenUI Data',
      data: jsonEncode(messageData),
      createdAt: DateTime.now(),
    );
    await DatabaseManager.instance.send({
      'type': 'chat_message',
      'object': message,
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _genUiConversation.dispose();
    _contentGenerator.dispose();
    super.dispose();
  }

  void _addSurfaceId(String surfaceId) {
    // Check if surface is already in the list
    final exists = _chatItems.any(
      (item) => item is GenUiSurfaceItem && item.surfaceId == surfaceId,
    );

    if (!exists) {
      setState(() {
        _chatItems.add(GenUiSurfaceItem(surfaceId: surfaceId));
      });
      // logger.d('Surface added to list: $surfaceId');
      //  logger.d('Total items: ${_chatItems.length}');
    }
  }

  void _onSurfaceAdded(SurfaceAdded event) {
    // logger.d('SurfaceAdded event: ${event.surfaceId}');
    _addSurfaceId(event.surfaceId);
  }

  void _onSurfaceDeleted(SurfaceRemoved update) {
    // logger.d('Surface deleted: ${update.surfaceId}');
    setState(() {
      _chatItems.removeWhere(
        (item) =>
            item is GenUiSurfaceItem && item.surfaceId == update.surfaceId,
      );
    });
  }

  void _sendMessage(String message) {
    if (message.trim().isEmpty) {
      return;
    }

    if (!_isLLMServiceRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LLM Service is not running.')),
      );
      return;
    }

    // Add user message to chat items
    setState(() {
      _chatItems.add(TextMessageItem(role: 'user', text: message.trim()));
    });
    _saveTextMessage('user', message.trim());

    _genUiConversation.sendRequest(UserMessage.text(message.trim()));
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLLMServiceRunning) {
      return const Center(child: Text("LLM Service is starting..."));
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text("AI Chat"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(height: 1.0, color: Colors.grey.shade300),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            tooltip: 'New Session',
            onPressed: () {
              // Clear local chat history
              setState(() {
                _chatItems.clear();
              });

              //assign new session id
              sessionId = UuidV4().generate().replaceAll('-', '');
              _saveSession();

              // Call service to start new session with empty history
              _contentGenerator
                  .startSession(
                    sessionId: sessionId,
                    modelName: _selectedModel,
                    history: [],
                  )
                  .then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('New session started')),
                    );
                  })
                  .catchError((error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to start new session: $error'),
                      ),
                    );
                  });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(
                bottom: 20,
                left: 16,
                right: 16,
                top: 16,
              ),
              itemCount: _chatItems.length,
              itemBuilder: (context, index) {
                final item = _chatItems[index];

                if (item is TextMessageItem) {
                  final isUser = item.role == 'user';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isUser
                                  ? Colors.blueAccent.withOpacity(0.9)
                                  : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          item.text,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                } else if (item is GenUiSurfaceItem) {
                  // logger.d('Rendering GenUiSurface for surface: ${item.surfaceId}',);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: GenUiSurface(
                      host: _genUiConversation.host,
                      surfaceId: item.surfaceId,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                  color: Colors.grey.withOpacity(0.1),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.0),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 3),
                    blurRadius: 5,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _textController,
                    onSubmitted: _sendMessage,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: "Ask me anything...",
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: 'Add Files',
                          onPressed: () {
                            // TODO: implement file picking
                          },
                        ),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _selectedModel,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedModel = newValue;
                              });

                              // Get the label for the snackbar message
                              final selectedModelLabel =
                                  _models.firstWhere(
                                    (m) => m['value'] == newValue,
                                  )['label'];

                              // Switch model for current session, preserving history
                              _contentGenerator
                                  .startSession(
                                    sessionId: sessionId,
                                    modelName: newValue,
                                    history:
                                        null, // Pass null to preserve history on server
                                  )
                                  .then((_) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Switched to $selectedModelLabel',
                                        ),
                                      ),
                                    );
                                  })
                                  .catchError((error) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to switch model: $error',
                                        ),
                                      ),
                                    );
                                  });
                            }
                          },
                          items:
                              _models.map<DropdownMenuItem<String>>((
                                Map<String, String> model,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: model['value'],
                                  child: Text(model['label']!),
                                );
                              }).toList(),
                          underline: Container(),
                        ),
                        _isGenerating
                            ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                ),
                              ),
                            )
                            : IconButton(
                              icon: const Icon(Icons.send),
                              tooltip: 'Send',
                              onPressed: () {
                                _sendMessage(_textController.text);
                              },
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
