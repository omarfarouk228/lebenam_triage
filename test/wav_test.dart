import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lebenam_triage/features/triage/voice/wav.dart';

void main() {
  test('wraps PCM in a valid 16 kHz mono WAV header', () {
    final pcm = Uint8List.fromList(List.generate(3200, (i) => i % 256));
    final wav = wavFromPcm16(pcm, sampleRate: 16000);
    final header = ByteData.sublistView(wav, 0, 44);

    expect(wav.length, 44 + pcm.length);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    expect(header.getUint32(4, Endian.little), 36 + pcm.length);
    expect(header.getUint16(22, Endian.little), 1); // mono
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint32(28, Endian.little), 32000); // byte rate
    expect(header.getUint32(40, Endian.little), pcm.length);
    expect(wav.sublist(44), pcm);
  });
}
