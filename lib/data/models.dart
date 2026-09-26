import 'db.dart';

/// مدل‌های داده — کلاس‌های ساده Dart بدون codegen.
/// هر مدل یک `id` عددی دارد که کلید واقعی رکورد در SQLite است.
/// زمان‌ها به صورت epoch میلی‌ثانیه ذخیره می‌شوند تا sort و مقایسه
/// بدون تبدیل و بدون وابستگی به timezone انجام شود.

int _toEpoch(DateTime? v) => (v ?? DateTime.now()).millisecondsSinceEpoch;

DateTime? _fromEpoch(Object? v) => v == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

// ── کتاب ──
class LibraryBook {
  final int? id;
  final String path;
  final String title;
  final String type; // pdf | epub
  final String? coverPath;

  /// لنگر دقیق موقعیت: برای EPUB شناسه CFI، برای PDF شماره صفحه
  final String? lastAnchor;
  final int lastPage;
  final int totalPages;
  final double progress;
  final DateTime addedAt;
  final DateTime? lastOpened;

  const LibraryBook({
    this.id,
    required this.path,
    required this.title,
    required this.type,
    required this.addedAt,
    this.coverPath,
    this.lastAnchor,
    this.lastPage = 1,
    this.totalPages = 0,
    this.progress = 0,
    this.lastOpened,
  });

  bool get isEpub => type == 'epub';

  /// فقط بعد از درج در پایگاه داده صدا زده می‌شود
  LibraryBook copyWithId(int id) => LibraryBook(
        id: id,
        path: path,
        title: title,
        type: type,
        addedAt: addedAt,
        coverPath: coverPath,
        lastAnchor: lastAnchor,
        lastPage: lastPage,
        totalPages: totalPages,
        progress: progress,
        lastOpened: lastOpened,
      );

  LibraryBook copyWith({
    String? title,
    String? coverPath,
    String? lastAnchor,
    int? lastPage,
    int? totalPages,
    double? progress,
    DateTime? lastOpened,
  }) =>
      LibraryBook(
        id: id,
        path: path,
        title: title ?? this.title,
        type: type,
        coverPath: coverPath ?? this.coverPath,
        lastAnchor: lastAnchor ?? this.lastAnchor,
        lastPage: lastPage ?? this.lastPage,
        totalPages: totalPages ?? this.totalPages,
        progress: progress ?? this.progress,
        addedAt: addedAt,
        lastOpened: lastOpened ?? this.lastOpened,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'path': path,
        'title': title,
        'type': type,
        'cover_path': coverPath,
        'last_anchor': lastAnchor,
        'last_page': lastPage,
        'total_pages': totalPages,
        'progress': progress,
        'added_at': _toEpoch(addedAt),
        'last_opened': lastOpened?.millisecondsSinceEpoch,
      };

  factory LibraryBook.fromRow(Map<String, Object?> r) => LibraryBook(
        id: r['id'] as int?,
        path: r['path'] as String? ?? '',
        title: r['title'] as String? ?? 'بدون عنوان',
        type: r['type'] as String? ?? 'pdf',
        coverPath: r['cover_path'] as String?,
        lastAnchor: r['last_anchor'] as String?,
        lastPage: (r['last_page'] as num?)?.toInt() ?? 1,
        totalPages: (r['total_pages'] as num?)?.toInt() ?? 0,
        progress: (r['progress'] as num?)?.toDouble() ?? 0,
        addedAt: _fromEpoch(r['added_at']) ?? DateTime.now(),
        lastOpened: _fromEpoch(r['last_opened']),
      );

  /// فقط فیلدهایی که [LibraryBook] قبلی در JSON داشت — برای مهاجرت از نسخه قدیم
  static LibraryBook fromLegacy(Map<String, dynamic> j) => LibraryBook(
        path: j['path'] as String? ?? '',
        title: j['title'] as String? ?? 'بدون عنوان',
        type: j['type'] as String? ?? 'pdf',
        lastPage: (j['lastPage'] as num?)?.toInt() ?? 1,
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ??
            DateTime.now(),
        lastOpened: DateTime.tryParse(j['lastOpened'] as String? ?? ''),
      );
}

