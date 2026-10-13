import 'speech_commands.dart';
import 'speech_engine.dart';

/// زبان تشخیص گفتار.
enum SpeechLanguage {
  persian('fa_IR', 'فارسی'),
  english('en_US', 'English');

  const SpeechLanguage(this.localeId, this.label);

  final String localeId;
  final String label;
}

/// وضعیت گفتار برای نمایش در UI.
enum SpeechUiState {
  idle,
  initializing,
  listening,
  processing,
  error,
}

/// سرویس سطح بالا برای گفتار.
///
/// مدل رویدادی دارد: [startListening] شروع می‌کند و نتیجه از طریق
/// callbackها می‌آید؛ [stopListening] پایان می‌دهد و متن نهایی را
/// برمی‌گرداند. این با رفتار واقعی پکیج `speech_to_text` یکی است
/// (listen بلافاصله بعد از شروع برمی‌گردد و جلسه تا stop ادامه دارد).
class SpeechService {
  SpeechService(this.engine);

  final SpeechEngine engine;
  final SpeechCommandParser _parser = const SpeechCommandParser();

  SpeechUiState _state = SpeechUiState.idle;
  SpeechUiState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  String _lastText = '';
  String get lastText => _lastText;

  bool get isAvailable => engine.isAvailable;
  bool get isListening => engine.isListening;

  /// آماده‌سازی و درخواست دسترسی میکروفون.
  Future<bool> initialize() async {
    _setState(SpeechUiState.initializing);
    try {
      final ok = await engine.initialize();
      if (!ok) {
        _lastError = 'تشخیص گفتار روی این دستگاه در دسترس نیست';
        _setState(SpeechUiState.error);
      } else {
        _setState(SpeechUiState.idle);
      }
      return ok;
    } catch (e) {
      _lastError = 'خطا در آماده‌سازی تشخیص گفتار: $e';
      _setState(SpeechUiState.error);
      return false;
    }
  }

  /// شروع گوش‌دادن.
  ///
  /// [onPartial] متن میانی را نمایش می‌دهد؛ [onFinal] متن نهایی را
  /// هنگام پایان تشخیص می‌دهد. جلسه تا [stopListening] یا [cancelListening]
  /// ادامه دارد.
  Future<void> startListening({
    void Function(String text)? onPartial,
    void Function(String text)? onFinal,
    SpeechLanguage language = SpeechLanguage.persian,
    bool onDevice = true,
    Duration? pauseFor,
    Duration? listenFor,
  }) async {
    _lastText = '';
    _setState(SpeechUiState.listening);
    await engine.listen(
      onPartial: (t) {
        _lastText = t;
        onPartial?.call(t);
      },
      onFinal: (t) {
        _lastText = t;
        _setState(SpeechUiState.processing);
        onFinal?.call(t);
      },
      localeId: language.localeId,
      onDevice: onDevice,
      pauseFor: pauseFor,
      listenFor: listenFor,
    );
  }

  /// پایان گوش‌دادن؛ متن نهایی تشخیص‌داده‌شده را برمی‌گرداند.
  Future<String> stopListening() async {
    await engine.stop();
    _setState(SpeechUiState.idle);
    return _lastText;
  }

  /// لغو گوش‌دادن بدون بازگرداندن متن.
  Future<void> cancelListening() async {
    await engine.cancel();
    _setState(SpeechUiState.idle);
  }

  /// گوش‌دادن برای یک دستور خواندن.
  ///
  /// متن نهایی به دستور تبدیل می‌شود؛ اگر دستور نبود، متن خام در
  /// [SpeechCommandResult.raw] برمی‌گردد تا فراخوانی‌کننده تصمیم بگیرد.
  Future<SpeechCommandResult> listenForCommand({
    SpeechLanguage language = SpeechLanguage.persian,
    bool onDevice = true,
    Duration? pauseFor,
    Duration? listenFor,
  }) async {
    _lastText = '';
    _setState(SpeechUiState.listening);
    String finalText = '';
    await startListening(
      onPartial: (t) => _lastText = t,
      onFinal: (t) {
        finalText = t;
        _lastText = t;
        _setState(SpeechUiState.processing);
      },
      language: language,
      onDevice: onDevice,
      pauseFor: pauseFor,
      listenFor: listenFor,
    );
    return _parser.parse(finalText);
  }

  /// متن خام را به دستور تبدیل می‌کند (آفلاین، بدون مدل).
  SpeechCommandResult parseCommand(String text) => _parser.parse(text);

  void _setState(SpeechUiState s) {
    _state = s;
  }

  void dispose() => engine.dispose();
}
