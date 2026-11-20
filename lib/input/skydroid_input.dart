import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A key or switch of the Skydroid handheld that the drive screen acts on.
enum SkydroidKey { a, b, c, d }

/// The Skydroid H12's own sticks, keys and switches (Skydroid's RC SDK, android/app/libs), as
/// channel values about 1050..1950 with 1500 in the middle. The H12 sends them over its radio,
/// not as a gamepad, so only the SDK reads them; a build without it reports [available] false.
class SkydroidInput extends ChangeNotifier {
  SkydroidInput({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('x30/skydroid'),
      _events = events ?? const EventChannel('x30/skydroid/channels');

  static const center = 1500.0;
  static const span = 450.0; // 1050..1950
  static const pressedAbove = 1700; // a key down reads about 1950

  /// The keys on the channels of the H12 (1-based): A 5, B 6, C 9, D 10.
  static const keyChannels = {SkydroidKey.a: 5, SkydroidKey.b: 6, SkydroidKey.c: 9, SkydroidKey.d: 10};

  /// The three-position switch E (channel 7): the speed level.
  static const levelChannel = 7;

  final MethodChannel _methods;
  final EventChannel _events;
  StreamSubscription<Object?>? _subscription;
  final _presses = StreamController<SkydroidKey>.broadcast();
  final _levels = StreamController<int>.broadcast();
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// This build has Skydroid's SDK.
  bool available = false;

  /// The SDK's link to the handheld's controls: connecting, connected, failed: ..., disconnected.
  String state = '';

  /// The newest channel values (empty before the first).
  List<int> channels = const [];

  /// Key presses (down edges only).
  Stream<SkydroidKey> get presses => _presses.stream;

  /// The speed level the E switch was moved to (1..3).
  Stream<int> get levels => _levels.stream;

  /// Channel values arrived in the last half second.
  bool get live => DateTime.now().difference(_last) < const Duration(milliseconds: 500);

  Future<void> start() async {
    try {
      available = await _methods.invokeMethod<bool>('available') ?? false;
    } on PlatformException {
      available = false;
    } on MissingPluginException {
      available = false; // tests, desktop: no Android side
    }
    if (!available) return;
    _subscription ??= _events.receiveBroadcastStream().listen(
      onEvent,
      onError: (Object error) {
        state = 'error: $error';
        notifyListeners();
      },
    );
  }

  /// One event of the Android side: the channel values, or the link state as text.
  @visibleForTesting
  void onEvent(Object? event) {
    if (event is String) {
      state = event;
      notifyListeners();
      return;
    }
    if (event is! List) return;
    final values = event.whereType<int>().toList(growable: false);
    if (values.isEmpty) return;
    final before = channels;
    channels = values;
    _last = DateTime.now();
    for (final MapEntry(key: key, value: channel) in keyChannels.entries) {
      if (_down(values, channel) && !_down(before, channel)) _presses.add(key);
    }
    final level = levelOf(values);
    if (level != null && level != levelOf(before)) _levels.add(level);
    notifyListeners();
  }

  static bool _down(List<int> values, int channel) =>
      values.length >= channel && values[channel - 1] > pressedAbove;

  /// The speed level of the E switch: up 1, middle 2, down 3 (null without the channel).
  static int? levelOf(List<int> values) {
    if (values.length < levelChannel) return null;
    final value = values[levelChannel - 1];
    return value < 1300 ? 1 : (value > 1700 ? 3 : 2);
  }

  /// A channel (1-based) as -1..1, inverted when asked; 0 when missing.
  double axis(int channel, {bool invert = false}) {
    if (channel < 1 || channels.length < channel) return 0;
    final value = ((channels[channel - 1] - center) / span).clamp(-1.0, 1.0);
    return invert ? -value : value;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _presses.close();
    _levels.close();
    super.dispose();
  }
}