// ── نشان (بوکمارک) ──
class BookmarkEntry {
  final int? id;
  final int? bookId;
  final String bookPath;
  final String book;
  final String note;
  final int? pageIndex;
  final DateTime at;

  const BookmarkEntry({
    this.id,
    this.bookId,
    required this.bookPath,
    required this.book,
    required this.note,
    required this.at,
    this.pageIndex,
  });

  BookmarkEntry copyWithId(int id) => BookmarkEntry(
        id: id,
        bookId: bookId,
        bookPath: bookPath,
        book: book,
        note: note,
        at: at,
        pageIndex: pageIndex,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'book_path': bookPath,
        'book_title': book,
        'note': note,
        'page_index': pageIndex,
        'created_at': _toEpoch(at),
      };

  factory BookmarkEntry.fromRow(Map<String, Object?> r) => BookmarkEntry(
        id: r['id'] as int?,
        bookId: r['book_id'] as int?,
        bookPath: r['book_path'] as String? ?? '',
        book: r['book_title'] as String? ?? '',
        note: r['note'] as String? ?? '',
        pageIndex: (r['page_index'] as num?)?.toInt(),
        at: _fromEpoch(r['created_at']) ?? DateTime.now(),
      );

  static BookmarkEntry fromLegacy(Map<String, dynamic> j) => BookmarkEntry(
        bookPath: j['bookPath'] as String? ?? '',
        book: j['book'] as String? ?? '',
        note: j['note'] as String? ?? '',
        pageIndex: (j['pageIndex'] as num?)?.toInt(),
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

// ── هایلایت / حاشیه‌نویسی ──
class HighlightEntry {
  final int? id;
  final int? bookId;
  final String bookPath;
  final String book;
  final String quote;
  final int pageIndex;
  final int color;
  final String note;
  final List<String> tags;
  final DateTime at;

  const HighlightEntry({
    this.id,
    this.bookId,
    required this.bookPath,
    required this.book,
    required this.quote,
    required this.pageIndex,
    required this.color,
    required this.at,
    this.note = '',
    this.tags = const [],
  });

  HighlightEntry copyWithId(int id) => HighlightEntry(
        id: id,
        bookId: bookId,
        bookPath: bookPath,
        book: book,
        quote: quote,
        pageIndex: pageIndex,
        color: color,
        at: at,
        note: note,
        tags: tags,
      );

  HighlightEntry copyWith({String? note, List<String>? tags}) => HighlightEntry(
        id: id,
        bookId: bookId,
        bookPath: bookPath,
        book: book,
        quote: quote,
        pageIndex: pageIndex,
        color: color,
        note: note ?? this.note,
        tags: tags ?? this.tags,
        at: at,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'book_path': bookPath,
        'book_title': book,
        'quote': quote,
        'page_index': pageIndex,
        'color': color,
        'note': note,
        'tags': tags.join(','),
        'search': _searchBlob(quote, note, tags),
        'created_at': _toEpoch(at),
      };

  /// نرمال‌سازی برای جستجوی متن کامل: کوچک‌کردن حروف + حذف نشانه‌گذاری
  static String _searchBlob(String quote, String note, List<String> tags) =>
      '${quote.toLowerCase()} ${note.toLowerCase()} ${tags.join(' ').toLowerCase()}';

  factory HighlightEntry.fromRow(Map<String, Object?> r) => HighlightEntry(
        id: r['id'] as int?,
        bookId: r['book_id'] as int?,
        bookPath: r['book_path'] as String? ?? '',
        book: r['book_title'] as String? ?? '',
        quote: r['quote'] as String? ?? '',
        pageIndex: (r['page_index'] as num?)?.toInt() ?? 1,
        color: (r['color'] as num?)?.toInt() ?? 0xFFFFE08A,
        note: r['note'] as String? ?? '',
        tags: ((r['tags'] as String?) ?? '')
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        at: _fromEpoch(r['created_at']) ?? DateTime.now(),
      );

  static HighlightEntry fromLegacy(Map<String, dynamic> j) => HighlightEntry(
        bookPath: j['bookPath'] as String? ?? '',
        book: j['book'] as String? ?? '',
        quote: j['quote'] as String? ?? '',
        pageIndex: (j['pageIndex'] as num?)?.toInt() ?? 1,
        color: (j['color'] as num?)?.toInt() ?? 0xFFFFE08A,
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

// ── کارت لایتنر با زمان‌بندی SM-2 ──
class FlashcardEntry {
  final int? id;
  final int? bookId;
  final String bookPath;
  final String word;
  final String meaning;
  final String context;
  final String book;
  final double easiness;
  final int intervalDays;
  final int repetitions;
  final DateTime dueAt;
  final DateTime at;

  const FlashcardEntry({
    this.id,
    this.bookId,
    this.bookPath = '',
    required this.word,
    required this.meaning,
    required this.context,
    required this.book,
    required this.at,
    required this.dueAt,
    this.easiness = 2.5,
    this.intervalDays = 1,
    this.repetitions = 0,
  });

  bool get isDue => !dueAt.isAfter(DateTime.now());

  FlashcardEntry copyWithId(int id) => FlashcardEntry(
        id: id,
        bookId: bookId,
        bookPath: bookPath,
        word: word,
        meaning: meaning,
        context: context,
        book: book,
        at: at,
        dueAt: dueAt,
        easiness: easiness,
        intervalDays: intervalDays,
        repetitions: repetitions,
      );

  FlashcardEntry copyWith({
    double? easiness,
    int? intervalDays,
    int? repetitions,
    DateTime? dueAt,
  }) =>
      FlashcardEntry(
        id: id,
        bookId: bookId,
        bookPath: bookPath,
        word: word,
        meaning: meaning,
        context: context,
        book: book,
        at: at,
        easiness: easiness ?? this.easiness,
        intervalDays: intervalDays ?? this.intervalDays,
        repetitions: repetitions ?? this.repetitions,
        dueAt: dueAt ?? this.dueAt,
      );

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'book_path': bookPath,
        'book_title': book,
        'word': word,
        'meaning': meaning,
        'context_sentence': context,
        'easiness': easiness,
        'interval_days': intervalDays,
        'repetitions': repetitions,
        'due_at': _toEpoch(dueAt),
        'created_at': _toEpoch(at),
      };

  factory FlashcardEntry.fromRow(Map<String, Object?> r) => FlashcardEntry(
        id: r['id'] as int?,
        bookId: r['book_id'] as int?,
        bookPath: r['book_path'] as String? ?? '',
        word: r['word'] as String? ?? '',
        meaning: r['meaning'] as String? ?? '',
        context: r['context_sentence'] as String? ?? '',
        book: r['book_title'] as String? ?? '',
        easiness: (r['easiness'] as num?)?.toDouble() ?? 2.5,
        intervalDays: (r['interval_days'] as num?)?.toInt() ?? 1,
        repetitions: (r['repetitions'] as num?)?.toInt() ?? 0,
        dueAt: _fromEpoch(r['due_at']) ?? DateTime.now(),
        at: _fromEpoch(r['created_at']) ?? DateTime.now(),
      );

  static FlashcardEntry fromLegacy(Map<String, dynamic> j) {
    final at = DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now();
    return FlashcardEntry(
      word: j['word'] as String? ?? '',
      meaning: j['meaning'] as String? ?? '',
      context: j['context'] as String? ?? '',
      book: j['book'] as String? ?? '',
      at: at,
      dueAt: at,
    );
  }
}

/// نگاشت نام ستون‌های قدیمی به ستون‌های جدید — در مهاجرت استفاده می‌شود.
const legacyKeyToColumn = <String, String>{
  'library_v1': Db.tBooks,
  'bookmarks_v1': Db.tBookmarks,
  'highlights_v1': Db.tHighlights,
  'flashcards_v1': Db.tFlashcards,
};
