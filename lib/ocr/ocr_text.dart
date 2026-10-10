/// ابزارهای خالص OCR — بدون Flutter، بدون پلاگین، قابل تست واحد.
///
/// موتور واقعی (Tesseract) در [OcrService] صدا زده می‌شود؛ هر چیزی که
/// بدون آن قابل تصمیم‌گیری است اینجاست: تگ زبان، اندازه رندر، نام فایل
/// کش و نرمال‌سازی متن.
class OcrTextTools {
  const OcrTextTools._();

  /// تگ زبان Tesseract: فارسی اول، انگلیسی برای سندهای مخلوط.
  ///
  /// هر دو مدل از مخزن `tessdata_fast` هستند تا حجم کم بماند
  /// (مجموعاً حدود ۴ مگابایت).
  static const languageTag = 'fas+eng';

  /// ضلع بزرگ تصویر رندرشده برای OCR، به پیکسل.
  ///
  /// تجربه پروژه‌های OCR فارسی نشان می‌دهد تصویر خیلی کوچک دقت را
  /// خراب می‌کند و تصویر خیلی بزرگ فقط باتری و زمان می‌خورد؛ ۲۰۰۰
  /// تعادل خوبی برای سند است.
  static const renderLongestEdge = 2000;

  /// ابعاد رندر با حفظ نسبت تصویر؛ ضلع بزرگ برابر [renderLongestEdge].
  ///
  /// [pageWidth] و [pageHeight] همان `PdfPage.width/height` هستند
  /// (واحد: پوینت PDF).
  static ({int width, int height}) renderSize(
      double pageWidth, double pageHeight) {
    final longest = pageWidth > pageHeight ? pageWidth : pageHeight;
    if (longest <= 0) return (width: 1, height: 1);
    final scale = renderLongestEdge / longest;
    final w = (pageWidth * scale).round();
    final h = (pageHeight * scale).round();
    return (
      width: w < 1 ? 1 : w,
      height: h < 1 ? 1 : h,
    );
  }

  /// کلید امن برای نام فایل کش از روی مسیر کتاب.
  ///
  /// فقط نام فایل (بدون پوشه و پسوند) نگه داشته می‌شود و اندازه فایل
  /// هم به آن می‌چسبد تا دو کتاب هم‌نام در پوشه‌های مختلف قاطی نشوند.
  static String cacheKeyFor({required String path, required int fileSize}) {
    final fileName = path.replaceAll(RegExp(r'^.*[/\\]'), '');
    final base = fileName.replaceAll(RegExp(r'\.[^.]*$'), '');
    final safe = base.replaceAll(RegExp('[^A-Za-z0-9\u0600-\u06FF]+'), '_');
    final short =
        safe.isEmpty ? 'book' : (safe.length > 40 ? safe.substring(0, 40) : safe);
    return '${short}_$fileSize';
  }

  /// نام فایل کش متن یک صفحه.
  static String cacheFileName(String bookKey, int pageNumber) =>
      'ocr_${bookKey}_p$pageNumber.txt';

  /// نرمال‌سازی خروجی خام OCR برای جستجو و نمایش.
  static String normalize(String? raw) {
    if (raw == null) return '';
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .trim();
  }

  /// آیا نتیجه OCR ارزش نگه‌داشتن و نشان‌دادن دارد؟
  ///
  /// خروجی‌های یکی‌دو کاراکتری معمولاً نویز تشخیص‌اند، نه متن.
  static bool hasUsableText(String? raw) {
    if (raw == null) return false;
    return normalize(raw).replaceAll(RegExp(r'\s+'), '').length >=
        kMinMeaningfulChars;
  }

  static const kMinMeaningfulChars = 12;
}
