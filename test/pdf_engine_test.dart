@TestOn('vm')
library;

import 'dart:io';

import 'package:book_reader_app/reader/pdf_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// تست موتور PDF روی فایل واقعی.
///
/// واحدهای بیلد و تست‌های معمولی فقط ثابت می‌کنند کد کامپایل می‌شود.
/// این تنها جایی است که pdfium واقعاً روی یک فایل باز و اجرا می‌شود؛
/// همان چیزی که با کامپایل‌شدن هیچ‌گاه معلوم نمی‌شود.
///
/// نیازمند مسیر فایل است، پس فقط با این متغیر محیطی اجرا می‌شود:
///
///   set BOOKA_PDF_PROBE=C:\path\to\book.pdf
///   flutter test test/pdf_engine_test.dart
///
/// چند فایل را می‌شود با «;» جدا کرد. هر فایل جداگانه بررسی می‌شود تا
/// هم PDF دیجیتال و هم PDF اسکن‌شده را بتوان هم‌زمان آزمود.
void main() {
  final raw = Platform.environment['BOOKA_PDF_PROBE'];
  final files = (raw ?? '')
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // pdfrx برای پوشه cache از path_provider می‌پرسد که در محیط تست
    // ثبت نشده؛ بدون این، تست با MissingPluginException می‌میرد.
    final temp = Directory.systemTemp.createTempSync('booka_pdf_cache');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => temp.path);
  });

  test('موتور pdfium فایل واقعی را باز می‌کند و متن را درست می‌خواند',
      () async {
    if (files.isEmpty) {
      markTestSkipped('BOOKA_PDF_PROBE تنظیم نشده — برای تست موتور '
          'مسیر یک PDF واقعی بده');
      return;
    }

    for (final path in files) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'فایل پیدا نشد: $path');

      final doc = await PdfDocumentRefFile(path).loadDocument((_, [__]) {});
      addTearDown(doc.dispose);

      expect(doc.pages.length, greaterThan(0), reason: '$path: سند بی‌صفحه است');

      // فهرست مطالب نباید خطا بدهد؛ خالی بودنش اشکالی ندارد.
      final outline = await doc.loadOutline();
      expect(outline, isA<List<PdfOutlineNode>>());

      final texts = <int, String>{};
      var withText = 0;
      for (final p in doc.pages) {
        final t = (await p.loadText())?.fullText ?? '';
        texts[p.pageNumber] = t;
        if (PdfTextTools.hasTextLayer(t)) withText++;
      }

      if (withText == 0) {
        // PDF اسکن‌شده: باید تشخیص داده شود، و جستجو نباید چیزی بترکاند.
        expect(PdfTextTools.isScannedDocument(withText, doc.pages.length),
            isTrue,
            reason: '$path: PDF بدون لایه متنی باید اسکن‌شده تشخیص داده شود');
        continue;
      }

      // PDF دیجیتال: نه اسکن‌شده، و متن واقعاً قابل جستجوست.
      expect(PdfTextTools.isScannedDocument(withText, doc.pages.length),
          isFalse,
          reason: '$path: دارد لایه متنی، پس نباید اسکن‌شده تلقی شود');

      // یک واژه واقعاً موجود در متن را بردار و جستجو کن؛ این همان مسیری
      // است که جستجوی داخل کتاب طی می‌کند.
      final page1 = texts[1] ?? '';
      final word = _longestWord(page1);
      expect(word.length, greaterThanOrEqualTo(3),
          reason: '$path: متن صفحه اول واژه قابل جستجو ندارد');

      final hits = PdfTextTools.searchPage(
          pageText: page1, pageNumber: 1, query: word);
      expect(hits, isNotEmpty,
          reason: '$path: واژه "$word" در متن هست ولی جستجو پیدایش نکرد');

      // نتیجه نباید چندخطی باشد وگرنه فهرست نتایج خراب می‌شود.
      for (final h in hits) {
        expect(h.snippet, isNot(contains('\n')),
            reason: '$path: snippet نباید شکست خط داشته باشد');
      }
    }
  });
}

/// طولانی‌ترین واژه متن، برای اینکه تست به محتوای فایل وابسته نباشد
String _longestWord(String text) {
  var best = '';
  for (final w in text.split(RegExp(r'\s+'))) {
    final clean = w.replaceAll(RegExp(r'[^A-Za-zء-ي]'), '');
    if (clean.length > best.length) best = clean;
  }
  return best;
}