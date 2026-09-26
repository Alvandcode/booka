import 'package:flutter/material.dart';

// صفحه حریم خصوصی — متن رسمی برای انتشار در پلی و سایت
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('🔒 حریم خصوصی')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('سیاست حریم خصوصی Booka',
              style: ts.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('آخرین به‌روزرسانی: ۱۴۰۴',
              style: ts.bodySmall),
          const SizedBox(height: 16),
          const _Section(
            title: 'خلاصه',
            body:
                'اپلیکیشن Booka کاملاً آفلاین کار می‌کند و هیچ داده‌ای را جمع‌آوری، ارسال یا ذخیره‌سازی نمی‌کند. '
                'بدون حساب کاربری، بدون تبلیغات، بدون تحلیلگر و بدون دسترسی به اینترنت.',
          ),
          const _Section(
            title: 'داده‌هایی که نگه می‌داریم',
            body: 'این اطلاعات فقط در حافظه محلی دستگاه شما ذخیره می‌شوند و با هیچ سروری به اشتراک گذاشته نمی‌شوند:\n'
                '• فایل‌های کتابی که وارد می‌کنید (کپی در پوشه اختصاصی اپ)\n'
                '• نشان‌کتاب، هایلایت‌ها و کارت‌های لایتنر\n'
                '• تنظیمات نمایش (تم و اندازه فونت)\n'
                '• آمار مطالعه (تعداد صفحه و زمان)',
          ),
          const _Section(
            title: 'دسترسی‌های دستگاه',
            body: '• انتخاب فایل: فقط برای وارد کردن کتاب از حافظه شما\n'
                '• موتور گفتار (TTS): برای تلفظ کلمات در دیکشنری — توسط سیستم‌عامل اجرا می‌شود\n'
                'Booka به مخاطبین، موقعیت مکانی، دوربین، میکروفن یا فایل‌های دیگر دسترسی ندارد.',
          ),
          const _Section(
            title: 'دیکشنری آفلاین',
            body:
                'فرهنگ لغت انگلیسی به فارسی داخل خود اپ (offline) است؛ جستجوی کلمه به‌صورت محلی انجام می‌شود و هیچ کلمه‌ای به اینترنت ارسال نمی‌شود.',
          ),
          const _Section(
            title: 'داده‌های کودکان',
            body: 'این اپ مناسب همه سنین است و عمداً هیچ داده‌ای از کاربران جمع‌آوری نمی‌کند.',
          ),
          const _Section(
            title: 'حذف داده‌ها',
            body:
                'با حذف اپلیکیشن، همه داده‌های محلی (کتاب‌ها، نشان‌ها، هایلایت‌ها، لایتنر و تنظیمات) به‌طور کامل پاک می‌شوند. '
                'در داخل اپ هم هر مورد با کشیدن یا دکمه حذف قابل پاک کردن است.',
          ),
          const _Section(
            title: 'تغییرات این سیاست',
            body: 'در صورت تغییر، نسخه جدید همین صفحه در اپ و مخزن گیت‌هاب منتشر می‌شود.',
          ),
          const _Section(
            title: 'تماس',
            body: 'اگر پرسشی دارید: تلگرام a.c.official — سازنده: alvandcode.github.io',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.9)),
        ],
      ),
    );
  }
}
