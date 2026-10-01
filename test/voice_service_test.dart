import 'package:flutter_test/flutter_test.dart';
import 'package:klugmind/core/services/voice_service.dart';

void main() {
  group('cleanTranscript', () {
    test('collapses whitespace and control chars', () {
      expect(VoiceService.cleanTranscript('  a \n\t b\u0000  c '), 'a b c');
    });
    test('empty stays empty', () {
      expect(VoiceService.cleanTranscript('   '), '');
    });
  });

  group('TranscriptSession', () {
    test('finish returns last partial words and confidence', () async {
      final s = TranscriptSession()..update('SN2 is', 0.4)..update('SN2 is bimolecular', 0);
      s.finish();
      final r = await s.future;
      expect(r.text, 'SN2 is bimolecular');
      expect(r.confidence, 0.4);
    });
    test('empty transcript completes with StateError', () {
      final s = TranscriptSession()..finish();
      expect(s.future, throwsStateError);
    });
    test('permission error is mapped', () async {
      final s = TranscriptSession()..finish(error: 'error_permission');
      await expectLater(
        s.future,
        throwsA(isA<StateError>().having((e) => e.message, 'm', contains('permission'))),
      );
    });
    test('finish is idempotent', () async {
      final s = TranscriptSession()..update('hi', 1);
      s.finish();
      s.finish(error: 'late'); // must not throw
      expect((await s.future).text, 'hi');
      expect(s.isDone, isTrue);
    });
  });
}