import 'dart:io';

// فقط EpubReader لازم است؛ کلاس Image این پکیج با Image فلاتر تداخل دارد
import 'package:epubx/epubx.dart' show EpubReader;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'about_page.dart';
import 'data/store.dart';
import 'dictionary/dictionary_service.dart';
import 'privacy_page.dart';
import 'reader/epub_document.dart';
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

      // فراداده‌ی واقعی کتاب (عنوان، نویسنده، کاور) جای نام فایل می‌نشیند
      final meta = await _readMetadata(dest, type);

      await ref.read(libraryProvider.notifier).import(LibraryBook(
            path: dest,
            title: meta?.title ?? base,
            type: type,
            addedAt: DateTime.now(),
            coverPath: meta?.coverPath,
            author: meta?.author,
          ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('📖 «${meta?.title ?? base}» به کتابخانه اضافه شد')));
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

  /// خواندن عنوان/نویسنده/کاور از خود فایل EPUB.
  /// برای PDF فراداده‌ای در دسترس نیست و به نام فایل تکیه می‌کنیم.
  Future<_BookMetadata?> _readMetadata(String path, String type) async {
    if (type != 'epub') return null;
    try {
      final bytes = await File(path).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      final doc = EpubDocument.fromBook(book);

      String? coverPath;
      final cover = doc.coverBytes;
      if (cover != null && cover.isNotEmpty) {
        // کاور کنار فایل کتاب ذخیره می‌شود تا با حذف کتاب پاک شود
        final file = File('$path.cover');
        await file.writeAsBytes(cover, flush: true);
        coverPath = file.path;
      }

      final title = doc.title?.trim();
      final author = doc.author?.trim();
      return _BookMetadata(
        title: (title == null || title.isEmpty) ? null : title,
        author: (author == null || author.isEmpty) ? null : author,
        coverPath: coverPath,
      );
    } catch (_) {
      // فراداده خوانده نشد — همان نام فایل استفاده می‌شود
      return null;
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
                                Expanded(child: _BookCover(book: b)),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      if (b.author != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          b.author!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(fontSize: 11),
                                        ),
                                      ],
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

class _BookMetadata {
  final String? title;
  final String? author;
  final String? coverPath;
  const _BookMetadata({this.title, this.author, this.coverPath});
}

/// کاور کتاب: تصویر واقعی اگر موجود باشد، وگرنه یک جلد تولیدی
/// که از عنوان و یک رنگ پایدار مشتق می‌شود.
class _BookCover extends StatelessWidget {
  final LibraryBook book;
  const _BookCover({required this.book});

  @override
  Widget build(BuildContext context) {
    final path = book.coverPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _fallback(context),
        );
      }
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    // رنگ از روی مسیر فایل مشتق می‌شود تا برای هر کتاب ثابت بماند
    final hue = (book.path.hashCode.abs() % 360).toDouble();
    final base = HSLColor.fromAHSL(1, hue, 0.32, 0.34).toColor();
    final top = HSLColor.fromAHSL(1, hue, 0.30, 0.20).toColor();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [top, base],
        ),
      ),
      padding: const EdgeInsets.all(10),
      alignment: Alignment.bottomRight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            book.isEpub ? Icons.auto_stories : Icons.picture_as_pdf,
            color: Colors.white.withOpacity(0.75),
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
                path: found.path,
                title: found.title,
                // در EPUB شماره ذخیره‌شده یک‌based است، ریدر صفر‌based می‌خواهد
                initialSection: pageIndex > 0 ? pageIndex - 1 : null,
              )
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
                ? const _EmptyHint(
                    icon: Icons.bookmark_border,
                    title: 'هنوز نشانی نداری',
                    hint: 'داخل ریدر دکمه بوکمارک را بزن',
                  )
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
            const _HighlightsTab(),
            // ── تب لایتنر ──
            const _FlashcardsTab(),
          ],
        ),
      ),
    );
  }
}

/// تب هایلایت‌ها با جستجوی متن کامل روی پایگاه داده.
class _HighlightsTab extends ConsumerStatefulWidget {
  const _HighlightsTab();

