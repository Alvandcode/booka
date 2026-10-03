import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// مستندسازی یک تله واقعی در pdfrx که کل ریدر PDF را خراب کرده بود.
///
/// سازنده PdfTextSearcher همگام (synchronous) به رویدادهای سند وصل
/// می‌شود و داخلش `controller!.document` را صدا می‌زند؛ پس اگر کنترلر
/// هنوز به viewer وصل نشده باشد (یعنی isReady غلط باشد) با خطای
/// «Null check operator used on a null value» می‌ترکد.
///
/// به همین دلیل در PdfReaderScreen جستجوگر فقط داخل onViewerReady
/// ساخته می‌شود، نه در لحظه لود سند. اگر این رفتار pdfrx روزی درست
/// شود و تست زیر قرمز شود، آن قید را می‌شود ساده کرد.
void main() {
  test('ساخت جستجوگر پیش از آماده‌شدن viewer خطای null می‌دهد', () {
    final controller = PdfViewerController();
    expect(controller.isReady, isFalse);
    expect(
      () => PdfTextSearcher(controller),
      throwsA(isA<TypeError>()),
    );
  });
}
