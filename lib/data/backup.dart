import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'dao.dart';
import 'models.dart';

/// قالب شناسه فایل بکاپ — برای تشخیص فایل خودمان از فایل غریبه
const kBackupFormat = 'booka-backup';
const kBackupVersion = 1;

/// نتیجه یک عملیات بازیابی
class ImportResult {
  final int books;
  final int bookmarks;
  final int highlights;
  final int flashcards;

  /// کتاب‌هایی که در دستگاه فعلی پیدا نشدند و فقط فراداده‌شان آمد
  final int unmatchedBooks;

  const ImportResult({
    this.books = 0,
    this.bookmarks = 0,
    this.highlights = 0,
    this.flashcards = 0,
    this.unmatchedBooks = 0,
  });

  int get total => books + bookmarks + highlights + flashcards;

  Map<String, Object?> toJson() => {
        'books': books,
        'bookmarks': bookmarks,
        'highlights': highlights,
        'flashcards': flashcards,
        'unmatchedBooks': unmatchedBooks,
        'total': total,
      };
}

/// ساخت و خواندن فایل بکاپ.
///
/// بکاپ فقط فراداده و یادداشت‌ها را نگه می‌دارد، نه خود فایل کتاب.
/// دلیلش این است که اپ کاملاً آفلاین است و فایل کتاب‌ها می‌تواند
/// گیگابایت باشد؛ کاربر کتاب را دوباره وارد می‌کند و بکاپ نشان‌ها و
/// هایلایت‌ها را با همان کتاب‌ها پیوند می‌دهد.
class BackupService {
  const BackupService(this._dao);

  final Dao _dao;

  // ── خروجی ──

  /// رکید آماده برای نوشتن در فایل بکاپ.
  ///
  /// شناسه `id` محلی است و بین دستگاه‌ها معنا ندارد، پس حذف می‌شود تا
  /// هنگام بازیابی شناسه تازه ساخته شود.
  @visibleForTesting
  static Map<String, Object?> backupRow(Map<String, Object?> row) =>
      Map<String, Object?>.of(row)..remove('id');

  /// کل داده‌ها به صورت JSON خوانا
  Future<String> exportJson() async {
    final books = await _dao.books();
    final bookmarks = await _dao.bookmarks();
    final highlights = await _dao.highlights();
    final flashcards = await _dao.flashcards();

    return const JsonEncoder.withIndent('  ').convert({
      'format': kBackupFormat,
      'version': kBackupVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'counts': {
        'books': books.length,
        'bookmarks': bookmarks.length,
        'highlights': highlights.length,
        'flashcards': flashcards.length,
      },
      'books': [for (final b in books) backupRow(b.toRow())],
      'bookmarks': [for (final b in bookmarks) backupRow(b.toRow())],
      'highlights': [for (final h in highlights) backupRow(h.toRow())],
      'flashcards': [for (final f in flashcards) backupRow(f.toRow())],
    });
  }

  // ── ورودی ──