  @override
  ConsumerState<_HighlightsTab> createState() => _HighlightsTabState();
}

class _HighlightsTabState extends ConsumerState<_HighlightsTab> {
  final _ctrl = TextEditingController();

  /// null یعنی حالت عادی (بدون جستجو)
  List<HighlightEntry>? _results;
  bool _searching = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    setState(() => _searching = true);
    final hits = await ref.read(highlightsProvider.notifier).search(q);
    if (!mounted) return;
    setState(() {
      _results = hits;
      _searching = false;
    });
  }

  void _clear() {
    _ctrl.clear();
    setState(() => _results = null);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(highlightsProvider);
    final items = _results ?? all;
    final searching = _searching;

    if (all.isEmpty) {
      return const _EmptyHint(
        icon: Icons.highlight_alt,
        title: 'هایلایتی نداری',
        hint: 'متن را در EPUB انتخاب کن یا در PDF دکمه هایلایت بزن',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'جستجو در هایلایت‌ها...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: _clear,
                    ),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              if (v.trim().length >= 2) {
                _runSearch(v);
              } else if (v.trim().isEmpty) {
                _clear();
              } else {
                setState(() {});
              }
            },
          ),
        ),
        if (searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: items.isEmpty
              ? const _EmptyHint(
                  icon: Icons.search_off,
                  title: 'نتیجه‌ای پیدا نشد',
                  hint: 'عبارت دیگری را امتحان کن',
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (c, i) {
                    final h = items[i];
                    return Dismissible(
                      key: ValueKey('hl-${h.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red.shade700,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) =>
                          ref.read(highlightsProvider.notifier).removeEntry(h),
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
                            '${h.book} • بخش/صفحه ${h.pageIndex}'
                            '${h.note.isEmpty ? '' : ' • ${h.note}'}'),
                        trailing: IconButton(
                          tooltip: 'حذف هایلایت',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => ref
                              .read(highlightsProvider.notifier)
                              .removeEntry(h),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) {
                              final found = ref
                                  .read(libraryProvider)
                                  .where((b) => b.path == h.bookPath)
                                  .firstOrNull;
                              if (found == null) {
                                return const _MissingBook();
                              }
                              return found.isEpub
                                  ? EpubReaderScreen(
                                      path: found.path,
                                      title: found.title,
                                      initialSection:
                                          h.pageIndex > 0 ? h.pageIndex - 1 : null,
                                    )
                                  : PdfReaderScreen(
                                      path: found.path,
                                      title: found.title,
                                      initialPage: h.pageIndex,
                                    );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// تب کارت‌های لایتنر با مرور روزانه بر پایه SM-2.
class _FlashcardsTab extends ConsumerWidget {
  const _FlashcardsTab();

  Future<void> _review(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(flashcardsProvider.notifier);
    final due = await notifier.due();
    if (!context.mounted) return;
    if (due.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کارت سررسیدی برای امروز نیست ✓')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => _ReviewSheet(queue: due),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(flashcardsProvider);
    if (cards.isEmpty) {
      return const _EmptyHint(
        icon: Icons.style,
        title: 'لایتنر خالی است',
        hint: 'در دیکشنری دکمه «لایتنر» را بزن',
      );
    }
    final dueCount = cards.where((c) => c.isDue).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: FilledButton.icon(
            onPressed: () => _review(context, ref),
            icon: const Icon(Icons.play_arrow),
            label: Text(dueCount > 0
                ? 'مرور امروز ($dueCount کارت)'
                : 'مرور امروز — کارتی نیست'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: cards.length,
            itemBuilder: (c, i) {
              final f = cards[i];
              return Dismissible(
                key: ValueKey('fc-${f.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red.shade700,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) =>
                    ref.read(flashcardsProvider.notifier).removeEntry(f),
                child: ListTile(
                  leading: const Icon(Icons.style, color: Color(0xFF7CB342)),
                  title: Text(f.word, textDirection: TextDirection.ltr),
                  subtitle: Text(
                    f.context.isNotEmpty
                        ? '${f.meaning} — «${f.context}»'
                        : f.meaning,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // وضعیت زمان‌بندی SM-2 روی خود کارت
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (f.isDue)
                        const Tooltip(
                          message: 'سررسید',
                          child: Icon(Icons.schedule,
                              size: 16, color: Color(0xFFE57373)),
                        ),
                      IconButton(
                        tooltip: 'تلفظ',
                        icon: const Icon(Icons.volume_up, size: 20),
                        onPressed: () => DictionaryService.instance.speak(f.word),
                      ),
                    ],
                  ),
                  onLongPress: () =>
                      ref.read(flashcardsProvider.notifier).removeEntry(f),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// مرور کارت‌ها: اول معنی پنهان است، بعد از «نمایش پاسخ» کاربر
/// کیفیت تسلطش را می‌گوید و SM-2 بازه بعدی را حساب می‌کند.
class _ReviewSheet extends ConsumerStatefulWidget {
  final List<FlashcardEntry> queue;
  const _ReviewSheet({required this.queue});

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  int _i = 0;
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    if (_i >= queue.length) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 56),
            const SizedBox(height: 12),
            Text('${queue.length} کارت مرور شد',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('بازه مرور بعدی خودکار تنظیم شد',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بستن'),
            ),
          ],
        ),
      );
    }

    final card = queue[_i];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_i + 1} / ${queue.length}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(
            card.word,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_revealed) ...[
            Text(card.meaning,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, height: 1.9)),
            if (card.context.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('«${card.context}»',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ] else
            TextButton.icon(
              onPressed: () => setState(() => _revealed = true),
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('نمایش پاسخ'),
            ),
          const SizedBox(height: 20),
          if (_revealed) ...[
            Row(
              children: [
                for (final grade in const [
                  (0, 'فراموش'),
                  (3, 'سخت'),
                  (4, 'خوب'),
                  (5, 'آسان'),
                ]) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: OutlinedButton(
                        onPressed: () => _grade(context, card, grade.$1),
                        child: Text(grade.$2,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => DictionaryService.instance.speak(card.word),
            icon: const Icon(Icons.volume_up, size: 18),
            label: const Text('تلفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _grade(
      BuildContext context, FlashcardEntry card, int quality) async {
    await ref.read(flashcardsProvider.notifier).review(card, quality);
    if (!mounted) return;
    setState(() {
      _i++;
      _revealed = false;
    });
  }
}

class _MissingBook extends StatelessWidget {
  const _MissingBook();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('کتاب یافت نشد')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('این کتاب دیگر در کتابخانه نیست',
              textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  const _EmptyHint(
      {required this.icon, required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
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
    final started = books.where((b) => b.progress > 0.01).length;
    final dueCards = cardsList.where((c) => c.isDue).length;
    final authors = books
        .map((b) => b.author?.trim())
        .where((a) => a != null && a.isNotEmpty)
        .toSet()
        .length;

    // تخمین صفحات خوانده‌شده: برای کتاب تمام‌شده کل صفحات،
    // برای کتاب در جریان همان صفحه‌ای که کاربر روی آن است
    var pagesRead = 0;
    for (final b in books) {
      if (b.progress >= 0.99 && b.totalPages > 0) {
        pagesRead += b.totalPages;
      } else if (b.progress > 0.01) {
        pagesRead += b.lastPage;
      }
    }

    final cards = [
      {'t': 'کل کتاب‌ها', 'v': '${books.length}', 'i': Icons.library_books},
      {'t': 'شروع‌شده', 'v': '$started', 'i': Icons.play_circle_outline},
      {'t': 'تمام‌شده', 'v': '$finished', 'i': Icons.check_circle},
      {'t': 'صفحه خوانده', 'v': '$pagesRead', 'i': Icons.article_outlined},
      {'t': 'نشان‌ها', 'v': '${marks.length}', 'i': Icons.bookmark},
      {'t': 'هایلایت‌ها', 'v': '${highlights.length}', 'i': Icons.highlight_alt},
      {
        't': 'کارت لایتنر',
        'v': dueCards > 0
            ? '${cardsList.length} ($dueCards سررسید)'
            : '${cardsList.length}',
        'i': Icons.style
      },
      if (authors > 0) {'t': 'نویسنده', 'v': '$authors', 'i': Icons.person},
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
