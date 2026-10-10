import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

import 'ocr_text.dart';

/// موتور OCR — تنها نقطه تماس با پلاگین Tesseract.
///
/// برای تست، تابع موتور و پوشه موقت تزریق می‌شوند تا بدون دستگاه
/// واقعی هم منطق کش و نرمال‌سازی آزموده شود.
typedef OcrEngineFn = Future<String> Function(String imagePath);

class OcrService {
  OcrService({OcrEngineFn? engineFn, Future<Directory> Function()? tempDirFn})
      : _engineFn = engineFn ?? _defaultEngine,
        _tempDirFn = tempDirFn ?? getTemporaryDirectory;

  final OcrEngineFn _engineFn;
  final Future<Directory> Function() _tempDirFn;

  static Future<String> _defaultEngine(String imagePath) =>
      // نکته: در این نسخه پلاگین، `options` (مثل PSM) به native
      // فرستاده نمی‌شود؛ پس عمداً چیزی جز زبان تنظیم نمی‌کنیم تا
      // کانفیگ مرده نداشته باشیم. پیش‌فرض native همان PSM 3 است که
      // برای صفحه کامل سند درست است.
      TesseractOcr.extractText(
        imagePath,
        config: const OCRConfig(
          language: OcrTextTools.languageTag,
          // موتور پیش‌فرض در iOS ویژن اپل است که فارسی را درست
          // نمی‌خواند؛ پس صریحاً Tesseract می‌خواهیم.
          engine: OCREngine.tesseract,
        ),
      );

  /// خواندن متن کش‌شده یک صفحه؛ null یعنی کش وجود ندارد یا خراب است.
  Future<String?> readCache({
    required String bookKey,
    required int pageNumber,
    required Directory cacheDir,
  }) async {
    final cacheFile = File(
        p.join(cacheDir.path, OcrTextTools.cacheFileName(bookKey, pageNumber)));
    try {
      if (!await cacheFile.exists()) return null;
      return OcrTextTools.normalize(await cacheFile.readAsString());
    } catch (_) {
      return null;
    }
  }

  /// متن OCR یک صفحه (شماره یک‌based).
  ///
  /// اول کش فایلی چک می‌شود؛ اگر نبود صفحه رندر، به PNG تبدیل و به
  /// موتور داده می‌شود. نتیجه تمیز ذخیره و برگردانده می‌شود؛ رشته
  /// خالی یعنی چیزی خوانده نشد.
  Future<String> recognizePage({
    required PdfDocument doc,
    required int pageNumber,
    required String bookKey,
    required Directory cacheDir,
    bool force = false,
  }) async {
    if (!force) {
      final cached =
          await readCache(bookKey: bookKey, pageNumber: pageNumber, cacheDir: cacheDir);
      if (cached != null) return cached;
    }

    final page = doc.pages[pageNumber - 1];
    final size = OcrTextTools.renderSize(page.width, page.height);
    final rendered =
        await page.render(width: size.width, height: size.height);
    if (rendered == null) return '';

    // پیکسل‌های pdfium به ترتیب BGRA هستند.
    final png = img.encodePng(img.Image.fromBytes(
      width: rendered.width,
      height: rendered.height,
      bytes: rendered.pixels.buffer,
      numChannels: 4,
      order: img.ChannelOrder.bgra,
    ));

    final tmpDir = await _tempDirFn();
    final tmp = File(p.join(tmpDir.path,
        'booka_ocr_${DateTime.now().microsecondsSinceEpoch}.png'));
    await tmp.writeAsBytes(png);
    final cacheFile = File(
        p.join(cacheDir.path, OcrTextTools.cacheFileName(bookKey, pageNumber)));
    try {
      final text = OcrTextTools.normalize(await _engineFn(tmp.path));
      if (OcrTextTools.hasUsableText(text)) {
        try {
          await cacheFile.writeAsString(text);
        } catch (_) {
          // ننوشتن کش نباید کل کار را خراب کند
        }
      }
      return text;
    } finally {
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }
}
