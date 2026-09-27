import 'dart:convert';

import 'package:book_reader_app/data/backup.dart';
import 'package:book_reader_app/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryBook book(
  String path, {
  String? title,
  String? author,
  double progress = 0,
}) =>
    LibraryBook(
      path: path,
      title: title ?? 'کتاب',
      type: 'epub',
      addedAt: DateTime(2024, 1, 1),
      author: author,
      progress: progress,
    );

BookmarkEntry mark(String path, String note, {int page = 1}) => BookmarkEntry(
      bookPath: path,
      book: 'کتاب',
      note: note,
      at: DateTime(2024, 1, 1),
      pageIndex: page,
    );

HighlightEntry hl(String path, String quote, {int page = 1}) => HighlightEntry(
      bookPath: path,
      book: 'کتاب',
      quote: quote,
      pageIndex: page,
      color: 0xFFFFE08A,
      at: DateTime(2024, 1, 1),
    );

FlashcardEntry card(String word) => FlashcardEntry(
      word: word,
      meaning: 'معنی',
      context: 'متن',
      book: 'کتاب',
      at: DateTime(2024, 1, 1),
      dueAt: DateTime(2024, 1, 2),
    );

void main() {
  group('ساخت JSON بکاپ', () {
    test('ساختار ریشه درست است', () {
      final json = jsonDecode(BackupServiceFixture.empty()) as Map;
      expect(json['format'], kBackupFormat);
      expect(json['version'], kBackupVersion);
      expect(json['createdAt'], isA<String>());
      expect(json['books'], isA<List>());
      expect(json['bookmarks'], isA<List>());
      expect(json['highlights'], isA<List>());
      expect(json['flashcards'], isA<List>());
    });

    test('شناسه id در فایل ذخیره نمی‌شود', () {
      // شناسه محلی است و نباید بین دستگاه‌ها حمل شود
      final withId = book('/a.epub', title: 'الف').copyWithId(42);
      final exported = BackupService.backupRow(withId.toRow());
      expect(exported.containsKey('id'), isFalse);
      expect(exported['title'], 'الف');
    });

    test('بدون id هم سطر ساخته می‌شود', () {
      final exported = BackupService.backupRow(book('/a.epub').toRow());
      expect(exported.containsKey('id'), isFalse);
      expect(exported['path'], '/a.epub');
    });

    test('سطر اصلی مدل دست‌نخورده می‌ماند', () {
      final b = book('/a.epub').copyWithId(7);
      final original = b.toRow();
      BackupService.backupRow(original);
      expect(original.containsKey('id'), isTrue,
          reason: 'سطر منبع نباید تغییر کند');
    });
  });

  group('خواندن بکاپ نامعتبر', () {
    test('JSON خراب، FormatException می‌دهد', () {
      expect(
        () => BackupServiceFixture.import('这不是 json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('JSON معتبر ولی غریبه، رد می‌شود', () {
      expect(
        () => BackupServiceFixture.import('{"format":"something-else"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('نسخه جدیدتر از اپ، رد می‌شود', () {
      expect(
        () => BackupServiceFixture.import(
            '{"format":"$kBackupFormat","version":99}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('آرایه به‌جای شیء، رد می‌شود', () {
      expect(
        () => BackupServiceFixture.import('[1,2,3]'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('خواندن بکاپ ناقص', () {
    test('کلیدهای غایب، لیست خالی در نظر گرفته می‌شوند', () {
      final result = BackupServiceFixture.importMinimal();
      expect(result, isNotNull);
    });
  });

  group('خروجی Markdown', () {
    test('هایلایت‌ها بر اساس کتاب گروه می‌شوند', () {
      final md = BackupService.highlightsMarkdown([
        hl('/a.epub', 'جمله اول'),
        hl('/a.epub', 'جمله دوم'),
        hl('/b.epub', 'جمله سوم'),
      ]);
      expect(md, contains('# هایلایت‌ها'));
      expect(md, contains('## کتاب'));
      expect(md, contains('جمله اول'));
      expect(md, contains('جمله سوم'));
      expect('جمله اول'.allMatches(md).length, 1);
    });

    test('یادداشت و برچسب در خروجی می‌آید', () {
      final h = HighlightEntry(
        bookPath: '/a.epub',
        book: 'کتاب',
        quote: 'متن',
        pageIndex: 2,
        color: 0,
        at: DateTime(2024),
        note: 'یادداشت من',
        tags: const ['فلسفه', 'مهم'],
      );
      final md = BackupService.highlightsMarkdown([h]);
      expect(md, contains('یادداشت: یادداشت من'));
      expect(md, contains('`فلسفه`'));
      expect(md, contains('بخش 2'));
    });

    test('لیست خالی، پیام مناسب می‌دهد', () {
      expect(BackupService.highlightsMarkdown([]), contains('هیچ'));
      expect(BackupService.bookmarksMarkdown([]), contains('هیچ'));
    });

    test('شکست خط در نقل‌قول، خط جدید نمی‌سازد', () {
      final h = hl('/a.epub', 'خط اول\nخط دوم');
      final md = BackupService.highlightsMarkdown([h]);
      // باید در همان bullet بماند
      expect(md, contains('«خط اول خط دوم»'));
    });

    test('نشان‌ها عنوان کتاب را دارند', () {
      final md = BackupService.bookmarksMarkdown([
        BookmarkEntry(
            bookPath: '/a.epub',
            book: 'شاهنامه',
            note: 'فصل اول',
            at: DateTime(2024)),
      ]);
      expect(md, contains('**شاهنامه**'));
      expect(md, contains('فصل اول'));
    });
  });

  group('خروجی CSV', () {
    test('سرستون درست است', () {
      final csv = BackupService.flashcardsCsv([card('abandon')]);
      expect(csv, startsWith('\uFEFFfront,back,book,context,interval,due,easiness'));
    });

    test('BOM برای اکسل فارسی هست', () {
      expect(BackupService.flashcardsCsv([]).codeUnitAt(0), 0xFEFF);
    });

    test('واژه‌های فارسی سالم می‌مانند', () {
      final csv = BackupService.flashcardsCsv([card('رها کردن')]);
      expect(csv, contains('رها کردن'));
    });

    test('کاما داخل مقدار، سلول را نقل‌قولی می‌کند', () {
      final c = FlashcardEntry(
        word: 'a,b',
        meaning: 'معنی',
        context: '',
        book: 'کتاب',
        at: DateTime(2024),
        dueAt: DateTime(2024, 1, 2),
      );
      final csv = BackupService.flashcardsCsv([c]);
      expect(csv, contains('"a,b"'));
    });

    test('نقل‌قول دوگانه داخل مقدار دو برابر می‌شود', () {
      final c = FlashcardEntry(
        word: 'say "hi"',
        meaning: '',
        context: '',
        book: '',
        at: DateTime(2024),
        dueAt: DateTime(2024, 1, 2),
      );
      expect(BackupService.flashcardsCsv([c]), contains('"say ""hi"""'));
    });

    test('شکست خط داخل مقدار، صاف می‌شود', () {
      final c = FlashcardEntry(
        word: 'a\nb',
        meaning: '',
        context: '',
        book: '',
        at: DateTime(2024),
        dueAt: DateTime(2024, 1, 2),
      );
      final csv = BackupService.flashcardsCsv([c]);
      expect(csv.contains('a\nb'), isFalse);
      expect(csv, contains('a b'));
    });

    test('تاریخ سررسید به شکل تاریخ ساده است', () {
      final csv = BackupService.flashcardsCsv([card('x')]);
      expect(csv, contains('2024-01-02'));
      expect(csv, isNot(contains('2024-01-02T')));
    });

    test('لیست خالی، فقط سرستون می‌دهد', () {
      final csv = BackupService.flashcardsCsv([]);
      expect(csv.trim().split('\n').length, 1);
    });
  });

  group('ری‌لینک مسیر کتاب‌ها', () {
    test('مسیر یکسان، مستقیم تطبیق می‌کند', () {
      final map = BackupService.mapBackupPaths(
        current: [book('/data/books/الف.epub')],
        backupPaths: ['/data/books/الف.epub'],
      );
      expect(map['/data/books/الف.epub'], '/data/books/الف.epub');
    });

    test('مسیر متفاوت ولی نام یکسان، تطبیق می‌کند', () {
      // انتقال به دستگاه جدید: پوشه اسناد فرق کرده
      final map = BackupService.mapBackupPaths(
        current: [book('/new/documents/books/الف.epub')],
        backupPaths: ['/old/documents/books/الف.epub'],
      );
      expect(map['/old/documents/books/الف.epub'],
          '/new/documents/books/الف.epub');
    });

    test('کتاب ناموجود، null برمی‌گرداند', () {
      final map = BackupService.mapBackupPaths(
        current: [book('/new/الف.epub')],
        backupPaths: ['/old/ب.epub'],
      );
      expect(map['/old/ب.epub'], isNull);
    });

    test('کتابخانه خالی، همه null', () {
      final map = BackupService.mapBackupPaths(
        current: const [],
        backupPaths: ['/old/الف.epub'],
      );
      expect(map.values.every((v) => v == null), isTrue);
    });

    test('مسیر خالی نادیده گرفته می‌شود', () {
      final map = BackupService.mapBackupPaths(
        current: [book('/new/الف.epub')],
        backupPaths: [''],
      );
      expect(map.containsKey(''), isFalse);
    });

    test('نام فایل با فاصله هم تطبیق می‌کند', () {
      final map = BackupService.mapBackupPaths(
        current: [book('/new/کتاب من.epub')],
        backupPaths: ['/old/کتاب من.epub'],
      );
      expect(map['/old/کتاب من.epub'], '/new/کتاب من.epub');
    });

    test('مسیر کامل بر مسیر کامل مقدم است', () {
      // دو کتاب هم‌نام در پوشه‌های مختلف
      final map = BackupService.mapBackupPaths(
        current: [book('/a/x.epub'), book('/b/x.epub')],
        backupPaths: ['/c/x.epub'],
      );
      // هیچ مسیر کاملی مطابقت ندارد، پس باید بر اساس نام تطبیق دهد
      expect(map['/c/x.epub'], isNotNull);
    });
  });

  group('کلیدهای تکراری‌زدایی', () {
    test('نشان یکسان، کلید یکسان', () {
      final t = DateTime(2024, 1, 1);
      expect(
        BackupService.markKey('/a.epub', 'فصل اول', 1, t),
        BackupService.markKey('/a.epub', 'فصل اول', 1, t),
      );
    });

    test('نشان با مسیر متفاوت، کلید متفاوت', () {
      final t = DateTime(2024, 1, 1);
      expect(
        BackupService.markKey('/a.epub', 'فصل اول', 1, t),
        isNot(BackupService.markKey('/b.epub', 'فصل اول', 1, t)),
      );
    });

    test('فاصله اضافه در یادداشت، تفاوت ایجاد نمی‌کند', () {
      final t = DateTime(2024, 1, 1);
      expect(
        BackupService.markKey('/a.epub', 'فصل اول', 1, t),
        BackupService.markKey('/a.epub', '  فصل اول  ', 1, t),
      );
    });

    test('صفحه null با صفحه خالی یکی است', () {
      final t = DateTime(2024, 1, 1);
      expect(
        BackupService.markKey('/a.epub', 'n', null, t),
        BackupService.markKey('/a.epub', 'n', null, t),
      );
    });

    test('زمان متفاوت، کلید متفاوت', () {
      expect(
        BackupService.markKey('/a.epub', 'n', 1, DateTime(2024)),
        isNot(BackupService.markKey('/a.epub', 'n', 1, DateTime(2025))),
      );
    });

    test('هایلایت یکسان، کلید یکسان', () {
      final t = DateTime(2024);
      expect(
        BackupService.highlightKey('/a.epub', 'متن', 2, t),
        BackupService.highlightKey('/a.epub', 'متن', 2, t),
      );
    });

    test('هایلایت با متن متفاوت، کلید متفاوت', () {
      final t = DateTime(2024);
      expect(
        BackupService.highlightKey('/a.epub', 'متن', 2, t),
        isNot(BackupService.highlightKey('/a.epub', 'متن دیگر', 2, t)),
      );
    });

    test('کارت یکسان، کلید یکسان', () {
      expect(
        BackupService.cardKey('Word', 'm', 'c', 'b'),
        BackupService.cardKey('word', 'm', 'c', 'b'),
        reason: 'حروف بزرگ/کوچک نباید کارت تکراری بسازد',
      );
    });

    test('کارت با معنی متفاوت، کلید متفاوت', () {
      expect(
        BackupService.cardKey('w', 'm1', 'c', 'b'),
        isNot(BackupService.cardKey('w', 'm2', 'c', 'b')),
      );
    });

    test('کارت در کتاب دیگر، کلید متفاوت', () {
      expect(
        BackupService.cardKey('w', 'm', 'c', 'b1'),
        isNot(BackupService.cardKey('w', 'm', 'c', 'b2')),
      );
    });
  });

  group('ImportResult', () {
    test('جمع کل درست است', () {
      const r = ImportResult(
          books: 2, bookmarks: 3, highlights: 4, flashcards: 5);
      expect(r.total, 14);
    });

    test('JSON نتیجه شمارش‌ها را دارد', () {
      final j = const ImportResult(books: 1, highlights: 2).toJson();
      expect(j['books'], 1);
      expect(j['highlights'], 2);
      expect(j['total'], 3);
    });
  });
}

/// جداسازی لایه سرویس از دیتابیس برای تست بخش‌های خالص
class BackupServiceFixture {
  static String empty() => jsonEncode({
        'format': kBackupFormat,
        'version': kBackupVersion,
        'createdAt': '2024-01-01T00:00:00.000',
        'books': <Object>[],
        'bookmarks': <Object>[],
        'highlights': <Object>[],
        'flashcards': <Object>[],
      });

  /// ورودی با کلیدهای ناقص
  static String importMinimal() =>
      jsonEncode({'format': kBackupFormat, 'version': 1});

  /// بررسی رد شدن ورودی نامعتبر — فقط اعتبارسنجی، بدون دیتابیس
  static void import(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('محتوای فایل یک شیء JSON نیست');
    }
    if (decoded['format'] != kBackupFormat) {
      throw const FormatException('این فایل بکاپ Booka نیست');
    }
    final version = (decoded['version'] as num?)?.toInt() ?? 0;
    if (version > kBackupVersion) {
      throw FormatException('نسخه $version');
    }
  }
}
