import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mydatatools/app_constants.dart';

/// Repository for managing AI Chat settings using [FlutterSecureStorage].
///
/// Handles storage of API keys (HuggingFace, Gemini, OpenAI, Grok) and
/// enabled/disabled states for specific models.
class AiChatSettingsRepository {
  static final AiChatSettingsRepository _instance =
      AiChatSettingsRepository._internal();
  factory AiChatSettingsRepository() => _instance;
  AiChatSettingsRepository._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      groupId: AppConstants.appName,
      synchronizable: true,
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _keyHuggingFaceKey = 'aichat_huggingface_key';
  static const String _keyHuggingFaceModels = 'aichat_huggingface_models';
  static const String _keyGeminiKey = 'aichat_gemini_key';
  static const String _keyGeminiEnabled = 'aichat_gemini_enabled';
  static const String _keyOpenAIKey = 'aichat_openai_key';
  static const String _keyOpenAIEnabled = 'aichat_openai_enabled';
  static const String _keyGrokKey = 'aichat_grok_key';
  static const String _keyGrokEnabled = 'aichat_grok_enabled';

  // New Model Specific Toggles
  static const String _keyGeminiFlashEnabled = 'aichat_gemini_flash_enabled';
  static const String _keyGeminiProEnabled = 'aichat_gemini_pro_enabled';
  static const String _keyGPT52Enabled = 'aichat_gpt_52_enabled';
  static const String _keyGPT5MiniEnabled = 'aichat_gpt_5_mini_enabled';
  static const String _keyGrok4Enabled = 'aichat_grok_4_enabled';
  static const String _keyGrok4FastEnabled = 'aichat_grok_4_fast_enabled';

  // --- Hugging Face ---
  Future<String?> getHuggingFaceKey() async {
    return await _storage.read(key: _keyHuggingFaceKey);
  }

  Future<void> setHuggingFaceKey(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _keyHuggingFaceKey);
    } else {
      await _storage.write(key: _keyHuggingFaceKey, value: value);
    }
  }

  Future<List<Map<String, dynamic>>> getHuggingFaceModels() async {
    final String? jsonString = await _storage.read(key: _keyHuggingFaceModels);
    if (jsonString == null) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> setHuggingFaceModels(List<Map<String, dynamic>> models) async {
    await _storage.write(key: _keyHuggingFaceModels, value: jsonEncode(models));
  }

  // --- Gemini ---
  Future<String?> getGeminiKey() async {
    return await _storage.read(key: _keyGeminiKey);
  }

  Future<void> setGeminiKey(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _keyGeminiKey);
    } else {
      await _storage.write(key: _keyGeminiKey, value: value);
    }
  }

  Future<bool> getGeminiEnabled() async {
    final val = await _storage.read(key: _keyGeminiEnabled);
    return val == 'true';
  }

  Future<void> setGeminiEnabled(bool value) async {
    await _storage.write(key: _keyGeminiEnabled, value: value.toString());
  }

  Future<bool> getGeminiFlashEnabled() async {
    final val = await _storage.read(key: _keyGeminiFlashEnabled);
    return val == 'true'; // Default false
  }

  Future<void> setGeminiFlashEnabled(bool value) async {
    await _storage.write(key: _keyGeminiFlashEnabled, value: value.toString());
  }

  Future<bool> getGeminiProEnabled() async {
    final val = await _storage.read(key: _keyGeminiProEnabled);
    return val == 'true'; // Default false
  }

  Future<void> setGeminiProEnabled(bool value) async {
    await _storage.write(key: _keyGeminiProEnabled, value: value.toString());
  }

  // --- OpenAI ---
  Future<String?> getOpenAIKey() async {
    return await _storage.read(key: _keyOpenAIKey);
  }

  Future<void> setOpenAIKey(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _keyOpenAIKey);
    } else {
      await _storage.write(key: _keyOpenAIKey, value: value);
    }
  }

  Future<bool> getOpenAIEnabled() async {
    final val = await _storage.read(key: _keyOpenAIEnabled);
    return val == 'true';
  }

  Future<void> setOpenAIEnabled(bool value) async {
    await _storage.write(key: _keyOpenAIEnabled, value: value.toString());
  }

  Future<bool> getGPT52Enabled() async {
    final val = await _storage.read(key: _keyGPT52Enabled);
    return val == 'true';
  }

  Future<void> setGPT52Enabled(bool value) async {
    await _storage.write(key: _keyGPT52Enabled, value: value.toString());
  }

  Future<bool> getGPT5MiniEnabled() async {
    final val = await _storage.read(key: _keyGPT5MiniEnabled);
    return val == 'true';
  }

  Future<void> setGPT5MiniEnabled(bool value) async {
    await _storage.write(key: _keyGPT5MiniEnabled, value: value.toString());
  }

  // --- Grok ---
  Future<String?> getGrokKey() async {
    return await _storage.read(key: _keyGrokKey);
  }

  Future<void> setGrokKey(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _keyGrokKey);
    } else {
      await _storage.write(key: _keyGrokKey, value: value);
    }
  }

  Future<bool> getGrokEnabled() async {
    final val = await _storage.read(key: _keyGrokEnabled);
    return val == 'true';
  }

  Future<void> setGrokEnabled(bool value) async {
    await _storage.write(key: _keyGrokEnabled, value: value.toString());
  }

  Future<bool> getGrok4Enabled() async {
    final val = await _storage.read(key: _keyGrok4Enabled);
    return val == 'true';
  }

  Future<void> setGrok4Enabled(bool value) async {
    await _storage.write(key: _keyGrok4Enabled, value: value.toString());
  }

  Future<bool> getGrok4FastEnabled() async {
    final val = await _storage.read(key: _keyGrok4FastEnabled);
    return val == 'true';
  }

  Future<void> setGrok4FastEnabled(bool value) async {
    await _storage.write(key: _keyGrok4FastEnabled, value: value.toString());
  }
}
