/// هویت اپ — منبع واحد.
///
/// نام و نسخه در چند جا تکرار می‌شوند: مانیفست اندروید، Info.plist
/// آی‌ورب، صفحه وب و manifest وب. هر تغییری باید از این فایل شروع شود.
///
/// نکته: [kVersion] باید با `version` در pubspec.yaml یکی باشد. برای
/// اینکه دستی هماهنگ نگه‌داری نشود، می‌توان بعداً از `package_info_plus`
/// استفاده کرد تا نسخه واقعی نصب‌شده خوانده شود.
class AppInfo {
  const AppInfo._();

  /// نامی که به کاربر نشان داده می‌شود
  static const String name = 'Booka';

  /// زیرعنوان محصول
  static const String tagline = 'کتابخوان آفلاین';

  /// باید با نسخه در pubspec.yaml یکی باشد
  static const String version = '0.1.0';

  /// شماره ساخت — باید یک واحد جلوتر از آخرین انتشار باشد
  static const String build = '1';

  /// رشته کامل برای نمایش
  static String get fullVersion => 'نسخه $version ($build)';

  /// رنگ طلایی برند، هماهنگ با تم‌های داخل اپ
  static const int brandGold = 0xFFC9A86A;

  /// رنگ پس‌زمینه تیره برند، هماهنگ با تم AMOLED
  static const int brandDark = 0xFF14121F;
}
