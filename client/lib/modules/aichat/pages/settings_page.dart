import 'package:flutter/material.dart';
import 'package:mydatatools/modules/aichat/repositories/aichat_settings_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _repository = AiChatSettingsRepository();

  // Hugging Face
  final _hfKeyController = TextEditingController();
  final _hfModelController = TextEditingController();
  final _hfLabelController = TextEditingController();
  static const _defaultLocalModel = 'google/gemma-3-4b-it';
  List<Map<String, dynamic>> _hfModels = [];

  // Gemini
  final _geminiKeyController = TextEditingController();
  bool _geminiFlashEnabled = false;
  bool _geminiProEnabled = false;

  // OpenAI
  final _openaiKeyController = TextEditingController();
  bool _gpt52Enabled = false;
  bool _gpt5MiniEnabled = false;

  // Grok
  final _grokKeyController = TextEditingController();
  bool _grok4Enabled = false;
  bool _grok4FastEnabled = false;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final hfKey = await _repository.getHuggingFaceKey();
    final hfModels = await _repository.getHuggingFaceModels();
    final geminiKey = await _repository.getGeminiKey();
    final geminiFlashEnabled = await _repository.getGeminiFlashEnabled();
    final geminiProEnabled = await _repository.getGeminiProEnabled();

    final openaiKey = await _repository.getOpenAIKey();
    final gpt52Enabled = await _repository.getGPT52Enabled();
    final gpt5MiniEnabled = await _repository.getGPT5MiniEnabled();

    final grokKey = await _repository.getGrokKey();
    final grok4Enabled = await _repository.getGrok4Enabled();
    final grok4FastEnabled = await _repository.getGrok4FastEnabled();

    if (mounted) {
      setState(() {
        _hfKeyController.text = hfKey ?? '';
        _hfModels = hfModels;
        _geminiKeyController.text = geminiKey ?? '';
        _geminiFlashEnabled = geminiFlashEnabled;
        _geminiProEnabled = geminiProEnabled;

        _openaiKeyController.text = openaiKey ?? '';
        _gpt52Enabled = gpt52Enabled;
        _gpt5MiniEnabled = gpt5MiniEnabled;

        _grokKeyController.text = grokKey ?? '';
        _grok4Enabled = grok4Enabled;
        _grok4FastEnabled = grok4FastEnabled;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _hfKeyController.dispose();
    _hfModelController.dispose();
    _hfLabelController.dispose();
    _geminiKeyController.dispose();
    _openaiKeyController.dispose();
    _grokKeyController.dispose();
    super.dispose();
  }

  // --- Save Handlers ---

  Future<void> _saveHuggingFaceKey(String value) async {
    setState(() {}); // specific key update to refresh UI state for buttons
    await _repository.setHuggingFaceKey(value);
  }

  Future<void> _addHuggingFaceModel() async {
    if (_hfModelController.text.isEmpty || _hfLabelController.text.isEmpty) {
      return;
    }
    setState(() {
      _hfModels.add({
        'name': _hfModelController.text, // Model ID/Value
        'label': _hfLabelController.text, // Friendly Name
        'enabled': true,
      });
      _hfModelController.clear();
      _hfLabelController.clear();
    });
    await _repository.setHuggingFaceModels(_hfModels);
  }

  Future<void> _toggleHuggingFaceModel(int index, bool value) async {
    setState(() {
      _hfModels[index]['enabled'] = value;
    });
    await _repository.setHuggingFaceModels(_hfModels);
  }

  Future<void> _deleteHuggingFaceModel(int index) async {
    setState(() {
      _hfModels.removeAt(index);
    });
    await _repository.setHuggingFaceModels(_hfModels);
  }

  Future<void> _saveGeminiKey(String value) async {
    setState(() {});
    await _repository.setGeminiKey(value);

    // Auto-enable logic
    if (value.isNotEmpty) {
      await _toggleGemini(true);
      await _toggleGeminiFlash(true);
      await _toggleGeminiPro(true);
    } else {
      await _toggleGemini(false);
      // We don't force disable individual preferences if key is cleared,
      // but UI will show them as disabled.
      // However, requirement says "when key is set automatically enable all".
      // Usually resetting to false on clear is good practice so they toggle back ON next time.
      await _toggleGeminiFlash(false);
      await _toggleGeminiPro(false);
    }
  }

  Future<void> _toggleGemini(bool value) async {
    await _repository.setGeminiEnabled(value);
  }

  Future<void> _toggleGeminiFlash(bool value) async {
    setState(() => _geminiFlashEnabled = value);
    await _repository.setGeminiFlashEnabled(value);
  }

  Future<void> _toggleGeminiPro(bool value) async {
    setState(() => _geminiProEnabled = value);
    await _repository.setGeminiProEnabled(value);
  }

  Future<void> _saveOpenAIKey(String value) async {
    setState(() {});
    await _repository.setOpenAIKey(value);

    if (value.isNotEmpty) {
      await _toggleOpenAI(true);
      await _toggleGPT52(true);
      await _toggleGPT5Mini(true);
    } else {
      await _toggleOpenAI(false);
      await _toggleGPT52(false);
      await _toggleGPT5Mini(false);
    }
  }

  Future<void> _toggleOpenAI(bool value) async {
    await _repository.setOpenAIEnabled(value);
  }

  Future<void> _toggleGPT52(bool value) async {
    setState(() => _gpt52Enabled = value);
    await _repository.setGPT52Enabled(value);
  }

  Future<void> _toggleGPT5Mini(bool value) async {
    setState(() => _gpt5MiniEnabled = value);
    await _repository.setGPT5MiniEnabled(value);
  }

  Future<void> _saveGrokKey(String value) async {
    setState(() {});
    await _repository.setGrokKey(value);

    if (value.isNotEmpty) {
      await _toggleGrok(true);
      await _toggleGrok4(true);
      await _toggleGrok4Fast(true);
    } else {
      await _toggleGrok(false);
      await _toggleGrok4(false);
      await _toggleGrok4Fast(false);
    }
  }

  Future<void> _toggleGrok(bool value) async {
    await _repository.setGrokEnabled(value);
  }

  Future<void> _toggleGrok4(bool value) async {
    setState(() => _grok4Enabled = value);
    await _repository.setGrok4Enabled(value);
  }

  Future<void> _toggleGrok4Fast(bool value) async {
    setState(() => _grok4FastEnabled = value);
    await _repository.setGrok4FastEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Chat Settings'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHuggingFaceSection(),
          const Divider(height: 32),
          _buildGeminiSection(),
          const Divider(height: 32),
          _buildOpenAISection(),
          const Divider(height: 32),
          _buildGrokSection(),
        ],
      ),
    );
  }

  Widget _buildHuggingFaceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hugging Face', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _hfKeyController,
          decoration: const InputDecoration(
            labelText: 'API Key',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vpn_key),
          ),
          obscureText: true,
          onChanged: _saveHuggingFaceKey,
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 1,
              child: TextField(
                controller: _hfLabelController,
                decoration: const InputDecoration(
                  labelText: 'Label (e.g., My Custom Model)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _hfModelController,
                decoration: const InputDecoration(
                  labelText: 'Model Name (e.g., google/gemma-3-4b-it)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed:
                  _hfKeyController.text.isNotEmpty &&
                          _hfModelController.text.isNotEmpty &&
                          _hfLabelController.text.isNotEmpty
                      ? _addHuggingFaceModel
                      : null,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Models', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Default Local Model (Always visible, always enabled, no delete)
        ListTile(
          title: const Text('Local LLM'),
          subtitle: const Text(_defaultLocalModel),
          trailing: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // No switch, implies always enabled
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Text(
                  'Always On',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        if (_hfModels.isNotEmpty) ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _hfModels.length,
            itemBuilder: (context, index) {
              final model = _hfModels[index];
              final label = model['label'] ?? model['name'];
              final value = model['name'];
              return ListTile(
                title: Text(label),
                subtitle: value != label ? Text(value) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: model['enabled'] ?? true,
                      onChanged: (val) => _toggleHuggingFaceModel(index, val),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteHuggingFaceModel(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildGeminiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Google Gemini', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _geminiKeyController,
          decoration: const InputDecoration(
            labelText: 'Gemini API Key',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vpn_key),
          ),
          obscureText: true,
          onChanged: _saveGeminiKey,
        ),
        if (_geminiKeyController.text.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Text(
              'API Key required to enable models',
              style: TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Gemini Flash'),
                value:
                    _geminiFlashEnabled && _geminiKeyController.text.isNotEmpty,
                onChanged:
                    _geminiKeyController.text.isNotEmpty
                        ? _toggleGeminiFlash
                        : null,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Gemini Pro'),
                value:
                    _geminiProEnabled && _geminiKeyController.text.isNotEmpty,
                onChanged:
                    _geminiKeyController.text.isNotEmpty
                        ? _toggleGeminiPro
                        : null,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpenAISection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('OpenAI', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _openaiKeyController,
          decoration: const InputDecoration(
            labelText: 'OpenAI API Key',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vpn_key),
          ),
          obscureText: true,
          onChanged: _saveOpenAIKey,
        ),
        if (_openaiKeyController.text.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Text(
              'API Key required to enable models',
              style: TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('GPT 5.2'),
                value: _gpt52Enabled && _openaiKeyController.text.isNotEmpty,
                onChanged:
                    _openaiKeyController.text.isNotEmpty ? _toggleGPT52 : null,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('GPT 5 Mini'),
                value: _gpt5MiniEnabled && _openaiKeyController.text.isNotEmpty,
                onChanged:
                    _openaiKeyController.text.isNotEmpty
                        ? _toggleGPT5Mini
                        : null,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrokSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grok', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _grokKeyController,
          decoration: const InputDecoration(
            labelText: 'Grok API Key',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vpn_key),
          ),
          obscureText: true,
          onChanged: _saveGrokKey,
        ),
        if (_grokKeyController.text.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Text(
              'API Key required to enable models',
              style: TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Grok 4'),
                value: _grok4Enabled && _grokKeyController.text.isNotEmpty,
                onChanged:
                    _grokKeyController.text.isNotEmpty ? _toggleGrok4 : null,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Grok 4 Fast'),
                value: _grok4FastEnabled && _grokKeyController.text.isNotEmpty,
                onChanged:
                    _grokKeyController.text.isNotEmpty
                        ? _toggleGrok4Fast
                        : null,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
