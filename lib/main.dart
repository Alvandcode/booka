import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'about_page.dart';
import 'data/store.dart';
import 'dictionary/dictionary_service.dart';
import 'privacy_page.dart';
import 'reader/epub_screen.dart';
import 'reader/pdf_screen.dart';
import 'theme/paper_glass_theme.dart';

void main() {
  runApp(const ProviderScope(child: BookReaderApp()));
}

final librarySearchProvider = StateProvider<String>((ref) => '');

class BookReaderApp extends ConsumerWidget {
  const BookReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    ThemeData theme;
    switch (mode) {
      case 'paper':
        theme = PaperGlassTheme.paper();
        break;
      case 'sepia':
        theme = PaperGlassTheme.sepia();
        break;
      case 'greyNight':
        theme = PaperGlassTheme.greyNight();
        break;
      default:
        theme = PaperGlassTheme.amoled();
    }
    return MaterialApp(
      title: 'Booka',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme,
      home: const LibraryScreen(),
    );
  }
}

// ── پوسته تب‌ها ──
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          LibraryPage(),
          BookmarksPage(),
          StatsPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.book), label: 'کتاب‌ها'),
          NavigationDestination(
              icon: Icon(Icons.bookmark), label: 'نشان‌ها'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'آمار'),
          NavigationDestination(
              icon: Icon(Icons.settings), label: 'تنظیمات'),
        ],
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

