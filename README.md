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

### ۱. ساخت کلید امضا (فقط یک‌بار)

> اگر کلید را گم کنی دیگر نمی‌توانی نسخه به‌روزشده‌ای روی فروشگاه
> منتشر کنی. حتماً یک نسخه پشتیبان امن نگه دار.

```bash
keytool -genkey -v -keystore ~/booka-release.jks \
        -keyalg RSA -keysize 2048 -validity 10000 -alias booka
```

### ۲. تنظیم کلید

```bash
cp android/key.properties.example android/key.properties
```

مقادیر داخل `android/key.properties` را پر کن:

```properties
storePassword=...
keyPassword=...
keyAlias=booka
storeFile=/مسیر/مطلق/تا/booka-release.jks
```

`android/key.properties` و فایل‌های `*.jks` در git نیستند.

### ۳. بالا بردن شماره نسخه

در `pubspec.yaml`:

```yaml
version: 0.2.0+2
```

همین نسخه را در `lib/app_info.dart` هم به‌روز کن تا داخل اپ درست
نمایش داده شود.

### ۴. ساخت

```bash
flutter build appbundle --release   # برای فروشگاه Play
flutter build apk --release         # برای نصب مستقیم
```

اگر `key.properties` نباشد، بیلد با کلید debug انجام می‌شود و یک هشدار
واضح چاپ می‌شود. چنین خروجی‌ای در فروشگاه قابل انتشار نیست.

بیلد release کد و منابع را با R8 کوچک می‌کند و خروجی به تفکیک معماری
(armeabi-v7a، arm64-v8a، x86_64) به‌علاوه یک APK یکپارچه ساخته می‌شود.

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

## مجوز

- کد: پروژه شخصی
- فونت Vazirmatn: SIL Open Font License 1.1 (متن کامل در
  `assets/fonts/OFL.txt`)