  /// خواندن بکاپ و بازگرداندن آن.
  ///
  /// مسیر کتاب‌ها روی دستگاه جدید وجود ندارد، بنابراین هر مسیر با
  /// نام فایل در کتابخانه فعلی تطبیق داده می‌شود. اگر کتاب پیدا نشود
  /// رکوردهایش با همان عنوان نگه داشته می‌شوند تا وقتی کتاب را دوباره
  /// وارد کرد کاربر بتواند دستی وصل کند.
  ///
  /// [replace] اگر true باشد داده فعلی پاک و بکاپ جایگزین آن می‌شود.
  Future<ImportResult> importJson(String raw, {bool replace = false}) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('محتوای فایل یک شیء JSON نیست');
    }
    if (decoded['format'] != kBackupFormat) {
      throw const FormatException(
          'این فایل بکاپ Booka نیست (نشانگر format متفاوت است)');
    }
    final version = (decoded['version'] as num?)?.toInt() ?? 0;
    if (version > kBackupVersion) {
      throw FormatException(
          'این بکاپ مربوط به نسخه جدیدتری از اپ است (نسخه $version)');
    }

    final books = _rows(decoded['books']);
    final bookmarks = _rows(decoded['bookmarks']);
    final highlights = _rows(decoded['highlights']);
    final flashcards = _rows(decoded['flashcards']);

    // در حالت جایگزینی، داده فعلی کاملاً پاک می‌شود تا نتیجه دقیقاً
    // برابر با محتوای بکاپ باشد
    if (replace) {
      await _dao.clearAllContent();
    }

    // نگاشت مسیر قدیمی → مسیر معادل روی این دستگاه
    final current = await _dao.books();
    final pathMap = mapBackupPaths(
      current: current,
      backupPaths: [for (final row in books) row['path'] as String? ?? ''],
    );

    var unmatched = 0;
    for (final row in books) {
      final oldPath = row['path'] as String? ?? '';
      if (oldPath.isEmpty) continue;
      if (pathMap[oldPath] == null) {
        // فایل کتاب روی این دستگاه نیست؛ فقط فراداده ثبت می‌شود
        unmatched++;
        await _dao.insertBook(LibraryBook.fromRow(row));
      }
    }

    // ── نشان‌ها ──
    final existingMarks = await _dao.bookmarks();
    final markKeys = {
      for (final m in existingMarks)
        markKey(m.bookPath, m.note, m.pageIndex, m.at)
    };
    var markAdded = 0;
    for (final row in bookmarks) {
      final e = BookmarkEntry.fromRow(row);
      final finalEntry = BookmarkEntry(
        bookPath: pathMap[e.bookPath] ?? e.bookPath,
        book: e.book,
        note: e.note,
        pageIndex: e.pageIndex,
        at: e.at,
      );
      final key = markKey(
          finalEntry.bookPath, finalEntry.note, finalEntry.pageIndex, finalEntry.at);
      if (markKeys.contains(key)) continue;
      await _dao.insertBookmark(finalEntry);
      markKeys.add(key);
      markAdded++;
    }

    // ── هایلایت‌ها ──
    final existingHl = await _dao.highlights();
    final hlKeys = {
      for (final h in existingHl)
        highlightKey(h.bookPath, h.quote, h.pageIndex, h.at)
    };
    var hlAdded = 0;
    for (final row in highlights) {
      final h = HighlightEntry.fromRow(row);
      final finalEntry = HighlightEntry(
        bookPath: pathMap[h.bookPath] ?? h.bookPath,
        book: h.book,
        quote: h.quote,
        pageIndex: h.pageIndex,
        color: h.color,
        note: h.note,
        tags: h.tags,
        at: h.at,
      );
      final key = highlightKey(
          finalEntry.bookPath, finalEntry.quote, finalEntry.pageIndex, finalEntry.at);
      if (hlKeys.contains(key)) continue;
      await _dao.insertHighlight(finalEntry);
      hlKeys.add(key);
      hlAdded++;
    }

    // ── کارت‌های لایتنر ──
    final existingCards = await _dao.flashcards();
    final cardKeys = {
      for (final c in existingCards)
        cardKey(c.word, c.meaning, c.context, c.book)
    };
    var cardAdded = 0;
    for (final row in flashcards) {
      final c = FlashcardEntry.fromRow(row);
      final key = cardKey(c.word, c.meaning, c.context, c.book);
      if (cardKeys.contains(key)) continue;
      await _dao.insertFlashcard(c);
      cardKeys.add(key);
      cardAdded++;
    }

    return ImportResult(
      books: books.length,
      bookmarks: markAdded,
      highlights: hlAdded,
      flashcards: cardAdded,
      unmatchedBooks: unmatched,
    );
  }

  /// نگاشت مسیر یک بکاپ به مسیر معادل روی این دستگاه.
  ///
  /// مسیر کتاب روی دستگاه جدید فرق می‌کند (پوشه اسناد فرق دارد)، پس
  /// با نام فایل تطبیق داده می‌شود. خروجی null یعنی کتاب متناظر پیدا
  /// نشد و رکوردهایش بدون پیوند باقی می‌مانند.
  @visibleForTesting
  static Map<String, String?> mapBackupPaths({
    required List<LibraryBook> current,
    required Iterable<String> backupPaths,
  }) {
    final byPath = <String, String>{
      for (final b in current) b.path: b.path,
    };
    final byName = <String, String>{};
    for (final b in current) {
      byName.putIfAbsent(p.basename(b.path), () => b.path);
    }

    final out = <String, String?>{};
    for (final old in backupPaths) {
      if (old.isEmpty) continue;
      // اگر فایل‌ها ناقص هم‌نام باشند، بهتر است تطبیق ندهیم تا
      // هایلایت‌های کتاب اشتباه به کتاب دیگری نچسبند
      out[old] = byPath[old] ?? byName[p.basename(old)];
    }
    return out;
  }

  static List<Map<String, Object?>> _rows(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, Object?>())
        .toList();
  }

  /// کلید یکتای یک نشان — برای تشخیص تکراری
  @visibleForTesting
  static String markKey(String path, String note, int? page, DateTime at) =>
      '$path|${note.trim()}|${page ?? ''}|${at.toIso8601String()}';

  /// کلید یکتای یک هایلایت
  @visibleForTesting
  static String highlightKey(
          String path, String quote, int page, DateTime at) =>
      '$path|${quote.trim()}|$page|${at.toIso8601String()}';

  /// کلید یکتای یک کارت لایتنر
  @visibleForTesting
  static String cardKey(
          String word, String meaning, String context, String book) =>
      '${word.trim().toLowerCase()}|${meaning.trim()}'
      '|${context.trim()}|${book.trim()}';

  // ── اکسپورت قابل خواندن ──

  /// هایلایت‌ها به Markdown، گروه‌بندی‌شده بر اساس کتاب
  static String highlightsMarkdown(
    List<HighlightEntry> items, {
    String title = 'هایلایت‌ها',
  }) {
    final b = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln('> ${items.length} مورد • $kBackupFormat')
      ..writeln();

    if (items.isEmpty) {
      b.writeln('_هیچ هایلایتی ثبت نشده است._');
      return b.toString();
    }

    final byBook = <String, List<HighlightEntry>>{};
    for (final h in items) {
      byBook.putIfAbsent(h.book, () => []).add(h);
    }

    for (final entry in byBook.entries) {
      b
        ..writeln('## ${entry.key}')
        ..writeln();
      for (final h in entry.value) {
        b.writeln('- «${h.quote.replaceAll('\n', ' ')}» — بخش ${h.pageIndex}');
        if (h.note.isNotEmpty) b.writeln('  - یادداشت: ${h.note}');
        if (h.tags.isNotEmpty) b.writeln('  - برچسب: ${h.tags.map((t) => '`$t`').join(' ')}');
      }
      b.writeln();
    }
    return b.toString();
  }

  /// نشان‌ها به Markdown
  static String bookmarksMarkdown(List<BookmarkEntry> items) {
    final b = StringBuffer()
      ..writeln('# نشان‌ها')
      ..writeln()
      ..writeln('> ${items.length} مورد')
      ..writeln();
    if (items.isEmpty) {
      b.writeln('_هیچ نشانی ثبت نشده است._');
      return b.toString();
    }
    for (final m in items) {
      b.writeln('- **${m.book}** — ${m.note}');
    }
    return b.toString();
  }

  /// کارت‌های لایتنر به CSV سازگار با اکسل (با BOM برای فارسی)
  ///
  /// ستون‌ها طوری چیده شده‌اند که با هر دو قالب Anki و مرور دستی بخواند.
  static String flashcardsCsv(List<FlashcardEntry> items) {
    final b = StringBuffer('\uFEFF'); // BOM تا اکسل فارسی را درست باز کند
    b.writeln('front,back,book,context,interval,due,easiness');
    for (final f in items) {
      b.writeln([
        _csvCell(f.word),
        _csvCell(f.meaning),
        _csvCell(f.book),
        _csvCell(f.context),
        f.intervalDays,
        f.dueAt.toIso8601String().split('T').first,
        f.easiness.toStringAsFixed(2),
      ].join(','));
    }
    return b.toString();
  }

  static String _csvCell(String value) {
    final v = value.replaceAll('\n', ' ').trim();
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
