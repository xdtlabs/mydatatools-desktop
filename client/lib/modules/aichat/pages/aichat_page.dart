import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:mydatatools/app_logger.dart';
import 'package:mydatatools/modules/aichat/services/local_llm_content_generator.dart';
import 'package:mydatatools/python_manager.dart';

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
  String _selectedModel = 'Local LLM';
  final List<String> _models = ['Local LLM', 'Gemini', 'ChatGPT', 'Grok'];
  final _textController = TextEditingController();

  late final LocalLlmContentGenerator _contentGenerator;
  bool _isGenerating = false;
  late final GenUiManager _genUiManager;
  late final GenUiConversation _genUiConversation;
  final List<ChatItem> _chatItems = [];

  @override
  void initState() {
    super.initState();

    // listen for changes
    PythonManager.isLLMServiceRunning.addListener(() {
      if (mounted) {
        setState(() {
          _isLLMServiceRunning = PythonManager.isLLMServiceRunning.value;
        });
      }
    });

    _genUiManager = GenUiManager(catalog: CoreCatalogItems.asCatalog());

    _contentGenerator = LocalLlmContentGenerator(
      systemInstruction: 'You are a helpful assistant.',
    );

    _contentGenerator.isProcessing.addListener(() {
      if (mounted) {
        setState(() {
          _isGenerating = _contentGenerator.isProcessing.value;
        });
      }
    });

    // Debug: Listen to a2uiMessageStream to see if messages are flowing
    // This must be done BEFORE creating GenUiConversation
    _contentGenerator.a2uiMessageStream.listen(
      (message) {
        //logger.d('DEBUG: a2uiMessageStream received message: $message');
      },
      onError: (error) {
        //logger.e('DEBUG: a2uiMessageStream error: $error');
      },
      onDone: () {
        //logger.d('DEBUG: a2uiMessageStream done');
      },
    );

    // Listen to text responses from the generator for non-UI messages
    _contentGenerator.textResponseStream.listen((text) {
      logger.d('DEBUG: textResponseStream received: $text');
      if (mounted) {
        setState(() {
          _chatItems.add(TextMessageItem(role: 'assistant', text: text));
        });
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
      logger.d('Surface added to list: $surfaceId');
      logger.d('Total items: ${_chatItems.length}');
    }
  }

  void _onSurfaceAdded(SurfaceAdded event) {
    logger.d('SurfaceAdded event: ${event.surfaceId}');
    _addSurfaceId(event.surfaceId);
  }

  void _onSurfaceDeleted(SurfaceRemoved update) {
    logger.d('Surface deleted: ${update.surfaceId}');
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
      _chatItems.add(TextMessageItem(role: 'user', text: message));
    });

    _genUiConversation.sendRequest(UserMessage.text(message));
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLLMServiceRunning) {
      return const Center(
        child: Text("LLM Service is not running or is still starting up."),
      );
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('todo: new session')),
              );
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
                            }
                          },
                          items:
                              _models.map<DropdownMenuItem<String>>((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
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
