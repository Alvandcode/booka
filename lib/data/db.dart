import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// اسکیمای پایگاه داده.
/// هر تغییر در ساختار جدول‌ها باید [schemaVersion] را یک واحد بالا ببرد
/// و یک شاخه جدید در [AppDatabase.onUpgrade] اضافه کند.
class Db {
  const Db._();

  static const fileName = 'booka.db';
  static const schemaVersion = 2;

  /// نام جدول‌ها
  static const tBooks = 'books';
  static const tBookmarks = 'bookmarks';
  static const tHighlights = 'highlights';
  static const tFlashcards = 'flashcards';

  static Database? _db;
  static Future<Database>? _opening;

  /// دسترسی به نمونه یکتای پایگاه داده. فراخوانی‌های همزمان
  /// روی یک باز شدن منتظر می‌مانند تا فقط یک اتصال ساخته شود.
  static Future<Database> get instance => _db != null
      ? Future.value(_db)
      : (_opening ??= _open().then((db) {
          _db = db;
          _opening = null;
          return db;
        }));

  static Future<Database> _open() async {
    final base = await getDatabasesPath();
    return openDatabase(
      p.join(base, fileName),
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch();

    // ── کتاب‌ها ──
    batch.execute('''
      CREATE TABLE $tBooks (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        path        TEXT    NOT NULL UNIQUE,
        title       TEXT    NOT NULL,
        type        TEXT    NOT NULL,
        cover_path  TEXT,
        author      TEXT,
        last_anchor TEXT,
        last_page   INTEGER NOT NULL DEFAULT 1,
        total_pages INTEGER NOT NULL DEFAULT 0,
        progress    REAL    NOT NULL DEFAULT 0,
        added_at    INTEGER NOT NULL,
        last_opened INTEGER
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_books_path ON $tBooks (path)');
    batch.execute(
        'CREATE INDEX idx_books_last_opened ON $tBooks (last_opened DESC)');

    // ── نشان‌ها ──
    // book_path عمداً تکرار (denormalize) شده تا اگر کتاب حذف شد،
    // نشان‌های یتیم همچنان عنوان و مسیر قابل‌نمایش داشته باشند.
    batch.execute('''
      CREATE TABLE $tBookmarks (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id    INTEGER REFERENCES $tBooks (id) ON DELETE CASCADE,
        book_path  TEXT    NOT NULL,
        book_title TEXT    NOT NULL,
        note       TEXT    NOT NULL DEFAULT '',
        page_index INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_bookmarks_book ON $tBookmarks (book_path)');
    batch.execute(
        'CREATE INDEX idx_bookmarks_created ON $tBookmarks (created_at DESC)');

    // ── هایلایت‌ها و یادداشت‌ها ──
    // search نرمال‌شده‌ی quote+note+tags است تا جستجوی متن کامل
    // بدون اتکا به FTS5 (که روی همه نسخه‌های اندروید در دسترس نیست) کار کند.
    batch.execute('''
      CREATE TABLE $tHighlights (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id    INTEGER REFERENCES $tBooks (id) ON DELETE CASCADE,
        book_path  TEXT    NOT NULL,
        book_title TEXT    NOT NULL,
        quote      TEXT    NOT NULL DEFAULT '',
        page_index INTEGER NOT NULL DEFAULT 1,
        color      INTEGER NOT NULL DEFAULT 0xFFFFE08A,
        note       TEXT    NOT NULL DEFAULT '',
        tags       TEXT    NOT NULL DEFAULT '',
        search     TEXT    NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_highlights_book ON $tHighlights (book_path)');
    batch.execute(
        'CREATE INDEX idx_highlights_created ON $tHighlights (created_at DESC)');

    // ── کارت‌های لایتنر با زمان‌بندی SM-2 ──
    batch.execute('''
      CREATE TABLE $tFlashcards (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id         INTEGER REFERENCES $tBooks (id) ON DELETE CASCADE,
        book_path       TEXT    NOT NULL DEFAULT '',
        book_title      TEXT    NOT NULL DEFAULT '',
        word            TEXT    NOT NULL,
        meaning         TEXT    NOT NULL DEFAULT '',
        context_sentence TEXT   NOT NULL DEFAULT '',
        easiness        REAL    NOT NULL DEFAULT 2.5,
        interval_days   INTEGER NOT NULL DEFAULT 1,
        repetitions     INTEGER NOT NULL DEFAULT 0,
        due_at          INTEGER NOT NULL,
        created_at      INTEGER NOT NULL
      )
    ''');
    batch.execute(
        'CREATE INDEX idx_flashcards_due ON $tFlashcards (due_at)');
    batch.execute(
        'CREATE INDEX idx_flashcards_word ON $tFlashcards (word)');

    await batch.commit(noResult: true);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    // نسخه ۱ → ۲: افزودن ستون نویسنده به کتاب‌ها
    if (from < 2) {
      await db.execute('ALTER TABLE $tBooks ADD COLUMN author TEXT');
    }
  }

  /// بستن اتصال — فقط برای تست و خروج تمیز از اپ.
  static Future<void> close() async {
    final db = _db;
    _db = null;
    _opening = null;
    await db?.close();
  }
}
