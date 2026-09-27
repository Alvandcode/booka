import 'package:meta/meta.dart';
import 'package:sqflite/sqflite.dart';

import 'db.dart';
import 'models.dart';

/// دسترسی به داده. همه کوئری‌ها اینجا متمرکزند و store.dart
/// فقط وضعیت را نگه می‌دارد.
///
/// باز شدن SQLite همیشه async است، ولی constructor نوتیفایرهای
/// Riverpod باید هم‌زمان مقدار اولیه بدهد. به همین دلیل [Dao] یک
/// `Future<Database>` نگه می‌دارد و هر عملیات خودش منتظر آن می‌شود؛
/// در نتیجه ساختن نمونه در constructor نوتیفایر بی‌خطر است.
class Dao {
  Dao(Future<Database> db) : _db = db;

  final Future<Database> _db;

  Future<T> _run<T>(Future<T> Function(Database db) body) async =>
      body(await _db);

  /// باز کردن پایگاه داده
  static Future<Dao> open() async => Dao(Db.instance);

  // ── کتاب‌ها ──

  Future<List<LibraryBook>> books() => _run((db) async {
        final rows = await db.query(Db.tBooks, orderBy: 'added_at DESC');
        return rows.map(LibraryBook.fromRow).toList();
      });

  Future<LibraryBook?> bookByPath(String path) => _run((db) async {
        final rows = await db
            .query(Db.tBooks, where: 'path = ?', whereArgs: [path], limit: 1);
        return rows.isEmpty ? null : LibraryBook.fromRow(rows.first);
      });

  /// درج کتاب. اگر همان مسیر قبلا ثبت شده باشد، شناسه موجود برگردانده می‌شود
  /// تا درج تکراری رکورد دوم نسازد.
  Future<int> insertBook(LibraryBook b) async {
    final existing = await bookByPath(b.path);
    final id = existing?.id;
    if (id != null) return id;
    return _run((db) => db.insert(Db.tBooks, b.toRow(),
        conflictAlgorithm: ConflictAlgorithm.ignore));
  }

  Future<void> updateBook(LibraryBook b) async {
    final id = b.id;
    if (id == null) return;
    await _run((db) =>
        db.update(Db.tBooks, b.toRow(), where: 'id = ?', whereArgs: [id]));
  }

  /// ذخیره موقعیت مطالعه. نوشتن کاملاً incremental است — برخلاف
  /// SharedPreferences که کل لیست را هر بار دوباره serialize می‌کرد.
  Future<void> saveProgress(
    String path, {
    int? page,
    int? totalPages,
    double? progress,
    String? anchor,
  }) async {
    final book = await bookByPath(path);
    if (book == null) return;
    await updateBook(book.copyWith(
      lastPage: page,
      totalPages: totalPages,
      progress: progress,
      lastAnchor: anchor,
      lastOpened: DateTime.now(),
    ));
  }

  /// حذف کتاب به همراه تمام نشان‌ها، هایلایت‌ها و کارت‌های مربوط.
  /// حذف آبشاری صریح است چون به مسیر تکیه می‌کند و برای رکوردهای
  /// مهاجرت‌یافته که ممکن است book_id نداشته باشند هم کار می‌کند.
  Future<void> deleteBook(String path) => _run((db) async {
        final rows = await db
            .query(Db.tBooks, where: 'path = ?', whereArgs: [path], limit: 1);
        final id = rows.isEmpty ? null : rows.first['id'] as int?;
        await db.transaction((txn) async {
          for (final table in [Db.tBookmarks, Db.tHighlights, Db.tFlashcards]) {
            await txn.delete(table, where: 'book_path = ?', whereArgs: [path]);
          }
          if (id != null) {
            await txn.delete(Db.tBooks, where: 'id = ?', whereArgs: [id]);
          }
        });
      });

  /// پاک کردن کامل داده‌های محتوایی.
  ///
  /// فایل خودِ کتاب‌ها روی دیسک دست‌نخورده می‌ماند؛ فقط رکوردهای
  /// پایگاه داده حذف می‌شوند تا کاربر بتواند دوباره واردشان کند.
  /// ترتیب حذف مهم است چون قید کلید خارجی فعال است.
  Future<void> clearAllContent() => _run((db) => db.transaction((txn) async {
        await txn.delete(Db.tBookmarks);
        await txn.delete(Db.tHighlights);
        await txn.delete(Db.tFlashcards);
        await txn.delete(Db.tBooks);
      }));

  // ── نشان‌ها ──

  Future<List<BookmarkEntry>> bookmarks() => _run((db) async {
        final rows = await db.query(Db.tBookmarks, orderBy: 'created_at DESC');
        return rows.map(BookmarkEntry.fromRow).toList();
      });

