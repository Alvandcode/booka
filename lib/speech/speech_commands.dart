/// تحلیل آفلاین دستورهای گفتاری به عمل خواندن.
///
/// همه‌چیز اینجا بدون مدل و بدون شبکه انجام می‌شود: متن تشخیص‌داده‌شده
/// نرمال می‌شود و با الگوهای ساده فارسی/انگلیسی تطبیق داده می‌شود.
/// به‌همین دلیل قابل‌تست است و کار می‌کند حتی وقتی تشخیص گفتار
/// کار نمی‌کند.
library;

/// دستورهایی که خواننده می‌تواند با دهان اجرا کند.
enum SpeechCommand {
  /// شروع یا ازسرگیری خواندن با صدا
  readAloud,
  /// توقف خواندن با صدا
  stopReading,
  /// رفتن به صفحه/بخش بعدی
  next,
  /// بازگشت به صفحه/بخش قبلی
  previous,
  /// توقف موقت خواندن
  pauseReading,
  /// برگرداندن کتاب به فهرست
  exitReader,
  /// توقف کامل (خواندن و ضبط)
  halt,
}

/// نتیجه‌ی تحلیل یک عبارت گفتاری.
class SpeechCommandResult {
  const SpeechCommandResult(this.command, {this.raw = ''});

  /// دستور تشخیص‌داده‌شده؛ در نبود دستور خالی است.
  final SpeechCommand? command;

  /// متن خام تشخیص‌داده‌شده (برای جستجو آزاد).
  final String raw;

  bool get isEmpty => command == null && raw.trim().isEmpty;

  bool get isCommand => command != null;
}

/// تحلیل‌گر آفلاین دستورهای گفتاری.
class SpeechCommandParser {
  const SpeechCommandParser();

  static const Map<String, SpeechCommand> _patterns = {
    // فارسی
    'بخوان': SpeechCommand.readAloud,
    'بخون': SpeechCommand.readAloud,
    'زنده': SpeechCommand.readAloud,
    'ادامه': SpeechCommand.readAloud,
    'شروع': SpeechCommand.readAloud,
    'توقف': SpeechCommand.stopReading,
    'بسه': SpeechCommand.stopReading,
    'بستن': SpeechCommand.stopReading,
    'تمام': SpeechCommand.stopReading,
    'بسته': SpeechCommand.stopReading,
    'بعدی': SpeechCommand.next,
    'بعد': SpeechCommand.next,
    'صفحه بعد': SpeechCommand.next,
    'قبلی': SpeechCommand.previous,
    'قبل': SpeechCommand.previous,
    'برگرد': SpeechCommand.previous,
    'مکث': SpeechCommand.pauseReading,
    'استراحت': SpeechCommand.pauseReading,
    'خروج': SpeechCommand.exitReader,
    'بیرون': SpeechCommand.exitReader,
    'بازگشت': SpeechCommand.exitReader,
    'انصراف': SpeechCommand.exitReader,
    'کتابخانه': SpeechCommand.exitReader,
    // انگلیسی
    'read': SpeechCommand.readAloud,
    'play': SpeechCommand.readAloud,
    'resume': SpeechCommand.readAloud,
    'continue': SpeechCommand.readAloud,
    'stop': SpeechCommand.stopReading,
    'quit': SpeechCommand.stopReading,
    'end': SpeechCommand.stopReading,
    'next': SpeechCommand.next,
    'forward': SpeechCommand.next,
    'previous': SpeechCommand.previous,
    'back': SpeechCommand.previous,
    'pause': SpeechCommand.pauseReading,
    'hold': SpeechCommand.pauseReading,
    'exit': SpeechCommand.exitReader,
    'leave': SpeechCommand.exitReader,
    'library': SpeechCommand.exitReader,
    'cancel': SpeechCommand.exitReader,
    'halt': SpeechCommand.halt,
  };

  /// عبارت را به دستور تبدیل می‌کند؛ در نبود دستور `null` برمی‌گرداند.
  SpeechCommandResult parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const SpeechCommandResult(null);

    // ابتدا تطابق کامل — دستور مستقیم
    final direct = _patterns[text];
    if (direct != null) return SpeechCommandResult(direct, raw: text);

    // بعد تطابق زیررشته‌ای برای دستورهای چندکلمه‌ای مثل «صفحه بعد»
    // یا عباراتی مثل «برو به صفحه بعد».
    for (final entry in _patterns.entries) {
      if (entry.key.length >= 3 && text.contains(entry.key)) {
        return SpeechCommandResult(entry.value, raw: text);
      }
    }
    return SpeechCommandResult(null, raw: text);
  }
}
