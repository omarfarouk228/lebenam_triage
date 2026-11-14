// ─────────────────────────────────────────────────────────────────────────────
// ON-DEVICE AI: Gemma 4 E2B on the phone's GPU, for when the network is gone.
//
//   Gemini (cloud)    understands AND composes the interface (A2UI)
//   Gemma (on device) only UNDERSTANDS: a tiny JSON, enforced by a schema
//   Dart rules        check that JSON and compose the interface
//
// A small model writing a whole interface would be slow and fragile. Asking
// it for three fields keeps the answer to a few dozen tokens, and the
// catalog, the protocol and the Dart guard stay exactly the same.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import 'offline_triage.dart';

/// Where the on-device model stands.
sealed class OnDeviceStatus {
  const OnDeviceStatus();
}

final class NotInstalled extends OnDeviceStatus {
  const NotInstalled();
}

final class Downloading extends OnDeviceStatus {
  const Downloading(this.percent);
  final int percent;
}

/// Installed; [loaded] once the model sits in memory, ready to answer.
final class Installed extends OnDeviceStatus {
  const Installed({required this.loaded});
  final bool loaded;
}

final class Unavailable extends OnDeviceStatus {
  const Unavailable(this.reason);
  final String reason;
}

class OnDeviceModel {
  OnDeviceModel._();
  static final instance = OnDeviceModel._();

  /// Gemma 4 E2B (2.6 GB), pinned and checksummed by the package catalog.
  /// Apache 2.0, no Hugging Face token needed. The generic file runs on the
  /// GPU and the CPU; the "-gpu" one needs a GPU engine the Android runtime
  /// no longer ships ("No available engine for backend: GPU_ARTISAN").
  static final _variant = LiteRtLmModels.gemma4E2bIt.generic;
  static const _modelId = 'gemma-4-E2B-it.litertlm';
  static const _legacyIds = ['gemma-4-E2B-it-gpu.litertlm'];

  /// Past this delay the rules answer instead: a patient never waits on it.
  static const timeout = Duration(seconds: 25);

  final status = ValueNotifier<OnDeviceStatus>(const NotInstalled());

  /// Duration of the last answer, shown in the settings sheet.
  final lastLatency = ValueNotifier<Duration?>(null);

  InferenceModel? _model;
  Future<InferenceModel>? _loading;
  bool _initialized = false;

  static const _system = '''
You are the offline helper of a clinic in West Africa. The patient writes or
speaks, in English, French or a local language. Fill in the JSON:
- symptom: the main problem, one of: fever, headache, chest_pain, breathing,
  cough, belly, bleeding, injury, child (a sick child or baby), pregnancy,
  tired, other, not_health (the message is not about health).
- alarm: true for any red flag: chest pain or tightness, difficulty
  breathing, fainting, seizures, paralysis, heavy bleeding, confusion, stiff
  neck with fever, fever in a baby under 3 months, vomiting blood, a
  pregnant woman who is bleeding.
- summary: ONE short, kind sentence in simple English telling the patient
  what you understood, e.g. "You have had a fever for three days."''';

  static final _format = ResponseFormat.jsonSchema({
    'type': 'object',
    'properties': {
      'symptom': {'type': 'string', 'enum': Understanding.symptoms},
      'alarm': {'type': 'boolean'},
      'summary': {
        'type': 'string',
        'maxLength': Understanding.maxSummaryLength,
      },
    },
    'required': ['symptom', 'alarm', 'summary'],
    'additionalProperties': false,
  }, name: 'triage_understanding');

  /// Registers the engine and, if the model is already on the phone, loads
  /// it in the background so the first offline answer is fast.
  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    try {
      await FlutterEdgeAi.initialize(
        inferenceEngines: const [LiteRtLmEngine()],
      );
      for (final id in _legacyIds) {
        if (await FlutterEdgeAi.isModelInstalled(id)) {
          await FlutterEdgeAi.uninstallModel(id); // frees ~2 GB on the phone
        }
      }
      if (await FlutterEdgeAi.isModelInstalled(_modelId)) {
        status.value = const Installed(loaded: false);
        unawaited(_load().then<void>((_) {}, onError: (_) {}));
      }
    } catch (e) {
      status.value = Unavailable('$e');
    }
  }

  /// Downloads the model once (on Wi-Fi, before going to the clinic).
  Future<void> download() async {
    if (status.value is Downloading) return;
    status.value = const Downloading(0);
    try {
      await FlutterEdgeAi.installModelFromCatalog(
        _variant,
      ).withProgress((p) => status.value = Downloading(p)).install();
      status.value = const Installed(loaded: false);
      await _load();
    } catch (e) {
      debugPrint('✖ On-device model download failed: $e');
      status.value = Unavailable('Download failed: $e');
    }
  }

  Future<InferenceModel> _load() => _loading ??= () async {
    final sw = Stopwatch()..start();
    try {
      final model = await FlutterEdgeAi.getActiveModel(
        defaults: _variant.runtimeDefaults,
        maxTokens: 2048,
        preferredBackend: PreferredBackend.gpu,
        supportAudio: true,
      );
      _model = model;
      status.value = const Installed(loaded: true);
      debugPrint(
        '⚡ Gemma loaded in ${sw.elapsed.inMilliseconds} ms '
        '(${model.activeBackend?.name ?? 'backend unknown'})',
      );
      return model;
    } catch (e) {
      _loading = null;
      status.value = Unavailable('Could not load the model: $e');
      rethrow;
    }
  }();

  bool get isReady => switch (status.value) {
    Installed() || Downloading() => _model != null,
    _ => false,
  };

  /// What the patient meant, or null: not installed, too slow, or an answer
  /// that does not pass the Dart checks. The caller then uses the rules.
  Future<Understanding?> understand(OfflineTurn turn) async {
    if (status.value is! Installed) return null;
    final message = switch (turn) {
      TextTurn(:final text) when text.isNotEmpty => Message.text(
        text: text,
        isUser: true,
      ),
      VoiceTurn(:final wav?) => Message.withAudio(
        text: 'The patient sent this voice message.',
        audioBytes: wav,
        isUser: true,
      ),
      _ => null, // Taps are structured already: the rules handle them.
    };
    if (message == null) return null;

    final sw = Stopwatch()..start();
    try {
      return await _ask(message).timeout(timeout);
    } catch (e) {
      debugPrint('✖ Gemma could not answer: $e');
      return null;
    } finally {
      lastLatency.value = sw.elapsed;
      debugPrint('⚡ Gemma answered in ${sw.elapsed.inMilliseconds} ms');
    }
  }

  Future<Understanding?> _ask(Message message) async {
    final model = await _load();
    // A fresh chat per turn: no history, so each answer is independent.
    final chat = await model.openChat(
      systemInstruction: _system,
      temperature: 0.1,
      maxOutputTokens: 128,
      supportAudio: message.hasAudio,
      responseFormat: _format,
    );
    try {
      await chat.addQueryChunk(message);
      final response = await chat.generateChatResponse();
      if (response is! TextResponse) return null;
      debugPrint('⚡ Gemma: ${response.token}');
      return Understanding.tryParse(jsonDecode(response.token));
    } finally {
      await chat.close();
    }
  }
}
