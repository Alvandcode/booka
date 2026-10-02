# 📚 Booka

[![Stars](https://img.shields.io/github/stars/Alvandcode/booka?style=flat-square)](https://github.com/Alvandcode/booka/stargazers)
[![Release](https://img.shields.io/github/actions/workflow/status/Alvandcode/booka/release.yml?style=flat-square&label=release)](https://github.com/Alvandcode/booka/actions)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-blue?style=flat-square)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](./LICENSE)
[![Last commit](https://img.shields.io/github/last-commit/Alvandcode/booka?style=flat-square)](https://github.com/Alvandcode/booka/commits)

> **EN:** Offline PDF & EPUB reader with real text selection, highlights, offline dictionary, SM-2 Leitner, backup and readable export. No account, no ads, no analytics, no internet.
>
> **FA:** کتابخوان آفلاین PDF و EPUB با انتخاب متن واقعی، هایلایت، دیکشنری آفلاین، لایتنر SM-2، بکاپ و خروجی خوانا. بدون حساب، تبلیغ، تحلیلگر و اینترنت.

<div dir="rtl" lang="fa">

## کتابخانه‌ات، همیشه همراهت — بدون اینترنت

Booka برای یک کار ساخته شده: **خواندن کتاب روی گوشی، آفلاین و خصوصی**. PDF و EPUB را با کاور واقعی نشان می‌دهد، از همان‌جا که بودی ادامه می‌دهد، متن را هایلایت می‌کند، معنی کلمه را همان‌جا می‌گوید و واژه‌ها را با لایتنر در حافظه‌ات نگه می‌دارد.

</div>

<p align="center">
  <a href="https://alvandcode.github.io/booka/tutorial.html"><b>🎓 آموزش قدم‌به‌قدم — کلیک کنید</b></a>
  <br/>
  <sub>Step-by-step tutorial — live page, or open <code>docs/tutorial.html</code> in your browser after cloning.</sub>
</p>

---

## 🎓 Tutorial | آموزش تصویری

**New here? Start with the visual step-by-step tutorial** (Persian): **[📖 Open the tutorial](https://alvandcode.github.io/booka/tutorial.html)** — after cloning you can also just open `docs/tutorial.html` in any browser.

<div dir="rtl" lang="fa">

**تازه واردی؟ از آموزش تصویری شروع کن** (فارسی، قدم‌به‌قدم با تصویر): **[📖 باز کردن صفحه آموزش](https://alvandcode.github.io/booka/tutorial.html)** — آفلاین هم می‌توانی فایل `docs/tutorial.html` را بعد از کلون در مرورگر باز کنی.

</div>

---

## 📑 Contents | فهرست

- [🎓 Tutorial | آموزش تصویری](#-tutorial--آموزش-تصویری)
- [✨ Features | قابلیت‌ها](#-features--قابلیتها)
- [✅ Requirements | نیازها](#-requirements--نیازها)
- [⚡ Quick Start | شروع سریع](#-quick-start--شروع-سریع)
- [📖 EPUB Reader | ریدر EPUB](#-epub-reader--ریدر-epub)
- [📄 PDF Reader | ریدر PDF](#-pdf-reader--ریدر-pdf)
- [🔤 Dictionary | دیکشنری](#-dictionary--دیکشنری)
- [🗂️ Leitner | لایتنر](#-leitner--لایتنر)
- [💾 Backup & Export | بکاپ و خروجی](#-backup--export--بکاپ-و-خروجی)
- [📊 Sample Export | نمونه خروجی](#-sample-export--نمونه-خروجی)
- [🛡️ Privacy | حریم خصوصی](#-privacy--حریم-خصوصی)
- [📁 Project Structure | ساختار پروژه](#-project-structure--ساختار-پروژه)
- [🛠️ Development | توسعه](#-development--توسعه)
- [🤝 Contributing | مشارکت](#-contributing--مشارکت)
- [⭐ Support | حمایت](#-support--حمایت)
- [📢 Contact | ارتباط](#-contact--ارتباط)
- [📄 License | لایسنس](#-license--لایسنس)

---

## ✨ Features | قابلیت‌ها

| | EN | FA |
|---|---|---|
| 📚 | **PDF & EPUB library** with real covers, authors, resume-from-last-position | **کتابخانه PDF و EPUB** با کاور و نویسنده واقعی و ادامه از آخرین موقعیت |
| 📄 | **Real PDF text**: selection, in-book search, outline, visible highlights (PDFium) | **متن واقعی PDF**: انتخاب، جستجوی درون‌کتاب، فهرست و هایلایت قابل دیدن (موتور PDFium) |
| 📖 | **EPUB rich + plain modes**, hierarchical TOC, search, font size 12–22 | **دو حالت قالب‌بندی و ساده**، فهرست سلسله‌مراتبی، جستجو و فونت ۱۲ تا ۲۲ |
| 🔖 | **Bookmarks & highlights** with full-text search, jump-to-source, delete | **نشان و هایلایت** با جستجوی متن کامل، پرش به محل اصلی و حذف |
| 🔤 | **Offline EN→FA dictionary**: 36,122 entries, stemming, device TTS, one-tap Leitner cards | **دیکشنری آفلاین**: ۳۶٬۱۲۲ مدخل، ریشه‌یابی، تلفظ و ساخت کارت لایتنر |
| 🗂️ | **SM-2 Leitner**: due-only daily review, Excel/Anki CSV export | **لایتنر SM-2**: مرور روزانه فقط سررسیده‌ها، خروجی CSV |
| 🎨 | **4 themes** (paper, sepia, grey night, AMOLED) + Vazirmatn typography | **۴ تم** (کاغذی، سپیا، خاکستری شب، AMOLED) با فونت وزیرمتن |
| 💾 | **Backup & export**: full JSON (merge or replace) + readable Markdown/CSV | **بکاپ و خروجی**: JSON کامل (ادغام یا جایگزینی) + Markdown و CSV خوانا |
| 🛡️ | **Zero permissions** in release; no account, ads, analytics or internet | **صفر دسترسی** در نسخه انتشار؛ بدون حساب، تبلیغ، تحلیلگر و اینترنت |

---

## ✅ Requirements | نیازها

**EN:** Android **7.0+**, ~30 MB free for a per-ABI APK (~80 MB for the universal one). No internet needed. For pronunciation, any on-device speech engine (e.g. Google Text-to-Speech).

<div dir="rtl" lang="fa">

**FA:** اندروید **۷ به بالا**، حدود ۳۰ مگ فضای خالی برای نسخه مخصوص معماری (حدود ۸۰ مگ برای نسخه یکپارچه). بدون نیاز به اینترنت. برای تلفظ کلمات، هر موتور گفتار روی گوشی کافی است.

</div>

---

## ⚡ Quick Start | شروع سریع

**EN:** Grab the APK from [latest Release](https://github.com/Alvandcode/booka/releases/latest) — `app-universal-release.apk` works on every device; per-ABI files (`app-arm64-v8a-release.apk` for most phones) are smaller:

```bash
# verify what you downloaded (compare with checksums.txt on the release page)
sha256sum app-universal-release.apk
```

Then install (enable “Install unknown apps” for your browser when asked), open the app and add your first PDF or EPUB. That’s it — everything works offline from here.

<div dir="rtl" lang="fa">

**FA:** از [آخرین Release](https://github.com/Alvandcode/booka/releases/latest) فایل را بگیر — `app-universal-release.apk` روی همه دستگاه‌ها کار می‌کند؛ فایل مخصوص معماری (برای بیشتر گوشی‌ها `app-arm64-v8a-release.apk`) کم‌حجم‌تر است. موقع نصب، «نصب از منبع ناشناس» را فقط برای همان مرورگر روشن کن، بعد اولین PDF یا EPUB را وارد کن. از اینجا به بعد همه‌چیز آفلاین است.

```bash
# بررسی اصالت فایل (با checksums.txt همان صفحه مقایسه کن)
sha256sum app-universal-release.apk
```

</div>

---

## 📖 EPUB Reader | ریدر EPUB

**EN:** Two modes — **rich** (the book’s own formatting, images and CSS) and **plain** (just the text). Hierarchical outline with jump-to-section, in-book search with surrounding-text snippets, bookmarks, real-text highlights, copy, and dictionary on any selection. Font size lives right in the reader bar (12–22, also in Settings).

<div dir="rtl" lang="fa">

**FA:** دو حالت دارد — **کامل** (قالب‌بندی، تصویر و استایل خود کتاب) و **ساده** (فقط متن). فهرست سلسله‌مراتبی با پرش، جستجوی درون‌کتاب با برش متن، نشان، هایلایت متن واقعی، کپی و دیکشنری روی هر انتخاب. اندازه فونت همان‌جا در نوار ریدر است (۱۲ تا ۲۲، در تنظیمات هم هست).

</div>

---

## 📄 PDF Reader | ریدر PDF

**EN:** Real text selection (PDFium engine) — select to get **dictionary**, **highlight** and **copy**. In-book search runs after a short pause so big books stay fast; the outline jumps you between chapters; **My Highlights** lists this book’s highlights and paints the tapped one back onto its page. Scanned (image-only) PDFs are detected and labeled — text features can’t work on photos, and the app tells you instead of failing silently.

<div dir="rtl" lang="fa">

**FA:** انتخاب متن واقعی (موتور PDFium) — با انتخاب، سه دکمه **دیکشنری**، **هایلایت** و **کپی** می‌آید. جستجو با کمی مکث اجرا می‌شود تا کتاب‌های بزرگ کند نشوند؛ فهرست مطالب بین فصل‌ها می‌پرد؛ **هایلایت‌های من** هایلایت‌های همین کتاب را فهرست می‌کند و با لمس، همان متن را روی صفحه زرد می‌کند. PDF اسکن‌شده (فقط عکس) تشخیص داده و برچسب می‌خورد — قابلیت‌های متنی روی عکس جواب نمی‌دهند و اپ به‌جای سکوت، این را می‌گوید.

</div>

---

## 🔤 Dictionary | دیکشنری

**EN:** Fully offline English→Persian, **36,122 entries** bundled (~1.6 MB). Tolerant lookup — strips Persian/Arabic punctuation, collapses spaces, tries simple stems (`-s/-es/-ing/-ed`). Pronunciation uses your device’s own speech engine (the button hides itself if none is installed). Copy the meaning or send the word straight to Leitner with its sentence and book attached.

<div dir="rtl" lang="fa">

**FA:** کاملاً آفلاین انگلیسی‌به‌فارسی با **۳۶٬۱۲۲ مدخل** داخل خود اپ (حدود ۱.۶ مگ). جستجو خطاپذیر است — نشانه‌های فارسی/عربی را تمیز می‌کند و ریشه ساده را هم امتحان می‌کند. تلفظ با موتور گفتار خود گوشی است (اگر نباشد دکمه‌اش پنهان می‌شود). معنی را کپی کن یا واژه را با جمله و نام کتاب مستقیم به لایتنر بفرست.

</div>

---

## 🗂️ Leitner | لایتنر

**EN:** Cards are born from your reading — word, meaning, source sentence, book. Each day only the **due** cards show up. Grading a card (0 = forgotten … 5 = mastered) reschedules it with the classic **SM-2** rule: forget → back to 1 day; 1st success → 1 day, 2nd → 6 days, then interval × easiness; easiness itself moves with the standard SM-2 formula, clamped to 1.3–2.8.

<div dir="rtl" lang="fa">

**FA:** کارت‌ها از دل مطالعه تو ساخته می‌شوند — واژه، معنی، جمله متن و نام کتاب. هر روز فقط کارت‌های **سررسیده** می‌آیند. نمره‌دادن (۰ یعنی فراموش … ۵ یعنی مسلط) زمان بعدی را با قانون کلاسیک **SM-2** تنظیم می‌کند: فراموشی یعنی برگشت به یک روز؛ موفقیت اول یک روز، دوم شش روز، بعد فاصله × ضریب سهولت؛ خود ضریب هم با فرمول استاندارد SM-2 و در بازه ۱.۳ تا ۲.۸ حرکت می‌کند.

</div>

---

## 💾 Backup & Export | بکاپ و خروجی

**EN:** One JSON file holds everything — books, bookmarks, highlights, Leitner. Restore **merges** (duplicates skipped) or **replaces** everything after confirmation. On a new device, import your books first: backup matches them by file name, orphaned records are kept as metadata. For humans: highlights and bookmarks export to **Markdown**, vocabulary to Excel/Anki-friendly **CSV**. Backup never includes the book files themselves.

<div dir="rtl" lang="fa">

**FA:** یک فایل JSON همه‌چیز را نگه می‌دارد — کتاب‌ها، نشان‌ها، هایلایت‌ها و لایتنر. بازیابی یا **ادغام** می‌کند (تکراری‌ها رد می‌شوند) یا بعد از تأیید **جایگزین** کامل می‌شود. در گوشی جدید اول کتاب‌ها را وارد کن: بکاپ با نام فایل به کتاب وصل می‌شود و رکورد بی‌کتاب هم به‌عنوان فراداده می‌ماند. برای آدم‌ها: هایلایت و نشان به **Markdown** و واژگان به **CSV** سازگار با اکسل و Anki خروجی می‌رود. بکاپ هیچ‌وقت خود فایل کتاب را ندارد.

</div>

---

## 📊 Sample Export | نمونه خروجی

```markdown
# هایلایت‌ها

> 2 مورد • booka-backup

## Book Title

- «Persistence is a virtue …» — بخش 3
  - یادداشت: برای مرور هفتگی
```

```csv
front,back,book,context,interval,due,easiness
persistence,پشتکار,Book Title,Persistence is a virtue …,6,2026-10-08,2.50
```

**EN:** Highlights/bookmarks export to Markdown grouped by book; vocabulary exports to CSV with BOM so Excel opens Persian correctly.

<div dir="rtl" lang="fa">

**FA:** هایلایت و نشان به Markdown گروه‌بندی‌شده بر اساس کتاب خروجی می‌روند؛ واژگان به CSV با BOM می‌رود تا اکسل فارسی را درست باز کند.

</div>

---

## 🛡️ Privacy | حریم خصوصی

- **EN:** The release build requests **zero Android permissions** — no INTERNET, no storage, nothing. No account, no ads, no analytics. The dictionary lives inside the app; no word ever leaves your device. Pronunciation runs on your OS speech engine. Deleting the app wipes everything — back up first from Settings.
- **FA:** نسخه انتشار **هیچ دسترسی اندروید** نمی‌خواهد — نه اینترنت، نه حافظه، هیچ‌چیز. بدون حساب، تبلیغ و تحلیلگر. دیکشنری داخل خود اپ است؛ هیچ کلمه‌ای به جایی ارسال نمی‌شود. تلفظ با موتور خود سیستم‌عامل است. با حذف اپ همه‌چیز پاک می‌شود — اول از تنظیمات بکاپ بگیر.

---

## 📁 Project Structure | ساختار پروژه

```text
lib/
  main.dart                 صفحات و ناوبری
  app_info.dart             نام و نسخه اپ (منبع واحد)
  export_page.dart          بکاپ، بازیابی و خروجی
  about_page.dart
  privacy_page.dart
  data/
    db.dart                 اسکیمای SQLite و مهاجرت
    dao.dart                 همه کوئری‌ها (+ گام SM-2)
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
  dictionary/               دیکشنری آفلاین + تلفظ + لایتنر
  theme/                    چهار تم و فونت وزیرمتن
test/                      168 tests (flutter test)
.github/workflows/release.yml   تگ → تست → امضا → انتشار
```

```bash
flutter pub get
flutter test      # 168 tests
flutter analyze   # clean: 0 errors, 0 warnings
```

---

## 🛠️ Development | توسعه

**EN:** Built with **Flutter 3.47.5** (Dart 3.13). Data layer is SQLite with all queries in `dao.dart`; plain-Dart models, no codegen; Riverpod providers. PDF engine is PDFium via `pdfrx`; EPUB via `epub_plus`.

Releases are fully automatic: bump `version` in `pubspec.yaml` **and** `lib/app_info.dart`, then tag:

```bash
git tag v0.1.2
git push origin v0.1.2
```

CI (`.github/workflows/release.yml`) checks out that tag, runs analyze + tests, signs with the permanent key from Secrets (`BOOKA_KEYSTORE_BASE64`, `BOOKA_STORE_PASSWORD`, `BOOKA_KEY_PASSWORD`, `BOOKA_KEY_ALIAS`) and publishes split APKs + universal APK + App Bundle to Releases. If secrets are missing, the job stops loudly instead of shipping a wrongly-signed build.

<div dir="rtl" lang="fa">

**FA:** ساخته‌شده با **فلاتر 3.47.5** (دارت 3.13). لایه داده SQLite است و همه کوئری‌ها در `dao.dart`؛ مدل‌ها کلاس ساده دارت بدون codegen؛ موتور PDF با PDFium و EPUB با `epub_plus`. انتشار کاملاً خودکار است: نسخه را در `pubspec.yaml` **و** `lib/app_info.dart` بالا ببر و تگ بزن؛ CI همان تگ را checkout می‌کند، تست می‌گیرد، با کلید دائمی امضا می‌کند و در Releases می‌گذارد.

</div>

---

## 🤝 Contributing | مشارکت

**EN:** Issues and Pull Requests are welcome! Bug reports with repro steps get fixed fastest. Please keep the app’s promise: offline-first, zero permissions, no tracking.

<div dir="rtl" lang="fa">

**FA:** ایشو و پول‌ریکوئست همیشه خوش‌آمد است! گزارش باگ با قدم‌های بازتولید سریع‌تر فیکس می‌شود. لطفاً قول اپ را نگه دار: آفلاین‌اول، صفر دسترسی، بدون ردیابی.

</div>

---

## ⭐ Support | حمایت

**EN:** If Booka earned a place on your phone, support it:

- ⭐ **Star the repo** — it keeps the project alive and visible
- 📣 **Share it** with anyone who reads on their phone
- 🐛 **Report bugs & ideas** via Issues — every report makes it better
- 💎 **Donate a little TON** — wallet below. Thank you!

<div dir="rtl" lang="fa">

**FA:** اگر بوکا جایی در گوشی‌ات باز کرد، حمایتش کن:

- ⭐ **به ریپو ستاره بده** — همین ستاره انگیزه ادامه و دیده‌شدن پروژه است
- 📣 **با بقیه به اشتراک بذار** — هر کسی که روی گوشی کتاب می‌خواند
- 🐛 **باگ و ایده را ایشو کن** — هر گزارش، پروژه را بهتر می‌کند
- 💎 اگر خوشت آمد، یک تراکنش کوچک Ton بفرست. ممنونم! آدرس کیف پول: `UQCB9rzvwmq0FJDaBkHVdBgbfZPb06FWdKco3woAHH6AXuUt`

</div>

---

## 📢 Contact | ارتباط

- 💬 Telegram channel: **[@a_c_official](https://t.me/a_c_official)** — news, updates and support
- 🌐 Website: [alvandcode.github.io](https://alvandcode.github.io)
- 💻 GitHub: [Alvandcode/booka](https://github.com/Alvandcode/booka)

<div dir="rtl" lang="fa">

- 💬 کانال تلگرام: **[@a_c_official](https://t.me/a_c_official)** — اخبار، آپدیت‌ها و پشتیبانی
- 🌐 وب‌سایت: [alvandcode.github.io](https://alvandcode.github.io)
- 💻 گیت‌هاب: [Alvandcode/booka](https://github.com/Alvandcode/booka)

</div>

---

## 📄 License | لایسنس

MIT — see [LICENSE](./LICENSE). Vazirmatn font: SIL Open Font License 1.1 (`assets/fonts/OFL.txt`).

👨‍💻 Built for offline reading. / ساخته‌شده برای مطالعه آفلاین.
