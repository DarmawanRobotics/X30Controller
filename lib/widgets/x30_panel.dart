import 'package:flutter/material.dart';

import '../l10n.dart';
import '../protocol/messages.dart';
import '../theme.dart';
import 'hud.dart';

/// The X30's own state at a glance, under the small view: its camera recorder (recording, how
/// long, raw thermal frames, the disk left) and its substation inspection (the point now, the
/// last one and its severity, the two cameras). Nothing on a robot without them.
class X30Panel extends StatelessWidget {
  const X30Panel({super.key, required this.state, required this.language});

  final RobotState state;
  final String language;

  String t(String key, [Map<String, Object> args = const {}]) => tr(language, key, args);

  @override
  Widget build(BuildContext context) {
    final recorder = state.recorder;
    final substation = state.substation;
    final rows = <Widget>[
      if (recorder != null) _recorderRow(recorder),
      if (substation != null) _substationRow(substation),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Glass(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _recorderRow(RecorderStatus recorder) {
    final free = recorder.freeGb == null ? '' : ' · ${recorder.freeGb!.toStringAsFixed(0)} GB';
    if (recorder.offline) {
      return _row(Icons.videocam_off_rounded, Palette.muted, t('rec_offline'));
    }
    if (!recorder.on) {
      final text = recorder.message.isNotEmpty ? recorder.message : t('rec_idle');
      return _row(Icons.videocam_off_rounded, Palette.muted, '$text$free');
    }
    final text = t('rec_on', {
      'time': clock(recorder.seconds),
      'frames': recorder.frames,
      'why': t(recorder.reason == 'patrol' ? 'rec_patrol' : 'rec_manual'),
    });
    final failing = recorder.streams.any((s) => s.endsWith('restarting'));
    return _row(
      Icons.fiber_manual_record_rounded,
      failing ? Palette.caution : Palette.stop,
      '$text$free',
      strong: true,
    );
  }

  Widget _substationRow(SubstationStatus substation) {
    if (substation.offline) {
      return _row(Icons.thermostat_rounded, Palette.muted, t('sub_offline'));
    }
    final cameras = [if (!substation.thermal) 'IR', if (!substation.acoustic) 'PD'];
    if (substation.state == 'inspecting') {
      return _row(
        Icons.thermostat_rounded,
        Palette.auto,
        t('sub_inspecting', {'point': substation.current}),
        strong: true,
      );
    }
    if (cameras.isNotEmpty) {
      return _row(
        Icons.no_photography_rounded,
        Palette.caution,
        t('sub_cameras', {'which': cameras.join(' + ')}),
      );
    }
    if (substation.last.isNotEmpty) {
      return _row(
        Icons.thermostat_rounded,
        severityColor(substation.severity),
        '${substation.last} · ${t('sev_${substation.severity}')}',
        strong: substation.severity != 'normal',
      );
    }
    return _row(
      Icons.thermostat_rounded,
      Palette.muted,
      t(substation.state == 'disabled' ? 'sub_disabled' : 'sub_points', {
        'n': substation.points,
      }),
    );
  }

  /// h:mm:ss or m:ss of a duration in seconds.
  static String clock(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  static Color severityColor(String severity) => switch (severity) {
    'critical' => Palette.stop,
    'warning' => Palette.remote,
    'attention' => Palette.caution,
    _ => Palette.ok,
  };

  Widget _row(IconData icon, Color color, String text, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: strong ? Txt.label.copyWith(color: color) : Txt.small,
            ),
          ),
        ],
      ),
    );
  }
}
