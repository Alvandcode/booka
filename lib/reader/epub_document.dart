import 'dart:typed_data';

import 'package:epubx/epubx.dart';

/// یک بخش قابل خواندن از کتاب (معمولاً یک فصل).
class EpubSection {
  final int index;

  /// مسیر فایل در manifest — برای نگاشت فهرست مطالب به این بخش
  final String href;
  final String html;

  /// عنوان بخش، اگر از فهرست مطالب قابل تشخیص باشد
  final String? title;

  const EpubSection({
    required this.index,
    required this.href,
    required this.html,
    this.title,
  });
}

/// یک ورودی فهرست مطالب، تخت‌شده با عمق برای نمایش تو‌در‌تو.
class TocEntry {
  final String title;

  /// اندیس بخشی از کتاب که این ورودی به آن اشاره می‌کند.
  /// اگر فایل هدف در spine نبود، null است و ورودی غیرقابل‌پرش می‌شود.
  final int? sectionIndex;

  /// لنگر داخل همان فایل (معمولاً `#id` یا فرم CFI قدیمی)
  final String? anchor;

  /// عمق در درخت ناوبری — صفر برای فصل‌های اصلی
  final int depth;

  const TocEntry({
    required this.title,
    required this.sectionIndex,
    required this.anchor,
    required this.depth,
  });

  bool get isJumpable => sectionIndex != null;
}

/// پوشش سند EPUB به شکلی که ریدر لازم دارد.
///
/// نکته کلیدی: ترتیب خواندن از `Spine` استخراج می‌شود، نه از ترتیب
/// درج manifest. بیشتر کتاب‌ها manifest را الفبایی مرتب می‌کنند، پس
/// اتکا به ترتیب map فصل‌ها را جابه‌جا نشان می‌داد.
class EpubDocument {
  final String? title;
  final String? author;

  /// بخش‌ها به ترتیب درست خواندن
  final List<EpubSection> sections;

  /// فهرست مطالب تخت‌شده
  final List<TocEntry> toc;

  final Uint8List? coverBytes;

  const EpubDocument({
    required this.sections,
    required this.toc,
    this.title,
    this.author,
    this.coverBytes,
  });

  bool get isEmpty => sections.isEmpty;
  int get length => sections.length;

  EpubSection? sectionAt(int index) =>
      (index < 0 || index >= sections.length) ? null : sections[index];

  /// عنوان بخش، با fallback به شماره بخش
  String sectionLabel(int index) {
    final s = sectionAt(index);
    if (s == null) return '—';
    final t = s.title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return 'بخش ${index + 1}';
  }

  /// اولین بخشی که عنوانش شامل [needle] است — برای «ادامه مطالعه»
  int? indexOfSectionTitle(String needle) {
    final q = needle.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (var i = 0; i < sections.length; i++) {
      final t = sections[i].title?.toLowerCase();
      if (t != null && t.contains(q)) return i;
    }
    return null;
  }

  factory EpubDocument.fromBook(EpubBook book) {
    final content = book.Content;
    final htmlFiles = content?.Html;
    if (htmlFiles == null || htmlFiles.isEmpty) {
      return EpubDocument(
        title: book.Title,
        author: book.Author,
        sections: const [],
        toc: const [],
        coverBytes: _coverBytes(book),
      );
    }

    // manifest id → href، برای تبدیل IdRef های spine به مسیر فایل
    final idToHref = <String, String>{};
    for (final item in book.Schema?.Package?.Manifest?.Items ?? const []) {
      final id = item.Id;
      final href = item.Href;
      if (id != null && href != null) idToHref[id] = _safeDecode(href);
    }

    // ── ترتیب خواندن از spine ──
    final ordered = <EpubSection>[];
    final hrefToIndex = <String, int>{};
    final spineItems = book.Schema?.Package?.Spine?.Items;

    if (spineItems != null && spineItems.isNotEmpty) {
      for (final ref in spineItems) {
        final idRef = ref.IdRef;
        if (idRef == null) continue;
        final href = idToHref[idRef];
        if (href == null) continue;
        final file = htmlFiles[href] ?? htmlFiles[Uri.encodeFull(href)];
        if (file == null) continue;
        hrefToIndex[href] = ordered.length;
        ordered.add(EpubSection(
          index: ordered.length,
          href: href,
          html: file.Content ?? '',
        ));
      }
    }

    // اگر spine خراب یا خالی بود، به ترتیب manifest برگرد
    if (ordered.isEmpty) {
      for (final entry in htmlFiles.entries) {
        final href = _safeDecode(entry.key);
        hrefToIndex[href] = ordered.length;
        hrefToIndex[entry.key] = ordered.length;
        ordered.add(EpubSection(
          index: ordered.length,
          href: href,
          html: entry.value.Content ?? '',
        ));
      }
    }

    // ── فهرست مطالب ──
    final toc = <TocEntry>[];
    for (final chapter in book.Chapters ?? const <EpubChapter>[]) {
      _flatten(chapter, 0, hrefToIndex, toc);
    }

    // عنوان هر بخش را از فهرست مطالب به آن الصاق می‌کنیم
    final titleByIndex = <int, String>{};
    for (final e in toc) {
      final i = e.sectionIndex;
      if (i == null) continue;
      titleByIndex.putIfAbsent(i, () => e.title);
    }
    final titled = [
      for (final s in ordered)
        EpubSection(
          index: s.index,
          href: s.href,
          html: s.html,
          title: titleByIndex[s.index],
        ),
    ];

    // فهرست مطالب خالی است؟ ورودی‌های کلی بساز تا کاربر حداقل
    // بتواند بین بخش‌ها جابه‌جا شود
    final effectiveToc = toc.isEmpty
        ? [
            for (final s in titled)
              TocEntry(
                title: s.title ?? 'بخش ${s.index + 1}',
                sectionIndex: s.index,
                anchor: null,
                depth: 0,
              ),
          ]
        : toc;

    return EpubDocument(
      title: book.Title,
      author: book.Author,
      sections: titled,
      toc: effectiveToc,
      coverBytes: _coverBytes(book),
    );
  }

  /// رمزگشایی امن مسیر — برخی EPUBهای واقعی href را درصدی رمزگذاری
  /// نکرده‌اند و `Uri.decodeFull` روی آن‌ها استثنا می‌دهد. در آن
  /// حالت همان رشته خام استفاده می‌شود تا کتاب باز شود.
  static String _safeDecode(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }

  static void _flatten(
    EpubChapter chapter,
    int depth,
    Map<String, int> hrefToIndex,
    List<TocEntry> out,
  ) {
    final href = chapter.ContentFileName;
    final title = _cleanTitle(chapter.Title) ?? 'بدون عنوان';
    // اگر نگاشت با مسیر decode‌شده پیدا نشد، با کلید خام امتحان می‌کنیم
    final index = href == null
        ? null
        : (hrefToIndex[href] ?? hrefToIndex[_safeDecode(href)]);
    out.add(TocEntry(
      title: title,
      sectionIndex: index,
      anchor: chapter.Anchor,
      depth: depth,
    ));
    for (final sub in chapter.SubChapters ?? const <EpubChapter>[]) {
      _flatten(sub, depth + 1, hrefToIndex, out);
    }
  }

  static String? _cleanTitle(String? raw) {
    if (raw == null) return null;
    final t = raw.replaceAll('\n', ' ').trim();
    return t.isEmpty ? null : t;
  }

  static Uint8List? _coverBytes(EpubBook book) {
    try {
      final bytes = book.CoverImage?.getBytes();
      if (bytes == null || bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }
}
