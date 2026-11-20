import 'package:flutter_test/flutter_test.dart';
import 'package:x30_controller/protocol/messages.dart';
import 'package:x30_controller/widgets/x30_panel.dart';

void main() {
  test('the welcome of an X30 names its cameras, its commands are not robot actions', () {
    final welcome = Welcome.fromJson({
      'name': 'x30',
      'robot': 'x30',
      'commands': ['nav_start', 'recorder_start', 'recorder_stop', 'inspect', 'stand_up'],
      'limits': [0.8, 0.4, 1.0],
      'cameras': ['visible', 'thermal'],
    });
    expect(welcome.robot, 'x30');
    expect(welcome.cameras, ['visible', 'thermal']);
    expect(welcome.robotCommands, ['stand_up']); // without robot_commands: the others
    expect(Welcome.fromJson({'commands': <String>[]}).cameras, isEmpty);
  });

  test("the X30's recorder and substation parts of the state", () {
    final state = RobotState.fromJson({
      'seq': 3,
      'camera': 'thermal',
      'localization': 'tag:gate',
      'recorder': {
        'on': true,
        'reason': 'patrol',
        'session': '101500_patrol',
        'sec': 61,
        'frames': 60,
        'free_gb': 88.4,
        'streams': ['visible: recording', 'thermal: restarting'],
        'offline': false,
      },
      'substation': {'state': 'inspecting', 'current': 'bay1', 'severity': 'warning'},
    });
    expect(state.camera, 'thermal');
    expect(state.localizationKind, 'tag');
    expect(state.localizationTag, 'gate');
    expect(state.recorder!.on, isTrue);
    expect(state.recorder!.frames, 60);
    expect(state.recorder!.freeGb, 88.4);
    expect(state.recorder!.streams.last, 'thermal: restarting');
    expect(state.substation!.state, 'inspecting');
    expect(state.substation!.current, 'bay1');
    final pashupati = RobotState.fromJson({'localization': 'origin'});
    expect(pashupati.recorder, isNull);
    expect(pashupati.substation, isNull);
    expect(pashupati.localizationKind, 'start');
  });

  test('a recording time reads as a clock', () {
    expect(X30Panel.clock(61), '1:01');
    expect(X30Panel.clock(3725), '1:02:05');
  });
}
