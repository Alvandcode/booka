import 'package:book_reader_app/reader/epub_document.dart';
import 'package:book_reader_app/reader/epub_text.dart';
import 'package:epub_plus/epub_plus.dart';
import 'package:flutter_test/flutter_test.dart';

/// یک ورودی فهرست مطالب
EpubChapter tocChapter(
  String title,
  String href, {
  String? anchor,
  List<EpubChapter>? children,
}) =>
    EpubChapter(
      title: title,
      contentFileName: href,
      anchor: anchor,
      subChapters: children ?? const <EpubChapter>[],
    );

/// ساخت یک EpubBook با ترتیب manifest عمداً الفبایی و ترتیب spine متفاوت،
/// تا اگر کد به ترتیب manifest تکیه کند تست لو برود.
EpubBook buildBook({
  List<String>? spineOrder,
  Map<String, String>? htmlByHref,
  List<EpubChapter>? chapters,
  bool withSpine = true,
}) {
  final hrefs = htmlByHref ??
      {
        'a.xhtml': '<p>متن الف</p>',
        'b.xhtml': '<p>متن ب</p>',
        'c.xhtml': '<p>متن ج</p>',
      };

  final manifestItems = <EpubManifestItem>[];
  final html = <String, EpubTextContentFile>{};

  // manifest به ترتیب الفبایی: a, b, c
  for (final href in hrefs.keys.toList()..sort()) {
    final id = 'id-${href.split('.').first}';
    manifestItems.add(EpubManifestItem(
      id: id,
      href: href,
      mediaType: 'application/xhtml+xml',
    ));
    html[href] = EpubTextContentFile(
        content: htmlByHref?[href] ?? '<p>x</p>');
  }

  final spine = EpubSpine(
    items: withSpine
        ? (spineOrder ?? ['id-c', 'id-a', 'id-b'])
            .map((id) => EpubSpineItemRef(idRef: id, isLinear: true))
            .toList()
        : const <EpubSpineItemRef>[],
    ltr: true,
  );

  final book = EpubBook(
    title: 'کتاب آزمایشی',
    author: 'نویسنده',
    content: EpubContent(html: html),
    schema: EpubSchema(
      package: EpubPackage(
        manifest: EpubManifest(items: manifestItems),
        spine: spine,
      ),
    ),
    chapters: chapters ??
        [tocChapter('فصل ج', 'c.xhtml'), tocChapter('فصل الف', 'a.xhtml')],
  );

  return book;
}

