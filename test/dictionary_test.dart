import 'package:book_reader_app/data/models.dart';
import 'package:book_reader_app/dictionary/dictionary_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('نرمال‌سازی واژه', () {
    final s = DictionaryService.instance;

    test('حروف بزرگ به کوچک تبدیل می‌شوند', () {
      expect(s.normalize('Hello'), 'hello');
      expect(s.normalize('HELLO'), 'hello');
    });

    test('فاصله‌های ابتدا و انتها حذف می‌شوند', () {
      expect(s.normalize('  word  '), 'word');
    });

    test('نشانه‌گذاری انتهایی حذف می‌شود', () {
      expect(s.normalize('word.'), 'word');
      expect(s.normalize('word!'), 'word');
      expect(s.normalize('word?'), 'word');
      expect(s.normalize('word,'), 'word');
      expect(s.normalize('word:'), 'word');
      expect(s.normalize('word;'), 'word');
    });

    test('نشانه‌گذاری ابتدایی حذف می‌شود', () {
      expect(s.normalize('«word»'), 'word');
      expect(s.normalize('(word)'), 'word');
      expect(s.normalize('"word"'), 'word');
    });

    test('نشانه‌های تکراری در دو طرف حذف می‌شوند', () {
      expect(s.normalize('«متن،'), 'متن');
      expect(s.normalize('...متن!!!'), 'متن');
    });

    test('نشانه‌های عربی و فارسی هم حذف می‌شوند', () {
      expect(s.normalize('کتاب؟'), 'کتاب');
      expect(s.normalize('کتاب؛'), 'کتاب');
      expect(s.normalize('کتاب،'), 'کتاب');
      expect(s.normalize('۵۰٪'), '۵۰');
    });

    test('نشانه‌های داخلی متن دست‌نخورده می‌مانند', () {
      expect(s.normalize('well-known'), 'well-known');
      expect(s.normalize("don't"), "don't");
    });

    test('نشانه‌گذاری داخلی فاصله‌ها فشرده می‌شود', () {
      expect(s.normalize('  Hello   World  '), 'hello world');
    });

    test('آپاستروف درون کلمه حفظ می‌شود', () {
      expect(s.normalize("don't"), "don't");
    });

    test('ورودی خالی یا فقط نشانه، خالی برمی‌گردد', () {
      expect(s.normalize(''), '');
      expect(s.normalize('   '), '');
      expect(s.normalize('...'), '');
    });
  });

  test('ستون author رفت‌وبرگشت می‌شود', () {
    final b = LibraryBook(
      path: '/a.epub',
      title: 'عنوان',
      type: 'epub',
      addedAt: DateTime(2024, 1, 1),
      author: 'نویسنده',
    );
    final back = LibraryBook.fromRow(b.toRow());
    expect(back.author, 'نویسنده');
  });

  test('author خالی از رکورد ناقص، null می‌ماند', () {
    final back = LibraryBook.fromRow({'id': 1, 'path': '/a.pdf'});
    expect(back.author, isNull);
    expect(back.coverPath, isNull);
  });

  test('copyWith نویسنده و کاور را نگه می‌دارد', () {
    final b = LibraryBook(
      path: '/a.epub',
      title: 'عنوان',
      type: 'epub',
      addedAt: DateTime(2024),
      author: 'نویسنده',
      coverPath: '/a.epub.cover',
    );
    final next = b.copyWith(lastPage: 5, progress: 0.25);
    expect(next.author, 'نویسنده');
    expect(next.coverPath, '/a.epub.cover');
    expect(next.lastPage, 5);
    expect(next.progress, 0.25);
  });

  group('سررسید کارت', () {
    test('کارت گذشته، سررسید است', () {
      final c = FlashcardEntry(
        word: 'w',
        meaning: 'm',
        context: '',
        book: 'b',
        at: DateTime(2020),
        dueAt: DateTime(2020).add(const Duration(days: 1)),
      );
      expect(c.isDue, isTrue);
    });

    test('کارت آینده، سررسید نیست', () {
      final c = FlashcardEntry(
        word: 'w',
        meaning: 'm',
        context: '',
        book: 'b',
        at: DateTime.now(),
        dueAt: DateTime.now().add(const Duration(days: 5)),
      );
      expect(c.isDue, isFalse);
    });
  });

  group('برچسب‌های هایلایت', () {
    test('رشته خالی به لیست خالی تبدیل می‌شود', () {
      final h = HighlightEntry.fromRow({
        'id': 1,
        'quote': 'q',
        'tags': '',
        'created_at': DateTime(2024).millisecondsSinceEpoch,
      });
      expect(h.tags, isEmpty);
    });

    test('فاصله‌های اضافه در برچسب‌ها حذف می‌شوند', () {
      final h = HighlightEntry.fromRow({
        'id': 1,
        'quote': 'q',
        'tags': 'یک , دو ,سه',
        'created_at': DateTime(2024).millisecondsSinceEpoch,
      });
      expect(h.tags, ['یک', 'دو', 'سه']);
    });
  });
}
