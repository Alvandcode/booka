import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// موتور تشخیص گفتار به‌صورت انتزاعی تا در تست‌ها قابل جانشینی باشد.
abstract class SpeechEngine {
  /// آیا آماده‌ی کار است؟
  bool get isAvailable;

  /// آیا در حال گوش‌دادن است؟
  bool get isListening;

  /// آخرین خطا (اگر هست).
  String? get lastError;

  /// آیا دسترسی میکروفون از قبل داده شده؟
  Future<bool> hasPermission();

  /// درخواست دسترسی میکروفون از کاربر.
  Future<bool> requestPermission();

  /// آماده‌سازی موتور؛ نتیجه نشان می‌دهد که تشخیص گفتار روی دستگاه
  /// در دسترس است یا نه.
  Future<bool> initialize();

  /// شروع گوش‌دادن.
  ///
  /// [onPartial] متن میانی را هر بار که موتور به‌روز کرد می‌دهد.
  /// [onFinal] متن نهایی را در پایان می‌دهد.
  /// [localeId] مثل `fa_IR` یا `en_US`.
  /// [onDevice] در صورت true تلاش می‌کند بدون شبکه تشخیص دهد.
  /// [pauseFor] مکث مجاز قبل از پایان تشخیص؛ خالی یعنی نامحدود.
  /// [listenFor] حداکثر مدت گوش‌دادن.
  Future<void> listen({
    void Function(String text)? onPartial,
    void Function(String text)? onFinal,
    String? localeId,
    bool onDevice = true,
    Duration? pauseFor,
    Duration? listenFor,
  });

  /// پایان گوش‌دادن و اعلام متن نهایی.
  Future<void> stop();

  /// لغو گوش‌دادن بدون اعلام متن نهایی.
  Future<void> cancel();

  /// آزادسازی منابع.
  void dispose();
}

/// پیاده‌سازی واقعی با پکیج `speech_to_text` و موتور بومی پلتفرم.
class RealSpeechEngine implements SpeechEngine {
  RealSpeechEngine({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _available = false;

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _speech.isListening;

  @override
  String? get lastError {
    final e = _speech.lastError;
    if (e == null) return null;
    // کد خطا را نگه می‌داریم تا UI بتواند پیام متناسب نشان دهد.
    return e.errorMsg.isEmpty ? 'خطای ناشناخته' : e.errorMsg;
  }

  @override
  Future<bool> hasPermission() async => _speech.hasPermission;

  @override
  Future<bool> requestPermission() async {
    // پلاگین در initialize خودش RECORD_AUDIO را از کاربر می‌خواهد
    // (SpeechToTextPlugin.kt: initializeIfPermitted)، پس همان مسیر
    // را می‌رویم و نتیجه‌اش را به‌عنوان وضعیت دسترسی برمی‌گردانیم.
    final ok = await initialize();
    return ok;
  }

  @override
  Future<bool> initialize() async {
    if (_available) return true;
    final ok = await _speech.initialize(
      onError: (_) {},
      debugLogging: false,
    );
    _available = ok;
    return ok;
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
    if (!_available) {
      final ok = await initialize();
      if (!ok) return;
    }
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) {
        final text = r.recognizedWords;
        if (r.finalResult) {
          onFinal?.call(text);
        } else {
          onPartial?.call(text);
        }
      },
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        onDevice: onDevice,
        partialResults: true,
        cancelOnError: false,
        pauseFor: pauseFor,
        listenFor: listenFor,
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  @override
  void dispose() => _speech.cancel();
}
