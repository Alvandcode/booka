import 'package:book_reader_app/reader/epub_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inline کردن تصاویر', () {
    final png = [0x89, 0x50, 0x4E, 0x47];

    test('src نسبی داخل کتاب به data URI تبدیل می‌شود', () {
      final out = EpubHtml.inlineImages(
        '<p><img src="images/fig1.png" /></p>',
        {'images/fig1.png': png},
      );
      expect(out, contains('data:image/png;base64,'));
      expect(out, isNot(contains('images/fig1.png')));
    });

    test('پسوند jpeg نوع درست می‌گیرد', () {
      final out = EpubHtml.inlineImages(
        '<img src="a.jpg">',
        {'a.jpg': png},
      );
      expect(out, contains('data:image/jpeg;base64,'));
    });

    test('پسوند ناشناخته به jpeg برمی‌گردد', () {
      final out = EpubHtml.inlineImages(
        '<img src="a.xyz">',
        {'a.xyz': png},
      );
      expect(out, contains('data:image/jpeg;base64,'));
    });

    test('هر سه نحو نوشتن src پشتیبانی می‌شود', () {
      final imgs = {'f.png': png};
      for (final html in [
        '<img src="f.png">',
        "<img src='f.png'>",
        '<img src=f.png>',
      ]) {
        expect(EpubHtml.inlineImages(html, imgs), contains('data:image/png'),
            reason: 'failed for: $html');
      }
    });

    test('نام فایل تنها هم پیدا می‌شود', () {
      // کتاب href را با مسیر کامل می‌دهد ولی HTML فقط نام را
      final out = EpubHtml.inlineImages(
        '<img src="fig1.png">',
        {'OEBPS/images/fig1.png': png},
      );
      expect(out, contains('data:image/png;base64,'));
    });

    test('مسیر درصدی رمزگذاری‌شده نگاشت می‌شود', () {
      // کتاب مسیر را درصدی رمزگذاری می‌کند، نگاشت باید رمزگشایی کند
      final out = EpubHtml.inlineImages(
        '<img src="%D9%81%D8%B5.png">',
        {'OEBPS/%D9%81%D8%B5.png': png},
      );
      expect(out, contains('data:image/png;base64,'));
    });

    test('کلید نگاشت خام با src رمزگذاری‌شده هم تطابق دارد', () {
      // نگاشت با نام فارسی است، src درصدی
      final out = EpubHtml.inlineImages(
        '<img src="%D9%81%D8%B5.png">',
        {'OEBPS/فص.png': png},
      );
      expect(out, contains('data:image/png;base64,'));
    });

    test('تصویر ناموجود دست‌نخورده می‌ماند', () {
      const html = '<img src="missing.png">';
      expect(EpubHtml.inlineImages(html, {'other.png': png}), html);
    });

    test('تصویر خالی inline نمی‌شود', () {
      const html = '<img src="a.png">';
      expect(EpubHtml.inlineImages(html, {'a.png': <int>[]}), html);
    });

    test('منابع بیرونی دست‌نخورده می‌مانند', () {
      for (final url in [
        'https://example.com/a.png',
        'http://example.com/a.png',
        '//example.com/a.png',
      ]) {
        final html = '<img src="$url">';
        expect(EpubHtml.inlineImages(html, {'a.png': png}), html,
            reason: 'touched: $url');
      }
    });

    test('data URI از پیش موجود دوباره inline نمی‌شود', () {
      const html = '<img src="data:image/png;base64,AAAA">';
      expect(EpubHtml.inlineImages(html, {'data:image/png;base64,AAAA': png}),
          html);
    });

    test('تصویر بیش از حد بزرگ inline نمی‌شود', () {
      final big = List<int>.filled(EpubHtml.maxInlineImageBytes + 1, 0);
      const html = '<img src="a.png">';
      expect(EpubHtml.inlineImages(html, {'a.png': big}), html);
    });

    test('بدون نقشه تصویر، HTML تغییر نمی‌کند', () {
      const html = '<img src="a.png">';
      expect(EpubHtml.inlineImages(html, const {}), html);
    });

    test('چند تصویر در یک بخش همه تبدیل می‌شوند', () {
      final out = EpubHtml.inlineImages(
        '<img src="a.png"><p>متن</p><img src="b.gif">',
        {'a.png': png, 'b.gif': [1, 2, 3]},
      );
      expect('data:image/png'.allMatches(out).length, 1);
      expect('data:image/gif'.allMatches(out).length, 1);
      expect(out, contains('متن'));
    });

    test('چند تصویر یکسان فقط یک بار inline می‌شود', () {
      final out = EpubHtml.inlineImages(
        '<img src="a.png"><img src="a.png">',
        {'a.png': png},
      );
      expect('data:image/png'.allMatches(out).length, 2);
    });

    test('تگ بدون src دست‌نخورده می‌ماند', () {
      const html = '<img alt="بدون مسیر">';
      expect(EpubHtml.inlineImages(html, {'a.png': png}), html);
    });  });

  group('تزریق CSS', () {
    test('CSS داخل head موجود تزریق می‌شود', () {
      final out = EpubHtml.renderable(
        '<html><head><title>x</title></head><body>متن</body></html>',
        css: 'p{color:red}',
      );
      expect(out, contains('<style type="text/css">p{color:red}</style>'));
      expect(out.indexOf('<style'), lessThan(out.indexOf('</head>')));
    });

    test('سند بدون head، head ساخته می‌شود', () {
      final out = EpubHtml.renderable('<body>متن</body>', css: 'p{margin:0}');
      expect(out, contains('<head><style>p{margin:0}</style></head>'));
      expect(out, contains('<body>متن</body>'));
    });

    test('سند بدون head و body، style اول می‌آید', () {
      final out = EpubHtml.renderable('<p>متن</p>', css: 'p{margin:0}');
      expect(out, startsWith('<style>p{margin:0}</style>'));
    });

    test('CSS خالی چیزی تزریق نمی‌کند', () {
      const html = '<body>متن</body>';
      expect(EpubHtml.renderable(html, css: '   '), html);
    });

    test('CSS تعریف‌نشده چیزی تزریق نمی‌کند', () {
      const html = '<body>متن</body>';
      expect(EpubHtml.renderable(html), html);
    });
  });

  group('renderable', () {
    test('هم تصویر و هم CSS اعمال می‌شود', () {
      final out = EpubHtml.renderable(
        '<html><head></head><body><img src="a.png"></body></html>',
        images: {'a.png': [1, 2, 3]},
        css: 'body{margin:0}',
      );
      expect(out, contains('data:image/png;base64,'));
      expect(out, contains('body{margin:0}'));
    });

    test('HTML خالی، خالی برمی‌گردد', () {
      expect(EpubHtml.renderable(''), '');
    });
  });

  group('استخراج متن خالص', () {
    test('تگ‌ها حذف می‌شوند', () {
      expect(EpubHtml.plainText('<p>سلام</p>'), 'سلام');
    });

    test('entity رمزگشایی می‌شود', () {
      expect(EpubHtml.plainText('<p>a&nbsp;b</p>'), contains('a'));
    });

    test('ورودی خالی، خالی برمی‌گردد', () {
      expect(EpubHtml.plainText(''), '');
    });
  });
}
