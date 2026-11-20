import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:x30_controller/input/gamepad_input.dart';
import 'package:x30_controller/input/skydroid_input.dart';
import 'package:x30_controller/input/sticks.dart';
import 'package:x30_controller/settings.dart';

Future<AppSettings> settingsWith(Map<String, Object> values) async {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(values);
  return AppSettings.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("the H12's sticks drive first, through the channels of the settings", () async {
    final settings = await settingsWith({'h12_channels': '2,1,3', 'h12_invert': '001'});
    final skydroid = SkydroidInput()
      ..onEvent([1950, 1950, 1950, 1500, 1050, 1050, 1050, 1500, 1050, 1050, 1500, 1500]);
    final sticks = Sticks(skydroid: skydroid, gamepad: GamepadInput())
      ..touch(left: const Offset(0, 1));
    final reading = sticks.read(settings);
    expect(reading.source, StickSource.skydroid);
    expect(reading.forward, 1.0);
    expect(reading.right, 1.0);
    expect(reading.turn, -1.0); // channel 3 reversed
    expect(reading.hold, isTrue);
  });

  test('without the H12 or a gamepad the touch sticks drive, when shown', () async {
    final settings = await settingsWith({});
    final sticks = Sticks(skydroid: SkydroidInput(), gamepad: GamepadInput())
      ..touch(left: const Offset(0.5, 1), right: const Offset(-1, 0));
    final reading = sticks.read(settings);
    expect(reading.source, StickSource.touch);
    expect(reading.forward, 1.0);
    expect(reading.right, greaterThan(0.4));
    expect(reading.turn, -1.0);
    expect(sticks.any(settings), isTrue);
    await settings.update(touchSticks: false);
    expect(sticks.read(settings).source, StickSource.none);
    expect(sticks.any(settings), isFalse);
  });

  test('the H12 settings keep three channels and fall back on junk', () async {
    final settings = await settingsWith({'h12_channels': '4,x', 'h12_invert': '1'});
    expect(settings.h12Channels, [2, 1, 3]);
    expect(settings.h12Invert, [false, false, false]);
    await settings.update(h12Channels: [4, 1, 3], h12Invert: [true, false, false]);
    expect(settings.h12Channels, [4, 1, 3]);
    expect(settings.h12Invert, [true, false, false]);
  });
}
