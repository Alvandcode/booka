import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../data/store.dart';
import '../dictionary/dictionary_sheet.dart';
import 'pdf_text.dart';

/// ریدر PDF بر پایه pdfrx — انتخاب متن، هایلایت واقعی، جستجو، دیکشنری
/// و فهرست مطالب.
///
/// برخلاف نسخه قبلی که فقط «صفحه N هایلایت شد» را ثبت می‌کرد، اینجا
/// متن واقعی انتخابی ذخیره می‌شود و قابلیت‌های متنی فعال است.
class PdfReaderScreen extends ConsumerStatefulWidget {
  final String path;
  final String title;
  final int? initialPage;
  final String? initialAnchor;

  const PdfReaderScreen({
    super.key,
    required this.path,
    required this.title,
    this.initialPage,
    this.initialAnchor,
  });

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  /// مرجع سند — به viewer داده می‌شود
  late final PdfDocumentRefFile _ref =
      PdfDocumentRefFile(widget.path);

  /// null تا وقتی سند باز نشده
  PdfDocument? _doc;
  String? _error;

  /// برای پرش برنامه‌ای به صفحه
  final PdfViewerController _controller = PdfViewerController();

  /// جستجوی متن و نمایش بصری هایلایت‌ها روی صفحه.
  ///
  /// pdfrx خودش مستطیل نتایج را روی صفحه نقاشی می‌کند، پس برای نشان دادن
  /// هایلایت‌های ذخیره‌شده لازم نیست مختصات آن‌ها را نگه داریم.
  PdfTextSearcher? _searcher;

  int _total = 0;
  int _page = 1;

  /// فهرست مطالب
  List<PdfTocEntry> _toc = const [];

  /// متن انتخابی فعلی
  String _selectedText = '';

  /// چند صفحه نمونه لایه متنی داشتند — برای تشخیص PDF اسکن‌شده
  int _pagesWithText = 0;
  bool _textProbeDone = false;

  List<PdfTextHit> _searchHits = const [];
  bool _searching = false;

  /// جستجو فقط وقتی کاربر مکث کند اجرا می‌شود.
  ///
  /// بدون این، با هر حرف تایپ متن همه صفحات دوباره خوانده می‌شد که روی
  /// کتاب‌های بزرگ کند است.
  Timer? _searchDebounce;

