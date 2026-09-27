import 'dart:io';

import 'package:book_reader_app/reader/epub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ریدر EPUB فقط با فایل روی دیسک کار می‌کند (dart:io)، پس تست روی
/// فایل واقعی از پوشه موقت اجرا می‌شود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('booka_epub_test');
  });

  tearDownAll(() async {
    // پایگاه داده ممکن است هنوز فایل را باز نگه داشته باشد؛
    // پاک کردن پوشه موقت نباید تست را شکست بدهد
    try {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// انتظار تا وقتی ریدر از حالت بارگذاری خارج شود.
  ///
  /// `pump` به‌تنهایی فقط microtaskها را خالی می‌کند و I/O واقعیِ فایل
  /// هرگز resolve نمی‌شود؛ `runAsync` به event loop دسترسی می‌دهد.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump();
    }
  }

  testWidgets('ریدر با EPUB خراب، خطا نشان می‌دهد و کرش نمی‌کند',
      (tester) async {
    final bad = File('${tmp.path}/bad.epub')
      ..writeAsBytesSync(List<int>.filled(512, 0x41));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EpubReaderScreen(path: bad.path, title: 'خراب'),
        ),
      ),
    );
    await settle(tester);

    expect(find.textContaining('خطا'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ریدر با مسیر ناموجود، خطا نشان می‌دهد', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: EpubReaderScreen(path: '${tmp.path}/nope.epub', title: 'نیست'),
        ),
      ),
    );
    await settle(tester);

    expect(find.textContaining('خطا'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
