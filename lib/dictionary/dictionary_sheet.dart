import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import 'dictionary_service.dart';

const kHighlightColor = Color(0xFFFFE08A);

/// باتم‌شیت واقعی دیکشنری — جستجوی آفلاین + تلفظ + افزودن به لایتنر
Future<void> showDictionarySheet(
  BuildContext context, {
  required String word,
  String contextText = '',
  String book = '',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _DictionaryBody(
      word: word,
      contextText: contextText,
      book: book,
    ),
  );
}

class _DictionaryBody extends ConsumerStatefulWidget {
  final String word;
  final String contextText;
  final String book;
  const _DictionaryBody(
      {required this.word, required this.contextText, required this.book});

  @override
  ConsumerState<_DictionaryBody> createState() => _DictionaryBodyState();
}

class _DictionaryBodyState extends ConsumerState<_DictionaryBody> {
  late String _word;
  late Future<List<String>> _future;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _word = widget.word;
    _controller = TextEditingController(text: widget.word);
    _future = DictionaryService.instance.lookup(_word);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String w) {
    final q = w.trim();
    if (q.isEmpty) return;
    setState(() {
      _word = q;
      _future = DictionaryService.instance.lookup(q);
    });
  }

  void _speak() => DictionaryService.instance.speak(_word);

  void _copy(List<String> meanings) {
    Clipboard.setData(ClipboardData(text: '$_word: ${meanings.join('، ')}'));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('معنی کپی شد')));
  }

  void _addToLightner(List<String> meanings) {
    if (meanings.isEmpty) return;
    final now = DateTime.now();
    ref.read(flashcardsProvider.notifier).add(FlashcardEntry(
          word: _word,
          meaning: meanings.first,
          context: widget.contextText,
          book: widget.book,
          at: now,
          // اولین مرور یک روز بعد — سپس الگوریتم SM-2 فاصله را خودش حساب می‌کند
          dueAt: now.add(const Duration(days: 1)),
        ));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('🗂 «$_word» به لایتنر اضافه شد')));
  }

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 10,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
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
                      borderRadius: BorderRadius.circular(5)))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _controller,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  decoration: const InputDecoration(
                    hintText: 'جستجوی کلمه...',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: _search,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.search),
                onPressed: () => _search(_controller.text),
              ),
            ],
          ),
          if (_word.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'کلمه‌ای بنویس و جستجو کن — کاملاً آفلاین ✓',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            const SizedBox(height: 14),
          if (_word.isEmpty)
            const SizedBox.shrink()
          else
            Flexible(
            child: FutureBuilder<List<String>>(
              future: _future,
              builder: (c, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final meanings = snap.data ?? [];
                if (meanings.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: [
                        Icon(Icons.search_off,
                            size: 40,
                            color: Theme.of(context).disabledColor),
                        const SizedBox(height: 8),
                        Text('«$_word» در دیکشنری آفلاین پیدا نشد',
                            textAlign: TextAlign.center),
                        Text('املا را چک کن یا کلمه دیگری بنویس',
                            style: ts.bodySmall),
                      ],
                    ),
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(_word,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                          ),
                          IconButton(
                              tooltip: 'تلفظ',
                              icon: const Icon(Icons.volume_up),
                              onPressed: _speak),
                        ],
                      ),
                      Text('${meanings.length} معنی • آفلاین ✓',
                          style: ts.bodySmall),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: kHighlightColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: kHighlightColor.withOpacity(0.3)),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          meanings.join('، '),
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(height: 1.9),
                        ),
                      ),
                      if (widget.contextText.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('از متن: «${widget.contextText}»',
                            style: ts.bodySmall,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                                onPressed: () => _addToLightner(meanings),
                                icon: const Icon(Icons.add),
                                label: const Text('لایتنر')),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                                onPressed: () => _copy(meanings),
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('کپی')),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
