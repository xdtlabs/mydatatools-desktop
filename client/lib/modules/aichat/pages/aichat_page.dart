import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:mydatatools/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:mydatatools/main.dart';
import 'package:mydatatools/python_manager.dart';
// fetch the response from the selected LLM service

class AichatPage extends StatefulWidget {
  const AichatPage({super.key});

  @override
  State<AichatPage> createState() => _AichatPage();
}

class _AichatPage extends State<AichatPage> {
  AppLogger logger = AppLogger(null);
  bool _isChatLoading = false;
  bool _isLLMServiceRunning = PythonManager.isLLMServiceRunning.value;
  String _selectedModel = 'Local LLM';
  final List<String> _models = ['Local LLM', 'Gemini', 'ChatGPT', 'Grok'];
  final _textController = TextEditingController();
  final List<Map<String, dynamic>> _chatHistory = <Map<String, dynamic>>[
    {
      "role": "model",
      "parts": ["You are a helpful assistant."],
    },
    {
      "role": "user",
      "parts": ["Hello!"],
    },
  ];

  @override
  void initState() {
    //get all chat sessions
    //_collectionService?.invoke(GetCollectionsServiceCommand("email"));

    // listen for changes
    PythonManager.isLLMServiceRunning.addListener(() {
      setState(() {
        _isLLMServiceRunning = PythonManager.isLLMServiceRunning.value;
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage(String message) async {
    if (message.trim().isEmpty) {
      return;
    }

    String? llmServiceUrl = MainApp.llmServiceUrl.valueOrNull;
    if (llmServiceUrl == null || llmServiceUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LLM Service is not running.')),
      );
      return;
    }

    // add user message to chat history
    setState(() {
      _isChatLoading = true;
      _chatHistory.add({
        "role": "user",
        "parts": [message],
      });
    });

    // call url with message and show response
    final session = await http.post(
      Uri.parse("$llmServiceUrl/start-session"),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, dynamic>{"model_name": "google/gemma-3-4b-it"}),
    );

    if (200 != session.statusCode) {
      logger.e('Failed to start session: ${session.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting session: ${session.statusCode}'),
        ),
      );
      return;
    }

    http
        .post(
          Uri.parse("$llmServiceUrl/chat"),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, dynamic>{
            "prompt": message,
            "system_instruction": "You are a helpful assistant.",
          }),
        )
        .then((response) {
          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            logger.d('Received response: $responseData');

            setState(() {
              _isChatLoading = false;
              _chatHistory.add({
                "role": "model",
                "parts": [responseData['ai_response']],
              });
            });
          } else {
            logger.e('Failed to get response: ${response.statusCode}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${response.statusCode}')),
            );
          }
        })
        .catchError((error) {
          logger.e('Error sending message: $error');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $error')));
        });

    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    //final theme = Theme.of(context);

    if (!_isLLMServiceRunning) {
      return const Center(
        child: Text("LLM Service is not running or is still starting up."),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text("AI Chat"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(height: 1.0, color: Colors.grey.shade300),
        ),
        actions: <Widget>[
          IconButton(
            // TODO: disable is no files are checked
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
      body: Stack(
        children: <Widget>[
          // TODO: This will be the chat history
          Positioned.fill(
            child: Container(
              padding: const EdgeInsets.only(bottom: 200, left: 16, right: 16),
              child: ListView.builder(
                itemCount: _chatHistory.length,
                itemBuilder: (context, index) {
                  final entry = _chatHistory[index];
                  final role =
                      (entry['role'] as String?)?.toLowerCase() ?? 'model';
                  final parts =
                      (entry['parts'] as List<dynamic>?)?.cast<String>() ??
                      <String>[];
                  final text = parts.join('\n');
                  final isUser = role == 'user';
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
                          text,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Center(
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
                      minLines: 3,
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
                            underline:
                                Container(), // Hides the default underline
                          ),
                          IconButton(
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
          ),
        ],
      ),
    );
  }
}
