import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dao.dart';
import 'db.dart';
import 'models.dart';

export 'models.dart';

/// کلیدهای نسخه قبلی که داده‌ها در SharedPreferences ذخیره می‌شدند.
/// پس از انتقال موفق، این کلیدها حذف می‌شوند.
const _legacyKeys = {
  'books': 'library_v1',
  'bookmarks': 'bookmarks_v1',
  'highlights': 'highlights_v1',
  'flashcards': 'flashcards_v1',
};

const _migrationFlag = 'sqflite_migrated_v1';

/// یک بار برای کل عمر اپ اجرا می‌شود: باز کردن پایگاه داده و سپس
/// انتقال داده‌های نسخه قبلی. نوتیفایرها پیش از اولین خواندن
/// روی همین Future منتظر می‌مانند تا هیچ داده‌ای جا نیفتد.
final Future<Dao> _ready = _bootstrap();

Future<Dao> _bootstrap() async {
  final dao = Dao(Db.instance);
  try {
    await _migrate(dao);
  } catch (_) {
    // مهاجرت نباید مانع کار کردن اپ شود؛ کاربر با کتابخانه خالی
    // وارد می‌شود و داده‌های قدیمی در SharedPreferences دست‌نخورده می‌مانند.
  }
  return dao;
}

// ── کتابخانه ──

class LibraryNotifier extends StateNotifier<List<LibraryBook>> {
  LibraryNotifier(this._ready) : super(const []) {
    _load();
  }

  final Future<Dao> _ready;

  Future<Dao> get _dao => _ready;

  Future<void> _load() async {
    try {
      state = await (await _dao).books();
    } catch (_) {
      // پایگاه داده در دسترس نیست — کتابخانه خالی می‌ماند
    }
  }

  Future<void> import(LibraryBook book) async {
    final id = await (await _dao).insertBook(book);
    if (!mounted) return;
    final withId = id > 0 ? book.copyWithId(id) : book;
    state = [withId, ...state.where((b) => b.path != book.path)];
  }

  Future<void> removeByPath(String path) async {
    await (await _dao).deleteBook(path);
    if (!mounted) return;
    state = state.where((b) => b.path != path).toList();
  }

  Future<void> saveProgress(
    String path, {
    int? page,
    int? totalPages,
    double? progress,
    String? anchor,
  }) async {
    await (await _dao).saveProgress(path,
        page: page,
        totalPages: totalPages,
        progress: progress,
        anchor: anchor);
  }
}

// ── نشان‌ها ──

class BookmarksNotifier extends StateNotifier<List<BookmarkEntry>> {
  BookmarksNotifier(this._ready) : super(const []) {
    _load();
  }

  final Future<Dao> _ready;

  Future<void> _load() async {
    try {
      state = await (await _ready).bookmarks();
    } catch (_) {}
  }

  Future<void> add(BookmarkEntry e) async {
    final id = await (await _ready).insertBookmark(e);
    if (!mounted) return;
    state = [e.copyWithId(id), ...state];
  }

  /// حذف با شناسه — دیگر به هویت شیء وابسته نیست
  Future<void> removeEntry(BookmarkEntry e) async {
    final id = e.id;
    if (id == null) return;
    await (await _ready).deleteBookmark(id);
    if (!mounted) return;
    state = state.where((b) => b.id != id).toList();
  }
}

// ── هایلایت‌ها ──

class HighlightsNotifier extends StateNotifier<List<HighlightEntry>> {
  HighlightsNotifier(this._ready) : super(const []) {
    _load();
  }

  final Future<Dao> _ready;

  Future<void> _load() async {
    try {
      state = await (await _ready).highlights();
    } catch (_) {}
  }

  Future<void> add(HighlightEntry e) async {
    final id = await (await _ready).insertHighlight(e);
    if (!mounted) return;
    state = [e.copyWithId(id), ...state];
  }

  Future<void> removeEntry(HighlightEntry e) async {
    final id = e.id;
    if (id == null) return;
    await (await _ready).deleteHighlight(id);
    if (!mounted) return;
    state = state.where((h) => h.id != id).toList();
  }

  /// جستجوی متن کامل — روی دیتابیس اجرا می‌شود نه در حافظه
  Future<List<HighlightEntry>> search(String term) async {
    if (term.trim().isEmpty) return state;
    try {
      return await (await _ready).searchHighlights(term);
    } catch (_) {
      return const [];
    }
  }
}

// ── کارت‌های لایتنر ──

class FlashcardsNotifier extends StateNotifier<List<FlashcardEntry>> {
  FlashcardsNotifier(this._ready) : super(const []) {
    _load();
  }

  final Future<Dao> _ready;

  Future<void> _load() async {
    try {
      state = await (await _ready).flashcards();
    } catch (_) {}
  }

  Future<void> add(FlashcardEntry e) async {
    final id = await (await _ready).insertFlashcard(e);
    if (!mounted) return;
    state = [e.copyWithId(id), ...state];
  }

  Future<void> removeEntry(FlashcardEntry e) async {
    final id = e.id;
    if (id == null) return;
    await (await _ready).deleteFlashcard(id);
    if (!mounted) return;
    state = state.where((c) => c.id != id).toList();
  }

