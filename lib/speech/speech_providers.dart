import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'speech_engine.dart';

/// موتور تشخیص گفتار در سطح اپ.
///
/// در تست‌ها از طریق `ProviderScope(overrides: ...)` قابل جانشینی است.
final speechEngineProvider = Provider<SpeechEngine>((ref) {
  return RealSpeechEngine();
});
