import 'dart:io';

import 'package:book_reader_app/ocr/ocr_service.dart';
import 'package:book_reader_app/ocr/ocr_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('تگ زبان و اندازه رندر', () {
    test('فارسی اول، انگلیسی دوم', () {
      expect(OcrTextTools.languageTag, 'fas+eng');
    });

    test('ضلع بزرگ همیشه ۲۰۰۰ می‌شود', () {
      // صفحه عمودی A4-ish
      expect(
        OcrTextTools.renderSize(595, 842),
        (width: 1413, height: 2000),
      );
      // صفحه افقی
      expect(
        OcrTextTools.renderSize(842, 595),
        (width: 2000, height: 1413),
      );
      // مربع
      expect(
        OcrTextTools.renderSize(500, 500),
        (width: 2000, height: 2000),
      );
    });

    test('ابعاد نامعتبر به حداقل می‌رسد، نه صفر یا منفی', () {
      expect(OcrTextTools.renderSize(0, 0), (width: 1, height: 1));
      // عرض منفی کلمپ می‌شود ولی نسبت تصویر حفظ می‌ماند
      expect(OcrTextTools.renderSize(-5, 100), (width: 1, height: 2000));
    });
  });

  group('کلید کش', () {
    test('فقط نام فایل بدون پوشه و پسوند', () {
      final k = OcrTextTools.cacheKeyFor(
          path: r'C:\books\my book.pdf', fileSize: 12345);
      expect(k, 'my_book_12345');
    });

    test('مسیر یونیکسی هم کار می‌کند', () {
      final k = OcrTextTools.cacheKeyFor(
          path: '/sdcard/کتاب من.epub', fileSize: 99);
      expect(k, 'کتاب_من_99');
    });

    test('اندازه فایل، کتاب‌های هم‌نام را جدا می‌کند', () {
      final a =
          OcrTextTools.cacheKeyFor(path: '/a/x.pdf', fileSize: 1);
      final b =
          OcrTextTools.cacheKeyFor(path: '/b/x.pdf', fileSize: 2);
      expect(a, isNot(b));
    });

    test('نام فایل کش الگوی ثابت دارد', () {
      expect(OcrTextTools.cacheFileName('k_1', 7), 'ocr_k_1_p7.txt');
    });
  });

  group('نرمال‌سازی و تشخیص متن مفید', () {
    test('فاصله‌ها فشرده و trim می‌شود', () {
      expect(OcrTextTools.normalize('  سلام   دنیا\n\n'), 'سلام دنیا');
    });

    test('null ورودی خالی می‌دهد', () {
      expect(OcrTextTools.normalize(null), '');
      expect(OcrTextTools.hasUsableText(null), isFalse);
    });

    test('نویز یکی‌دو کاراکتری متن حساب نمی‌شود', () {
      expect(OcrTextTools.hasUsableText('ab'), isFalse);
      expect(OcrTextTools.hasUsableText('   \n '), isFalse);
    });

    test('مرز دوازده کاراکتر', () {
      expect(OcrTextTools.hasUsableText('a' * 11), isFalse);
      expect(OcrTextTools.hasUsableText('a' * 12), isTrue);
    });
  });

  group('خواندن کش فایلی', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('booka_ocr_test');
    });
    tearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('کش موجود، نرمال‌شده برمی‌گردد', () async {
      final svc = OcrService(engineFn: (_) async => 'SHOULD NOT RUN');
      final f = File('${dir.path}/ocr_k_p3.txt');
      await f.writeAsString('  سلام   دنیا  ');
      expect(
        await svc.readCache(bookKey: 'k', pageNumber: 3, cacheDir: dir),
        'سلام دنیا',
      );
    });

    test('کش ناموجود null می‌دهد', () async {
      final svc = OcrService(engineFn: (_) async => 'SHOULD NOT RUN');
      expect(
        await svc.readCache(bookKey: 'nope', pageNumber: 1, cacheDir: dir),
        isNull,
      );
    });

    test('بایت نامعتبر (کش خراب) null می‌دهد نه خطا', () async {
      final svc = OcrService(engineFn: (_) async => 'SHOULD NOT RUN');
      final f = File('${dir.path}/ocr_k_p1.txt');
      await f.writeAsBytes([0xFF, 0xFE, 0x00]);
      expect(
        await svc.readCache(bookKey: 'k', pageNumber: 1, cacheDir: dir),
        isNull,
      );
    });
  });
}
