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
/// Retroid, any Bluetooth pad), or the touch sticks on the screen, in that order: the first that
/// is live drives.
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

  /// Something can drive: the H12's sticks, a gamepad, or the touch sticks when shown.
  bool any(AppSettings settings) =>
      skydroid.live || gamepad.connected || settings.touchSticks;

  /// The command of the live source now.
  StickReading read(AppSettings settings) {
    if (skydroid.live) {
      final map = settings.h12Channels;
      final invert = settings.h12Invert;
      return StickReading(
        StickSource.skydroid,
        GamepadInput.shaped(skydroid.axis(map[0], invert: invert[0])),
        GamepadInput.shaped(skydroid.axis(map[1], invert: invert[1])),
        GamepadInput.shaped(skydroid.axis(map[2], invert: invert[2])),
      );
    }
    if (gamepad.connected) {
      return StickReading(
        StickSource.gamepad,
        GamepadInput.shaped(gamepad.axis(GamepadAxis.leftStickY)),
        GamepadInput.shaped(gamepad.axis(GamepadAxis.leftStickX)),
        GamepadInput.shaped(gamepad.axis(GamepadAxis.rightStickX)),
        hold: !settings.deadman || gamepad.pressed(GamepadButton.rightBumper),
      );
    }
    if (settings.touchSticks) {
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
