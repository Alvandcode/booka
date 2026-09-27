import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_info.dart';
import 'privacy_page.dart';

// صفحه «درباره ما» — سازنده، حمایت، لینک‌ها
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _site = 'alvandcode.github.io';
  static const _telegram = 'a.c.official';
  static const _github = 'https://github.com/alvandcode';
  static const _ton =
      'UQCB9rzvwmq0FJDaBkHVdBgbfZPb06FWdKco3woAHH6AXuUt';

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label کپی شد')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('درباره ما')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary.withOpacity(0.35)),
              ),
              child: const Icon(Icons.menu_book, size: 48),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(AppInfo.name,
                style: Theme.of(context).textTheme.titleLarge),
          ),
          Center(
            child: Text('${AppInfo.tagline} — ${AppInfo.fullVersion}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 24),

          const _Section(title: 'سازنده'),
          _LinkTile(
            icon: Icons.language,
            label: 'وب‌سایت',
            value: _site,
            onTap: () => _copy(context, 'لینک سایت', 'https://$_site'),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('حریم خصوصی'),
              subtitle: const Text('داده‌ها فقط روی دستگاه شماست'),
              trailing: const Icon(Icons.chevron_left, size: 18),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPage()),
              ),
            ),
          ),
          _LinkTile(
            icon: Icons.send,
            label: 'تلگرام',
            value: '@$_telegram',
            onTap: () => _copy(context, 'آیدی تلگرام', _telegram),
          ),
          _LinkTile(
            icon: Icons.code,
            label: 'گیت‌هاب',
            value: _github,
            onTap: () => _copy(context, 'لینک گیت‌هاب', _github),
          ),

          const SizedBox(height: 16),
          const _Section(title: 'حمایت مالی'),
          _LinkTile(
            icon: Icons.currency_bitcoin,
            label: 'آدرس کیف پول Ton (TON)',
            value: _ton,
            mono: true,
            onTap: () => _copy(context, 'آدرس Ton', _ton),
          ),
          Text(
            'اگر از اپ خوشت آمد، یک تراکنش کوچک Ton برام بفرست. ممنونم!',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'ساخته‌شده با ❤️ برای مطالعهٔ آفلاین',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool mono;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(
          value,
          maxLines: mono ? 3 : 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: mono
              ? const TextStyle(
                  fontFamily: 'monospace', fontSize: 12, letterSpacing: 0.5)
              : null,
        ),
        trailing: const Icon(Icons.copy, size: 18),
        onTap: onTap,
      ),
    );
  }
}
