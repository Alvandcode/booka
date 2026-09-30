# قوانین نگه‌داری برای R8 در بیلد release.
#
# پلاگین Gradle فلاتر قوانین خودش را اضافه می‌کند؛ این‌ها لایه دفاعی
# هستند تا کوچک‌سازی، چیزی را که باید باقی بماند حذف نکند.

# ── موتور فلاتر ──
# کلاس‌هایی که از طریق بازتاب (reflection) صدا زده می‌شوند و نباید
# جابه‌جا یا حذف شوند.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# متدهایی که فقط از بومی صدا زده می‌شوند و امضایشان در دارت نیست
-keepclassmembers class io.flutter.** {
    native <methods>;
}

# ── MainActivity ──
# فعالیت اصلی از بومی ساخته می‌شود؛ نام کاملش در مانیفست آمده است.
-keep class com.bookreader.book_reader_app.MainActivity { *; }

# ── پلاگین‌ها ──
# هر پلاگینی که از بازتاب یا callback نام‌دار استفاده می‌کند باید اینجا
# اضافه شود. موارد زیر بر اساس پلاگین‌های فعلی پروژه است.
-keep class com.tekartik.sqflite.** { *; }
-keep class com.tekartik.sqflite.**$* { *; }
-keep class com.tundralabs.darttts.** { *; }

# ── هشدارها ──
# موتور فلاتر به کلاس‌های Play Core ارجاع می‌دهد (PlayStoreDeferredComponentManager)
# ولی این اپ از deferred components استفاده نمی‌کند، پس کتابخانه مربوطه
# اضافه نمی‌شود و R8 شکست می‌خورد. این خطوط جلوی خطا را می‌گیرد.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

-dontwarn java.lang.invoke.**
-dontwarn javax.annotation.**
-dontwarn sun.misc.**
-dontwarn org.xmlpull.v1.**
