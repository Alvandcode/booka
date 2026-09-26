import 'package:html/parser.dart' as html_parser;

/// ابزارهای خالصِ متن — بدون وابستگی به Flutter، قابل تست واحد.
///
/// HTML اینجا با parser واقعی به‌جای regex پارس می‌شود. کارِ قبلی
/// با `replaceAll(RegExp(r'<[^>]*>'))` متن را می‌درید:entity ها را
/// خام نشان می‌داد (`&nbsp;` به‌جای فاصله)، تگ‌های `script`/`style`
/// را هم حذف نمی‌کرد و شکست خط را از دست می‌داد.
class EpubText {
  const EpubText._();

  /// تگ‌هایی که محتوایشان متن نیست و باید کامل حذف شوند
  static final _nonTextBlocks = RegExp(
    r'<(script|style|head)\b[^>]*>.*?</\1>',
    caseSensitive: false,
    dotAll: true,
  );

  /// پایان تگ‌های بلوکی → یک خط خالی (فاصله پاراگراف)
  static final _blockEnds = RegExp(
    r'</(p|div|li|h[1-6]|blockquote|tr|section|article|ul|ol|table|pre)>',
    caseSensitive: false,
  );

  /// `<br>` → یک خط جدید
  static final _breaks = RegExp(r'<br\s*/?>', caseSensitive: false);

  /// تبدیل HTML به متن ساده و قابل خواندن.
  static String strip(String html) {
    if (html.isEmpty) return '';

    // شکست خط‌ها قبل از پارس به‌صورت متن خام تزریق می‌شوند تا
    // parser آن‌ها را به‌عنوان محتوای سند نگه دارد
    final prepared = html
        .replaceAll(_nonTextBlocks, ' ')
        .replaceAll(_breaks, '\n')
        .replaceAllMapped(_blockEnds, (_) => '\n\n');

    try {
      // parser واقعی entity ها را درست رمزگشایی می‌کند
      return _collapse(html_parser.parseFragment(prepared).text ?? '');
    } catch (_) {
      // اگر پارس شکست خورد، به روش ساده برمی‌گردیم تا متن از دست نرود
      return _collapse(prepared.replaceAll(RegExp(r'<[^>]*>'), ' '));
    }
  }

  /// فشرده‌سازی فاصله‌های اضافی بدون خراب کردن پاراگراف‌ها
  static String _collapse(String input) {
    return input
        .replaceAll('\r\n', '\n')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// کوچک‌سازی برای مقایسه — برای جستجوی متن کتاب
  static String normalize(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[\u200c\u200f\u200e]'), ' ').trim();
}

/// یک نتیجه جستجو درون کتاب
class SearchHit {
  final int sectionIndex;
  final String sectionTitle;

  /// متن پیرامون نتیجه، برای نمایش
  final String snippet;

  /// جایگاه نتیجه داخل متن بخش (برای اسکرول کردن)
  final int offset;

  const SearchHit({
    required this.sectionIndex,
    required this.sectionTitle,
    required this.snippet,
    required this.offset,
  });
}

/// جستجوی متن کامل درون یک سند.
///
/// روی متن از پیش استخراج‌شده اجرا می‌شود تا جستجوی زنده در حین
/// تایپ، کتاب را دوباره پارس نکند.
class EpubSearch {
  const EpubSearch._();

  /// [texts] باید هم‌طول با بخش‌های سند باشد.
  static List<SearchHit> run({
    required List<String> texts,
    required List<String> sectionLabels,
    required String query,
    int maxResults = 200,
  }) {
    final q = EpubText.normalize(query);
    if (q.length < 2) return const [];

    final hits = <SearchHit>[];
    for (var i = 0; i < texts.length; i++) {
      if (hits.length >= maxResults) break;
      final haystack = EpubText.normalize(texts[i]);
      if (haystack.isEmpty) continue;

      var from = 0;
      while (hits.length < maxResults) {
        final at = haystack.indexOf(q, from);
        if (at < 0) break;
        hits.add(SearchHit(
          sectionIndex: i,
          sectionTitle: i < sectionLabels.length ? sectionLabels[i] : 'بخش ${i + 1}',
          snippet: _snippet(haystack, at, q.length),
          offset: at,
        ));
        from = at + q.length;
      }
    }
    return hits;
  }

  /// برش متن پیرامون نتیجه با مرز روی کلمه
  static String _snippet(String text, int at, int length, {int pad = 60}) {
    var start = at - pad;
    var end = at + length + pad;
    if (start < 0) start = 0;
    if (end > text.length) end = text.length;

    // مرز را روی مرز کلمه می‌بریم تا وسط کلمه بریده نشود
    if (start > 0) {
      final space = text.indexOf(' ', start);
      if (space != -1 && space < at) start = space + 1;
    }
    if (end < text.length) {
      final space = text.lastIndexOf(' ', end);
      if (space > at + length) end = space;
    }

    final prefix = start > 0 ? '…' : '';
    final suffix = end < text.length ? '…' : '';
    return '$prefix${text.substring(start, end).trim()}$suffix';
  }
}
