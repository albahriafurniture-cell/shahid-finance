import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// v1.1.9: ghost AI writing suggestions for Journal entries.
///
/// The user types, and ~700ms after they stop, a faint continuation
/// suggestion appears under the entry field. It is NEVER auto-inserted:
/// only an explicit tap on the suggestion (or its Accept button)
/// appends it. Typing, the keyboard, and saving are never blocked,
/// and any failure silently yields "no suggestion" — never a crash
/// or a raw error in the editor.
///
/// HONEST CONSTRAINT: there is no API key in this repo or in the
/// user's records, and none is invented, hardcoded, or faked here.
/// The model is an OPEN-WEIGHT model behind an OpenAI-compatible
/// endpoint — Groq's `llama-3.1-8b-instant` (good quality, free
/// tier) by default — and the key comes ONLY from the user's own
/// free account, pasted once in the Diary AI setup sheet. The key
/// lives ONLY in flutter_secure_storage on this phone: never in
/// Hive, never in cloud backup, never in code. Only the journal
/// text the user is currently typing is sent to the endpoint, and
/// only when a key is saved — nothing from the vault or finance
/// data ever reaches it.
class AiSuggestConfig {
  final String endpoint;
  final String model;
  final String apiKey;
  const AiSuggestConfig({
    required this.endpoint,
    required this.model,
    required this.apiKey,
  });

  bool get hasKey => apiKey.isNotEmpty;
}

const defaultAiEndpoint =
    'https://api.groq.com/openai/v1/chat/completions';
const defaultAiModel = 'llama-3.1-8b-instant';

const _keyEndpoint = 'ai_endpoint';
const _keyModel = 'ai_model';
const _keyApiKey = 'ai_api_key';

/// JSON poster, injectable so tests never hit a real API.
typedef AiPost = Future<Map<String, dynamic>?> Function(
    Uri url, Map<String, String> headers, String body);

Future<Map<String, dynamic>?> _defaultPost(
    Uri url, Map<String, String> headers, String body) async {
  try {
    final client = HttpClient();
    try {
      final req = await client.postUrl(url);
      headers.forEach(req.headers.set);
      req.write(body);
      final resp = await req.close().timeout(const Duration(seconds: 20));
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } finally {
      client.close();
    }
  } catch (_) {
    return null;
  }
}

/// Prompt construction, kept pure for tests: one short continuation,
/// same language as the user's text, never repeating their text.
Map<String, dynamic> aiSuggestRequestBody(String text, String model) {
  return {
    'model': model,
    'temperature': 0.7,
    'max_tokens': 60,
    'messages': [
      {
        'role': 'system',
        'content':
            'You are a writing assistant continuing the user\'s personal journal entry. '
                'Reply with ONLY the natural continuation, at most one or two sentences, '
                'in the same language as the user\'s text. Never repeat the user\'s text, '
                'never add quotes, labels, or explanations.',
      },
      {'role': 'user', 'content': text},
    ],
  };
}

/// Extract the continuation from a chat-completions response, or null.
/// Strips an echoed copy of the user's text if the model repeats it.
String? aiSuggestParseResponse(
    Map<String, dynamic>? json, String userText) {
  try {
    final choices = json?['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final message = choices.first['message'];
    final content = message?['content'];
    if (content is! String) return null;
    var out = content.trim();
    if (out.isEmpty) return null;
    // Echo guard: drop a leading copy of the user's own text.
    final trimmedUser = userText.trim();
    if (trimmedUser.isNotEmpty && out.startsWith(trimmedUser)) {
      out = out.substring(trimmedUser.length).trim();
    }
    // Strip wrapping quotes the model sometimes adds.
    if (out.length >= 2 &&
        ((out.startsWith('"') && out.endsWith('"')) ||
            (out.startsWith("'") && out.endsWith("'")))) {
      out = out.substring(1, out.length - 1).trim();
    }
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}

class AiSuggestService {
  static const _storage = FlutterSecureStorage();
  final AiPost _post;

  AiSuggestService({AiPost? post}) : _post = post ?? _defaultPost;

  static Future<AiSuggestConfig?> loadConfig() async {
    try {
      final key = await _storage.read(key: _keyApiKey);
      if (key == null || key.isEmpty) return null;
      final endpoint =
          await _storage.read(key: _keyEndpoint) ?? defaultAiEndpoint;
      final model = await _storage.read(key: _keyModel) ?? defaultAiModel;
      return AiSuggestConfig(
          endpoint: endpoint, model: model, apiKey: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveConfig(AiSuggestConfig config) async {
    await _storage.write(key: _keyApiKey, value: config.apiKey);
    await _storage.write(key: _keyEndpoint, value: config.endpoint);
    await _storage.write(key: _keyModel, value: config.model);
  }

  static Future<void> clearConfig() async {
    await _storage.delete(key: _keyApiKey);
  }

  /// One suggestion, or null: no key, too little text, any failure.
  /// Never throws.
  Future<String?> suggest(String text, {AiSuggestConfig? config}) async {
    try {
      final cfg = config ?? await loadConfig();
      if (cfg == null || !cfg.hasKey) return null;
      if (text.trim().length < 3) return null;
      final body = jsonEncode(aiSuggestRequestBody(text, cfg.model));
      final json = await _post(
        Uri.parse(cfg.endpoint),
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${cfg.apiKey}',
        },
        body,
      );
      return aiSuggestParseResponse(json, text);
    } catch (_) {
      return null;
    }
  }
}

/// Debounced front-end: only the latest text gets a network call,
/// ~700ms after typing stops; stale results are dropped.
class AiSuggester {
  final AiSuggestService _service;
  final Duration debounce;
  final AiSuggestConfig? config;
  Timer? _timer;
  int _seq = 0;

  AiSuggester(
      {AiSuggestService? service,
      this.debounce = const Duration(milliseconds: 700),
      this.config})
      : _service = service ?? AiSuggestService();

  void request(String text, void Function(String?) onResult) {
    _timer?.cancel();
    final seq = ++_seq;
    if (text.trim().length < 3) {
      onResult(null);
      return;
    }
    _timer = Timer(debounce, () async {
      final suggestion = await _service.suggest(text, config: config);
      if (seq == _seq) onResult(suggestion);
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
