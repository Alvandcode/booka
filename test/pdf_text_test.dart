import 'package:book_reader_app/reader/pdf_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('تشخیص لایه متنی', () {
    test('صفحه با متن واقعی، لایه متنی دارد', () {
      expect(PdfTextTools.hasTextLayer('This is a real sentence.'), isTrue);
      expect(PdfTextTools.hasTextLayer('متن فارسی معنادار در این صفحه'),
          isTrue);
    });

    test('صفحه خالی یا null، لایه متنی ندارد', () {
      expect(PdfTextTools.hasTextLayer(null), isFalse);
      expect(PdfTextTools.hasTextLayer(''), isFalse);
    });

    test('فقط فاصله و شکست خط، متن محسوب نمی‌شود', () {
      // این حالت دقیقاً همان چیزی است که PDF اسکن‌شده برمی‌گرداند
      expect(PdfTextTools.hasTextLayer('   \n\n\t  '), isFalse);
      expect(PdfTextTools.hasTextLayer('\n\n\n'), isFalse);
    });

    test('متن خیلی کوتاه، لایه متنی محسوب نمی‌شود', () {
      // جلوگیری از مثبت کاذب روی نویزِ استخراج
      expect(PdfTextTools.hasTextLayer('ab'), isFalse);
      expect(PdfTextTools.hasTextLayer('a b c d'), isFalse);
    });
  });

  group('تشخیص سند اسکن‌شده', () {
    test('اکثر صفحات بدون متن یعنی اسکن‌شده', () {
      expect(PdfTextTools.isScannedDocument(1, 10), isTrue);
      expect(PdfTextTools.isScannedDocument(4, 10), isTrue);
    });

    test('بیشتر صفحات با متن یعنی دیجیتال', () {
      expect(PdfTextTools.isScannedDocument(9, 10), isFalse);
      expect(PdfTextTools.isScannedDocument(10, 10), isFalse);
    });

    test('سند خالی اسکن‌شده نیست', () {
      expect(PdfTextTools.isScannedDocument(0, 0), isFalse);
    });
  });

  group('نرمال‌سازی متن', () {
    test('فاصله‌های اضافه فشرده می‌شوند', () {
      expect(PdfTextTools.normalize('a    b'), 'a b');
    });

    test('فاصله غیرقابل‌شکن تبدیل می‌شود', () {
      expect(PdfTextTools.normalize('a\u00A0b'), 'a b');
    });

    test('فاصله‌های ابتدا و انتها حذف می‌شوند', () {
      expect(PdfTextTools.normalize('  hello  '), 'hello');
    });

    test('null ورودی به رشته خالی تبدیل می‌شود', () {
      expect(PdfTextTools.normalize(null), '');
    });
  });

  group('جستجو در صفحه', () {
    const text = 'The quick brown fox jumps over the lazy dog quickly';

    test('تعداد درست نتایج', () {
      final hits = PdfTextTools.searchPage(
        pageText: text,
        pageNumber: 5,
        query: 'quick',
      );
      expect(hits.length, 2);
      expect(hits.every((h) => h.page == 5), isTrue);
    });

    test('جستجوی بدون حساسیت به بزرگی حروف', () {
      final hits = PdfTextTools.searchPage(
        pageText: text,
        pageNumber: 1,
        query: 'QUICK',
      );
      expect(hits.length, 2);
    });

    test('عبارت چندکلمه‌ای', () {
      final hits = PdfTextTools.searchPage(
        pageText: text,
        pageNumber: 1,
        query: 'brown fox',
      );
      expect(hits.length, 1);
    });

    test('شماره صفحه همان یک‌based منتقل می‌شود', () {
      final hits = PdfTextTools.searchPage(
        pageText: text,
        pageNumber: 42,
        query: 'fox',
      );
      expect(hits.single.page, 42);
    });

    test('عبارت کمتر از دو حرف جستجو نمی‌شود', () {
      expect(
        PdfTextTools.searchPage(pageText: text, pageNumber: 1, query: 'q'),
        isEmpty,
      );
    });

    test('بدون نتیجه لیست خالی', () {
      expect(
        PdfTextTools.searchPage(
            pageText: text, pageNumber: 1, query: 'zebra'),
        isEmpty,
      );
    });

    test('صفحه بدون متن، نتیجه نمی‌دهد', () {
      expect(
        PdfTextTools.searchPage(pageText: '', pageNumber: 1, query: 'fox'),
        isEmpty,
      );
    });

    test('سقف نتایج رعایت می‌شود', () {
      final many = List.filled(500, 'fox').join(' ');
      final hits = PdfTextTools.searchPage(
        pageText: many,
        pageNumber: 1,
        query: 'fox',
        maxResults: 5,
      );
      expect(hits.length, 5);
    });

    test('عبارت تکراری جلوی حلقه بی‌نهایت را می‌گیرد', () {
      final hits = PdfTextTools.searchPage(
        pageText: 'ab' * 3000,
        pageNumber: 1,
        query: 'ab',
        maxResults: 10,
      );
      expect(hits.length, 10);
    });

    test('متن فارسی هم جستجو می‌شود', () {
      final hits = PdfTextTools.searchPage(
        pageText: 'کتابخانه آفلاین و کتابخانه بزرگ',
        pageNumber: 3,
        query: 'کتابخانه',
      );
      expect(hits.length, 2);
    });

    test('فاصله‌های اضافه در متن صفحه مانع یافتن نمی‌شود', () {
      final hits = PdfTextTools.searchPage(
        pageText: 'the   brown',
        pageNumber: 1,
        query: 'the brown',
      );
      expect(hits.length, 1);
    });
  });

  group('قطعه متن پیرامون نتیجه', () {
    test('نتیجه در ابتدای متن، بدون پیشوند', () {
      final s = PdfTextTools.snippet('hello world', 0, 5, pad: 20);
      expect(s, startsWith('hello'));
      expect(s, isNot(startsWith('…')));
    });

    test('نتیجه وسط متن، با پیشوند و پسوند', () {
      final long = '${'کلمه ' * 40}هدف${' کلمه' * 40}';
      final at = long.indexOf('هدف');
      final s = PdfTextTools.snippet(long, at, 3);
      expect(s, contains('هدف'));
      expect(s, startsWith('…'));
    });

    test('کلمه وسط بریده نمی‌شود', () {
      final s = PdfTextTools.snippet('alpha bravo charlie', 11, 7);
      expect(s, contains('charlie'));
    });

    test('شکست خط داخل برش به فاصله تبدیل می‌شود', () {
      // متن استخراج‌شده از PDF پاراگراف‌به‌پاراگراف است؛ اگر اینجا
      // نشکند، نتیجه در فهرست چندخطی و نامرتب دیده می‌شود.
      const text = 'first line here\nsecond line there\nthird line';
      final at = text.indexOf('second');
      final s = PdfTextTools.snippet(text, at, 6);
      expect(s, isNot(contains('\n')));
      expect(s, contains('second line'));
    });

    test('برش تک‌خطی حتی با فاصله‌های اضافه تمیز است', () {
      const text = 'a     b\n\n\nc';
      final s = PdfTextTools.snippet(text, 2, 1);
      expect(s.replaceAll(RegExp(r'\s+'), ' '), s);
    });
  });

  group('استخراج کلمه انگلیسی', () {
    test('اولین کلمه انگلیسی پیدا می‌شود', () {
      expect(PdfTextTools.firstEnglishWord('some English word here'),
          'some');
      expect(PdfTextTools.firstEnglishWord('کتابخانه سه English word'),
          'English');
    });

    test('کلمه دارای آپاستروف حفظ می‌شود', () {
      expect(PdfTextTools.firstEnglishWord("don't stop"), "don't");
    });

    test('متن بدون کلمه انگلیسی، رشته خالی', () {
      expect(PdfTextTools.firstEnglishWord('فقط فارسی'), '');
      expect(PdfTextTools.firstEnglishWord(''), '');
    });

    test('کلمه با حروف فارسی-انگلیسی مخلوط', () {
      expect(PdfTextTools.firstEnglishWord('کتاب book'), 'book');
    });
  });
}
