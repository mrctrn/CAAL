import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../services/config_service.dart';

/// Full settings screen accessible from welcome screen.
/// Includes server URL (required for mobile) and all agent settings.
class SettingsScreen extends StatefulWidget {
  final ConfigService configService;
  final VoidCallback onSave;

  const SettingsScreen({
    super.key,
    required this.configService,
    required this.onSave,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  String _saveStatus = '';
  String? _error;
  bool _serverConnected = false;

  // Agent settings fields
  String _agentName = 'Cal';
  List<String> _wakeGreetings = ["Hey, what's up?", "What's up?", 'How can I help?'];

  // Provider settings
  String _sttProvider = 'speaches';
  String _llmProvider = 'ollama';
  String _ollamaHost = 'http://localhost:11434';
  String _ollamaModel = '';
  String _groqApiKey = '';
  String _groqModel = '';
  String _openaiBaseUrl = '';
  String _openaiApiKey = '';
  String _openaiModel = '';
  String _openrouterApiKey = '';
  String _openrouterModel = '';
  String _ttsProvider = 'kokoro';
  String _ttsVoiceKokoro = 'am_puck';
  String _ttsVoicePiper = 'speaches-ai/piper-en_US-ryan-high';

  // Integration settings
  bool _hassEnabled = false;
  String _hassHost = '';
  String _hassToken = '';
  bool _n8nEnabled = false;
  String _n8nUrl = '';
  String _n8nToken = '';

  // LLM settings
  double _temperature = 0.15;
  int _numCtx = 8192;
  int _maxTurns = 20;
  int _toolCacheSize = 3;

  // Turn detection
  bool _allowInterruptions = true;
  double _minEndpointingDelay = 0.5;

  // Wake word
  bool _wakeWordEnabled = false;
  String _wakeWordModel = 'models/hey_cal.onnx';
  double _wakeWordThreshold = 0.5;
  double _wakeWordTimeout = 3.0;

  // Language
  String _language = 'en';

  // Available options
  List<String> _voices = [];
  List<String> _ollamaModels = [];
  List<String> _groqModels = [];
  List<String> _openaiModels = [];
  List<String> _openrouterModels = [];
  List<String> _wakeWordModels = [];

  // Test states
  bool _testingOllama = false;
  bool _ollamaConnected = false;
  String? _ollamaError;
  bool _testingGroq = false;
  bool _groqConnected = false;
  String? _groqError;
  bool _testingOpenai = false;
  bool _openaiConnected = false;
  String? _openaiError;
  bool _testingOpenrouter = false;
  bool _openrouterConnected = false;
  String? _openrouterError;
  bool _testingHass = false;
  bool _hassConnected = false;
  String? _hassError;
  String? _hassInfo;
  bool _testingN8n = false;
  bool _n8nConnected = false;
  String? _n8nError;

  // Text controllers
  final _wakeGreetingsController = TextEditingController();

  String get _webhookUrl {
    final serverUrl = _serverUrlController.text.trim();
    if (serverUrl.isEmpty) return '';
    final uri = Uri.tryParse(serverUrl);
    if (uri == null) return '';
    return 'http://${uri.host}:8889';
  }

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = widget.configService.serverUrl;
    // Try to load settings if server is configured
    if (widget.configService.isConfigured) {
      unawaited(_loadSettings());
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _wakeGreetingsController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final webhookUrl = _webhookUrl;
    if (webhookUrl.isEmpty) {
      setState(() {
        _error = 'Enter a valid server URL first';
        _serverConnected = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse('$webhookUrl/settings')).timeout(
            const Duration(seconds: 5),
          );
      if (response.statusCode == 200) {
        setState(() {
          _serverConnected = true;
        });
        await _loadSettings();
      } else {
        setState(() {
          _serverConnected = false;
          _error = 'Server returned ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _serverConnected = false;
        _error = 'Could not connect to server';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    final webhookUrl = _webhookUrl;
    if (webhookUrl.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // First load settings to get the correct tts_provider
      final settingsRes = await http.get(Uri.parse('$webhookUrl/settings'));

      String ttsProvider = _ttsProvider;
      if (settingsRes.statusCode == 200) {
        final data = jsonDecode(settingsRes.body);
        final settings = data['settings'] ?? {};
        ttsProvider = settings['tts_provider'] ?? _ttsProvider;
      }

      // Now fetch voices with the correct provider, plus wake word models
      final results = await Future.wait([
        http.get(Uri.parse('$webhookUrl/voices?provider=$ttsProvider')),
        http.get(Uri.parse('$webhookUrl/wake-word/models')),
      ]);

      final voicesRes = results[0];
      final wakeWordModelsRes = results[1];

      if (settingsRes.statusCode == 200) {
        final data = jsonDecode(settingsRes.body);
        final settings = data['settings'] ?? {};

        setState(() {
          _serverConnected = true;
          // Agent
          _agentName = settings['agent_name'] ?? _agentName;
          _wakeGreetings = List<String>.from(settings['wake_greetings'] ?? _wakeGreetings);
          _wakeGreetingsController.text = _wakeGreetings.join('\n');

          // Providers
          _sttProvider = settings['stt_provider'] ?? _sttProvider;
          _llmProvider = settings['llm_provider'] ?? _llmProvider;
          _ollamaHost = settings['ollama_host'] ?? _ollamaHost;
          _ollamaModel = settings['ollama_model'] ?? _ollamaModel;
          _groqModel = settings['groq_model'] ?? _groqModel;
          _openaiBaseUrl = settings['openai_base_url'] ?? _openaiBaseUrl;
          _openaiModel = settings['openai_model'] ?? _openaiModel;
          _openrouterModel = settings['openrouter_model'] ?? _openrouterModel;
          _ttsProvider = settings['tts_provider'] ?? _ttsProvider;
          _ttsVoiceKokoro = settings['tts_voice_kokoro'] ?? _ttsVoiceKokoro;
          _ttsVoicePiper = settings['tts_voice_piper'] ?? _ttsVoicePiper;

          // Integrations
          _hassEnabled = settings['hass_enabled'] ?? _hassEnabled;
          _hassHost = settings['hass_host'] ?? _hassHost;
          _hassToken = settings['hass_token'] ?? _hassToken;
          _n8nEnabled = settings['n8n_enabled'] ?? _n8nEnabled;
          _n8nUrl = settings['n8n_url'] ?? _n8nUrl;
          _n8nToken = settings['n8n_token'] ?? _n8nToken;

          // LLM settings
          _temperature = (settings['temperature'] ?? _temperature).toDouble();
          _numCtx = settings['num_ctx'] ?? _numCtx;
          _maxTurns = settings['max_turns'] ?? _maxTurns;
          _toolCacheSize = settings['tool_cache_size'] ?? _toolCacheSize;

          // Turn detection
          _allowInterruptions = settings['allow_interruptions'] ?? _allowInterruptions;
          _minEndpointingDelay = (settings['min_endpointing_delay'] ?? _minEndpointingDelay).toDouble();

          // Wake word
          _wakeWordEnabled = settings['wake_word_enabled'] ?? _wakeWordEnabled;
          _wakeWordModel = settings['wake_word_model'] ?? _wakeWordModel;
          _wakeWordThreshold = (settings['wake_word_threshold'] ?? _wakeWordThreshold).toDouble();
          _wakeWordTimeout = (settings['wake_word_timeout'] ?? _wakeWordTimeout).toDouble();

          // Language
          _language = settings['language'] ?? 'en';
        });
      }

      if (voicesRes.statusCode == 200) {
        final data = jsonDecode(voicesRes.body);
        setState(() {
          _voices = List<String>.from(data['voices'] ?? []);
        });
      }

      if (wakeWordModelsRes.statusCode == 200) {
        final data = jsonDecode(wakeWordModelsRes.body);
        setState(() {
          _wakeWordModels = List<String>.from(data['models'] ?? []);
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load settings: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchVoices(String provider) async {
    final webhookUrl = _webhookUrl;
    if (webhookUrl.isEmpty) return;

    try {
      final res = await http.get(Uri.parse('$webhookUrl/voices?provider=$provider'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _voices = List<String>.from(data['voices'] ?? []);
        });
      }
    } catch (e) {
      // Silently fail - voices list will remain as-is
    }
  }

  void _handleTtsProviderChange(String provider) {
    if (provider == _ttsProvider) return;
    setState(() {
      _ttsProvider = provider;
    });
    unawaited(_fetchVoices(provider));
  }

  Future<void> _testOllama() async {
    if (_ollamaHost.isEmpty) return;
    setState(() {
      _testingOllama = true;
      _ollamaError = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$_webhookUrl/setup/test-ollama'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'host': _ollamaHost}),
      );
      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        setState(() {
          _ollamaConnected = true;
          _ollamaModels = List<String>.from(result['models'] ?? []);
          if (_ollamaModel.isEmpty && _ollamaModels.isNotEmpty) {
            _ollamaModel = _ollamaModels.first;
          }
        });
      } else {
        setState(() {
          _ollamaConnected = false;
          _ollamaError = result['error'] ?? 'Connection failed';
        });
      }
    } catch (e) {
      setState(() {
        _ollamaConnected = false;
        _ollamaError = 'Failed to connect';
      });
    } finally {
      setState(() {
        _testingOllama = false;
      });
    }
  }

  Future<void> _testGroq() async {
    // Allow testing with empty key - backend falls back to stored key
    if (_groqApiKey.isEmpty && _groqModel.isEmpty) return;
    setState(() {
      _testingGroq = true;
      _groqError = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$_webhookUrl/setup/test-groq'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': _groqApiKey}),
      );
      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        setState(() {
          _groqConnected = true;
          _groqModels = List<String>.from(result['models'] ?? []);
          if (_groqModel.isEmpty && _groqModels.isNotEmpty) {
            final preferred = 'llama-3.3-70b-versatile';
            _groqModel = _groqModels.contains(preferred) ? preferred : _groqModels.first;
          }
        });
      } else {
        setState(() {
          _groqConnected = false;
          _groqError = result['error'] ?? 'Invalid API key';
        });
      }
    } catch (e) {
      setState(() {
        _groqConnected = false;
        _groqError = 'Failed to validate';
      });
    } finally {
      setState(() {
        _testingGroq = false;
      });
    }
  }

  Future<void> _testOpenaiCompatible() async {
    if (_openaiBaseUrl.isEmpty) return;
    setState(() {
      _testingOpenai = true;
      _openaiError = null;
    });

    try {
      final body = <String, dynamic>{'base_url': _openaiBaseUrl};
      if (_openaiApiKey.isNotEmpty) body['api_key'] = _openaiApiKey;
      final res = await http.post(
        Uri.parse('$_webhookUrl/setup/test-openai-compatible'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        setState(() {
          _openaiConnected = true;
          _openaiModels = List<String>.from(result['models'] ?? []);
          if (_openaiModel.isEmpty && _openaiModels.isNotEmpty) {
            _openaiModel = _openaiModels.first;
          }
        });
      } else {
        setState(() {
          _openaiConnected = false;
          _openaiError = result['error'] ?? 'Connection failed';
        });
      }
    } catch (e) {
      setState(() {
        _openaiConnected = false;
        _openaiError = 'Failed to connect';
      });
    } finally {
      setState(() {
        _testingOpenai = false;
      });
    }
  }

  Future<void> _testOpenRouter() async {
    // Allow testing with empty key - backend falls back to stored key
    if (_openrouterApiKey.isEmpty && _openrouterModel.isEmpty) return;
    setState(() {
      _testingOpenrouter = true;
      _openrouterError = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$_webhookUrl/setup/test-openrouter'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': _openrouterApiKey}),
      );
      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        setState(() {
          _openrouterConnected = true;
          _openrouterModels = List<String>.from(result['models'] ?? []);
          if (_openrouterModel.isEmpty && _openrouterModels.isNotEmpty) {
            _openrouterModel = _openrouterModels.first;
          }
        });
      } else {
        setState(() {
          _openrouterConnected = false;
          _openrouterError = result['error'] ?? 'Invalid API key';
        });
      }
    } catch (e) {
      setState(() {
        _openrouterConnected = false;
        _openrouterError = 'Failed to validate';
      });
    } finally {
      setState(() {
        _testingOpenrouter = false;
      });
    }
  }

  Future<void> _testHass() async {
    if (_hassHost.isEmpty || _hassToken.isEmpty) return;
    setState(() {
      _testingHass = true;
      _hassError = null;
      _hassInfo = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$_webhookUrl/setup/test-hass'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'host': _hassHost, 'token': _hassToken}),
      );
      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        setState(() {
          _hassConnected = true;
          _hassInfo = 'Connected - ${result['device_count']} entities';
        });
      } else {
        setState(() {
          _hassConnected = false;
          _hassError = result['error'] ?? 'Connection failed';
        });
      }
    } catch (e) {
      setState(() {
        _hassConnected = false;
        _hassError = 'Failed to connect';
      });
    } finally {
      setState(() {
        _testingHass = false;
      });
    }
  }

  String _getN8nMcpUrl(String host) {
    if (host.isEmpty) return '';
    final baseUrl = host.replaceAll(RegExp(r'/$'), '');
    if (baseUrl.contains('/mcp-server')) return baseUrl;
    return '$baseUrl/mcp-server/http';
  }

  Future<void> _testN8n() async {
    if (_n8nUrl.isEmpty || _n8nToken.isEmpty) return;
    setState(() {
      _testingN8n = true;
      _n8nError = null;
    });

    try {
      final mcpUrl = _getN8nMcpUrl(_n8nUrl);
      final res = await http.post(
        Uri.parse('$_webhookUrl/setup/test-n8n'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': mcpUrl, 'token': _n8nToken}),
      );
      final result = jsonDecode(res.body);

      if (result['success'] == true) {
        setState(() {
          _n8nConnected = true;
        });
      } else {
        setState(() {
          _n8nConnected = false;
          _n8nError = result['error'] ?? 'Connection failed';
        });
      }
    } catch (e) {
      setState(() {
        _n8nConnected = false;
        _n8nError = 'Failed to connect';
      });
    } finally {
      setState(() {
        _testingN8n = false;
      });
    }
  }

  String get _currentVoice {
    return _ttsProvider == 'piper' ? _ttsVoicePiper : _ttsVoiceKokoro;
  }

  void _setCurrentVoice(String voice) {
    setState(() {
      if (_ttsProvider == 'piper') {
        _ttsVoicePiper = voice;
      } else {
        _ttsVoiceKokoro = voice;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _saveStatus = 'Saving...';
      _error = null;
    });

    try {
      // Save server URL first
      await widget.configService.setServerUrl(_serverUrlController.text.trim());

      // If connected, save agent settings
      if (_serverConnected) {
        final greetings =
            _wakeGreetingsController.text.split('\n').where((g) => g.trim().isNotEmpty).toList();

        final settings = {
          // Agent
          'agent_name': _agentName,
          'wake_greetings': greetings,

          // Providers
          'stt_provider': _sttProvider,
          'llm_provider': _llmProvider,
          'ollama_host': _ollamaHost,
          'ollama_model': _ollamaModel,
          'groq_model': _groqModel,
          'openai_base_url': _openaiBaseUrl,
          'openai_model': _openaiModel,
          'openrouter_model': _openrouterModel,
          'tts_provider': _ttsProvider,
          'tts_voice_kokoro': _ttsVoiceKokoro,
          'tts_voice_piper': _ttsVoicePiper,

          // Integrations
          'hass_enabled': _hassEnabled,
          'hass_host': _hassHost,
          'hass_token': _hassToken,
          'n8n_enabled': _n8nEnabled,
          'n8n_url': _n8nEnabled ? _getN8nMcpUrl(_n8nUrl) : _n8nUrl,
          'n8n_token': _n8nToken,

          // LLM settings
          'temperature': _temperature,
          'num_ctx': _numCtx,
          'max_turns': _maxTurns,
          'tool_cache_size': _toolCacheSize,

          // Turn detection
          'allow_interruptions': _allowInterruptions,
          'min_endpointing_delay': _minEndpointingDelay,

          // Wake word
          'wake_word_enabled': _wakeWordEnabled,
          'wake_word_model': _wakeWordModel,
          'wake_word_threshold': _wakeWordThreshold,
          'wake_word_timeout': _wakeWordTimeout,

          // Language
          'language': _language,
        };

        final res = await http.post(
          Uri.parse('$_webhookUrl/settings'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'settings': settings}),
        );

        if (res.statusCode != 200) {
          setState(() {
            _error = 'Failed to save agent settings: ${res.statusCode}';
          });
          return;
        }

        // Save API keys via /setup/complete for providers that need them
        if (_llmProvider == 'groq' && _groqApiKey.isNotEmpty) {
          await http.post(
            Uri.parse('$_webhookUrl/setup/complete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'llm_provider': 'groq',
              'groq_api_key': _groqApiKey,
              'groq_model': _groqModel,
            }),
          );
        }
        if (_llmProvider == 'openai_compatible' && _openaiApiKey.isNotEmpty) {
          await http.post(
            Uri.parse('$_webhookUrl/setup/complete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'llm_provider': 'openai_compatible',
              'openai_api_key': _openaiApiKey,
              'openai_base_url': _openaiBaseUrl,
              'openai_model': _openaiModel,
            }),
          );
        }
        if (_llmProvider == 'openrouter' && _openrouterApiKey.isNotEmpty) {
          await http.post(
            Uri.parse('$_webhookUrl/setup/complete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'llm_provider': 'openrouter',
              'openrouter_api_key': _openrouterApiKey,
              'openrouter_model': _openrouterModel,
            }),
          );
        }
        // Save Groq API key for STT if STT=groq and LLM!=groq
        if (_sttProvider == 'groq' && _llmProvider != 'groq' && _groqApiKey.isNotEmpty) {
          await http.post(
            Uri.parse('$_webhookUrl/setup/complete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'llm_provider': _llmProvider,
              'groq_api_key': _groqApiKey,
            }),
          );
        }

        // Download Piper model if using Piper
        if (_ttsProvider == 'piper' && _ttsVoicePiper.isNotEmpty) {
          setState(() {
            _saveStatus = 'Downloading voice model...';
          });
          try {
            await http.post(
              Uri.parse('$_webhookUrl/download-piper-model'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'model_id': _ttsVoicePiper}),
            );
          } catch (e) {
            // Non-critical - model can be downloaded later
          }
        }
      }

      widget.onSave();
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isFirstSetup = !widget.configService.isConfigured;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        leading: isFirstSetup
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          isFirstSetup ? l10n.caalSetup : l10n.settingsTitle,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (_saving)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF45997C)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _saveStatus.isNotEmpty ? _saveStatus : l10n.saving,
                    style: const TextStyle(
                      color: Color(0xFF45997C),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                l10n.save,
                style: const TextStyle(
                  color: Color(0xFF45997C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Connection Section
              _buildSectionHeader(l10n.connection, Icons.link),
              _buildCard([
                _buildLabel(l10n.serverUrl),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _serverUrlController,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(hint: l10n.serverUrlHint),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.serverUrlRequired;
                          }
                          final uri = Uri.tryParse(value.trim());
                          if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                            return l10n.serverUrlInvalid;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _loading ? null : _testConnection,
                      style: TextButton.styleFrom(
                        backgroundColor:
                            _serverConnected ? const Color(0xFF45997C) : const Color(0xFF2A2A2A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(_serverConnected ? '✓' : l10n.test),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _serverConnected ? l10n.connectedToServer : l10n.yourServerAddress,
                  style: TextStyle(
                    fontSize: 12,
                    color: _serverConnected ? const Color(0xFF45997C) : Colors.white54,
                  ),
                ),
              ]),

              // Language Section (after Connection, before settings that require connection)
              const SizedBox(height: 24),
              _buildSectionHeader(l10n.language, Icons.language),
              _buildCard([
                _buildLabel(l10n.language),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF2A2A2A),
                  decoration: _inputDecoration(),
                  items: [
                    DropdownMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
                    DropdownMenuItem(value: 'fr', child: Text(l10n.languageFrench)),
                    DropdownMenuItem(value: 'it', child: Text(l10n.languageItalian)),
                    DropdownMenuItem(value: 'pt', child: Text(l10n.languagePortuguese)),
                    DropdownMenuItem(value: 'da', child: Text(l10n.languageDanish)),
                    DropdownMenuItem(value: 'ro', child: Text(l10n.languageRomanian)),
                  ],
                  onChanged: (value) async {
                    if (value != null) {
                      // Keep _language in sync so _save() doesn't overwrite
                      _language = value;
                      // Update app locale immediately for UI
                      final localeProvider = context.read<LocaleProvider>();
                      await localeProvider.setLocale(
                        Locale(value),
                        widget.configService.serverUrl,
                      );

                      // Switch TTS to Piper for non-English languages
                      if (value != 'en' && _serverConnected) {
                        const piperModels = {
                          'en': 'speaches-ai/piper-en_US-ryan-high',
                          'fr': 'speaches-ai/piper-fr_FR-siwis-medium',
                          'it': 'speaches-ai/piper-it_IT-paola-medium',
                          'pt': 'speaches-ai/piper-pt_BR-faber-medium',
                        };
                        final modelId =
                            piperModels[value] ?? piperModels['en']!;
                        try {
                          await http.post(
                            Uri.parse('$_webhookUrl/settings'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'settings': {
                                'tts_provider': 'piper',
                                'tts_voice_piper': modelId,
                              }
                            }),
                          );
                          // Download the Piper model so it appears in voice list
                          unawaited(http.post(
                            Uri.parse('$_webhookUrl/download-piper-model'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({'model_id': modelId}),
                          ));
                        } catch (e) {
                          // Best-effort
                        }
                      }

                      // Reload settings to pick up updated greetings + TTS
                      if (_serverConnected) {
                        await _loadSettings();
                      }
                    }
                  },
                ),
              ]),

              // Settings (only show if connected)
              if (_serverConnected) ...[
                // Agent Section
                const SizedBox(height: 24),
                _buildSectionHeader(l10n.agent, Icons.smart_toy_outlined),
                _buildCard([
                  _buildTextField(
                    label: l10n.agentName,
                    value: _agentName,
                    onChanged: (v) => setState(() => _agentName = v),
                  ),
                  _buildLabel(l10n.wakeGreetings),
                  TextFormField(
                    controller: _wakeGreetingsController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(hint: l10n.onePerLine),
                  ),
                ]),

                // Providers Section
                const SizedBox(height: 24),
                _buildSectionHeader(l10n.providers, Icons.cloud_outlined),
                _buildCard([
                  // STT Provider
                  _buildLabel(l10n.sttProvider),
                  _buildProviderToggle(
                    options: ['speaches', 'groq'],
                    labels: ['Speaches', 'Groq Whisper'],
                    subtitles: [l10n.speachesLocalStt, l10n.groqWhisperCloud],
                    selected: _sttProvider,
                    onChanged: (v) => setState(() => _sttProvider = v),
                  ),
                  const SizedBox(height: 8),
                  if (_sttProvider == 'groq' && _llmProvider == 'groq')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l10n.sttGroqKeyShared,
                          style: const TextStyle(color: Color(0xFF45997C), fontSize: 12)),
                    ),
                  if (_sttProvider == 'groq' && _llmProvider != 'groq') ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l10n.sttGroqKeyNeeded,
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                    _buildLabel(l10n.apiKey),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _groqApiKey,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(hint: 'gsk_...'),
                            onChanged: (v) => setState(() => _groqApiKey = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTestButton(
                          l10n: l10n,
                          testing: _testingGroq,
                          connected: _groqConnected,
                          onPressed: _testGroq,
                        ),
                      ],
                    ),
                    if (_groqError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_groqError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                  ],

                  const Divider(color: Colors.white24, height: 24),

                  // LLM Provider
                  _buildLabel(l10n.llmProvider),
                  _buildProviderToggle(
                    options: ['ollama', 'groq', 'openai_compatible', 'openrouter'],
                    labels: ['Ollama', 'Groq', l10n.openaiCompatible, 'OpenRouter'],
                    subtitles: [
                      l10n.ollamaLocalPrivate,
                      l10n.groqFastCloud,
                      l10n.openaiCompatibleDesc,
                      l10n.openrouterDesc,
                    ],
                    selected: _llmProvider,
                    onChanged: (v) => setState(() => _llmProvider = v),
                    grid: true,
                  ),
                  const SizedBox(height: 16),

                  // Ollama config
                  if (_llmProvider == 'ollama') ...[
                    _buildLabel(l10n.ollamaHost),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _ollamaHost,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(hint: 'http://localhost:11434'),
                            onChanged: (v) => setState(() => _ollamaHost = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTestButton(
                          l10n: l10n,
                          testing: _testingOllama,
                          connected: _ollamaConnected,
                          onPressed: _testOllama,
                        ),
                      ],
                    ),
                    if (_ollamaError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_ollamaError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    if (_ollamaConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l10n.modelsAvailable(_ollamaModels.length),
                            style: const TextStyle(color: Color(0xFF45997C), fontSize: 12)),
                      ),
                    const SizedBox(height: 12),
                    if (_ollamaModels.isNotEmpty || _ollamaModel.isNotEmpty)
                      _buildDropdown(
                        label: l10n.model,
                        value: _ollamaModel.isNotEmpty
                            ? _ollamaModel
                            : (_ollamaModels.isNotEmpty ? _ollamaModels.first : ''),
                        options: _ollamaModels.isNotEmpty ? _ollamaModels : [_ollamaModel],
                        onChanged: (v) => setState(() => _ollamaModel = v ?? _ollamaModel),
                      ),
                  ],

                  // Groq config
                  if (_llmProvider == 'groq') ...[
                    _buildLabel(l10n.apiKey),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _groqApiKey,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                                hint: _groqModel.isNotEmpty ? '••••••••••••••••' : 'gsk_...'),
                            onChanged: (v) => setState(() => _groqApiKey = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTestButton(
                          l10n: l10n,
                          testing: _testingGroq,
                          connected: _groqConnected,
                          onPressed: _testGroq,
                        ),
                      ],
                    ),
                    if (_groqError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_groqError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    if (_groqConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l10n.modelsAvailable(_groqModels.length),
                            style: const TextStyle(color: Color(0xFF45997C), fontSize: 12)),
                      ),
                    if (!_groqConnected && _groqApiKey.isEmpty && _groqModel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l10n.apiKeyConfigured,
                            style: const TextStyle(color: Color(0xFF45997C), fontSize: 12)),
                      ),
                    const SizedBox(height: 12),
                    if (_groqModels.isNotEmpty || _groqModel.isNotEmpty)
                      _buildDropdown(
                        label: l10n.model,
                        value: _groqModel.isNotEmpty
                            ? _groqModel
                            : (_groqModels.isNotEmpty ? _groqModels.first : ''),
                        options: _groqModels.isNotEmpty ? _groqModels : [_groqModel],
                        onChanged: (v) => setState(() => _groqModel = v ?? _groqModel),
                      ),
                  ],

                  // OpenAI-compatible config
                  if (_llmProvider == 'openai_compatible') ...[
                    _buildLabel(l10n.baseUrl),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _openaiBaseUrl,
                            style: const TextStyle(color: Colors.white),
                            decoration:
                                _inputDecoration(hint: 'http://localhost:1234/v1'),
                            onChanged: (v) => setState(() => _openaiBaseUrl = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTestButton(
                          l10n: l10n,
                          testing: _testingOpenai,
                          connected: _openaiConnected,
                          onPressed: _testOpenaiCompatible,
                        ),
                      ],
                    ),
                    if (_openaiError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_openaiError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    if (_openaiConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l10n.modelsAvailable(_openaiModels.length),
                            style: const TextStyle(color: Color(0xFF45997C), fontSize: 12)),
                      ),
                    const SizedBox(height: 12),
                    _buildLabel('${l10n.apiKey} (${l10n.optional})'),
                    TextFormField(
                      initialValue: _openaiApiKey,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(
                          hint: _openaiModel.isNotEmpty
                              ? '••••••••••••••••'
                              : 'sk-...'),
                      onChanged: (v) => setState(() => _openaiApiKey = v),
                    ),
                    if (!_openaiConnected &&
                        _openaiApiKey.isEmpty &&
                        _openaiModel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l10n.apiKeyConfigured,
                            style: const TextStyle(color: Color(0xFF45997C), fontSize: 12)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: Text(l10n.openaiApiKeyNote,
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ),
                    if (_openaiModels.isNotEmpty || _openaiModel.isNotEmpty)
                      _buildDropdown(
                        label: l10n.model,
                        value: _openaiModel.isNotEmpty
                            ? _openaiModel
                            : (_openaiModels.isNotEmpty ? _openaiModels.first : ''),
                        options:
                            _openaiModels.isNotEmpty ? _openaiModels : [_openaiModel],
                        onChanged: (v) =>
                            setState(() => _openaiModel = v ?? _openaiModel),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(l10n.testConnectionToSee,
                            style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                  ],

                  // OpenRouter config
                  if (_llmProvider == 'openrouter') ...[
                    _buildLabel(l10n.apiKey),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _openrouterApiKey,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(
                                hint: _openrouterModel.isNotEmpty
                                    ? '••••••••••••••••'
                                    : 'sk-or-...'),
                            onChanged: (v) =>
                                setState(() => _openrouterApiKey = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTestButton(
                          l10n: l10n,
                          testing: _testingOpenrouter,
                          connected: _openrouterConnected,
                          onPressed: _testOpenRouter,
                        ),
                      ],
                    ),
                    if (_openrouterError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_openrouterError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    if (_openrouterConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l10n.modelsAvailable(_openrouterModels.length),
                            style: const TextStyle(color: Color(0xFF45997C), fontSize: 12)),
                      ),
                    if (!_openrouterConnected &&
                        _openrouterApiKey.isEmpty &&
                        _openrouterModel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l10n.apiKeyConfigured,
                            style: const TextStyle(color: Color(0xFF45997C), fontSize: 12)),
                      ),
                    const SizedBox(height: 12),
                    if (_openrouterModels.isNotEmpty || _openrouterModel.isNotEmpty)
                      _buildSearchableModelDropdown(l10n)
                    else if (_openrouterModel.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(l10n.testConnectionToSee,
                            style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                  ],

                  const Divider(color: Colors.white24, height: 32),

                  // TTS Provider
                  _buildLabel(l10n.ttsProvider),
                  _buildProviderToggle(
                    options: ['kokoro', 'piper'],
                    labels: ['Kokoro', 'Piper'],
                    subtitles: [l10n.kokoroGpuNeural, l10n.piperCpuLightweight],
                    selected: _ttsProvider,
                    onChanged: _handleTtsProviderChange,
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: l10n.voice,
                    value: _currentVoice,
                    options: _voices.isNotEmpty
                        ? (_voices.contains(_currentVoice) ? _voices : [_currentVoice, ..._voices])
                        : [_currentVoice],
                    onChanged: (v) => _setCurrentVoice(v ?? _currentVoice),
                  ),
                ]),

                // Integrations Section
                const SizedBox(height: 24),
                _buildSectionHeader(l10n.integrations, Icons.extension_outlined),

                // Home Assistant
                _buildCard([
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.homeAssistant,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      Switch(
                        value: _hassEnabled,
                        onChanged: (v) => setState(() => _hassEnabled = v),
                        activeTrackColor: const Color(0xFF45997C),
                      ),
                    ],
                  ),
                  if (_hassEnabled) ...[
                    const SizedBox(height: 12),
                    _buildLabel(l10n.hostUrl),
                    TextFormField(
                      initialValue: _hassHost,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(hint: 'http://homeassistant.local:8123'),
                      onChanged: (v) => setState(() => _hassHost = v),
                    ),
                    const SizedBox(height: 12),
                    _buildLabel(l10n.accessToken),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _hassToken,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(hint: 'eyJ0eX...'),
                            onChanged: (v) => setState(() => _hassToken = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTestButton(
                          l10n: l10n,
                          testing: _testingHass,
                          connected: _hassConnected,
                          onPressed: _testHass,
                        ),
                      ],
                    ),
                    if (_hassError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_hassError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    if (_hassInfo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_hassInfo!, style: const TextStyle(color: Color(0xFF45997C), fontSize: 12)),
                      ),
                  ],
                ]),

                const SizedBox(height: 12),

                // n8n
                _buildCard([
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('n8n', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      Switch(
                        value: _n8nEnabled,
                        onChanged: (v) => setState(() => _n8nEnabled = v),
                        activeTrackColor: const Color(0xFF45997C),
                      ),
                    ],
                  ),
                  if (_n8nEnabled) ...[
                    const SizedBox(height: 12),
                    _buildLabel(l10n.hostUrl),
                    TextFormField(
                      initialValue: _n8nUrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(hint: 'http://n8n:5678'),
                      onChanged: (v) => setState(() => _n8nUrl = v),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(l10n.n8nMcpNote,
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ),
                    const SizedBox(height: 12),
                    _buildLabel(l10n.accessToken),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _n8nToken,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration(hint: 'n8n_api_...'),
                            onChanged: (v) => setState(() => _n8nToken = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTestButton(
                          l10n: l10n,
                          testing: _testingN8n,
                          connected: _n8nConnected,
                          onPressed: _testN8n,
                        ),
                      ],
                    ),
                    if (_n8nError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_n8nError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    if (_n8nConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l10n.connected, style: const TextStyle(color: Color(0xFF45997C), fontSize: 12)),
                      ),
                  ],
                ]),

                const SizedBox(height: 24),
                _buildSectionHeader(l10n.llmSettings, Icons.tune),
                _buildCard([
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberField(
                          label: l10n.temperature,
                          value: _temperature,
                          min: 0.0,
                          max: 2.0,
                          decimals: 1,
                          onChanged: (v) => setState(() => _temperature = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildIntField(
                          label: l10n.contextSize,
                          value: _numCtx,
                          min: 1024,
                          max: 131072,
                          step: 1024,
                          onChanged: (v) => setState(() => _numCtx = v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildIntField(
                          label: l10n.maxTurns,
                          value: _maxTurns,
                          min: 1,
                          max: 100,
                          onChanged: (v) => setState(() => _maxTurns = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildIntField(
                          label: l10n.toolCache,
                          value: _toolCacheSize,
                          min: 0,
                          max: 10,
                          onChanged: (v) => setState(() => _toolCacheSize = v),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  // Turn Detection section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.allowInterruptions,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            l10n.interruptAgent,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _allowInterruptions,
                        onChanged: (v) => setState(() => _allowInterruptions = v),
                        activeTrackColor: const Color(0xFF45997C),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildNumberField(
                    label: l10n.endpointingDelay,
                    value: _minEndpointingDelay,
                    min: 0.1,
                    max: 1.0,
                    decimals: 1,
                    onChanged: (v) => setState(() => _minEndpointingDelay = v),
                  ),
                  Text(
                    l10n.endpointingDelayDesc,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ]),

                const SizedBox(height: 24),
                _buildSectionHeader(l10n.wakeWord, Icons.hearing),
                _buildCard([
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.serverSideWakeWord,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            l10n.activateWithWakePhrase,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _wakeWordEnabled,
                        onChanged: (v) => setState(() => _wakeWordEnabled = v),
                        activeTrackColor: const Color(0xFF45997C),
                      ),
                    ],
                  ),
                  if (_wakeWordEnabled) ...[
                    const SizedBox(height: 12),
                    _buildWakeWordModelDropdown(l10n),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberField(
                            label: l10n.threshold,
                            value: _wakeWordThreshold,
                            min: 0.1,
                            max: 1.0,
                            decimals: 1,
                            onChanged: (v) => setState(() => _wakeWordThreshold = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumberField(
                            label: l10n.timeout,
                            value: _wakeWordTimeout,
                            min: 1.0,
                            max: 30.0,
                            decimals: 1,
                            onChanged: (v) => setState(() => _wakeWordTimeout = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ]),

                const SizedBox(height: 16),
                Text(
                  l10n.changesNote,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ] else if (!isFirstSetup) ...[
                const SizedBox(height: 48),
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off, size: 48, color: Colors.white38),
                      const SizedBox(height: 16),
                      Text(
                        l10n.connectToServerFirst,
                        style: const TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderToggle({
    required List<String> options,
    required List<String> labels,
    required List<String> subtitles,
    required String selected,
    required ValueChanged<String> onChanged,
    bool grid = false,
  }) {
    Widget buildOption(int i, {BorderRadius? borderRadius}) {
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(options[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected == options[i]
                  ? const Color(0xFF45997C).withValues(alpha: 0.2)
                  : const Color(0xFF2A2A2A),
              border: Border.all(
                color: selected == options[i]
                    ? const Color(0xFF45997C)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              borderRadius: borderRadius ?? BorderRadius.zero,
            ),
            child: Column(
              children: [
                Text(
                  labels[i],
                  style: TextStyle(
                    color: selected == options[i] ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitles[i],
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (grid && options.length == 4) {
      return Column(
        children: [
          Row(
            children: [
              buildOption(0,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(8))),
              buildOption(1,
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(8))),
            ],
          ),
          Row(
            children: [
              buildOption(2,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8))),
              buildOption(3,
                  borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8))),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < options.length; i++)
          buildOption(i,
              borderRadius: BorderRadius.only(
                topLeft: i == 0 ? const Radius.circular(8) : Radius.zero,
                bottomLeft: i == 0 ? const Radius.circular(8) : Radius.zero,
                topRight: i == options.length - 1 ? const Radius.circular(8) : Radius.zero,
                bottomRight:
                    i == options.length - 1 ? const Radius.circular(8) : Radius.zero,
              )),
      ],
    );
  }

  void _showModelPicker(AppLocalizations l10n) {
    var search = '';
    unawaited(showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        final allModels =
            _openrouterModels.isNotEmpty ? _openrouterModels : [_openrouterModel];
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = search.isEmpty
                ? allModels
                : allModels
                    .where((m) => m.toLowerCase().contains(search.toLowerCase()))
                    .toList();
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: l10n.searchModels,
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => setSheetState(() => search = v),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(l10n.noModelsFound,
                                style: const TextStyle(color: Colors.white38, fontSize: 13)),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final model = filtered[index];
                              final isSelected = model == _openrouterModel;
                              return ListTile(
                                dense: true,
                                title: Text(
                                  model,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 13,
                                    fontWeight:
                                        isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                tileColor: isSelected
                                    ? const Color(0xFF45997C).withValues(alpha: 0.2)
                                    : null,
                                trailing: isSelected
                                    ? const Icon(Icons.check, color: Color(0xFF45997C), size: 18)
                                    : null,
                                onTap: () {
                                  Navigator.of(context).pop(model);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((selected) {
      if (selected != null) {
        setState(() => _openrouterModel = selected);
      }
    }));
  }

  Widget _buildSearchableModelDropdown(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(l10n.model),
        GestureDetector(
          onTap: () => _showModelPicker(l10n),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _openrouterModel.isNotEmpty
                        ? _openrouterModel
                        : l10n.searchModels,
                    style: TextStyle(
                      color: _openrouterModel.isNotEmpty
                          ? Colors.white
                          : Colors.white38,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white38),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTestButton({
    required AppLocalizations l10n,
    required bool testing,
    required bool connected,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: testing ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: connected ? const Color(0xFF45997C) : const Color(0xFF2A2A2A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: testing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Text(connected ? '✓' : l10n.test),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF45997C), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          initialValue: value,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    final safeValue = options.contains(value) ? value : (options.isNotEmpty ? options.first : value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        DropdownButtonFormField<String>(
          initialValue: safeValue,
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF2A2A2A),
          decoration: _inputDecoration(),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNumberField({
    required String label,
    required double value,
    required double min,
    required double max,
    required int decimals,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          initialValue: value.toStringAsFixed(decimals),
          style: const TextStyle(color: Colors.white),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration(),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null && parsed >= min && parsed <= max) {
              onChanged(parsed);
            }
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildIntField({
    required String label,
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextFormField(
          initialValue: value.toString(),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: _inputDecoration(),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            if (parsed != null && parsed >= min && parsed <= max) {
              onChanged(parsed);
            }
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _formatModelName(String path) {
    return path
        .replaceAll('models/', '')
        .replaceAll('.onnx', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  Widget _buildWakeWordModelDropdown(AppLocalizations l10n) {
    final options = _wakeWordModels.isNotEmpty ? _wakeWordModels : [_wakeWordModel];
    final safeValue = options.contains(_wakeWordModel) ? _wakeWordModel : options.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.wakeWordModel,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: safeValue,
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF2A2A2A),
          decoration: _inputDecoration(),
          items: options
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(_formatModelName(m)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _wakeWordModel = v ?? _wakeWordModel),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
