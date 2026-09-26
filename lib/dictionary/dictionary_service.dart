import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';

// دیکشنری کاملاً آفلاین — دیتاست انگلیسی→فارسی داخل خود اپ (assets)
class DictionaryService {
  static final DictionaryService instance = DictionaryService._();
  DictionaryService._();

  Map<String, dynamic>? _map;
  final _tts = FlutterTts();

  Future<void> _ensureLoaded() async {
    if (_map != null) return;
    final raw = await rootBundle.loadString('assets/dict/en_fa.json');
    _map = jsonDecode(raw) as Map<String, dynamic>;
  }

  String normalize(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'''[!?,;:"'()\[\]{}«».]$'''), '')
        .replaceAll(RegExp(r'''^[!?,;:"'()\[\]{}«».]'''), '');
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

  /// تلفظ با موتور TTS خود گوشی — آفلاین، حجم صفر
  Future<void> speak(String text, {String lang = 'en-US'}) async {
    try {
      await _tts.setLanguage(lang);
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
