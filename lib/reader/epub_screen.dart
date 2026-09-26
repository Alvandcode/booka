import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epubx/epubx.dart';
import 'dart:io';

import '../data/store.dart';
import '../dictionary/dictionary_sheet.dart';

// ریدر EPUB با تایپوگرافی فارسی — justify، فاصله خط قابل تنظیم
class EpubReaderScreen extends ConsumerStatefulWidget {
  final String path;
  final String title;
  final int? initialPage;
  const EpubReaderScreen(
      {super.key, required this.path, required this.title, this.initialPage});

  @override
  ConsumerState<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends ConsumerState<EpubReaderScreen> {
  EpubBook? _book;
  String? _error;
  List<String> _spineHtml = [];
  int _index = 0;
  String _selectedText = '';

  double get _fontSize => ref.watch(readerFontSizeProvider);

  void _setFont(double v) =>
      ref.read(readerFontSizeProvider.notifier).set(
            v.clamp(kMinReaderFont, kMaxReaderFont).toDouble());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final book = await EpubReader.readBook(bytes);
      final spine = book.Content?.Html?.values.toList() ?? [];
      // بازگردانی: نشانِ صریح یا آخرین موقعیت ذخیره‌شده
      var start = 0;
      if (widget.initialPage != null) {
        final p = widget.initialPage! - 1;
        if (p >= 0 && p < spine.length) start = p;
      } else {
        final saved = ref
            .read(libraryProvider)
            .where((b) => b.path == widget.path)
            .toList();
        if (saved.isNotEmpty) {
          final lp = saved.first.lastPage - 1;
          if (lp >= 0 && lp < spine.length) start = lp;
        }
      }
      setState(() {
        _book = book;
        _spineHtml = spine.map((c) => c.Content ?? '').toList();
        _index = start;
      });
    } catch (e) {
      setState(() => _error = 'خطا در باز کردن EPUB: $e');
    }
  }

  void _go(int next) {
    if (next < 0 || next >= _spineHtml.length) return;
    setState(() => _index = next);
    ref.read(libraryProvider.notifier).saveProgress(
          widget.path,
          page: next + 1,
          totalPages: _spineHtml.length,
          progress:
              _spineHtml.isEmpty ? 0 : (next + 1) / _spineHtml.length,
          anchor: 'spine:$next',
        );
  }

  void _addBookmark() {
    ref.read(bookmarksProvider.notifier).add(BookmarkEntry(
          book: _book?.Title ?? widget.title,
          note: 'بخش ${_index + 1} از ${_spineHtml.length}',
          at: DateTime.now(),
          bookPath: widget.path,
          pageIndex: _index + 1,
        ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔖 نشان ذخیره شد — در تب نشان‌ها ببین')),
    );
  }

  String get _currentText => _plainText(
      _index < _spineHtml.length ? _spineHtml[_index] : '');

  void _lookupSelection() {
    final w = _firstWord(_selectedText);
    if (w.isEmpty) return;
    showDictionarySheet(
      context,
      word: w,
      contextText: _selectedText.length > 120
          ? '${_selectedText.substring(0, 120)}…'
          : _selectedText,
      book: _book?.Title ?? widget.title,
    );
  }

  void _highlightSelection() {
    if (_selectedText.trim().isEmpty) return;
    ref.read(highlightsProvider.notifier).add(HighlightEntry(
          bookPath: widget.path,
          book: _book?.Title ?? widget.title,
          quote: _selectedText.trim(),
          pageIndex: _index + 1,
          color: kHighlightColor.value,
          at: DateTime.now(),
        ));
    setState(() => _selectedText = '');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✳ هایلایت ذخیره شد — در تب نشان‌ها ببین')),
    );
  }

  void _copySelection() {
    Clipboard.setData(ClipboardData(text: _selectedText));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('کپی شد')));
  }

  String _firstWord(String s) {
    final m = RegExp(r'''[A-Za-z][A-Za-z'’-]*''').firstMatch(s);
    return m?.group(0) ?? '';
  }

  @override
  Widget build(BuildContext context) {
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
    if (_book == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_book?.Title ?? widget.title),
        actions: [
          IconButton(
            tooltip: 'نشان‌گذاری بخش',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _addBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: () => _setFont(_fontSize + 1),
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: () => _setFont(_fontSize - 1),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              // NOTE: برای رندر کامل HTML از webview_flutter استفاده کن؛
              // این نسخه سبک، متن خام را نمایش می‌دهد تا حجم کم بماند.
              child: SelectableText(
                _currentText,
                style: TextStyle(fontSize: _fontSize, height: 2.2),
                textAlign: TextAlign.justify,
                onSelectionChanged: (sel, cause) {
                  final txt =
                      sel.isValid && !sel.isCollapsed
                          ? sel.textInside(_currentText)
                          : '';
                  setState(() => _selectedText = txt);
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
                        label: const Text('دیکشنری')),
                    TextButton.icon(
                        onPressed: _highlightSelection,
                        icon: const Icon(Icons.highlight_alt, size: 18),
                        label: const Text('هایلایت')),
                    TextButton.icon(
                        onPressed: _copySelection,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('کپی')),
                  ],
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _index > 0 ? () => _go(_index - 1) : null,
                child: const Text('قبلی ›'),
              ),
              Text('${_index + 1} / ${_spineHtml.length}'),
              TextButton(
                onPressed:
                    _index < _spineHtml.length - 1 ? () => _go(_index + 1) : null,
                child: const Text('‹ بعدی'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _plainText(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
