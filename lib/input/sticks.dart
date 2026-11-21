import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:gamepads/gamepads.dart';

import '../settings.dart';
import 'gamepad_input.dart';
import 'skydroid_input.dart';

/// Where a drive command came from.
enum StickSource { none, skydroid, gamepad, touch }

/// One reading of the sticks: forward (+ ahead), right (+ to the right), turn (+ clockwise), each
/// -1..1 after the dead zone; [hold] false when the gamepad's deadman is not held.
class StickReading {
  const StickReading(this.source, this.forward, this.right, this.turn, {this.hold = true});

  static const idle = StickReading(StickSource.none, 0, 0, 0);

  final StickSource source;
  final double forward;
  final double right;
  final double turn;
  final bool hold;

  double get strongest => [forward.abs(), right.abs(), turn.abs()].reduce((a, b) => a > b ? a : b);
}

/// The drive sticks of the handheld: the Skydroid H12's own (through its SDK), a gamepad (a
/// Retroid, any Bluetooth pad), or the touch sticks on the screen. In [InputMode.auto] the first
/// that is live drives, in that order; otherwise only the one chosen in the settings.
class Sticks extends ChangeNotifier {
  Sticks({required this.skydroid, required this.gamepad});

  final SkydroidInput skydroid;
  final GamepadInput gamepad;

  Offset _left = Offset.zero;
  Offset _right = Offset.zero;

  /// The touch sticks: x right +, y up +, each -1..1; zero when released.
  Offset get left => _left;
  Offset get right => _right;

  void touch({Offset? left, Offset? right}) {
    _left = left ?? _left;
    _right = right ?? _right;
    notifyListeners();
  }

  /// The source that drives now, under the input chosen in [settings]; none when the chosen
  /// sticks are not there.
  StickSource source(AppSettings settings) {
    switch (settings.input) {
      case InputMode.h12:
        return skydroid.live ? StickSource.skydroid : StickSource.none;
      case InputMode.gamepad:
        return gamepad.connected ? StickSource.gamepad : StickSource.none;
      case InputMode.touch:
        return StickSource.touch;
      case InputMode.auto:
        if (skydroid.live) return StickSource.skydroid;
        if (gamepad.connected) return StickSource.gamepad;
        return StickSource.touch;
    }
  }

  /// Something can drive.
  bool any(AppSettings settings) => source(settings) != StickSource.none;

  /// The touch sticks are on the screen.
  bool showTouch(AppSettings settings) => source(settings) == StickSource.touch;

  /// The command of the source that drives now.
  StickReading read(AppSettings settings) {
    final from = source(settings);
    if (from == StickSource.skydroid) {
      final map = settings.h12Channels;
      final invert = settings.h12Invert;
      return StickReading(
        StickSource.skydroid,
        GamepadInput.shaped(skydroid.axis(map[0], invert: invert[0])),
        GamepadInput.shaped(skydroid.axis(map[1], invert: invert[1])),
        GamepadInput.shaped(skydroid.axis(map[2], invert: invert[2])),
      );
    }
    if (from == StickSource.gamepad) {
      return StickReading(
        StickSource.gamepad,
        GamepadInput.shaped(gamepad.axis(GamepadAxis.leftStickY)),
        GamepadInput.shaped(gamepad.axis(GamepadAxis.leftStickX)),
        GamepadInput.shaped(gamepad.axis(GamepadAxis.rightStickX)),
        hold: !settings.deadman || gamepad.pressed(GamepadButton.rightBumper),
      );
    }
    if (from == StickSource.touch) {
      return StickReading(
        StickSource.touch,
        GamepadInput.shaped(_left.dy, 0.08),
        GamepadInput.shaped(_left.dx, 0.08),
        GamepadInput.shaped(_right.dx, 0.08),
      );
    }
    return StickReading.idle;
  }
}
