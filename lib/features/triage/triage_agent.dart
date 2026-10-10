// ─────────────────────────────────────────────────────────────────────────────
// THE AGENT LOOP: how GenUI connects Gemini to Flutter.
//
//   patient text or voice / widget event
//          │
//          ▼
//   Conversation ──► A2uiTransportAdapter.onSend ──► Gemini (streaming)
//                                                        │  A2UI JSON chunks
//                                                        ▼
//   Surface widget ◄── SurfaceController ◄── transport.addChunk(...)
//          │
//          └── user taps a widget → dispatchEvent → controller.onSubmit
//                                   → Conversation sends it back to Gemini
//
// No screen is hardcoded: every answer is a new "surface" composed by the
// agent from the catalog.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:firebase_ai/firebase_ai.dart' as gemini;

import '../../catalog/catalog_items.dart';
import '../../core/constants/prompts.dart';

/// Raised when a turn ends without any interface to show.
class TriageAgentException implements Exception {
  const TriageAgentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TriageAgent {
  TriageAgent({required String model}) {
    // 1. The controller owns the surfaces and knows our catalog.
    controller = SurfaceController(catalogs: [triageCatalog]);

    // 2. The transport is the pipe to the LLM. We plug Gemini in `onSend`
    //    and push its streamed text back with `addChunk`: genui's parser
    //    extracts the A2UI JSON blocks on the fly.
    _transport = A2uiTransportAdapter(onSend: _enqueue);

    // 3. Conversation glues both: incoming A2UI messages → controller, and
    //    widget events (controller.onSubmit) → a new request to the LLM.
    conversation = Conversation(controller: controller, transport: _transport);

    _surfaceSub = controller.surfaceUpdates.listen(_onSurfaceUpdate);
    _eventsSub = conversation.events.listen((event) {
      if (event is ConversationError) {
        debugPrint('✖ Gemini error: ${event.error.runtimeType}: ${event.error}');
        error.value = event.error;
      }
    });

    // 4. PromptBuilder merges our domain prompt with the A2UI protocol rules
    //    and the JSON Schema of every CatalogItem.
    final prompt = PromptBuilder.chat(
      catalog: triageCatalog,
      systemPromptFragments: [triageSystemPrompt],
    );

    // No API key in the app: Firebase AI Logic holds it server-side.
    _chat = gemini.FirebaseAI.googleAI()
        .generativeModel(
          model: model,
          systemInstruction: gemini.Content.system(prompt.systemPromptJoined()),
          generationConfig: gemini.GenerationConfig(temperature: 0.3),
        )
        .startChat();
  }

  late final SurfaceController controller;
  late final Conversation conversation;
  late final A2uiTransportAdapter _transport;
  late final gemini.ChatSession _chat;
  late final StreamSubscription<SurfaceUpdate> _surfaceSub;
  late final StreamSubscription<ConversationEvent> _eventsSub;

  /// Id of the surface currently displayed (the latest complete one).
  final currentSurfaceId = ValueNotifier<String?>(null);

  /// True while Gemini is composing an interface.
  final isThinking = ValueNotifier<bool>(false);

  /// Last error, cleared when a new turn starts.
  final error = ValueNotifier<Object?>(null);

  /// Interfaces refused before reaching the patient (genui schema validation
  /// or the Dart guard), as reported back to the agent.
  Stream<String> get renderErrors => _renderErrors.stream;
  final _renderErrors = StreamController<String>.broadcast();

  static const _maxRepairs = 2;
  int _turn = 0;
  int _inFlight = 0;
  int _repairs = 0;
  bool _repairQueued = false;
  Future<void> _queue = Future.value();

  /// Sends the patient's free text to the agent.
  Future<void> send(String text) {
    _repairs = 0;
    return conversation.sendRequest(ChatMessage.user(text.trim()));
  }

  /// Live demo only: plays a prepared A2UI answer as if Gemini had written
  /// it, to show a hallucination on stage without relying on the model.
  /// `{{surfaceId}}` is replaced with the next surface id.
  void injectForDemo(String a2uiBlocks) {
    _repairs = 0;
    error.value = null;
    final surfaceId = 'triage-${++_turn}';
    _transport.addChunk(a2uiBlocks.replaceAll('{{surfaceId}}', surfaceId));
  }

  /// Sends a voice message: Gemini listens to the audio itself (no
  /// speech-to-text step), so it also understands local languages.
  Future<void> sendVoice(Uint8List wav) {
    _repairs = 0;
    return conversation.sendRequest(
      ChatMessage.user('', parts: [DataPart(wav, mimeType: _wavMimeType)]),
    );
  }

  static const _wavMimeType = 'audio/wav';

  SurfaceContext contextFor(String surfaceId) =>
      controller.contextFor(surfaceId);

  // ── Surface tracking ──────────────────────────────────────────────────────

  void _onSurfaceUpdate(SurfaceUpdate update) {
    // A surface is ready to show once its components (with a root) arrived.
    if (update case ComponentsUpdated(
      :final surfaceId,
      :final definition,
    ) when definition.components.containsKey('root')) {
      currentSurfaceId.value = surfaceId;
    }
  }

  // ── Transport → Gemini ────────────────────────────────────────────────────

  /// Turns are serialised: a widget event or a repair request arriving while
  /// Gemini is still streaming waits for the current turn to finish.
  Future<void> _enqueue(ChatMessage message) async {
    if (_isLocalOnly(message)) return;
    if (_isRenderError(message)) {
      _repairQueued = true;
      _renderErrors.add(_errorMessage(message));
    }
    _inFlight++;
    isThinking.value = true;
    final run = _queue.then((_) => _runTurn(message)).whenComplete(() {
      if (--_inFlight == 0) isThinking.value = false;
    });
    _queue = run.catchError((_) {});
    return run;
  }

  /// Widget-internal events (e.g. StepperCard navigation) stay on device.
  bool _isLocalOnly(ChatMessage message) => message.parts.any(
    (p) =>
        p is DataPart &&
        p.mimeType == UiPartConstants.interactionMimeType &&
        localOnlyEvents.contains(
          (_decodeInteraction(p)['action'] as Map?)?['name'],
        ),
  );

  Future<void> _runTurn(ChatMessage message) async {
    final surfaceId = 'triage-${++_turn}';
    final isRepair = _isRenderError(message);
    if (isRepair) {
      _repairQueued = false;
      if (++_repairs > _maxRepairs) {
        throw const TriageAgentException(
          "L'agent n'arrive pas à composer l'interface. Reformulez votre demande.",
        );
      }
    }
    error.value = null;

    final content = _toContent(message, surfaceId);
    debugPrint(
      '▶ Gemini [$surfaceId]\n'
      '${content.parts.map((p) => p is gemini.TextPart ? p.text : '[audio]').join('\n')}',
    );

    // Stream Gemini's answer straight into genui's parser. A failure before
    // the first chunk (network blip, App Check token fetch) is retried once.
    for (var attempt = 1; ; attempt++) {
      var received = false;
      try {
        await for (final chunk in _chat.sendMessageStream(content)) {
          final text = chunk.text;
          if (text != null && text.isNotEmpty) {
            received = true;
            _transport.addChunk(text);
          }
        }
        break;
      } catch (e) {
        if (received || attempt > 1) rethrow;
        debugPrint('↻ Gemini retry after: $e');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    // Let the parser → controller → listeners pipeline flush its microtasks.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    if (currentSurfaceId.value != surfaceId && !_repairQueued) {
      throw const TriageAgentException(
        "L'agent n'a pas produit d'interface. Réessayez.",
      );
    }
  }

  /// Converts a genui [ChatMessage] into the turn Gemini receives: text
  /// lines, plus the audio clip when the patient spoke.
  gemini.Content _toContent(ChatMessage message, String surfaceId) {
    final lines = <String>[];
    final audio = <gemini.Part>[];
    for (final part in message.parts) {
      if (part is TextPart && part.text.trim().isNotEmpty) {
        lines.add(patientTurn(part.text.trim(), surfaceId));
      } else if (part is DataPart && part.mimeType == _wavMimeType) {
        lines.add(voiceTurn(surfaceId));
        audio.add(gemini.InlineDataPart(part.mimeType, part.bytes));
      } else if (part is DataPart &&
          part.mimeType == UiPartConstants.interactionMimeType) {
        final payload = _decodeInteraction(part);
        if (payload['action'] case final Map<dynamic, dynamic> action) {
          lines.add(
            interactionTurn(
              '${action['name']}',
              jsonEncode(action['context'] ?? const {}),
              surfaceId,
            ),
          );
        } else if (payload['error'] != null) {
          lines.add(renderErrorTurn(jsonEncode(payload['error']), surfaceId));
        }
      }
    }
    return gemini.Content.multi([gemini.TextPart(lines.join('\n')), ...audio]);
  }

  bool _isRenderError(ChatMessage message) => message.parts.any(
    (p) =>
        p is DataPart &&
        p.mimeType == UiPartConstants.interactionMimeType &&
        _decodeInteraction(p)['error'] != null,
  );

  String _errorMessage(ChatMessage message) => [
    for (final p in message.parts)
      if (p is DataPart && p.mimeType == UiPartConstants.interactionMimeType)
        if (_decodeInteraction(p)['error'] case {'message': final m}) '$m',
  ].join('\n');

  Map<String, Object?> _decodeInteraction(DataPart part) {
    try {
      final json = jsonDecode(UiInteractionPart.fromDataPart(part).interaction);
      return json is Map<String, Object?> ? json : const {};
    } catch (_) {
      return const {};
    }
  }

  void dispose() {
    _surfaceSub.cancel();
    _eventsSub.cancel();
    _renderErrors.close();
    conversation.dispose();
    _transport.dispose();
    controller.dispose();
    currentSurfaceId.dispose();
    isThinking.dispose();
    error.dispose();
  }
}