void main() {
  group('ترتیب خواندن از spine', () {
    test('فصل‌ها به ترتیب spine چیده می‌شوند، نه ترتیب manifest', () {
      final doc = EpubDocument.fromBook(buildBook());
      // spine = c, a, b است در حالی که manifest = a, b, c
      expect(doc.sections.map((s) => s.href).toList(),
          ['c.xhtml', 'a.xhtml', 'b.xhtml']);
      expect(doc.sections[0].index, 0);
      expect(doc.sections[2].index, 2);
    });

    test('وقتی spine خالی است، به ترتیب manifest برمی‌گرد', () {
      final doc = EpubDocument.fromBook(buildBook(withSpine: false));
      expect(doc.sections.map((s) => s.href).toList(),
          ['a.xhtml', 'b.xhtml', 'c.xhtml']);
    });

    test('href بدون decode درست نگاشت می‌شود', () {
      final doc = EpubDocument.fromBook(buildBook(
        spineOrder: ['id-one'],
        htmlByHref: {
          'فصل ۱.xhtml': '<p>سلام</p>',
        },
      ));
      expect(doc.length, 1);
      expect(doc.sections.first.html, contains('سلام'));
    });

    test('id ناشناخته در spine، کتاب را خراب نمی‌کند', () {
      final doc = EpubDocument.fromBook(buildBook(
        spineOrder: ['id-nope', 'id-a'],
      ));
      expect(doc.length, 1);
      expect(doc.sections.first.href, 'a.xhtml');
    });

    test('کتاب بدون محتوای HTML، خالی برمی‌گردد نه کرش', () {
      final book = EpubBook(title: 'خالی');
      final doc = EpubDocument.fromBook(book);
      expect(doc.isEmpty, isTrue);
      expect(doc.length, 0);
      expect(doc.toc, isEmpty);
    });
  });

  group('فهرست مطالب', () {
    test('ورودی‌ها به بخش درست نگاشت می‌شوند', () {
      final doc = EpubDocument.fromBook(buildBook());
      // «فصل الف» به a.xhtml اشاره دارد که در spine شماره ۱ است
      final alf = doc.toc.firstWhere((e) => e.title == 'فصل الف');
      expect(alf.sectionIndex, 1);
      expect(doc.sections[alf.sectionIndex!].href, 'a.xhtml');
    });

    test('سلسله‌مراتبی تخت می‌شود و عمق حفظ می‌شود', () {
      final doc = EpubDocument.fromBook(buildBook(
        spineOrder: ['id-a'],
        htmlByHref: {'a.xhtml': '<p>متن</p>'},
        chapters: [
          tocChapter('بخش یک', 'a.xhtml', children: [
            tocChapter('زیربخش', 'a.xhtml', anchor: 's2', children: [
              tocChapter('زیرزیربخش', 'a.xhtml', anchor: 's3'),
            ]),
          ]),
        ],
      ));
      expect(doc.toc.map((e) => e.title), ['بخش یک', 'زیربخش', 'زیرزیربخش']);
      expect(doc.toc.map((e) => e.depth), [0, 1, 2]);
    });

    test('لنگر داخل فایل حفظ می‌شود', () {
      final doc = EpubDocument.fromBook(buildBook(
        spineOrder: ['id-a'],
        htmlByHref: {'a.xhtml': '<p>متن</p>'},
        chapters: [tocChapter('با لنگر', 'a.xhtml', anchor: 'بخش۲')],
      ));
      expect(doc.toc.single.anchor, 'بخش۲');
      expect(doc.toc.single.sectionIndex, 0);
    });

    test('فهرست خالی → ورودی کلی ساخته می‌شود تا ناوبری ممکن باشد', () {
      final doc = EpubDocument.fromBook(buildBook(chapters: []));
      expect(doc.toc, isNotEmpty);
      expect(doc.toc.every((e) => e.isJumpable), isTrue);
      expect(doc.toc.length, doc.length);
    });

    test('ورودی بدون عنوان، عنوان جایگزین می‌گیرد', () {
      final doc = EpubDocument.fromBook(buildBook(
        spineOrder: ['id-a'],
        htmlByHref: {'a.xhtml': '<p>متن</p>'},
        chapters: [tocChapter('  \n ', 'a.xhtml')],
      ));
      expect(doc.toc.single.title, 'بدون عنوان');
    });

    test('ورودی به فایل ناموجود، غیرقابل‌پرش علامت می‌خورد', () {
      final doc = EpubDocument.fromBook(buildBook(
        spineOrder: ['id-a'],
        htmlByHref: {'a.xhtml': '<p>متن</p>'},
        chapters: [tocChapter('گم‌شده', 'missing.xhtml')],
      ));
      expect(doc.toc.single.sectionIndex, isNull);
      expect(doc.toc.single.isJumpable, isFalse);
    });
  });

  group('برچسب بخش', () {
    test('عنوان فهرست مطالب روی بخش می‌نشیند', () {
      final doc = EpubDocument.fromBook(buildBook());
      expect(doc.sectionLabel(0), 'فصل ج');
    });

    test('بخش بدون عنوان، شماره نشان می‌دهد', () {
      final doc = EpubDocument.fromBook(buildBook(chapters: []));
      expect(doc.sectionLabel(0), 'بخش ۱'.replaceFirst('۱', '1'));
    });

    test('اندیس بیرون از محدوده، برچسب خنثی می‌دهد', () {
      final doc = EpubDocument.fromBook(buildBook());
      expect(doc.sectionLabel(99), '—');
      expect(doc.sectionAt(-1), isNull);
    });
  });

  group('استخراج متن', () {
    test('entity ها درست رمزگشایی می‌شوند', () {
      expect(EpubText.strip('<p>سلام&nbsp;دنیا</p>'), 'سلام دنیا');
      expect(EpubText.strip('<p>a &amp; b</p>'), 'a & b');
      expect(EpubText.strip('<p>&lt;tag&gt;</p>'), '<tag>');
    });

    test('محتوای script و style متن حساب نمی‌شود', () {
      const html = '<style>p{color:red}</style><p>متن</p>'
          '<script>alert("x")</script>';
      final out = EpubText.strip(html);
      expect(out, 'متن');
      expect(out, isNot(contains('color:red')));
      expect(out, isNot(contains('alert')));
    });

    test('پاراگراف‌ها با خط خالی از هم جدا می‌شوند', () {
      expect(EpubText.strip('<p>اول</p><p>دوم</p>'), 'اول\n\nدوم');
    });

    test('br به خط جدید تبدیل می‌شود', () {
      expect(EpubText.strip('<p>الف<br/>ب</p>'), 'الف\nب');
      expect(EpubText.strip('<p>الف<br>ب</p>'), 'الف\nب');
    });

    test('فاصله‌های اضافه فشرده می‌شوند', () {
      expect(EpubText.strip('<p>الف     ب</p>'), 'الف ب');
    });

    test('ورودی خالی، خروجی خالی', () {
      expect(EpubText.strip(''), '');
    });

    test('HTML خراب هم متن تولید می‌کند', () {
      expect(EpubText.strip('<p>نیمه‌باز'), isNotEmpty);
    });

    test('فارسی و راست‌به‌چپ حفظ می‌شود', () {
      expect(EpubText.strip('<p>کتابخانه آفلاین</p>'), 'کتابخانه آفلاین');
    });
  });

  group('نرمال‌سازی جستجو', () {
    test('حروف بزرگ کوچک می‌شود', () {
      expect(EpubText.normalize('Hello World'), 'hello world');
    });

    test('نیم‌فاصله به فاصله تبدیل می‌شود', () {
      expect(EpubText.normalize('می‌رود'), 'می رود');
    });
  });

  group('جستجوی درون کتاب', () {
    final texts = ['اولین فصل درباره گل بود', 'فصل دوم درباره درخت بود'];
    final labels = ['فصل یک', 'فصل دو'];

    test('همه نتایج پیدا می‌شوند', () {
      final hits = EpubSearch.run(
        texts: texts,
        sectionLabels: labels,
        query: 'فصل',
      );
      expect(hits.length, 2);
      expect(hits.map((h) => h.sectionIndex).toList(), [0, 1]);
    });

    test('جستجوی بی‌تفاوت به بزرگی حروف', () {
      final hits = EpubSearch.run(
        texts: ['The Quick Brown Fox'],
        sectionLabels: ['x'],
        query: 'quick',
      );
      expect(hits.length, 1);
    });

    test('چند نتیجه در یک بخش', () {
      final hits = EpubSearch.run(
        texts: ['گل و درخت و گل دیگر'],
        sectionLabels: ['x'],
        query: 'گل',
      );
      expect(hits.length, 2);
    });

    test('کلمه تکراری جلوی حلقه بی‌نهایت را می‌گیرد', () {
      final hits = EpubSearch.run(
        texts: ['گل' * 3000],
        sectionLabels: ['x'],
        query: 'گل',
        maxResults: 10,
      );
      expect(hits.length, 10);
    });

    test('عبارت کوتاه‌تر از دو حرف جستجو نمی‌شود', () {
      expect(
        EpubSearch.run(texts: texts, sectionLabels: labels, query: 'ف'),
        isEmpty,
      );
    });

    test('بدون نتیجه، لیست خالی', () {
      expect(
        EpubSearch.run(texts: texts, sectionLabels: labels, query: 'زرافه'),
        isEmpty,
      );
    });

    test('snippet متن پیرامون نتیجه را نشان می‌دهد', () {
      final long = 'شروع ${'کلمه ' * 40} پایان';
      final hits = EpubSearch.run(
        texts: [long],
        sectionLabels: ['x'],
        query: 'پایان',
      );
      expect(hits.single.snippet, contains('پایان'));
      expect(hits.single.snippet, isNot(contains('شروع')));
    });

    test('نتایج بیشتر از سقف، بریده می‌شوند', () {
      final hits = EpubSearch.run(
        texts: List.filled(20, 'گل گل گل'),
        sectionLabels: List.filled(20, 'x'),
        query: 'گل',
        maxResults: 5,
      );
      expect(hits.length, 5);
    });
  });
}
