# Booka | بوکا

[![Release](https://img.shields.io/github/v/release/Alvandcode/booka)](https://github.com/Alvandcode/booka/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-gold.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-blue.svg)](https://flutter.dev)
[![Tutorial](https://img.shields.io/badge/Tutorial-آموزش قدم‌به‌قدم-gold.svg)](https://alvandcode.github.io/booka/tutorial.html)

> **کتابخوان آفلاین PDF و EPUB** — انتخاب متن واقعی، هایلایت، دیکشنری آفلاین، لایتنر، بکاپ و خروجی خوانا. بدون حساب، بدون تبلیغ، بدون تحلیلگر و بدون اینترنت.

> **Offline PDF & EPUB reader** — real text selection, highlights, offline dictionary, Leitner, backup and readable export. No account, no ads, no analytics, no internet.

**شروع سریع / Quick links:** [دانلود آخرین نسخه](https://github.com/Alvandcode/booka/releases/latest) • [آموزش قدم‌به‌قدم](https://alvandcode.github.io/booka/tutorial.html) • [راهنمای نصب](docs/INSTALL.fa.md) • [حریم خصوصی داخل اپ](lib/privacy_page.dart) • [حمایت](#حمایت--support)

---

## فارسی

### نصب

۱. از [آخرین Release](https://github.com/Alvandcode/booka/releases/latest) فایل را بگیرید:
   - اگر معماری دستگاه را نمی‌دانید: `app-universal-release.apk` روی همه کار می‌کند ولی بزرگ‌تر است.
   - برای دانلود کم‌حجم‌تر: بیشتر گوشی‌ها `app-arm64-v8a-release.apk`، گوشی‌های خیلی قدیمی `app-armeabi-v7a-release.apk`، شبیه‌ساز `app-x86_64-release.apk`.
۲. نصب از منبع ناشناس را فقط برای همان مرورگر/فایل‌ساز روشن کنید.
۳. همه نسخه‌ها با یک کلید دائمی امضا می‌شوند؛ نسخه جدید روی قبلی نصب می‌شود.

فایل یکپارچه `app-universal-release.apk` هم در همان صفحه هست. جزئیات کامل در [راهنمای نصب](docs/INSTALL.fa.md) و آموزش کامل در [صفحه آموزش](https://alvandcode.github.io/booka/tutorial.html) است.

### قابلیت‌ها

- **کتابخانه PDF و EPUB** با کاور و نویسنده واقعی و ادامه مطالعه از آخرین موقعیت.
- **EPUB:** حالت قالب‌بندی کامل و حالت متن ساده، فهرست مطالب سلسله‌مراتبی، جستجوی درون‌کتاب، نشان، هایلایت متن واقعی، کپی، دیکشنری، و کنترل اندازه فونت.
- **PDF:** انتخاب متن، هایلایت متن واقعی، جستجوی درون‌کتاب، فهرست مطالب، نشان صفحه، و نمایش دوباره هایلایت ذخیره‌شده روی همان صفحه.
- **تشخیص PDF اسکن‌شده:** اگر کتاب لایه متنی نداشته باشد، اپ هشدار «بدون لایه متنی» می‌دهد؛ جستجو و هایلایت متنی روی عکس جواب نمی‌دهد.
- **نشان، هایلایت و لایتنر:** سه تب جدا با شمارش، جستجوی متن کامل در هایلایت‌ها، پرش به محل اصلی، و حذف.
- **دیکشنری آفلاین انگلیسی→فارسی:** ۳۶٬۱۲۲ مدخل داخل خود اپ، با تحمل نشانه‌گذاری فارسی/عربی، ریشه‌یابی ساده، تلفظ با موتور گوشی، کپی معنی و ارسال مستقیم به لایتنر.
- **لایتنر SM-2:** کارت واژه با معنی، جمله متن و نام کتاب؛ فقط کارت‌های سررسیده برای مرور روزانه؛ خروجی CSV سازگار با اکسل و Anki.
- **تم و تایپوگرافی:** چهار تم کاغذی، سپیا، خاکستری شب و مشکی AMOLED با فونت وزیرمتن و اندازه فونت ۱۲ تا ۲۲.
- **بکاپ و خروجی:** بکاپ کامل JSON با دو حالت افزودن بدون تکرار یا جایگزینی کامل؛ خروجی هایلایت و نشان به Markdown و واژگان به CSV. بکاپ فقط فراداده است، نه خود فایل کتاب.
- **حریم خصوصی واقعی:** نسخه انتشار هیچ دسترسی اندروید نمی‌خواهد؛ بدون حساب، تبلیغ، تحلیلگر و اینترنت. با حذف اپ همه داده‌ها پاک می‌شود.

### چرا Booka با اپ‌های معمول فرق دارد؟

| موضوع | Booka | خیلی از اپ‌های فروشگاهی |
|---|---|---|
| حریم خصوصی | بدون دسترسی، بدون حساب/تبلیغ/تحلیلگر/اینترنت | حساب، تبلیغ و ردیابی |
| دیکشنری | آفلاین داخل اپ با تلفظ و ریشه‌یابی | آنلاین، جداگانه یا پولی |
| یادگیری | لایتنر SM-2 که از همان متن کتاب کارت می‌سازد | هایلایت جدا از مرور واژه |
| خروجی داده | JSON کامل به‌علاوه Markdown و CSV خوانا | قفل داده داخل اپ |
| PDF | متن واقعی، جستجو، فهرست و تشخیص اسکن‌شده | فقط ورق‌زدن |
| بروزرسانی | کلید امضای دائمی؛ نصب روی نسخه قبلی | امضای ناپایدار و نصب دوباره |

### حمایت / Support

اگر از اپ خوشت آمد، یک تراکنش کوچک Ton برام بفرست. ممنونم!

- آدرس کیف پول Ton: `UQCB9rzvwmq0FJDaBkHVdBgbfZPb06FWdKco3woAHH6AXuUt`
- وب‌سایت: [alvandcode.github.io](https://alvandcode.github.io)
- تلگرام: [@a_c_official](https://t.me/a_c_official)
- گیت‌هاب: [Alvandcode/booka](https://github.com/Alvandcode/booka)

---

## English

### Install

1. From [latest Release](https://github.com/Alvandcode/booka/releases/latest), pick an APK:
   - Unsure about your device: `app-universal-release.apk` works everywhere but is bigger.
   - For a smaller download: most modern phones take `app-arm64-v8a-release.apk`, very old 32-bit phones `app-armeabi-v7a-release.apk`, x86_64 emulator `app-x86_64-release.apk`.
2. Enable “Install unknown apps” only for the browser/file manager you download with.
3. Every release is signed with one permanent key, so updates install over the previous version.

A universal `app-universal-release.apk` is also on the same page. See [install guide](docs/INSTALL.fa.md) and the [step-by-step tutorial](https://alvandcode.github.io/booka/tutorial.html).

### Features

- **PDF & EPUB library** with real covers/authors and resume-from-last-position.
- **EPUB:** full rich-text mode plus plain-text mode, hierarchical TOC, in-book search, bookmarks, real-text highlights, copy, dictionary, and font-size controls.
- **PDF:** real text selection and highlights, in-book search, document outline, page bookmarks, and stored highlights re-shown on their page.
- **Scanned-PDF detection:** if a PDF has no text layer, the app says so; text search/highlight/dictionary cannot work on images.
- **Bookmarks, highlights, Leitner:** three counted tabs, full-text highlight search, jump-to-source, delete.
- **Offline English→Persian dictionary:** 36,122 bundled entries, punctuation-tolerant lookup, simple stemming, device TTS pronunciation, copy, and one-tap Leitner cards.
- **SM-2 Leitner:** word cards with meaning, source sentence and book; daily due review; Excel/Anki-compatible CSV export.
- **Themes & typography:** paper, sepia, grey night and true-black AMOLED themes with Vazirmatn and 12–22 reader font size.
- **Backup & export:** full JSON backup with merge-without-duplicates or full-replace restore; highlights/bookmarks to Markdown and vocabulary to CSV. Backup stores metadata only, not book files.
- **Real privacy:** the release build requests no Android permissions; no account, ads, analytics or internet. Uninstall wipes everything.

### Why Booka is different

| Area | Booka | Many store readers |
|---|---|---|
| Privacy | No permissions, no account/ads/analytics/internet | Accounts, ads, tracking |
| Dictionary | Bundled offline with pronunciation and stemming | Online, separate or paid |
| Learning | SM-2 Leitner cards created from the text you read | Highlights disconnected from review |
| Data export | Full JSON plus readable Markdown and CSV | Locked-in data |
| PDF | Real text, search, outline and scan detection | Page-flipping only |
| Updates | One permanent signing key; clean in-place upgrades | Unstable signatures and reinstalls |

### Support

If you like the app, send a small Ton transaction. Thank you!

- TON wallet: `UQCB9rzvwmq0FJDaBkHVdBgbfZPb06FWdKco3woAHH6AXuUt`
- Website: [alvandcode.github.io](https://alvandcode.github.io)
- Telegram: [@a_c_official](https://t.me/a_c_official)
- GitHub: [Alvandcode/booka](https://github.com/Alvandcode/booka)

---

## معماری / Architecture

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
    pdf_text.dart            ابزار متن، جستجو و TOC مسطح‌شده
  dictionary/
  theme/
```

لایه داده روی SQLite است و همه کوئری‌ها در `dao.dart` متمرکزند. مدل‌ها کلاس‌های ساده Dart هستند و هیچ مرحله codegen ندارند.

## توسعه / Development

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

`dependency_overrides` در `pubspec.yaml` عمدی است: `epub_plus` روی `image 3` و `archive 3` قفل است ولی موتور `pdfrx` به `image 4` و `archive 4` نیاز دارد؛ تنها API مشترک `ZipDecoder().decodeBytes` در هر دو نسخه هست و تست‌ها آن را پوشش می‌دهند.

## انتشار اندروید / Android release

اپ در فروشگاه نیست. خروجی با امضای مستقیم در صفحه Releases همین ریپو منتشر می‌شود. راهنمای نصب برای کاربران در [docs/INSTALL.fa.md](docs/INSTALL.fa.md) و آموزش کامل در [صفحه آموزش](https://alvandcode.github.io/booka/tutorial.html) است.

### کلید امضا / Signing key

کلید از قبل ساخته شده و **یک بار برای همیشه** استفاده می‌شود. همین نکته باعث می‌شود نسخه جدید روی نسخه قبلی نصب شود و کاربر مجبور به حذف و نصب دوباره نشود.

| | |
|---|---|
| محل کلید | `~/.booka/booka-release.jks` (خارج از ریپو) |
| اطلاعات و رمز | `~/.booka/credentials.txt` |
| اعتبار گواهی | تا سال ۲۰۵۴ |
| الگوریتم | RSA 4096 / SHA256withRSA |

> **این کلید را گم نکن.** اگر کلید یا رمزش را از دست بدهی، دیگر نمی‌توانی نسخه‌ای منتشر کنی که روی نصب‌های موجود کاربران نصب شود؛ مجبور می‌شوی `applicationId` را عوض کنی و اپ را از نو منتشر کنی. از هر دو فایل پشتیبان بگیر و در جای امن نگه دار.

### انتشار محلی / Local release

```bash
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

`android/key.properties` به کلید اشاره می‌کند و در git نیست. اگر نبود، بیلد با کلید debug انجام می‌شود و هشدار چاپ می‌کند که خروجی قابل انتشار نیست.

### انتشار خودکار / CI release

`.github/workflows/release.yml` با زدن تگ، همان تگ را checkout می‌کند، تست می‌کند، با کلید واقعی امضا می‌کند و در صفحه Releases قرار می‌دهد.

```bash
# در pubspec.yaml نسخه را بالا ببر، مثلاً version: 0.2.0+2
git tag v0.2.0
git push origin v0.2.0
```

برای اینکه CI بتواند امضا کند، یک‌بار این secretها را در `Settings → Secrets and variables → Actions` اضافه کن:

| نام | مقدار |
|---|---|
| `BOOKA_KEYSTORE_BASE64` | خروجی `base64 -w0 ~/.booka/booka-release.jks` |
| `BOOKA_STORE_PASSWORD` | رمز انبار کلید |
| `BOOKA_KEY_PASSWORD` | رمز کلید |
| `BOOKA_KEY_ALIAS` | `booka` |

اگر این secretها تنظیم نشده باشند، بیلد با پیام روشن متوقف می‌شود تا نسخه‌ای با امضای اشتباه منتشر نشود.

### بالا بردن نسخه / Versioning

نسخه را در `pubspec.yaml` عوض کن و همان را در `lib/app_info.dart` به‌روز کن تا داخل اپ هم درست نمایش داده شود.

## انتشار iOS / iOS

نیازمند macOS و Xcode:

```bash
flutter build ipa --release
```

پیش از اولین انتشار، `PRODUCT_BUNDLE_IDENTIFIER` را در `ios/Runner.xcodeproj` روی یک شناسه یکتا تنظیم کن و در حساب توسعه‌دهنده اپ ثبتش کن.

## وب / Web

نسخه وب پشتیبانی نمی‌شود چون کد اپ از `dart:io` برای فایل و دیتابیس استفاده می‌کند؛ پس `flutter build web` فعلاً مسیر انتشار نیست.

## وضعیت زنجیره ابزار / Toolchain

| مؤلفه | نسخه | چرا |
|---|---|---|
| Flutter | 3.47.5 | نسخه پایدار فعلی |
| Gradle | 9.4.1 | حداقلی که AGP 9.2 می‌خواهد |
| AGP | 9.2.0 | سقف پشتیبانی‌شده در Flutter 3.47 |
| Kotlin | 2.4.0 | نسخه‌ای که Flutter پیشنهاد می‌کند |
| JDK | 17 | |
| NDK | 25.2.9519653 | نسخه نصب‌شده روی این ماشین |

### دو نکته که ممکن است تعجب‌آور باشند

**NDK روی ۲۵.۲ ثابت شده، نه ۲۸.۲.** فلاتر پیشنهاد می‌دهد `28.2.13676358`، ولی دانلود آن از `dl.google.com` روی این شبکه ناموفق است. برای کامپایل بومی پلاگین‌ها ۲۵.۲ کافی است. اگر روزی لازم شد، فقط مقدار `ndkVersion` را در `android/app/build.gradle` تغییر بده.

**`file_picker` به نسخه ۱۳ ارتقا کرد.** نسخه ۸ در buildscript خودش `com.android.tools.build:gradle:7.4.2` اعلام می‌کرد که با Gradle 9 سازگار نیست. نسخه ۱۳ این مشکل را ندارد، ولی API عوض شده بود (`FilePicker.platform.pickFiles` → `FilePicker.pickFiles`) و در `lib/main.dart` و `lib/export_page.dart` به‌روزرسانی شد.

### آینه‌های مخزن / Mirrors

`dl.google.com` روی این ماشین کند و گاهی ناموفق است. فایل `~/.gradle/init.d/00-mirrors-only.gradle` آینه‌های لازم را اضافه می‌کند. این فایل **هیچ نسخه‌ای را قفل نمی‌کند**، فقط مخازن را عوض می‌کند. چون artifactهای AGP فقط در آینه `google` هستند، ترتیب پیشنهادی این است:

```groovy
settingsEvaluated { settings ->
    settings.pluginManagement {
        repositories {
            maven { url 'https://maven.aliyun.com/repository/google' }
            maven { url 'https://maven.aliyun.com/repository/central' }
            maven { url 'https://maven.aliyun.com/repository/public' }
            maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
            google()
            mavenCentral()
            gradlePluginPortal()
        }
    }
}

allprojects {
    buildscript {
        repositories {
            maven { url 'https://maven.aliyun.com/repository/google' }
            maven { url 'https://maven.aliyun.com/repository/central' }
            maven { url 'https://maven.aliyun.com/repository/public' }
            google()
            mavenCentral()
        }
    }
}
```

> بلوک `dependencyResolutionManagement` در `settings.gradle` عمداً وجود ندارد؛ با مخازنی که init script اضافه می‌کند تضاد پیدا می‌کند.

## مجوز / License

- کد: MIT (متن کامل در [LICENSE](LICENSE))
- فونت Vazirmatn: SIL Open Font License 1.1 (متن کامل در `assets/fonts/OFL.txt`)
