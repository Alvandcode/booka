import 'package:pdfrx/pdfrx.dart';

/// یک نتیجه جستجو در متن PDF
class PdfTextHit {
  /// شماره صفحه، یک‌based (مثل EPUB که از صفر شروع می‌شود فرق دارد)
  final int page;

  /// متن پیرامون نتیجه برای نمایش
  final String snippet;

  const PdfTextHit({required this.page, required this.snippet});
}

/// ابزارهای خالصِ متن PDF — بدون Flutter، قابل تست واحد.
///
/// PDF برخلاف EPUB لایه متنی قابل استخراج ندارد مگر اینکه نویسنده
/// آن را در فایل گذاشته باشد. برای اسکن‌های تصویری متنی وجود ندارد
/// و همه توابع اینجا نتیجه خالی برمی‌گردانند.
class PdfTextTools {
  const PdfTextTools._();

  /// آیا متن این صفحه قابل استخراج است؟
  ///
  /// برای تشخیص زودهنگام کتاب اسکن‌شده لازم است تا به کاربر بگوییم
  /// قابلیت‌های متنی کار نمی‌کند، به‌جای اینکه بی‌صدا شکست بخورند.
  static bool hasTextLayer(String? rawText) {
    if (rawText == null) return false;
    // فقط فاصله و شکست خط، متن محسوب نمی‌شود
    final meaningful = rawText.replaceAll(RegExp(r'\s+'), '');
    return meaningful.length >= kMinMeaningfulChars;
}

  /// حداقل کاراکتر معنادار برای اینکه صفحه «دارای لایه متن» تلقی شود
  static const kMinMeaningfulChars = 12;

  /// آیا کل سند اسکن‌شده است؟
  ///
  /// اگر بیشتر صفحات متن نداشته باشند، کتاب اسکن‌شده است و قابلیت‌های
  /// متنی (جستجو، هایلایت، دیکشنری) روی آن کار نمی‌کنند.
  static bool isScannedDocument(int pagesWithText, int totalPages) {
    if (totalPages <= 0) return false;
    return pagesWithText / totalPages < kScannedTextRatioThreshold;
  }

  /// اگر کمتر از این نسبت صفحات متن داشته باشند، سند اسکن‌شده است
  static const kScannedTextRatioThreshold = 0.5;

  /// متن قابل جستجو یک صفحه، با حذف فاصله‌های اضافه
  static String normalize(String? rawText) {
    if (rawText == null) return '';
    return rawText
        .replaceAll('\r\n', '\n')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .trim();
  }

  /// جستجوی یک عبارت در متن یک صفحه.
  ///
  /// [pageNumber] یک‌based است و همان‌طور در نتیجه برگردانده می‌شود.
  static List<PdfTextHit> searchPage({
    required String pageText,
    required int pageNumber,
    required String query,
    int maxResults = 50,
  }) {
    final q = normalize(query).toLowerCase();
    if (q.length < 2) return const [];

    final haystack = normalize(pageText);
    if (haystack.isEmpty) return const [];

    final lowerHay = haystack.toLowerCase();
    final hits = <PdfTextHit>[];
    var from = 0;
    while (hits.length < maxResults) {
      final at = lowerHay.indexOf(q, from);
      if (at < 0) break;
      hits.add(PdfTextHit(
        page: pageNumber,
        snippet: snippet(haystack, at, q.length),
      ));
      from = at + q.length;
    }
    return hits;
  }

  /// برش متن پیرامون نتیجه با مرز روی کلمه
  ///
  /// شکست خط‌ها داخل برش به فاصله تبدیل می‌شوند: متن استخراج‌شده از PDF
  /// پاراگراف‌به‌پاراگراف است و اگر اینجا فاصله نشوند، نتیجه در فهرست
  /// چندخطی و نامرتب نمایش داده می‌شود.
  static String snippet(String text, int at, int length, {int pad = 55}) {
    var start = at - pad;
    var end = at + length + pad;
    if (start < 0) start = 0;
    if (end > text.length) end = text.length;

    if (start > 0) {
      final space = text.indexOf(' ', start);
      if (space != -1 && space < at) start = space + 1;
    }
    if (end < text.length) {
      final space = text.lastIndexOf(' ', end);
      if (space > at + length) end = space;
    }

    final flat = text.substring(start, end).replaceAll(_wsRun, ' ').trim();
    final prefix = start > 0 ? '…' : '';
    final suffix = end < text.length ? '…' : '';
    return '$prefix$flat$suffix';
  }

  /// دو یا چند فاصله/شکست خط پیاپی
  static final _wsRun = RegExp(r'\s+');

  /// اولین کلمه انگلیسی در متن انتخابی — برای جستجوی دیکشنری
  static String firstEnglishWord(String selection) {
    final m = RegExp(r'''[A-Za-z][A-Za-z'’-]*''').firstMatch(selection);
    return m?.group(0) ?? '';
  }
}

/// یک ورودی فهرست مطالب PDF، تخت‌شده با عمق
class PdfTocEntry {
  final String title;

  /// شماره صفحه مقصد، یک‌based. اگر مقصد قابل حل نبود null است.
  final int? page;
  final int depth;

  const PdfTocEntry({
    required this.title,
    required this.page,
    required this.depth,
  });

  bool get isJumpable => page != null;
}

/// تبدیل درخت فهرست مطالب pdfrx به فهرست تخت‌شده.
///
/// ورودی‌هایی که مقصد ندارند یا شماره صفحه‌شان نامعتبر است، بدون
/// صفحه می‌مانند و در UI غیرقابل‌پرش نشان داده می‌شوند.
List<PdfTocEntry> flattenOutline(
  List<PdfOutlineNode> nodes, {
  int totalPages = 0,
  int depth = 0,
}) {
  final out = <PdfTocEntry>[];
  for (final node in nodes) {
    var page = node.dest?.pageNumber;
    // شماره صفحه باید در محدوده سند باشد
    if (page != null && page < 1) page = null;
    if (page != null && totalPages > 0 && page > totalPages) page = null;

    final title = node.title.trim();
    out.add(PdfTocEntry(
      title: title.isEmpty ? 'بدون عنوان' : title,
      page: page,
      depth: depth,
    ));
    if (node.children.isNotEmpty) {
      out.addAll(flattenOutline(node.children,
          totalPages: totalPages, depth: depth + 1));
    }
  }
  return out;
}
