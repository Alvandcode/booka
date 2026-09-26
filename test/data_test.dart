import 'package:book_reader_app/data/dao.dart';
import 'package:book_reader_app/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SM-2', () {
    FlashcardEntry card({
      double easiness = 2.5,
      int intervalDays = 1,
      int repetitions = 0,
    }) =>
        FlashcardEntry(
          word: 'abandon',
          meaning: 'رها کردن',
          context: 'They had to abandon the plan.',
          book: 'Test',
          at: DateTime(2024),
          dueAt: DateTime(2024),
          easiness: easiness,
          intervalDays: intervalDays,
          repetitions: repetitions,
        );

    test('اولین مرور موفق، بازه را یک روز می‌کند', () {
      final r = Dao.sm2(card(), 4);
      expect(r.repetitions, 1);
      expect(r.intervalDays, 1);
    });

    test('دومین مرور موفق، بازه شش روز می‌شود', () {
      final r = Dao.sm2(card(repetitions: 1, intervalDays: 1), 4);
      expect(r.repetitions, 2);
      expect(r.intervalDays, 6);
    });

    test('سومین مرور، بازه را در ضریب سهولت قبلی ضرب می‌کند', () {
      final r = Dao.sm2(card(repetitions: 2, intervalDays: 6), 5);
      expect(r.repetitions, 3);
      // SM-2 استاندارد: بازه با ضریب سهولت *قبلی* حساب می‌شود
      // (۶ × ۲٫۵) و ضریب سهولت بعد از آن به‌روز می‌شود
      expect(r.intervalDays, 15);
      // ضریب سهولت برای کیفیت ۵ روی ۲٫۶ تنظیم می‌شود
      expect(r.easiness, closeTo(2.6, 1e-9));
    });

    test('پاسخ پایین، تکرارها را صفر می‌کند', () {
      final r = Dao.sm2(card(repetitions: 5, intervalDays: 40), 1);
      expect(r.repetitions, 0);
      expect(r.intervalDays, 1);
    });

    test('ضریب سهولت هرگز از کف ۱٫۳ کمتر نمی‌شود', () {
      var c = card();
      for (var i = 0; i < 20; i++) {
        c = Dao.sm2(c, 0);
      }
      expect(c.easiness, 1.3);
    });

    test('ضریب سهولت هرگز از سقف ۲٫۸ بیشتر نمی‌شود', () {
      var c = card();
      for (var i = 0; i < 20; i++) {
        c = Dao.sm2(c, 5);
      }
      expect(c.easiness, 2.8);
    });

    test('کیفیت خارج از بازه، به بازه محدود می‌شود', () {
      expect(Dao.sm2(card(), 99).repetitions, 1);
      expect(Dao.sm2(card(), -5).repetitions, 0);
    });

    test('تاریخ سررسید همیشه در آینده است', () {
      final r = Dao.sm2(card(), 5);
      expect(r.dueAt.isAfter(DateTime.now()), isTrue);
    });
  });

  group('سریال‌سازی مدل‌ها', () {
    test('رفت‌وبرگشت کتاب بدون افت اطلاعات', () {
      final b = LibraryBook(
        path: '/books/a.epub',
        title: 'الف',
        type: 'epub',
        addedAt: DateTime(2024, 3, 2),
        lastPage: 7,
        totalPages: 40,
        progress: 0.175,
        lastAnchor: 'spine:6',
        lastOpened: DateTime(2024, 4, 1),
      );
      final back = LibraryBook.fromRow(b.toRow());
      expect(back.path, b.path);
      expect(back.title, b.title);
      expect(back.lastPage, 7);
      expect(back.totalPages, 40);
      expect(back.progress, closeTo(0.175, 1e-9));
      expect(back.lastAnchor, 'spine:6');
      expect(back.addedAt, b.addedAt);
      expect(back.lastOpened, b.lastOpened);
    });

    test('رفت‌وبرگشت هایلایت، برچسب‌ها و یادداشت را حفظ می‌کند', () {
      final h = HighlightEntry(
        bookPath: '/books/a.epub',
        book: 'الف',
        quote: 'جمله مهم',
        pageIndex: 3,
        color: 0xFFFFE08A,
        at: DateTime(2024, 5, 5),
        note: 'یادداشت من',
        tags: const ['فلسفه', 'مهم'],
      );
      final back = HighlightEntry.fromRow(h.toRow());
      expect(back.quote, h.quote);
      expect(back.note, 'یادداشت من');
      expect(back.tags, ['فلسفه', 'مهم']);
    });

    test('رفت‌وبرگشت کارت لایتنر، زمان‌بندی SM-2 را حفظ می‌کند', () {
      final c = FlashcardEntry(
        word: 'ephemeral',
        meaning: 'گذرا',
        context: 'an ephemeral moment',
        book: 'Test',
        at: DateTime(2024),
        dueAt: DateTime(2024, 6, 1),
        easiness: 2.6,
        intervalDays: 15,
        repetitions: 4,
      );
      final back = FlashcardEntry.fromRow(c.toRow());
      expect(back.word, c.word);
      expect(back.easiness, closeTo(2.6, 1e-9));
      expect(back.intervalDays, 15);
      expect(back.repetitions, 4);
      expect(back.dueAt, c.dueAt);
    });

    test('رکورد ناقص از دیتابیس، اپ را نمی‌شکند', () {
      final b = LibraryBook.fromRow({'id': 1});
      expect(b.title, 'بدون عنوان');
      expect(b.type, 'pdf');
      expect(b.lastPage, 1);
      expect(b.progress, 0);
    });
  });

  group('جستجوی متن کامل', () {
    test('blob جستجو حروف را کوچک می‌کند', () {
      final h = HighlightEntry(
        bookPath: '/a.epub',
        book: 'A',
        quote: 'The QUICK Brown Fox',
        pageIndex: 1,
        color: 0,
        at: DateTime(2024),
      );
      final blob = h.toRow()['search'] as String;
      expect(blob, contains('quick'));
    });

    test('blob جستجو شامل یادداشت و برچسب هم هست', () {
      final h = HighlightEntry(
        bookPath: '/a.epub',
        book: 'A',
        quote: 'quote',
        pageIndex: 1,
        color: 0,
        at: DateTime(2024),
        note: 'یادداشت',
        tags: const ['برچسب'],
      );
      final blob = h.toRow()['search'] as String;
      expect(blob, contains('یادداشت'));
      expect(blob, contains('برچسب'));
    });
  });

  group('مهاجرت از نسخه قبلی', () {
    test('JSON قدیمی کتاب به مدل جدید تبدیل می‌شود', () {
      final b = LibraryBook.fromLegacy({
        'path': '/books/old.pdf',
        'title': 'قدیمی',
        'type': 'pdf',
        'addedAt': '2024-01-02T03:04:05.000',
        'lastPage': 12,
        'progress': 0.4,
        'lastOpened': '2024-02-02T00:00:00.000',
      });
      expect(b.id, isNull);
      expect(b.lastPage, 12);
      expect(b.progress, closeTo(0.4, 1e-9));
      expect(b.lastOpened, isNotNull);
    });

    test('JSON ناقص/خراب، مقدار پیش‌فرض امن می‌گیرد', () {
      final b = LibraryBook.fromLegacy({'path': '/x.pdf'});
      expect(b.title, 'بدون عنوان');
      expect(b.lastPage, 1);
      expect(b.progress, 0);
    });

    test('JSON خالی هم کرش نمی‌کند', () {
      expect(BookmarkEntry.fromLegacy(const {}).bookPath, '');
      expect(HighlightEntry.fromLegacy(const {}).quote, '');
      expect(FlashcardEntry.fromLegacy(const {}).word, '');
    });

    test('کارت قدیمی بلافاصله سررسید است تا در مرور امروز بیاید', () {
      final c = FlashcardEntry.fromLegacy({'word': 'x', 'at': '2020-01-01T00:00:00.000'});
      expect(c.isDue, isTrue);
    });
  });
}
