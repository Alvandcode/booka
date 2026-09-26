import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../dictionary/dictionary_sheet.dart';
import 'epub_document.dart';
import 'epub_text.dart';

/// ریدر EPUB — تایپوگرافی فارسی، فهرست مطالب و جستجوی درون‌کتاب.
///
/// متن هر بخش یک‌بار در [EpubText.strip] استخراج و نگه داشته می‌شود تا
/// جستجو و رندر، هر دو روی یک منبع مشترک کار کنند.
class EpubReaderScreen extends ConsumerStatefulWidget {
  final String path;
  final String title;
  final int? initialSection;
  final String? initialAnchor;

  const EpubReaderScreen({
    super.key,
    required this.path,
    required this.title,
    this.initialSection,
    this.initialAnchor,
  });

  @override
  ConsumerState<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  EpubDocument? _doc;

  /// متن استخراج‌شده هر بخش، هم‌طول با بخش‌های سند
  List<String> _texts = const [];

  String? _error;
  int _section = 0;
  String _selectedText = '';

  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  double get _fontSize => ref.watch(readerFontSizeProvider);

  void _setFont(double v) => ref
      .read(readerFontSizeProvider.notifier)
      .set(v.clamp(kMinReaderFont, kMaxReaderFont).toDouble());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      final doc = EpubDocument.fromBook(book);
      if (doc.isEmpty) {
        setState(() => _error = 'این فایل EPUB هیچ بخش متنی ندارد');
        return;
      }

