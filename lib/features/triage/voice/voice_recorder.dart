import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'wav.dart';

/// Records the patient's voice as a WAV clip Gemini can listen to.
///
/// The microphone is streamed as raw 16-bit PCM (supported on every
/// platform, web included, without touching the file system) and wrapped in
/// a WAV header on stop. 16 kHz mono is what speech models expect anyway:
/// ~32 KB per second, small enough to send inline.
class VoiceRecorder {
  static const sampleRate = 16000;
  static const maxDuration = Duration(seconds: 60);

  final _recorder = AudioRecorder();
  final _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<Amplitude>? _levelSub;
  Timer? _ticker;
  final _clock = Stopwatch();

  /// Elapsed recording time, updated a few times per second.
  final elapsed = ValueNotifier(Duration.zero);

  /// Microphone level, 0 (silence) to 1 (loud).
  final level = ValueNotifier(0.0);

  /// Called when [maxDuration] is reached.
  VoidCallback? onMaxDuration;

  /// Asks for the microphone permission if needed. `false` = denied.
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    _pcm.clear();
    elapsed.value = Duration.zero;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    _audioSub = stream.listen(_pcm.add);
    _levelSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((a) => level.value = ((a.current + 50) / 50).clamp(0.0, 1.0));
    _clock
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      elapsed.value = _clock.elapsed;
      if (_clock.elapsed >= maxDuration) onMaxDuration?.call();
    });
  }

  /// Stops and returns the clip as WAV bytes (`null` if nothing was heard).
  Future<Uint8List?> stop() async {
    await _recorder.stop();
    await _teardown();
    final pcm = _pcm.takeBytes();
    // Under ~0.3 s it is a mis-tap, not a message.
    if (pcm.length < sampleRate * 2 * 0.3) return null;
    return wavFromPcm16(pcm, sampleRate: sampleRate);
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    await _teardown();
    _pcm.clear();
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _clock.stop();
    await _audioSub?.cancel();
    await _levelSub?.cancel();
    _audioSub = null;
    _levelSub = null;
    level.value = 0;
  }

  Future<void> dispose() async {
    await _teardown();
    await _recorder.dispose();
    elapsed.dispose();
    level.dispose();
  }
}