  /// کارت‌های سررسیده برای مرور امروز
  Future<List<FlashcardEntry>> due() async {
    try {
      return await (await _ready).dueFlashcards();
    } catch (_) {
      return const [];
    }
  }

  /// ثبت پاسخ و زمان‌بندی مرور بعدی طبق SM-2
  Future<void> review(FlashcardEntry e, int quality) async {
    final id = e.id;
    if (id == null) return;
    final dao = await _ready;
    await dao.reviewFlashcard(id, quality);
    try {
      state = await dao.flashcards();
    } catch (_) {}
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, List<LibraryBook>>(
        (ref) => LibraryNotifier(_ready));

final bookmarksProvider =
    StateNotifierProvider<BookmarksNotifier, List<BookmarkEntry>>(
        (ref) => BookmarksNotifier(_ready));

final highlightsProvider =
    StateNotifierProvider<HighlightsNotifier, List<HighlightEntry>>(
        (ref) => HighlightsNotifier(_ready));

final flashcardsProvider =
    StateNotifierProvider<FlashcardsNotifier, List<FlashcardEntry>>(
        (ref) => FlashcardsNotifier(_ready));

/// انتقال داده‌های نسخه قبلی از SharedPreferences به SQLite.
/// هر بخش جداگانه محافظت می‌شود تا یک رکورد خراب، کل مهاجرت را
/// از بین نبرد. کلیدهای قدیمی فقط پس از انتقال کامل پاک می‌شوند.
Future<void> _migrate(Dao dao) async {
  final sp = await SharedPreferences.getInstance();
  if (sp.getBool(_migrationFlag) == true) return;

  List<Map<String, dynamic>> read(String key) {
    final raw = sp.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // کتاب‌ها اول — بقیه رکوردها به مسیر کتاب ارجاع می‌دهند
  for (final j in read(_legacyKeys['books']!)) {
    try {
      final b = LibraryBook.fromLegacy(j);
      if (b.path.isEmpty) continue;
      await dao.insertBook(b);
    } catch (_) {}
  }

  for (final j in read(_legacyKeys['bookmarks']!)) {
    try {
      final e = BookmarkEntry.fromLegacy(j);
      if (e.bookPath.isEmpty) continue;
      await dao.insertBookmark(e);
    } catch (_) {}
  }

  for (final j in read(_legacyKeys['highlights']!)) {
    try {
      final e = HighlightEntry.fromLegacy(j);
      if (e.bookPath.isEmpty) continue;
      await dao.insertHighlight(e);
    } catch (_) {}
  }

  for (final j in read(_legacyKeys['flashcards']!)) {
    try {
      final e = FlashcardEntry.fromLegacy(j);
      if (e.word.isEmpty) continue;
      await dao.insertFlashcard(e);
    } catch (_) {}
  }

  for (final k in _legacyKeys.values) {
    await sp.remove(k);
  }
  await sp.setBool(_migrationFlag, true);
}

// ── تنظیمات ──
// تنظیمات دو مقدار اسکالر هستند؛ SharedPreferences برای این کار
// درست‌تر از SQLite است و نیازی به جدول جداگانه ندارد.

class _SettingNotifier<T> extends StateNotifier<T> {
  final String key;
  final T Function(Object? raw) decode;
  final Object? Function(T value) encode;

  _SettingNotifier({
    required this.key,
    required T fallback,
    required this.decode,
    required this.encode,
  }) : super(fallback) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (!sp.containsKey(key)) return;
      state = decode(sp.get(key));
    } catch (_) {
      // مقدار پیش‌فرض را نگه می‌داریم
    }
  }

  void set(T value) {
    if (value == state) return;
    state = value;
    _persist(value);
  }

  Future<void> _persist(T value) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(key, jsonEncode(encode(value)));
    } catch (_) {}
  }
}

const kThemeModes = ['paper', 'sepia', 'greyNight', 'amoled'];
const kDefaultTheme = 'amoled';
const kMinReaderFont = 12.0;
const kMaxReaderFont = 22.0;
const kDefaultReaderFont = 15.0;

class ThemeModeNotifier extends _SettingNotifier<String> {
  ThemeModeNotifier()
      : super(
          key: 'settings_theme_v1',
          fallback: kDefaultTheme,
          decode: (raw) {
            final v = raw as String?;
            return (v != null && kThemeModes.contains(v)) ? v : kDefaultTheme;
          },
          encode: (v) => v,
        );
}

class ReaderFontSizeNotifier extends _SettingNotifier<double> {
  ReaderFontSizeNotifier()
      : super(
          key: 'settings_reader_font_v1',
          fallback: kDefaultReaderFont,
          decode: (raw) => ((raw as num?)?.toDouble() ?? kDefaultReaderFont)
              .clamp(kMinReaderFont, kMaxReaderFont)
              .toDouble(),
          encode: (v) => v,
        );
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, String>(
    (ref) => ThemeModeNotifier());

final readerFontSizeProvider =
    StateNotifierProvider<ReaderFontSizeNotifier, double>(
        (ref) => ReaderFontSizeNotifier());
