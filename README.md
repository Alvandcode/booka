# Booka

کتابخوان آفلاین PDF و EPUB با تایپوگرافی فارسی، دیکشنری انگلیسی-فارسی
آفلاین و مرور واژگان با فاصله‌گذاری تکرارشونده.

اپ کاملاً آفلاین کار می‌کند: هیچ حساب کاربری، تبلیغات، تحلیلگر یا
دسترسی به اینترنت وجود ندارد. همه داده‌ها روی دستگاه می‌مانند.

## قابلیت‌ها

- کتابخانه PDF و EPUB با کاور و نویسنده واقعی، و ادامه مطالعه از
  آخرین موقعیت
- رندر کامل EPUB: تصویر، جدول، بولد و ایتالیک، فهرست مطالب و جستجوی
  درون‌کتاب
- فهرست مطالب سلسله‌مراتبی و پرش سریع بین بخش‌ها
- نشان، هایلایت رنگی با یادداشت و برچسب، و جستجوی متن کامل در
  هایلایت‌ها
- دیکشنری انگلیسی-فارسی آفلاین با تلفظ و ریشه‌یابی ساده
- مرور واژگان با الگوریتم SM-2
- چهار تم مطالعه (کاغذی، سپیا، خاکستری، AMOLED) با فونت وزیرمتن
- بکاپ و بازیابی، و خروجی Markdown و CSV

## معماری

```
lib/
  main.dart                 صفحات و ناوبری
  app_info.dart             نام و نسخه اپ (منبع واحد)
  export_page.dart          بکاپ، بازیابی و خروجی
  about_page.dart
  privacy_page.dart
  data/
    db.dart                 اسکیمای SQLite و مهاجرت
    dao.dart                 همه کوئری‌ها
    models.dart              مدل‌های داده، بدون codegen
    store.dart               providerهای Riverpod و مهاجرت داده
    backup.dart              قالب بکاپ و اکسپورت
  reader/
    epub_document.dart       ترتیب خواندن، فهرست مطالب، فراداده
    epub_html.dart           آماده‌سازی HTML و تصاویر برای رندر
    epub_text.dart           استخراج متن و جستجوی درون‌کتاب
    epub_screen.dart
    pdf_screen.dart
  dictionary/
  theme/
```

لایه داده روی SQLite است و همه کوئری‌ها در `dao.dart` متمرکزند.
مدل‌ها کلاس‌های ساده Dart هستند و هیچ مرحله codegen ندارند.

## توسعه

```bash
flutter pub get
flutter run
flutter test
flutter analyze
```

اگر `pub get` به خطای دسترسی خورد:

```bash
# ویندوز پاورشل
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
```

## انتشار اندروید

اپ در فروشگاه نیست. خروجی با امضای مستقیم در صفحه Releases همین ریپو
منتشر می‌شود. راهنمای نصب برای کاربران در
[docs/INSTALL.fa.md](docs/INSTALL.fa.md) است.

### کلید امضا

کلید از قبل ساخته شده و **یک بار برای همیشه** استفاده می‌شود. همین
نکته باعث می‌شود نسخه جدید روی نسخه قبلی نصب شود و کاربر مجبور به
حذف و نصب دوباره نشود.

| | |
|---|---|
| محل کلید | `~/.booka/booka-release.jks` (خارج از ریپو) |
| اطلاعات و رمز | `~/.booka/credentials.txt` |
| اعتبار گواهی | تا سال ۲۰۵۴ |
| الگوریتم | RSA 4096 / SHA256withRSA |

> **این کلید را گم نکن.** اگر کلید یا رمزش را از دست بدهی، دیگر
> نمی‌توانی نسخه‌ای منتشر کنی که روی نصب‌های موجود کاربران نصب شود؛
> مجبور می‌شوی `applicationId` را عوض کنی و اپ را از نو منتشر کنی. از
> هر دو فایل پشتیبان بگیر و در جای امن نگه دار.

### انتشار محلی

```bash
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

`android/key.properties` به کلید اشاره می‌کند و در git نیست. اگر نبود،
بیلد با کلید debug انجام می‌شود و هشدار چاپ می‌کند که خروجی قابل
انتشار نیست.

### انتشار خودکار

`.github/workflows/release.yml` با زدن تگ بیلد می‌گیرد، تست می‌کند،
با کلید واقعی امضا می‌کند و در صفحه Releases قرار می‌دهد.

```bash
# در pubspec.yaml نسخه را بالا ببر، مثلاً version: 0.2.0+2
git tag v0.2.0
git push origin v0.2.0
```

برای اینکه CI بتواند امضا کند، یک‌بار این secretها را در
`Settings → Secrets and variables → Actions` اضافه کن:

| نام | مقدار |
|---|---|
| `BOOKA_KEYSTORE_BASE64` | خروجی `base64 -w0 ~/.booka/booka-release.jks` |
| `BOOKA_STORE_PASSWORD` | رمز انبار کلید |
| `BOOKA_KEY_PASSWORD` | رمز کلید |
| `BOOKA_KEY_ALIAS` | `booka` |

اگر این secretها تنظیم نشده باشند، بیلد با پیام روشن متوقف می‌شود تا
نسخه‌ای با امضای اشتباه منتشر نشود.

### بالا بردن نسخه

نسخه را در `pubspec.yaml` عوض کن و همان را در `lib/app_info.dart`
به‌روز کن تا داخل اپ هم درست نمایش داده شود.

## انتشار iOS

نیازمند macOS و Xcode:

```bash
flutter build ipa --release
```

پیش از اولین انتشار، `PRODUCT_BUNDLE_IDENTIFIER` را در
`ios/Runner.xcodeproj` روی یک شناسه یکتا تنظیم کن و در حساب
توسعه‌دهنده اپ ثبتش کن.

## وب

نسخه وب هنوز کامل نیست: کد ریدر از `dart:io` استفاده می‌کند و `pdfx`
پشتیبانی وب ندارد، پس `flutter build web` فعلاً کامپایل نمی‌شود.

## وضعیت زنجیره ابزار

این پروژه روی Flutter 3.24.5 و AGP 8.1.0 ساخته شده که نسبت به نسخه‌های
روز مرداد ۱۴۰۵ قدیمی‌اند. `compileSdk = 36` رسماً توسط AGP 8.1
پشتیبانی نمی‌شود و با `android.suppressUnsupportedCompileSdk` در
gradle.properties ساکت خاموش شده. پیش از انتشار گسترده، ارتقای Flutter
و AGP توصیه می‌شود.

## مجوز

- کد: MIT (متن کامل در [LICENSE](LICENSE))
- فونت Vazirmatn: SIL Open Font License 1.1 (متن کامل در
  `assets/fonts/OFL.txt`)

