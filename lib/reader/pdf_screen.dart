import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../data/store.dart';
import '../dictionary/dictionary_sheet.dart';

// ریدر PDF سبک بر پایه Pdfium — رندر تنبل برای فایل‌های سنگین
class PdfReaderScreen extends ConsumerStatefulWidget {
  final String path;
  final String title;
  final int? initialPage;
  const PdfReaderScreen(
      {super.key, required this.path, required this.title, this.initialPage});

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  late PdfControllerPinch _controller;
  int _page = 1;
  int _total = 0;
  int? _pendingJump;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.path),
    );
    // صفحه مقصد: نشانِ صریحی، یا آخرین موقعیت ذخیره‌شده از کتابخانه
    var target = widget.initialPage ?? 1;
    if (widget.initialPage == null) {
      final saved = ref
          .read(libraryProvider)
          .where((b) => b.path == widget.path)
          .toList();
      if (saved.isNotEmpty && saved.first.lastPage > 1) {
        target = saved.first.lastPage;
      }
    }
    if (target > 1) {
      _pendingJump = target;
      _page = target;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDocLoaded(PdfDocument doc) {
    setState(() => _total = doc.pagesCount);
    // تعداد کل صفحه‌ها را همان اولین بار ثبت می‌کنیم تا درصد پیشرفت
    // و تخمین زمان باقی‌مانده در آمار درست باشد
    ref
        .read(libraryProvider.notifier)
        .saveProgress(widget.path, totalPages: doc.pagesCount);
    // پرش فقط بعد از لود کامل سند معتبر است
    final jump = _pendingJump;
    _pendingJump = null;
    if (jump != null && jump > 1 && jump <= doc.pagesCount) {
      _controller.jumpToPage(jump);
    }
  }

  void _saveProgress(int p) {
    if (_total > 0) {
      ref.read(libraryProvider.notifier).saveProgress(
            widget.path,
            page: p,
            totalPages: _total,
            progress: p / _total,
            anchor: 'page:$p',
          );
    }
  }

  void _addBookmark() {
    ref.read(bookmarksProvider.notifier).add(BookmarkEntry(
          book: widget.title,
          note: _total > 0 ? 'صفحه $_page از $_total' : 'صفحه $_page',
          at: DateTime.now(),
          bookPath: widget.path,
          pageIndex: _page,
        ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔖 نشان ذخیره شد — در تب نشان‌ها ببین')),
    );
  }

  // pdfx متن قابل انتخاب ندارد → هایلایت صفحه‌ای
  void _highlightPage() {
    ref.read(highlightsProvider.notifier).add(HighlightEntry(
          bookPath: widget.path,
          book: widget.title,
          quote: _total > 0 ? 'صفحه $_page از $_total' : 'صفحه $_page',
          pageIndex: _page,
          color: kHighlightColor.value,
          at: DateTime.now(),
        ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✳ صفحه هایلایت شد — در تب نشان‌ها ببین')),
    );
  }

  void _openDictionary() {
    showDictionarySheet(context, word: '', book: widget.title);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'دیکشنری',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: _openDictionary,
          ),
          IconButton(
            tooltip: 'هایلایت صفحه',
            icon: const Icon(Icons.highlight_alt),
            onPressed: _highlightPage,
          ),
          IconButton(
            tooltip: 'نشان‌گذاری صفحه',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _addBookmark,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$_page / $_total',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: _controller,
        onPageChanged: (p) {
          setState(() => _page = p);
          _saveProgress(p);
        },
        onDocumentLoaded: _onDocLoaded,
        // TODO: invert هوشمند برای PDF اسکن‌شده در تم شب (فقط متن، نه عکس)
      ),
    );
  }
}