  /// متن صفحاتی که خوانده شده — جستجو را تکراری نکند
  final Map<int, String> _textCache = {};

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searcher?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final doc = await _ref.loadDocument((_, [__]) {});
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _total = doc.pages.length;
        _page = _resolveStart();
      });
      unawaited(_loadOutline(doc));
      unawaited(_probeTextLayer(doc));
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyOpenError(e));
    }
  }

  /// پیام قابل فهم برای کاربر به‌جای متن خام انگلیسی موتور.
  static String _friendlyOpenError(Object e) {
    if (e is PdfPasswordException) {
      return 'این فایل با رمز محافظت شده است و فعلاً باز کردن فایل رمزشده پشتیبانی نمی‌شود.';
    }
    if (e is PdfException) {
      return 'این فایل خراب است یا PDF معتبر نیست و باز نمی‌شود.';
    }
    return 'خطا در باز کردن PDF. اگر فایل را جابه‌جا کرده‌ای، یک‌بار دیگر آن را وارد کن.';
  }

  /// نقطه شروع: نشان صریح، موقعیت ذخیره‌شده، یا اول
  int _resolveStart() {
    if (widget.initialPage case final p? when p >= 1 && _inRange(p)) {
      return p;
    }
    if (widget.initialAnchor case final a?) {
      final m = RegExp(r'(?:page|anchor:page):(\d+)').firstMatch(a);
      final p = m == null ? null : int.tryParse(m.group(1)!);
      if (p != null && _inRange(p)) return p;
    }
    final saved = ref
        .read(libraryProvider)
        .where((b) => b.path == widget.path)
        .firstOrNull;
    final lp = saved?.lastPage ?? 1;
    return _inRange(lp) ? lp : 1;
  }

  bool _inRange(int p) => p >= 1 && (_total == 0 || p <= _total);

  Future<void> _loadOutline(PdfDocument doc) async {
    try {
      final nodes = await doc.loadOutline();
      if (!mounted) return;
      setState(() => _toc = flattenOutline(nodes, totalPages: _total));
    } catch (_) {
      // کتاب بدون فهرست مطالب، یا فهرست خراب
    }
  }

  /// بررسی می‌کند سند لایه متنی دارد یا اسکن‌شده است.
  ///
  /// نتیجه در UI گفته می‌شود چون روی کتاب اسکن‌شده قابلیت‌های متنی کار
  /// نمی‌کنند و بهتر است کاربر بداند تا بی‌صدا شکست بخورد.
  Future<void> _probeTextLayer(PdfDocument doc) async {
    try {
      // چند صفحه از ابتدا، وسط و انتها نمونه‌برداری می‌کنیم تا کل کتاب اسکن
      // نشود — برای کتاب ۵۰۰ صفحه‌ای لازم نیست
      final sample = <int>{};
      if (_total <= 6) {
        for (var i = 1; i <= _total; i++) {
          sample.add(i);
        }
      } else {
        sample.addAll([1, 2, 3, _total ~/ 2, _total - 1, _total]);
      }

      var withText = 0;
      for (final p in sample) {
        if (PdfTextTools.hasTextLayer(await _pageText(doc, p))) withText++;
      }
      if (!mounted) return;
      setState(() {
        _pagesWithText = withText;
        _textProbeDone = true;
      });
    } catch (_) {
      if (mounted) setState(() => _textProbeDone = true);
    }
  }

  /// خواندن متن یک صفحه، با کش
  Future<String?> _pageText(PdfDocument doc, int pageNumber) async {
    final cached = _textCache[pageNumber];
    if (cached != null) return cached;
    try {
      final text = (await doc.pages[pageNumber - 1].loadText())?.fullText;
      if (text != null) _textCache[pageNumber] = text;
      return text;
    } catch (_) {
      return null;
    }
  }

  bool get _isScanned =>
      _textProbeDone && PdfTextTools.isScannedDocument(_pagesWithText, _total);

  void _onPageChanged(int? page) {
    if (page == null || page == _page) return;
    setState(() => _page = page);
    _saveProgress(page);
  }

  void _saveProgress(int p) {
    if (_total <= 0) return;
    ref.read(libraryProvider.notifier).saveProgress(
          widget.path,
          page: p,
          totalPages: _total,
          progress: p / _total,
          anchor: 'page:$p',
        );
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade800 : null,
      ));
  }

  // ── نشان و هایلایت ──

  void _addBookmark() {
    ref.read(bookmarksProvider.notifier).add(BookmarkEntry(
          book: widget.title,
          note: 'صفحه $_page از $_total',
          at: DateTime.now(),
          bookPath: widget.path,
          pageIndex: _page,
        ));
    _toast('🔖 نشان ذخیره شد — در تب نشان‌ها ببین');
  }

  /// ذخیره متن واقعی انتخابی، با شماره صفحه‌ای که کاربر روی آن است.
  ///
  /// اگر متنی انتخاب نشده باشد، به‌جای ثبت یک هایلایت بی‌معنی، به کاربر
  /// می‌گوید اول متنی انتخاب کند.
  void _highlightSelection(String? text) {
    final quote = (text ?? _selectedText).trim();
    if (quote.isEmpty) {
      _toast('اول متنی را در صفحه انتخاب کن');
      return;
    }
    ref.read(highlightsProvider.notifier).add(HighlightEntry(
          bookPath: widget.path,
          book: widget.title,
          quote: quote,
          pageIndex: _page,
          color: kHighlightColor.toARGB32(),
          at: DateTime.now(),
        ));
    setState(() => _selectedText = '');
    // همان لحظه روی صفحه نشانش می‌دهیم تا کاربر مطمئن شود ثبت شد
    final needle = _needleFor(quote);
    if (needle.isNotEmpty) _searcher?.startTextSearch(needle);
    _toast('✳ هایلایت ذخیره شد — در تب نشان‌ها ببین');
  }

  void _copySelection(String? text) {
    final t = text ?? _selectedText;
    if (t.trim().isEmpty) {
      _toast('اول متنی را انتخاب کن');
      return;
    }
    Clipboard.setData(ClipboardData(text: t));
    _toast('کپی شد');
  }

  /// دیکشنری روی اولین کلمه انگلیسی متن انتخابی
  void _lookupSelection(String? text) {
    final t = text ?? _selectedText;
    final word = PdfTextTools.firstEnglishWord(t);
    if (word.isEmpty) {
      _toast('اول یک کلمه انگلیسی را انتخاب کن');
      return;
    }
    showDictionarySheet(
      context,
      word: word,
      contextText: t.length > 120 ? '${t.substring(0, 120)}…' : t,
      book: widget.title,
    );
  }

  // ── هایلایت‌های ذخیره‌شده ──

  /// هایلایت‌های این کتاب
  ///
  /// روی PDF نمی‌توان مختصات را نگه داشت، پس به‌جای رندر ذخیره‌شده، متن
  /// انتخابی را دوباره روی همان صفحه جستجو می‌کنیم و pdfrx مستطیلش را
  /// نقاشی می‌کند. نتیجه همان چیزی است که کاربر می‌خواهد: دیدن هایلایت.
  Future<void> _openMyHighlights() async {
    final items = ref
        .watch(highlightsProvider)
        .where((h) => h.bookPath == widget.path)
        .toList()
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

    if (items.isEmpty) {
      _toast('هنوز هایلایتی برای این کتاب ثبت نشده');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (c, controller) => Column(
          children: [
            const SizedBox(height: 10),
            _grabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(
                children: [
                  Text('هایلایت‌های من',
                      style: Theme.of(c).textTheme.titleMedium),
                  const Spacer(),
                  Text('${items.length} مورد',
                      style: Theme.of(c).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: items.length,
                itemBuilder: (c, i) {
                  final h = items[i];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 13,
                      backgroundColor:
                          Color(h.color).withValues(alpha: 0.35),
                    ),
                    title: Text(h.quote,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    subtitle: Text('صفحه ${h.pageIndex}'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showHighlightOnPage(h);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// پرش به صفحه هایلایت و نقاشی آن روی صفحه
  void _showHighlightOnPage(HighlightEntry h) {
    _goToPage(h.pageIndex);
    final needle = _needleFor(h.quote);
    if (needle.isEmpty) {
      _toast('این هایلایت متن قابل نمایش ندارد', error: true);
      return;
    }
    _searcher?.startTextSearch(needle);
  }

  /// بخش قابل جستجوی یک هایلایت.
  ///
  /// کل متن هایلایت ممکن است به‌خاطر تفاوت فاصله‌ها یا نیم‌فاصله با متن
  /// استخراج‌شده یکی نباشد، پس فقط ابتدای آن را می‌جوییم.
  static String _needleFor(String quote) {
    final flat = quote.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= 40) return flat;
    return flat.substring(0, 40).trim();
  }

  // ── فهرست مطالب ──

  Future<void> _openToc() async {
    if (_toc.isEmpty) {
      _toast('این PDF فهرست مطالب ندارد');
      return;
    }
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
            _grabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
              child: Row(
                children: [
                  Text('فهرست مطالب',
                      style: Theme.of(c).textTheme.titleMedium),
                  const Spacer(),
                  Text('${_toc.length} مدخل',
                      style: Theme.of(c).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: _toc.length,
                itemBuilder: (c, i) {
                  final e = _toc[i];
                  final active = e.page == _page;
                  return ListTile(
                    dense: e.depth > 0,
                    contentPadding:
                        EdgeInsets.only(right: 16 + e.depth * 18, left: 12),
                    leading: e.depth == 0
                        ? Icon(
                            active ? Icons.bookmark : Icons.list,
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
                    subtitle:
                        e.isJumpable ? null : const Text('مقصد در دسترس نیست'),
                    trailing: e.isJumpable ? Text('${e.page}') : null,
                    onTap: e.isJumpable
                        ? () {
                            Navigator.pop(sheetContext);
                            _goToPage(e.page!);
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

  /// پرش واقعی به صفحه از طریق controller — بدون بازسازی viewer
  void _goToPage(int page) {
    if (!_inRange(page)) return;
    _controller.goToPage(pageNumber: page);
    setState(() => _page = page);
    _saveProgress(page);
  }

  // ── جستجو ──

  Future<void> _openSearch() async {
    if (_isScanned) {
      _toast('این PDF اسکن‌شده است و متن قابل جستجو ندارد', error: true);
      return;
    }
    final ctrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (c, setSheetState) {
          void run(String q) {
            _searchDebounce?.cancel();
            if (q.trim().length < 2) {
              setSheetState(() => _searching = false);
              return;
            }
            setSheetState(() => _searching = true);
            // صبر می‌کنیم تا کاربر مکث کند، وگرنه با هر حرف کل کتاب
            // دوباره خوانده می‌شود.
            _searchDebounce = Timer(
                const Duration(milliseconds: 350), () async {
              final hits = await _search(q);
              if (!mounted) return;
              setState(() {
                _searchHits = hits;
                _searching = false;
              });
              setSheetState(() {});
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
                Center(child: _grabber()),
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
                if (_searching) const LinearProgressIndicator(minHeight: 2),
                Flexible(child: _searchPanel(c, ctrl)),
              ],
            ),
          );
        },
      ),
    );
    ctrl.dispose();
    _searchDebounce?.cancel();
  }

  Widget _searchPanel(BuildContext c, TextEditingController ctrl) {
    if (_searchHits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          ctrl.text.trim().length < 2
              ? 'دو حرف یا بیشتر بنویس'
              : (_searching ? 'در حال جستجو…' : 'نتیجه‌ای پیدا نشد'),
          textAlign: TextAlign.center,
          style: Theme.of(c).textTheme.bodySmall,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${_searchHits.length} نتیجه',
            style: Theme.of(c).textTheme.bodySmall),
        const SizedBox(height: 6),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _searchHits.length,
            itemBuilder: (c, i) {
              final h = _searchHits[i];
              return ListTile(
                dense: true,
                leading: Text('${i + 1}', style: Theme.of(c).textTheme.bodySmall),
                title: Text(
                  'صفحه ${h.page}',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(h.snippet,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(c);
                  _goToPage(h.page);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// جستجو در متن صفحات، با کش
  Future<List<PdfTextHit>> _search(String query) async {
    final doc = _doc;
    final q = query.trim();
    if (doc == null || q.length < 2) return const [];

    final hits = <PdfTextHit>[];
    for (var p = 1; p <= _total; p++) {
      final text = await _pageText(doc, p);
      if (text == null) continue;
      final found = PdfTextTools.searchPage(
        pageText: text,
        pageNumber: p,
        query: q,
      );
      if (found.isNotEmpty) hits.addAll(found);
      if (hits.length >= 200) break;
    }
    return hits;
  }

  void _onSelectionChanged(PdfTextSelection selection) async {
    final text =
        selection.hasSelectedText ? await selection.getSelectedText() : '';
    if (!mounted) return;
    if (text.trim() != _selectedText.trim()) {
      setState(() => _selectedText = text);
    }
  }

  Widget _grabber() => Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey.shade700,
          borderRadius: BorderRadius.circular(5),
        ),
      );

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
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_toc.isNotEmpty)
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
            tooltip: 'هایلایت‌های من',
            icon: const Icon(Icons.highlight_outlined),
            onPressed: _openMyHighlights,
          ),
          IconButton(
            tooltip: 'نشان‌گذاری صفحه',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _addBookmark,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('صفحه $_page از $_total',
                      style: const TextStyle(fontSize: 12.5)),
                ),
                if (_isScanned)
                  Text('بدون لایه متنی',
                      style: TextStyle(
                          fontSize: 11.5, color: Colors.orange.shade200)),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isScanned) _scannedBanner(),
          Expanded(
            child: PdfViewer(
              _ref,
              controller: _controller,
              initialPageNumber: _page,
              params: PdfViewerParams(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                margin: 8,
                sizeDelegateProvider:
                    const PdfViewerSizeDelegateProviderLegacy(maxScale: 6),
                onPageChanged: _onPageChanged,
                // جستجوگر فقط وقتی ساخته می‌شود که viewer واقعاً آماده
                // باشد؛ ساختن زودتر (مثلاً همان لحظه لود سند) چون کنترلر
                // هنوز به viewer وصل نیست، با خطای null می‌ترکد.
                onViewerReady: (document, controller) {
                  if (!mounted) return;
                  _searcher?.dispose();
                  _searcher = PdfTextSearcher(controller);
                },
                textSelectionParams: PdfTextSelectionParams(
                  enabled: true,
                  showContextMenuAutomatically: true,
                  onTextSelectionChange: _onSelectionChanged,
                ),
              ),
            ),
          ),
          if (_selectedText.trim().isNotEmpty) _selectionBar(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _page > 1 ? () => _goToPage(_page - 1) : null,
                child: const Text('قبلی ›'),
              ),
              Text(
                '${(_page / (_total == 0 ? 1 : _total) * 100).round()}٪',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(
                onPressed: _total == 0 || _page < _total
                    ? () => _goToPage(_page + 1)
                    : null,
                child: const Text('‹ بعدی'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// هشدار برای کتاب اسکن‌شده
  Widget _scannedBanner() => Material(
        color: Colors.orange.withValues(alpha: 0.14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: Colors.orange.shade200),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'این PDF اسکن‌شده است؛ جستجو، هایلایت متنی و دیکشنری روی آن کار نمی‌کند.',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade100),
                ),
              ),
            ],
          ),
        ),
      );

  /// نوار عملیات روی متن انتخابی
  Widget _selectionBar() {
    final text = _selectedText;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                text.length > 90 ? '${text.substring(0, 90)}…' : text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _lookupSelection(text),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('دیکشنری'),
                ),
                TextButton.icon(
                  onPressed: () => _highlightSelection(text),
                  icon: const Icon(Icons.highlight_alt, size: 18),
                  label: const Text('هایلایت'),
                ),
                TextButton.icon(
                  onPressed: () => _copySelection(text),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('کپی'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}