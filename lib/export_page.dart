import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/backup.dart';
import 'data/dao.dart';
import 'data/db.dart';
import 'data/store.dart';

/// بکاپ و اکسپورت.
///
/// از آنجا که اپ کاملاً آفلاین است و داده فقط روی دستگاه زندگی
/// می‌کند، حذف اپ یعنی از دست رفتن همه‌چیز. این صفحه راه خروج دادن
/// داده از دستگاه را می‌دهد.
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  bool _busy = false;

  Future<BackupService> _service() async => BackupService(Dao(Db.instance));

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade800 : null,
      ));
  }

  /// ذخیره متن در مسیری که کاربر انتخاب می‌کند
  Future<void> _save(
    String suggestedName, {
    required List<int> Function() build,
    List<String> extensions = const ['json'],
  }) {
    return _run(() async {
      final bytes = build();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'ذخیره فایل',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: extensions,
        bytes: Uint8List.fromList(bytes),
      );
      if (path == null) return;
      // روی دسکتاپ و برخی پلتفرم‌ها باید خودمان هم بنویسیم
      if (!File(path).existsSync()) {
        await File(path).writeAsBytes(bytes, flush: true);
      }
      _toast('ذخیره شد');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on FormatException catch (e) {
      _toast(e.message, error: true);
    } catch (e) {
      _toast('خطا: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _stamp() {
    final n = DateTime.now();
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${p2(n.month)}-${p2(n.day)}_${p2(n.hour)}${p2(n.minute)}';
  }

  // ── اکسپورت‌های تکی ──

  Future<void> _exportHighlightsMarkdown() => _run(() async {
        final items = ref.read(highlightsProvider);
        final md = BackupService.highlightsMarkdown(items);
        await _save('booka-highlights-$_stamp.md', build: () => utf8.encode(md),
            extensions: ['md']);
      });

  Future<void> _exportBookmarksMarkdown() => _run(() async {
        final items = ref.read(bookmarksProvider);
        final md = BackupService.bookmarksMarkdown(items);
        await _save('booka-bookmarks-$_stamp.md', build: () => utf8.encode(md),
            extensions: ['md']);
      });

  Future<void> _exportFlashcardsCsv() => _run(() async {
        final items = ref.read(flashcardsProvider);
        final csv = BackupService.flashcardsCsv(items);
        await _save('booka-vocabulary-$_stamp.csv', build: () => utf8.encode(csv),
            extensions: ['csv']);
      });

  // ── بکاپ کامل ──

  Future<void> _exportFull() async {
    await _run(() async {
      final svc = await _service();
      final json = await svc.exportJson();
      await _save('booka-backup-$_stamp.json',
          build: () => utf8.encode(json), extensions: ['json']);
    });
  }

  Future<void> _importBackup({required bool replace}) async {
    await _run(() async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final picked = res?.files.singleOrNull;
      if (picked == null) {
        _toast('فایلی انتخاب نشد');
        return;
      }
      // برخی پلتفرم‌ها فقط مسیر، برخی فقط بایت می‌دهند
      final raw = picked.path != null && File(picked.path!).existsSync()
          ? await File(picked.path!).readAsString()
          : (picked.bytes != null
              ? utf8.decode(picked.bytes!)
              : null);
      if (raw == null) {
        _toast('فایل خوانده نشد', error: true);
        return;
      }

      final svc = await _service();
      final result = await svc.importJson(raw, replace: replace);

      // providerها باید داده تازه را از دیتابیس بخوانند
      ref.invalidate(libraryProvider);
      ref.invalidate(bookmarksProvider);
      ref.invalidate(highlightsProvider);
      ref.invalidate(flashcardsProvider);

      _toast('بازیابی شد: ${result.total} مورد'
          '${result.unmatchedBooks > 0 ? ' • ${result.unmatchedBooks} کتاب روی این دستگاه نبود' : ''}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final highlights = ref.watch(highlightsProvider).length;
    final bookmarks = ref.watch(bookmarksProvider).length;
    final cards = ref.watch(flashcardsProvider).length;
    final books = ref.watch(libraryProvider).length;

    return Scaffold(
      appBar: AppBar(title: const Text('💾 بکاپ و خروجی داده')),
      body: ListView(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('داده‌ها فقط روی این دستگاه هستند',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'با حذف اپ همه‌چیز پاک می‌شود. پیش از حذف، بکاپ بگیر و '
                      'فایلش را جای امنی نگه دار.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$books کتاب • $bookmarks نشان • $highlights هایلایت • $cards کارت',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const _Section('بکاپ کامل (پیشنهادی)'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('تهیه فایل بکاپ'),
            subtitle: const Text('همه کتاب‌ها، نشان‌ها، هایلایت‌ها و لایتنر در یک فایل JSON'),
            onTap: _exportFull,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('بازیابی و افزودن به داده فعلی'),
            subtitle: const Text('داده‌های تکراری نادیده گرفته می‌شوند'),
            onTap: () => _importBackup(replace: false),
          ),
          ListTile(
            leading: Icon(Icons.delete_sweep, color: Colors.red.shade300),
            title: Text('جایگزینی کامل با فایل بکاپ',
                style: TextStyle(color: Colors.red.shade200)),
            subtitle: const Text('داده فعلی پاک و بکاپ جایگزین آن می‌شود'),
            onTap: () async {
              final ok = await _confirmReplace();
              if (ok) _importBackup(replace: true);
            },
          ),

          const Divider(),
          const _Section('خروجی قابل خواندن'),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('هایلایت‌ها به Markdown'),
            subtitle: Text('$highlights مورد • قابل باز شدن در هر ویرایشگر'),
            enabled: highlights > 0,
            onTap: _exportHighlightsMarkdown,
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('نشان‌ها به Markdown'),
            subtitle: Text('$bookmarks مورد'),
            enabled: bookmarks > 0,
            onTap: _exportBookmarksMarkdown,
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('واژگان به CSV'),
            subtitle: Text('$cards مورد • سازگار با اکسل و Anki'),
            enabled: cards > 0,
            onTap: _exportFlashcardsCsv,
          ),

          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Text(
              'بکاپ فایل کتاب‌ها را در بر نمی‌گیرد؛ برای انتقال یادداشت‌ها به '
              'دستگاه جدید، کتاب‌ها را اول وارد کن و بعد بکاپ را بازیابی کن.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmReplace() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('جایگزینی همه داده‌ها؟'),
        content: const Text(
            'داده فعلی این دستگاه پاک می‌شود و جای خود را به محتوای فایل بکاپ می‌دهد. این کار برگشت‌پذیر نیست.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('جایگزین کن'),
          ),
        ],
      ),
    );
    return ok == true;
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