  Future<int> insertBookmark(BookmarkEntry e) =>
      _run((db) => db.insert(Db.tBookmarks, e.toRow()));

  Future<void> deleteBookmark(int id) => _run(
      (db) => db.delete(Db.tBookmarks, where: 'id = ?', whereArgs: [id]));

  // ── هایلایت‌ها ──

  Future<List<HighlightEntry>> highlights() => _run((db) async {
        final rows = await db.query(Db.tHighlights, orderBy: 'created_at DESC');
        return rows.map(HighlightEntry.fromRow).toList();
      });

  /// جستجوی متن کامل در هایلایت‌ها روی متن، یادداشت و برچسب‌ها.
  Future<List<HighlightEntry>> searchHighlights(String term) => _run((db) async {
        final q = '%${term.trim().toLowerCase()}%';
        final rows = await db.query(
          Db.tHighlights,
          where: 'search LIKE ?',
          whereArgs: [q],
          orderBy: 'created_at DESC',
        );
        return rows.map(HighlightEntry.fromRow).toList();
      });

  Future<int> insertHighlight(HighlightEntry e) =>
      _run((db) => db.insert(Db.tHighlights, e.toRow()));

  Future<void> updateHighlight(HighlightEntry e) async {
    final id = e.id;
    if (id == null) return;
    await _run((db) => db.update(Db.tHighlights, e.toRow(),
        where: 'id = ?', whereArgs: [id]));
  }

  Future<void> deleteHighlight(int id) => _run(
      (db) => db.delete(Db.tHighlights, where: 'id = ?', whereArgs: [id]));

  // ── کارت‌های لایتنر ──

  Future<List<FlashcardEntry>> flashcards() => _run((db) async {
        final rows = await db.query(Db.tFlashcards, orderBy: 'created_at DESC');
        return rows.map(FlashcardEntry.fromRow).toList();
      });

  /// کارت‌های سررسیده — مبنای الگوریتم مرور SM-2
  Future<List<FlashcardEntry>> dueFlashcards({int limit = 50}) => _run((db) async {
        final rows = await db.query(
          Db.tFlashcards,
          where: 'due_at <= ?',
          whereArgs: [DateTime.now().millisecondsSinceEpoch],
          orderBy: 'due_at ASC',
          limit: limit,
        );
        return rows.map(FlashcardEntry.fromRow).toList();
      });

  Future<int> insertFlashcard(FlashcardEntry e) =>
      _run((db) => db.insert(Db.tFlashcards, e.toRow()));

  Future<void> updateFlashcard(FlashcardEntry e) async {
    final id = e.id;
    if (id == null) return;
    await _run((db) => db.update(Db.tFlashcards, e.toRow(),
        where: 'id = ?', whereArgs: [id]));
  }

  Future<void> deleteFlashcard(int id) => _run(
      (db) => db.delete(Db.tFlashcards, where: 'id = ?', whereArgs: [id]));

  /// ثبت پاسخ یک کارت و زمان‌بندی مرور بعدی طبق SM-2.
  /// [quality]: ۰ تا ۵ (۰ = کاملاً فراموش، ۵ = کاملاً مسلط)
  Future<void> reviewFlashcard(int id, int quality) async {
    final rows = await _run((db) => db.query(Db.tFlashcards,
        where: 'id = ?', whereArgs: [id], limit: 1));
    if (rows.isEmpty) return;
    await updateFlashcard(sm2(FlashcardEntry.fromRow(rows.first), quality));
  }

  /// یک گام از الگوریتم SM-2.
  /// جدا و [visibleForTesting] است تا رفتار مرور بدون نیاز به دیتابیس تست شود.
  @visibleForTesting
  static FlashcardEntry sm2(FlashcardEntry c, int quality) {
    final q = quality.clamp(0, 5);
    var easiness = c.easiness;
    var interval = c.intervalDays;
    var reps = c.repetitions;

    if (q < 3) {
      // فراموش شده: تکرارها صفر و بازه به یک روز برمی‌گردد
      reps = 0;
      interval = 1;
    } else {
      reps += 1;
      if (reps == 1) {
        interval = 1;
      } else if (reps == 2) {
        interval = 6;
      } else {
        interval = (interval * easiness).round();
      }
    }
    // ضریب سهولت با فرمول استاندارد SM-2 به‌روز و در بازه معتبر محدود می‌شود
    easiness =
        (easiness + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))).clamp(1.3, 2.8);

    return c.copyWith(
      easiness: easiness,
      intervalDays: interval,
      repetitions: reps,
      dueAt: DateTime.now().add(Duration(days: interval)),
    );
  }
}
