import 'package:flutter_test/flutter_test.dart';
import 'package:x30_controller/input/skydroid_input.dart';

/// Twelve H12 channels: sticks 1..4, keys A 5 and B 6, switch E 7, keys C 9 and D 10.
List<int> channels({
  int ch1 = 1500,
  int ch2 = 1500,
  int ch3 = 1500,
  int keyA = 1050,
  int keyB = 1050,
  int e = 1050,
}) => [ch1, ch2, ch3, 1500, keyA, keyB, e, 1500, 1050, 1050, 1500, 1500];

void main() {
  test('the H12 channels become axes, the middle is zero', () {
    final input = SkydroidInput()..onEvent(channels(ch1: 1950, ch2: 1275));
    expect(input.live, isTrue);
    expect(input.axis(1), 1.0);
    expect(input.axis(2), closeTo(-0.5, 1e-9));
    expect(input.axis(2, invert: true), closeTo(0.5, 1e-9));
    expect(input.axis(3), 0.0);
    expect(input.axis(13), 0.0); // no such channel
  });

  test('a key counts once when it goes down, the E switch sets the speed level', () async {
    final input = SkydroidInput();
    final keys = <SkydroidKey>[];
    final levels = <int>[];
    input.presses.listen(keys.add);
    input.levels.listen(levels.add);
    input.onEvent(channels());
    input.onEvent(channels(keyB: 1950));
    input.onEvent(channels(keyB: 1950)); // still held
    input.onEvent(channels(keyA: 1950, e: 1500));
    input.onEvent(channels(e: 1950));
    await Future<void>.delayed(Duration.zero);
    expect(keys, [SkydroidKey.b, SkydroidKey.a]);
    expect(levels, [1, 2, 3]);
  });

  test('the link state comes as text and junk is ignored', () {
    final input = SkydroidInput()
      ..onEvent('connected')
      ..onEvent(42)
      ..onEvent(<Object?>[]);
    expect(input.state, 'connected');
    expect(input.channels, isEmpty);
    expect(input.live, isFalse);
    expect(SkydroidInput.levelOf(const [1500]), isNull);
  });
}
