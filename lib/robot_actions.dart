import 'package:flutter/material.dart';

/// How a robot driver command looks on the action rail.
class RobotAction {
  const RobotAction(this.name, this.icon, this.labelId, this.labelEn, {this.confirm = false});

  final String name;
  final IconData icon;
  final String labelId;
  final String labelEn;

  /// Ask before running: the robot drops, jumps or changes control.
  final bool confirm;

  String label(String language) => language == 'id' ? labelId : labelEn;
}

const _known = <RobotAction>[
  RobotAction('stand_up', Icons.accessibility_new_rounded, 'Berdiri', 'Stand up'),
  RobotAction('sit_down', Icons.airline_seat_recline_normal_rounded, 'Duduk', 'Sit down'),
  RobotAction('lie_down', Icons.bed_rounded, 'Rebah', 'Lie down'),
  RobotAction('recovery_stand', Icons.restart_alt_rounded, 'Bangkit', 'Recover'),
  RobotAction('balance_stand_mode', Icons.balance_rounded, 'Seimbang', 'Balance'),
  RobotAction('balance_stand', Icons.balance_rounded, 'Seimbang', 'Balance'),
  RobotAction('move_mode', Icons.directions_walk_rounded, 'Mode jalan', 'Walk mode'),
  RobotAction('lock_mode', Icons.lock_rounded, 'Kunci', 'Lock'),
  RobotAction('damp', Icons.power_settings_new_rounded, 'Lemaskan', 'Damp', confirm: true),
  RobotAction('slow_speed', Icons.speed_rounded, 'Gigi pelan', 'Slow gear'),
  RobotAction('normal_speed', Icons.speed_rounded, 'Gigi normal', 'Normal gear'),
  RobotAction('fast_speed', Icons.fast_forward_rounded, 'Gigi cepat', 'Fast gear'),
  RobotAction('crawl_forward', Icons.pets_rounded, 'Merangkak', 'Crawl', confirm: true),
  RobotAction(
    'climbing_high_platform',
    Icons.stairs_rounded,
    'Naik platform',
    'Climb platform',
    confirm: true,
  ),
  RobotAction(
    'hand_stand',
    Icons.sports_gymnastics_rounded,
    'Handstand',
    'Handstand',
    confirm: true,
  ),
  RobotAction('unload_squat', Icons.download_rounded, 'Jongkok', 'Squat', confirm: true),
  RobotAction('hello', Icons.waving_hand_rounded, 'Sapa', 'Hello'),
  RobotAction('stretch', Icons.self_improvement_rounded, 'Peregangan', 'Stretch'),
  RobotAction('dance', Icons.music_note_rounded, 'Joget', 'Dance', confirm: true),
  RobotAction(
    'enter_lab_mode',
    Icons.science_rounded,
    'Masuk mode lab',
    'Lab mode on',
    confirm: true,
  ),
  RobotAction('exit_lab_mode', Icons.science_outlined, 'Keluar mode lab', 'Lab mode off'),
  RobotAction(
    'enter_entertainment_mode',
    Icons.celebration_rounded,
    'Mode hiburan',
    'Fun mode on',
    confirm: true,
  ),
  RobotAction(
    'exit_entertainment_mode',
    Icons.celebration_outlined,
    'Keluar hiburan',
    'Fun mode off',
  ),
  RobotAction(
    'sdk_control_right',
    Icons.sports_esports_rounded,
    'Ambil kendali',
    'Take control',
  ),
  RobotAction(
    'remote_control_right',
    Icons.settings_remote_rounded,
    'Kendali ke remote',
    'Give to remote',
    confirm: true,
  ),
  // the X30 (x30_driver): stepping in place before it walks, its gaits
  RobotAction('start_stepping', Icons.directions_walk_rounded, 'Mulai melangkah', 'Start stepping'),
  RobotAction('stop_stepping', Icons.front_hand_rounded, 'Berhenti melangkah', 'Stop stepping'),
  RobotAction('torque_control', Icons.fitness_center_rounded, 'Mode torsi', 'Torque stand'),
  RobotAction('gait_walk', Icons.hiking_rounded, 'Gait jalan', 'Walk gait'),
  RobotAction('gait_off_road', Icons.terrain_rounded, 'Gait off-road', 'Off-road gait'),
  RobotAction('gait_slope', Icons.trending_up_rounded, 'Gait tanjakan', 'Slope gait'),
  RobotAction('gait_stair', Icons.stairs_rounded, 'Gait tangga', 'Stair gait', confirm: true),
  RobotAction('gait_silent', Icons.volume_off_rounded, 'Gait senyap', 'Silent gait'),
  RobotAction('height_normal', Icons.height_rounded, 'Tinggi normal', 'Normal height'),
  RobotAction('height_crawl', Icons.vertical_align_bottom_rounded, 'Rendah', 'Crawl height'),
  RobotAction(
    'emergency_stop',
    Icons.dangerous_rounded,
    'Stop motor',
    'Motor stop',
    confirm: true,
  ),
];

final _byName = {for (final action in _known) action.name: action};

/// The catalog entry of a command, or a generic one built from its name.
RobotAction robotAction(String name) {
  final known = _byName[name];
  if (known != null) return known;
  final words = name.replaceAll('_', ' ').trim();
  final label = words.isEmpty ? name : words[0].toUpperCase() + words.substring(1);
  return RobotAction(name, Icons.bolt_rounded, label, label);
}