      final texts = [for (final s in doc.sections) EpubText.strip(s.html)];
      setState(() {
        _doc = doc;
        _texts = texts;
        _section = _resolveStart(doc);
      });
    } catch (e) {
      setState(() => _error = 'خطا در باز کردن EPUB: $e');
    }
  }

  /// نقطه شروع: نشان صریح، موقعیت ذخیره‌شده، یا اول
  int _resolveStart(EpubDocument doc) {
    if (widget.initialSection != null) {
      final s = widget.initialSection!;
      if (s >= 0 && s < doc.length) return s;
    }
    if (widget.initialAnchor != null && widget.initialAnchor!.isNotEmpty) {
      final m = RegExp(r'^spine:(\d+)$').firstMatch(widget.initialAnchor!);
      final idx = m == null ? null : int.tryParse(m.group(1)!);
      if (idx != null && idx >= 0 && idx < doc.length) return idx;
    }
    final saved = ref
        .read(libraryProvider)
        .where((b) => b.path == widget.path)
        .firstOrNull;
    final lp = (saved?.lastPage ?? 1) - 1;
    if (lp >= 0 && lp < doc.length) return lp;
    return 0;
  }

  String get _currentText => _section < _texts.length ? _texts[_section] : '';

  String get _displayTitle {
    final t = _doc?.title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return widget.title;
  }

  void _goTo(int next, {bool scrollToTop = true}) {
    final doc = _doc;
    if (doc == null || next < 0 || next >= doc.length) return;
    setState(() => _section = next);
    if (scrollToTop && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    ref.read(libraryProvider.notifier).saveProgress(
          widget.path,
          page: next + 1,
          totalPages: doc.length,
          progress: (next + 1) / doc.length,
          anchor: 'spine:$next',
        );
  }

  void _addBookmark() {
    ref.read(bookmarksProvider.notifier).add(BookmarkEntry(
          book: _displayTitle,
          note: _doc?.sectionLabel(_section) ?? 'بخش ${_section + 1}',
          at: DateTime.now(),
          bookPath: widget.path,
          pageIndex: _section + 1,
        ));
    _toast('🔖 نشان ذخیره شد — در تب نشان‌ها ببین');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _firstWord(String s) {
    final m = RegExp(r'''[A-Za-z][A-Za-z'’-]*''').firstMatch(s);
    return m?.group(0) ?? '';
  }

  void _lookupSelection() {
    final w = _firstWord(_selectedText);
    if (w.isEmpty) {
      _toast('اول یک کلمه انگلیسی را انتخاب کن');
      return;
    }
    showDictionarySheet(
      context,
      word: w,
      contextText: _selectedText.length > 120
          ? '${_selectedText.substring(0, 120)}…'
          : _selectedText,
      book: _displayTitle,
    );
  }

  void _highlightSelection() {
    final text = _selectedText.trim();
    if (text.isEmpty) return;
    ref.read(highlightsProvider.notifier).add(HighlightEntry(
          bookPath: widget.path,
          book: _displayTitle,
          quote: text,
          pageIndex: _section + 1,
          color: kHighlightColor.value,
          at: DateTime.now(),
        ));
    setState(() => _selectedText = '');
    _toast('✳ هایلایت ذخیره شد — در تب نشان‌ها ببین');
  }

  void _copySelection() {
    Clipboard.setData(ClipboardData(text: _selectedText));
    _toast('کپی شد');
  }

  Future<void> _openToc() async {
    final doc = _doc;
    if (doc == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (c, controller) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(
                children: [
                  Text('فهرست مطالب',
                      style: Theme.of(c).textTheme.titleMedium),
                  const Spacer(),
                  Text('${doc.toc.length} فصل',
                      style: Theme.of(c).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: doc.toc.length,
                itemBuilder: (c, i) {
                  final e = doc.toc[i];
                  final active = e.sectionIndex == _section;
                  return ListTile(
                    dense: e.depth > 0,
                    // عمق در درخت ناوبری به تورفتگی ترجمه می‌شود
                    contentPadding: EdgeInsets.only(
                        right: 16 + e.depth * 18, left: 12, top: 0, bottom: 0),
                    leading: e.depth == 0
                        ? Icon(
                            active ? Icons.bookmark : Icons.menu_book_outlined,
                            size: 20,
                            color: active
                                ? Theme.of(c).colorScheme.primary
                                : null,
                          )
                        : null,
                    title: Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        fontSize: e.depth == 0 ? 15 : 13.5,
                      ),
                    ),
                    subtitle: e.isJumpable ? null : const Text('در دسترس نیست'),
                    onTap: e.isJumpable
                        ? () {
                            Navigator.pop(sheetContext);
                            _goTo(e.sectionIndex!);
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    final doc = _doc;
    if (doc == null) return;
    final ctrl = TextEditingController();
    List<SearchHit> hits = const [];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (c, setSheetState) {
          void run(String q) {
            setSheetState(() {
              hits = EpubSearch.run(
                texts: _texts,
                sectionLabels: [
                  for (var i = 0; i < doc.length; i++) doc.sectionLabel(i),
                ],
                query: q,
              );
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 10,
              bottom: 24 + MediaQuery.of(c).viewInsets.bottom,
            ),
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
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'جستجو در متن کتاب...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: run,
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: hits.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 26),
                          child: Column(
                            children: [
                              Icon(Icons.search,
                                  size: 40,
                                  color: Theme.of(c).disabledColor),
                              const SizedBox(height: 8),
                              Text(
                                ctrl.text.trim().length < 2
                                    ? 'دو حرف یا بیشتر بنویس'
                                    : 'نتیجه‌ای پیدا نشد',
                                style: Theme.of(c).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: hits.length,
                          itemBuilder: (c, i) {
                            final h = hits[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.chevron_left, size: 20),
                              title: Text(
                                h.sectionTitle,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                h.snippet,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _goTo(h.sectionIndex);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (doc == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_displayTitle, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'فهرست مطالب',
            icon: const Icon(Icons.list),
            onPressed: _openToc,
          ),
          IconButton(
            tooltip: 'جستجو در کتاب',
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: 'نشان‌گذاری',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _addBookmark,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(38),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    doc.sectionLabel(_section),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                Text(
                  '${_section + 1} / ${doc.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 6),
                // کنترل اندازه فونت در همان نوار، همیشه در دسترس
                IconButton(
                  tooltip: 'کوچک‌تر',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.text_decrease, size: 18),
                  onPressed: () => _setFont(_fontSize - 1),
                ),
                IconButton(
                  tooltip: 'بزرگ‌تر',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.text_increase, size: 18),
                  onPressed: () => _setFont(_fontSize + 1),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: SelectableText(
                _currentText,
                style: TextStyle(fontSize: _fontSize, height: 2.2),
                textAlign: TextAlign.justify,
                onSelectionChanged: (sel, cause) {
                  final txt = sel.isValid && !sel.isCollapsed
                      ? sel.textInside(_currentText)
                      : '';
                  if (txt != _selectedText) {
                    setState(() => _selectedText = txt);
                  }
                },
              ),
            ),
          ),
          if (_selectedText.trim().isNotEmpty)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _lookupSelection,
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('دیکشنری'),
                    ),
                    TextButton.icon(
                      onPressed: _highlightSelection,
                      icon: const Icon(Icons.highlight_alt, size: 18),
                      label: const Text('هایلایت'),
                    ),
                    TextButton.icon(
                      onPressed: _copySelection,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('کپی'),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _section > 0 ? () => _goTo(_section - 1) : null,
                child: const Text('قبلی ›'),
              ),
              // نوار پیشرفت جابه‌جایی سریع در کتاب
              Expanded(
                child: Slider(
                  value: _section.toDouble(),
                  min: 0,
                  max: (doc.length - 1).toDouble().clamp(1, double.infinity),
                  onChanged: (v) => _goTo(v.round(), scrollToTop: false),
                ),
              ),
              TextButton(
                onPressed:
                    _section < doc.length - 1 ? () => _goTo(_section + 1) : null,
                child: const Text('‹ بعدی'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
