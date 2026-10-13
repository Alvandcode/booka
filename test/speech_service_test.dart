import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader_app/speech/speech_commands.dart';
import 'package:book_reader_app/speech/speech_engine.dart';
import 'package:book_reader_app/speech/speech_service.dart';

/// موتور ساختگی که نتایج را از یک فهرست پیکربندی‌شده تولید می‌کند.
class FakeEngine implements SpeechEngine {
  FakeEngine({this.available = true, this.granted = true});

  bool available;
  bool granted;
  int initializeCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  String? lastLocale;
  bool? lastOnDevice;
  Duration? lastPauseFor;
  Duration? lastListenFor;

  /// متن‌هایی که به‌عنوان partial اعلام می‌شوند.
  List<String> partials = [];
  /// متن‌هایی که به‌عنوان final اعلام می‌شوند.
  List<String> finals = [];

  void Function(String)? partialCb;
  void Function(String)? finalCb;

  @override
  bool get isAvailable => available;

  @override
  bool get isListening => false;

  @override
  String? get lastError => null;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> requestPermission() async {
    initializeCalls++;
    return granted;
  }

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return available;
  }

  @override
  Future<void> listen({
    void Function(String text)? onPartial,
    void Function(String text)? onFinal,
    String? localeId,
    bool onDevice = true,
    Duration? pauseFor,
    Duration? listenFor,
  }) async {
    listenCalls++;
    lastLocale = localeId;
    lastOnDevice = onDevice;
    lastPauseFor = pauseFor;
    lastListenFor = listenFor;
    partialCb = onPartial;
    finalCb = onFinal;
    for (final p in partials) {
      partialCb?.call(p);
    }
    for (final f in finals) {
      finalCb?.call(f);
    }
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> cancel() async => cancelCalls++;

  @override
  void dispose() {}
}

void main() {
  group('SpeechService.initialize', () {
    test('موتور در دسترس → موفق و وضعیت idle', () async {
      final engine = FakeEngine();
      final svc = SpeechService(engine);
      expect(await svc.initialize(), isTrue);
      expect(svc.state, SpeechUiState.idle);
      expect(svc.isAvailable, isTrue);
      expect(engine.initializeCalls, 1);
    });

    test('موتور ناموجود → شکست و پیام خطا', () async {
      final engine = FakeEngine(available: false);
      final svc = SpeechService(engine);
      expect(await svc.initialize(), isFalse);
      expect(svc.state, SpeechUiState.error);
      expect(svc.lastError, isNotNull);
    });

    test('استثنا در موتور → شکست و وضعیت error', () async {
      final engine = FakeEngine()..available = false;
      final svc = SpeechService(engine);
      expect(await svc.initialize(), isFalse);
      expect(svc.state, SpeechUiState.error);
    });
  });

  group('SpeechService.startListening', () {
    test('زبان و گزینه‌ها به موتور فرستاده می‌شود', () async {
      final engine = FakeEngine();
      final svc = SpeechService(engine);
      await svc.initialize();
      await svc.startListening(
        language: SpeechLanguage.english,
        onDevice: true,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 20),
      );
      expect(engine.listenCalls, 1);
      expect(engine.lastLocale, 'en_US');
      expect(engine.lastOnDevice, isTrue);
      expect(engine.lastPauseFor, const Duration(seconds: 2));
      expect(engine.lastListenFor, const Duration(seconds: 20));
      expect(svc.isListening, isFalse);
    });

    test('متن partial و final ثبت می‌شود', () async {
      final engine = FakeEngine()..finals = ['سلام'];
      final svc = SpeechService(engine);
      await svc.initialize();
      final partials = <String>[];
      String? finalText;
      await svc.startListening(
        onPartial: partials.add,
        onFinal: (t) => finalText = t,
      );
      engine.partialCb?.call('س');
      engine.finalCb?.call('سلام');
      expect(partials, ['س']);
      expect(finalText, 'سلام');
      expect(svc.lastText, 'سلام');
      expect(svc.state, SpeechUiState.processing);
    });
  });

  group('SpeechService.stopListening', () {
    test('متن نهایی را برمی‌گرداند و وضعیت idle می‌شود', () async {
      final engine = FakeEngine()..finals = ['کتاب'];
      final svc = SpeechService(engine);
      await svc.initialize();
      await svc.startListening();
      final text = await svc.stopListening();
      expect(text, 'کتاب');
      expect(engine.stopCalls, 1);
      expect(svc.state, SpeechUiState.idle);
    });
  });

  group('SpeechService.cancelListening', () {
    test('stop صدا زده نمی‌شود و وضعیت idle می‌شود', () async {
      final engine = FakeEngine();
      final svc = SpeechService(engine);
      await svc.initialize();
      await svc.startListening();
      await svc.cancelListening();
      expect(engine.cancelCalls, 1);
      expect(engine.stopCalls, 0);
      expect(svc.state, SpeechUiState.idle);
    });
  });

  group('SpeechService.parseCommand', () {
    test('دستور فارسی تبدیل می‌شود', () {
      final svc = SpeechService(FakeEngine());
      expect(svc.parseCommand('بخوان').command, SpeechCommand.readAloud);
      expect(svc.parseCommand('بعدی').command, SpeechCommand.next);
    });

    test('بدون دستور → raw', () {
      final svc = SpeechService(FakeEngine());
      final r = svc.parseCommand('چه کتابی داری');
      expect(r.isCommand, isFalse);
      expect(r.raw, 'چه کتابی داری');
    });
  });
}
