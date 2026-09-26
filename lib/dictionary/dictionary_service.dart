import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';

// دیکشنری کاملاً آفلاین — دیتاست انگلیسی→فارسی داخل خود اپ (assets)
class DictionaryService {
  static final DictionaryService instance = DictionaryService._();
  DictionaryService._();

  Map<String, dynamic>? _map;

  /// موتور TTS با نیاز lazily ساخته می‌شود. ساختنش در constructor باعث
  /// می‌شد استفاده از منطق خالصِ [normalize] هم به کانال پلتفرم وابسته
  /// شود و در تست واحد بشکند.
  FlutterTts? _tts;
  FlutterTts get _speech => _tts ??= FlutterTts();

  Future<void> _ensureLoaded() async {
    if (_map != null) return;
    final raw = await rootBundle.loadString('assets/dict/en_fa.json');
    _map = jsonDecode(raw) as Map<String, dynamic>;
  }

  /// نشانه‌هایی که ممکن است دور واژه باشند — شامل علامت‌های
  /// عربی و فارسی که در متن کتاب‌ها بسیار رایج‌اند.
  /// توجه: این الگو فقط روی ابتدا و انتها اعمال می‌شود، نه کل رشده،
  /// تا نشانه‌های داخلی مثل آپاستروف در don't سالم بمانند.
  static final _leadingPunctuation =
      RegExp(r'''^[\s!?,;:"'`(){}\[\]«»،؛؟٪٫…\.\-–—/\\|]+''');
  static final _trailingPunctuation =
      RegExp(r'''[\s!?,;:"'`(){}\[\]«»،؛؟٪٫…\.\-–—/\\|]+$''');

  /// یکسان‌سازی واژه برای جستجو: کوچک‌سازی حروف، حذف نشانه‌گذاری
  /// ابتدا و انتها و فشرده‌سازی فاصله‌های داخلی.
  ///
  /// نسخه قبلی فقط یک نشانه از هر طرف را حذف می‌کرد و نشانه‌های
  /// عربی مثل «،» و «؟» را نمی‌شناخت، بنابراین جستجوی کلمه‌ای که
  /// در جمله با ویرگول آمده بود شکست می‌خورد.
  String normalize(String s) {
    return s
        .toLowerCase()
        .replaceFirst(_leadingPunctuation, '')
        .replaceFirst(_trailingPunctuation, '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// معنی‌ها؛ آرایه خالی یعنی پیدا نشد
  Future<List<String>> lookup(String word) async {
    await _ensureLoaded();
    final q = normalize(word);
    if (q.isEmpty) return [];
    final m = _map!;
    final direct = m[q];
    if (direct is List && direct.isNotEmpty) {
      return direct.cast<String>();
    }
    // تلاش برای ریشه (حذف s/es/ing/ed ساده)
    for (final suf in <String>['s', 'es', 'ing', 'ed']) {
      if (q.length > suf.length + 2 && q.endsWith(suf)) {
        final stem = q.substring(0, q.length - suf.length);
        final hit = m[stem];
        if (hit is List && hit.isNotEmpty) return hit.cast<String>();
        if (suf == 'es') {
          final hit2 = m[q.substring(0, q.length - 1)];
          if (hit2 is List && hit2.isNotEmpty) return hit2.cast<String>();
        }
      }
    }
    return [];
  }

  /// تلفظ با موتور TTS خود گوشی — آفلاین، حجم صفر.
  /// خطا اینجا عمداً بی‌صدا رد می‌شود چون نبود موتور TTS نباید
  /// جریان عادی خواندن را متوقف کند؛ وضعیت در [isSpeechAvailable] دیده می‌شود.
  Future<void> speak(String text, {String lang = 'en-US'}) async {
    try {
      final tts = _speech;
      await tts.setLanguage(lang);
      await tts.setSpeechRate(0.45);
      await tts.speak(text);
    } catch (_) {}
  }

  /// آیا موتور تلفظ روی این دستگاه در دسترس است؟
  /// برای پنهان کردن دکمه تلفظ وقتی هیچ موتوری نصب نیست.
  Future<bool> isSpeechAvailable() async {
    try {
      final engines = await _speech.getEngines;
      return engines is List && engines.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }
}
