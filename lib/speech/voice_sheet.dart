import 'package:flutter/material.dart';

import 'speech_service.dart';

/// دکمه‌ی میکروفون برای دیکته و دستور صوتی.
///
/// با لمس، برگه‌ی گفتار را باز می‌کند؛ نتیجه از طریق [onResult] برمی‌گردد.
/// اگر تشخیص گفتار در دسترس نباشد، پیام مناسب نشان می‌دهد.
class VoiceButton extends StatefulWidget {
  const VoiceButton({
    super.key,
    required this.service,
    required this.onResult,
    this.language = SpeechLanguage.persian,
    this.onDevice = true,
    this.label = 'گفتار',
  });

  final SpeechService service;
  final void Function(String text) onResult;
  final SpeechLanguage language;
  final bool onDevice;
  final String label;

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await widget.service.initialize();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  widget.service.lastError ?? 'تشخیص گفتار در دسترس نیست'),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      final text = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _VoiceSheet(
          service: widget.service,
          language: widget.language,
          onDevice: widget.onDevice,
        ),
      );
      if (text != null && text.trim().isNotEmpty) {
        widget.onResult(text.trim());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.label,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.mic_none_outlined),
      onPressed: _open,
    );
  }
}

/// برگه‌ی گفتار: متن زنده، وضعیت و دکمه‌ی پایان.
class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet({
    required this.service,
    required this.language,
    required this.onDevice,
  });

  final SpeechService service;
  final SpeechLanguage language;
  final bool onDevice;

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet> {
  String _text = '';
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _listening = true);
    await widget.service.startListening(
      onPartial: (t) {
        if (mounted) setState(() => _text = t);
      },
      onFinal: (t) {
        if (mounted) setState(() => _text = t);
      },
      language: widget.language,
      onDevice: widget.onDevice,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
    );
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _finish() async {
    final text = await widget.service.stopListening();
    if (mounted) Navigator.pop(context, text);
  }

  Future<void> _cancel() async {
    await widget.service.cancelListening();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = widget.service.state;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _listening ? Icons.graphic_eq : Icons.mic,
                color: _listening ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _listening
                      ? 'در حال گوش‌دادن... بگویید'
                      : (state == SpeechUiState.processing
                          ? 'پردازش شد'
                          : 'گوش‌دادن متوقف شد'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: _cancel, child: const Text('انصراف')),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _text.isEmpty ? '—' : _text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _listening ? _finish : _start,
            icon: Icon(_listening ? Icons.stop : Icons.mic),
            label: Text(_listening ? 'پایان' : 'شروع دوباره'),
          ),
        ],
      ),
    );
  }
}
