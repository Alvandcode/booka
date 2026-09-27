import 'dart:convert';

import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;

/// آماده‌سازی HTML بخش‌های EPUB برای رندر.
///
/// دو کار انجام می‌دهد:
/// ۱. تصاویر داخل کتاب را به `data:` URI تبدیل می‌کند تا رندرکننده
///    بتواند بدون دسترسی به فایل‌سیستم آن‌ها را نشان دهد.
/// ۲. سبک‌های سراسری کتاب را داخل همان سند تزریق می‌کند، چون فلاتر
///    فایل CSS جداگانه را بارگذاری نمی‌کند.
class EpubHtml {
  const EpubHtml._();

  /// بیشینه حجم هر تصویر به base64. تصویرهای بزرگ‌تر نمی‌روند تا
  /// حافظه و زمان پارس یک بخش غیرقابل‌کنترل نشود.
  static const maxInlineImageBytes = 4 * 1024 * 1024;

  static const _mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'bmp': 'image/bmp',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
  };

  /// ساخت HTML آماده رندر برای یک بخش.
  ///
  /// [images] نقشه مسیر → بایت‌های تصویر از خود کتاب است.
  static String renderable(
    String html, {
    Map<String, List<int>> images = const {},
    String? css,
  }) {
    if (html.isEmpty) return '';
    var out = inlineImages(html, images);
    if (css != null && css.trim().isNotEmpty) {
      out = _injectStyle(out, css);
    }
    return out;
  }

  /// جایگزینی `src` تصویرها با `data:` URI.
  ///
  /// فقط مسیرهای نسبی داخل کتاب نگاشت می‌شوند؛ `data:` و `http` دست‌نخورده
  /// می‌مانند و تصویرهای بیش از حد بزرگ یا ناموجود حذف می‌شوند.
  static String inlineImages(
    String html,
    Map<String, List<int>> images,
  ) {
    if (images.isEmpty) return html;

    // کلیدها را به شکل‌های مختلف نگاشت می‌کنیم تا با هر نحوه
    // نوشتن href در کتاب‌های مختلف پیدا شوند
    final lookup = <String, List<int>>{};
    for (final entry in images.entries) {
      final raw = entry.key;
      if (entry.value.isEmpty) continue;
      lookup[raw] = entry.value;
      lookup[_tryDecode(raw)] = entry.value;
      final base = _basename(raw);
      if (base != raw) lookup[base] = entry.value;
    }

    return html.replaceAllMapped(_imgSrc, (m) {
      final quotedDouble = m.group(1);
      final quotedSingle = m.group(2);
      final bare = m.group(3);
      final src = quotedDouble ?? quotedSingle ?? bare;
      if (src == null || src.isEmpty) return m.group(0)!;

      final lower = src.toLowerCase();
      // منابع بیرونی یا از پیش inline را دست نمی‌زنیم
      if (lower.startsWith('data:') ||
          lower.startsWith('http://') ||
          lower.startsWith('https://') ||
          lower.startsWith('//')) {
        return m.group(0)!;
      }

      final bytes = lookup[src] ??
          lookup[_tryDecode(src)] ??
          lookup[_basename(src)];
      if (bytes == null || bytes.isEmpty) return m.group(0)!;
      if (bytes.length > maxInlineImageBytes) return m.group(0)!;

      // بدون نقل‌قول باید همان شکل بدون نقل‌قول بماند
      if (bare != null) return 'src=$bare'.replaceFirst(bare, _dataUri(src, bytes));
      return m.group(0)!.replaceFirst(src, _dataUri(src, bytes));
    });
  }

  /// تطبیق `src="..."` و `src='...'` و `src=...`
  static final _imgSrc = RegExp(
    r'''src\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
    caseSensitive: false,
  );

  static String _dataUri(String src, List<int> bytes) {
    final ext = _basename(src).contains('.')
        ? _basename(src).split('.').last.toLowerCase()
        : '';
    final mime = _mimeByExtension[ext] ?? 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  /// تزریق CSS کتاب به داخل سند
  static String _injectStyle(String html, String css) {
    final headClose = html.toLowerCase().indexOf('</head>');
    if (headClose != -1) {
      return html.replaceRange(
        headClose,
        headClose,
        '<style type="text/css">$css</style>',
      );
    }
    final bodyOpen = html.toLowerCase().indexOf('<body');
    if (bodyOpen != -1) {
      return html.replaceRange(
          bodyOpen, bodyOpen, '<head><style>$css</style></head>');
    }
    return '<style>$css</style>$html';
  }

  static String _tryDecode(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }

  static String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i == -1 ? path : path.substring(i + 1);
  }

  /// ساخت نقشه تصاویر از محتوای کتاب، برای [inlineImages]
  static Map<String, List<int>> imageMap(EpubBook book) {
    final raw = book.Content?.Images;
    if (raw == null || raw.isEmpty) return const {};
    final out = <String, List<int>>{};
    raw.forEach((href, file) {
      try {
        final bytes = file.Content;
        if (bytes != null && bytes.isNotEmpty) out[href] = bytes;
      } catch (_) {
        // تصویر خراب نادیده گرفته می‌شود
      }
    });
    return out;
  }

  /// یکپارچه‌سازی CSS های داخل کتاب (به ترتیب نام فایل)
  static String combinedCss(EpubBook book) {
    final raw = book.Content?.Css;
    if (raw == null || raw.isEmpty) return '';
    final keys = raw.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final k in keys) {
      try {
        buffer.writeln(raw[k]?.Content ?? '');
      } catch (_) {}
    }
    return buffer.toString();
  }

  /// استخراج متن خالص از HTML برای جستجو — بدون تصویر و بدون CSS
  static String plainText(String html) {
    if (html.isEmpty) return '';
    try {
      final frag = html_parser.parseFragment(html);
      return frag.text?.trim() ?? '';
    } catch (_) {
      return html.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
    }
  }
}
