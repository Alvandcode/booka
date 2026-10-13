import 'package:flutter_test/flutter_test.dart';
import 'package:book_reader_app/speech/speech_commands.dart';

void main() {
  const parser = SpeechCommandParser();

  group('SpeechCommandParser', () {
    test('عبارت خالی → بدون دستور', () {
      expect(parser.parse('').isCommand, isFalse);
      expect(parser.parse('   ').isCommand, isFalse);
    });

    test('دستور مستقیم فارسی', () {
      expect(parser.parse('بخوان').command, SpeechCommand.readAloud);
      expect(parser.parse('توقف').command, SpeechCommand.stopReading);
      expect(parser.parse('بعدی').command, SpeechCommand.next);
      expect(parser.parse('قبلی').command, SpeechCommand.previous);
      expect(parser.parse('مکث').command, SpeechCommand.pauseReading);
      expect(parser.parse('خروج').command, SpeechCommand.exitReader);
    });

    test('دستور مستقیم انگلیسی', () {
      expect(parser.parse('read').command, SpeechCommand.readAloud);
      expect(parser.parse('stop').command, SpeechCommand.stopReading);
      expect(parser.parse('next').command, SpeechCommand.next);
      expect(parser.parse('previous').command, SpeechCommand.previous);
      expect(parser.parse('pause').command, SpeechCommand.pauseReading);
      expect(parser.parse('exit').command, SpeechCommand.exitReader);
    });

    test('دستور داخل عبارت طولانی', () {
      expect(parser.parse('برو به صفحه بعد').command, SpeechCommand.next);
      expect(parser.parse('لطفا متوقف کن').command, SpeechCommand.stopReading);
    });

    test('متن بدون دستور → raw برمی‌گردد', () {
      final r = parser.parse('چه کتابی داری');
      expect(r.isCommand, isFalse);
      expect(r.raw, 'چه کتابی داری');
      expect(r.isEmpty, isFalse);
    });

    test('بدون تاثیر حروف اضافی', () {
      expect(parser.parse('  بخوان  ').command, SpeechCommand.readAloud);
    });
  });
}