// ── ۱. کتابخانه ──
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _importing = false;

  Future<void> _importBook() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub'],
      );
      final picked = res?.files.singleOrNull;
      final src = picked?.path;
      if (picked == null || src == null || !File(src).existsSync()) return;

      final ext = picked.extension?.toLowerCase() ?? '';
      final type = ext == 'epub' ? 'epub' : 'pdf';

      // کپی به پوشه دائمی اپ (مسیر file_picker ممکن است موقت باشد)
      final docs = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${docs.path}/books');
      if (!booksDir.existsSync()) booksDir.createSync(recursive: true);
      var base = (picked.name.contains('.')
          ? picked.name.substring(0, picked.name.lastIndexOf('.'))
          : picked.name);
      if (base.trim().isEmpty) base = 'کتاب';
      var dest = '${booksDir.path}/$base.$type';
      var n = 1;
      while (File(dest).existsSync()) {
        dest = '${booksDir.path}/$base ($n).$type';
        n++;
      }
      await File(src).copy(dest);

      await ref.read(libraryProvider.notifier).import(LibraryBook(
            path: dest,
            title: base,
            type: type,
            addedAt: DateTime.now(),
          ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('📖 «$base» به کتابخانه اضافه شد')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در افزودن کتاب: $e')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _deleteBook(LibraryBook b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف کتاب؟'),
        content: Text('«${b.title}» از کتابخانه حذف شود؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(libraryProvider.notifier).removeByPath(b.path);
    // نشان‌ها، هایلایت‌ها و کارت‌های این کتاب در پایگاه داده آبشاری حذف
    // شدند؛ این سه provider باید وضعیت حافظه‌شان را تازه کنند.
    ref.invalidate(bookmarksProvider);
    ref.invalidate(highlightsProvider);
    ref.invalidate(flashcardsProvider);
    try {
      final f = File(b.path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('کتاب حذف شد')));
    }
  }

  void _openBook(LibraryBook b) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => b.type == 'epub'
            ? EpubReaderScreen(path: b.path, title: b.title)
            : PdfReaderScreen(path: b.path, title: b.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(libraryProvider);
    final query = ref.watch(librarySearchProvider).trim().toLowerCase();
    final books = query.isEmpty
        ? all
        : all
            .where((b) => b.title.toLowerCase().contains(query))
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 کتابخانه من'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'افزودن کتاب',
            icon: _importing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_circle_outline),
            onPressed: _importBook,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              hintText: 'جستجو در کتاب‌های آفلاین...',
              leading: const Icon(Icons.search),
              onChanged: (v) =>
                  ref.read(librarySearchProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: all.isEmpty
                ? _EmptyLibrary(onImport: _importBook)
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: books.length,
                    itemBuilder: (c, i) {
                      final b = books[i];
                      return GestureDetector(
                        onTap: () => _openBook(b),
                        onLongPress: () => _deleteBook(b),
                        child: Hero(
                          tag: b.path,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          colors: [
                                            Colors.deepPurple.shade400,
                                            Colors.black87
                                          ]),
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    alignment: Alignment.bottomRight,
                                    child: Text(b.title,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          b.type == 'epub'
                                              ? 'EPUB • ${(b.progress * 100).round()}٪ خوانده'
                                              : 'PDF • صفحه ${b.lastPage}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                      const SizedBox(height: 6),
                                      LinearProgressIndicator(
                                          value: b.progress.clamp(0.0, 1.0)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: all.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _importing ? null : _importBook,
              icon: const Icon(Icons.add),
              label: const Text('افزودن کتاب'),
            ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final VoidCallback onImport;
  const _EmptyLibrary({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_books_outlined,
              size: 72, color: Theme.of(context).disabledColor),
          const SizedBox(height: 14),
          const Text('کتابخانه خالی است'),
          const SizedBox(height: 6),
          Text('PDF یا EPUB را از گوشی اضافه کن',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('افزودن کتاب')),
        ],
      ),
    );
  }
}

// ── ۲. نشان‌ها + هایلایت‌ها + لایتنر (سه تب) ──
class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({super.key});

  void _openBook(BuildContext context, WidgetRef ref,
      {required String? bookPath, required int pageIndex}) {
    if (bookPath == null) return;
    LibraryBook? book;
    for (final b in ref.read(libraryProvider)) {
      if (b.path == bookPath) {
        book = b;
        break;
      }
    }
    if (book == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('کتاب این مورد دیگر در کتابخانه نیست')));
      return;
    }
    final found = book;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => found.type == 'epub'
            ? EpubReaderScreen(
                path: found.path, title: found.title, initialPage: pageIndex)
            : PdfReaderScreen(
                path: found.path, title: found.title, initialPage: pageIndex),
      ),
    );
  }

  Future<bool> _confirmDelete(
      BuildContext context, String title, String content) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حذف')),
        ],
      ),
    );
    return ok == true;
  }

  Widget _empty(BuildContext context, IconData icon, String title,
      String hint) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(title),
          const SizedBox(height: 6),
          Text(hint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = ref.watch(bookmarksProvider);
    final highlights = ref.watch(highlightsProvider);
    final cards = ref.watch(flashcardsProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نشان‌ها'),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.bookmark), text: 'نشان (${marks.length})'),
              Tab(
                  icon: const Icon(Icons.highlight_alt),
                  text: 'هایلایت (${highlights.length})'),
              Tab(
                  icon: const Icon(Icons.style),
                  text: 'لایتنر (${cards.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── تب نشان‌ها ──
            marks.isEmpty
                ? _empty(context, Icons.bookmark_border, 'هنوز نشانی نداری',
                    'داخل ریدر دکمه بوکمارک را بزن')
                : ListView.builder(
                    itemCount: marks.length,
                    itemBuilder: (c, i) {
                      final m = marks[i];
                      return Dismissible(
                        key: ValueKey('bm-${m.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red.shade700,
                          alignment: Alignment.centerLeft,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => ref
                            .read(bookmarksProvider.notifier)
                            .removeEntry(m),
                        child: ListTile(
                          leading: const Icon(Icons.bookmark,
                              color: Color(0xFFC9A86A)),
                          title: Text(m.book),
                          subtitle: Text(m.note),
                          trailing: IconButton(
                            tooltip: 'حذف نشان',
                            icon: const Icon(Icons.delete_outline,
                                size: 20),
                            onPressed: () async {
                              if (await _confirmDelete(context, 'حذف نشان؟',
                                  'نشان «${m.note}» از «${m.book}» حذف شود؟')) {
                                await ref
                                    .read(bookmarksProvider.notifier)
                                    .removeEntry(m);
                              }
                            },
                          ),
                          onTap: () => _openBook(
                              context, ref,
                              bookPath: m.bookPath,
                              pageIndex: m.pageIndex ?? 1),
                        ),
                      );
                    },
                  ),
            // ── تب هایلایت‌ها ──
            highlights.isEmpty
                ? _empty(context, Icons.highlight_alt, 'هایلایتی نداری',
                    'متن را در EPUB انتخاب کن یا در PDF دکمه هایلایت بزن')
                : ListView.builder(
                    itemCount: highlights.length,
                    itemBuilder: (c, i) {
                      final h = highlights[i];
                      return Dismissible(
                        key: ValueKey('hl-${h.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red.shade700,
                          alignment: Alignment.centerLeft,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => ref
                            .read(highlightsProvider.notifier)
                            .removeEntry(h),
                        child: ListTile(
                          leading: Container(
                            width: 12,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Color(h.color),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          title: Text(
                            h.quote,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                              '${h.book} • بخش/صفحه ${h.pageIndex}'),
                          trailing: IconButton(
                            tooltip: 'حذف هایلایت',
                            icon: const Icon(Icons.delete_outline,
                                size: 20),
                            onPressed: () async {
                              if (await _confirmDelete(
                                  context,
                                  'حذف هایلایت؟',
                                  'این هایلایت حذف شود؟')) {
                                await ref
                                    .read(highlightsProvider.notifier)
                                    .removeEntry(h);
                              }
                            },
                          ),
                          onTap: () => _openBook(context, ref,
                              bookPath: h.bookPath, pageIndex: h.pageIndex),
                        ),
                      );
                    },
                  ),
            // ── تب لایتنر ──
            cards.isEmpty
                ? _empty(context, Icons.style, 'لایتنر خالی است',
                    'در دیکشنری دکمه «لایتنر» را بزن')
                : ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (c, i) {
                      final f = cards[i];
                      return Dismissible(
                        key: ValueKey('fc-${f.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red.shade700,
                          alignment: Alignment.centerLeft,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => ref
                            .read(flashcardsProvider.notifier)
                            .removeEntry(f),
                        child: ListTile(
                          leading: const Icon(Icons.style,
                              color: Color(0xFF7CB342)),
                          title: Text(f.word,
                              textDirection: TextDirection.ltr),
                          subtitle: Text(
                            f.context.isNotEmpty
                                ? '${f.meaning} — «${f.context}»'
                                : f.meaning,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: 'تلفظ',
                            icon: const Icon(Icons.volume_up, size: 20),
                            onPressed: () => DictionaryService.instance
                                .speak(f.word),
                          ),
                          onLongPress: () async {
                            if (await _confirmDelete(context, 'حذف کارت؟',
                                'کارت «${f.word}» حذف شود؟')) {
                              await ref
                                  .read(flashcardsProvider.notifier)
                                  .removeEntry(f);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

// ── ۳. آمار (واقعی) ──
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marks = ref.watch(bookmarksProvider);
    final books = ref.watch(libraryProvider);
    final highlights = ref.watch(highlightsProvider);
    final cardsList = ref.watch(flashcardsProvider);
    final finished = books.where((b) => b.progress >= 0.99).length;
    final pagesRead = books.fold<int>(0, (s, b) => s + b.lastPage);
    final cards = [
      {'t': 'کل کتاب‌ها', 'v': '${books.length}', 'i': Icons.library_books},
      {'t': 'تمام‌شده', 'v': '$finished', 'i': Icons.check_circle},
      {'t': 'نشان‌ها', 'v': '${marks.length}', 'i': Icons.bookmark},
      {'t': 'هایلایت‌ها', 'v': '${highlights.length}', 'i': Icons.highlight_alt},
      {'t': 'کارت لایتنر', 'v': '${cardsList.length}', 'i': Icons.style},
      {'t': 'صفحات خوانده', 'v': '$pagesRead', 'i': Icons.article_outlined},
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('📊 آمار مطالعه')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: cards.length,
        itemBuilder: (c, i) {
          final d = cards[i];
          return Card(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(d['i'] as IconData,
                    size: 30, color: const Color(0xFFC9A86A)),
                const SizedBox(height: 8),
                Text(d['v'] as String,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
                Text(d['t'] as String,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── ۴. تنظیمات (واقعی) ──
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const themes = {
    'paper': '☀️ کاغذی (روز)',
    'sepia': '📜 سپیا',
    'greyNight': '🌆 خاکستری (شب)',
    'amoled': '🌙 مشکی AMOLED',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final fs = ref.watch(readerFontSizeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ تنظیمات')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('تم مطالعه',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          for (final e in themes.entries)
            RadioListTile<String>(
              title: Text(e.value),
              value: e.key,
              groupValue: mode,
              onChanged: (v) =>
                  ref.read(themeModeProvider.notifier).set(v!),
            ),
          const Divider(),
          ListTile(
            title: const Text('اندازه فونت ریدر'),
            subtitle: Slider(
              min: kMinReaderFont,
              max: kMaxReaderFont,
              divisions: (kMaxReaderFont - kMinReaderFont).round(),
              value: fs,
              label: fs.toStringAsFixed(0),
              onChanged: (v) =>
                  ref.read(readerFontSizeProvider.notifier).set(v),
            ),
            trailing: Text(fs.toStringAsFixed(0)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('حریم خصوصی'),
            subtitle: const Text('داده‌ها فقط روی دستگاه شماست'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('درباره ما'),
            subtitle: const Text('سازنده، حمایت، لینک‌ها'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.menu_book),
            title: Text('Booka'),
            subtitle: Text('نسخه ۰٫۱٫۰ — Paper & Glass'),
          ),
        ],
      ),
    );
  }
}
