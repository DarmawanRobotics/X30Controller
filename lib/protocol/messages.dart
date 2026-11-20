/// JSON messages of the teleop protocol v1 (Pashupati's, with the X30's own parts: x30_ros
/// x30_bridge/PROTOCOL.md).
library;

/// Commands that belong to Pashupati itself; everything else in `welcome.commands` is the robot's.
const pashupatiCommands = {
  'set_mode',
  'estop',
  'estop_release',
  'nav_start',
  'nav_stop',
  'nav_pause',
  'nav_resume',
  'record_start',
  'record_stop',
  'mark_stop',
  'load_route',
  'get_route',
  'list_routes',
  'localize',
  'record_tags',
  'inspection_set',
  'inspection_models',
  'inspection_categories',
  'people_set',
  'nav_speed',
  'trip_reset',
  // the X30's (x30_bridge): not the robot driver's actions
  'dock',
  'undock',
  'recorder_start',
  'recorder_stop',
  'inspect',
};

double? _num(Object? value) => value is num && value.isFinite ? value.toDouble() : null;

String _str(Object? value, [String fallback = '']) => value is String ? value : fallback;

List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const <String>[];

/// `state.tags`: rows of [id, x0, y0, x1, y1, x2, y2, x3, y3]; broken rows are skipped.
List<Tag> _tags(Object? value) {
  if (value is! List) return const [];
  final out = <Tag>[];
  for (final row in value) {
    if (row is! List || row.length != 9) continue;
    final numbers = [for (final v in row) _num(v)];
    if (numbers.contains(null)) continue;
    out.add(Tag(numbers.first!.round(), [for (final v in numbers.skip(1)) v!]));
  }
  return out;
}

/// A model name as Ollama lists it: `moondream` -> `moondream:latest` (as the robot compares).
String fullModelName(String model) {
  final name = model.trim();
  return name.split('/').last.contains(':') ? name : '$name:latest';
}

/// Answer to a LAN `discover` probe.
class Beacon {
  const Beacon({
    required this.host,
    required this.name,
    required this.secured,
    required this.inUseBy,
    required this.seen,
    this.mode,
    this.battery,
  });

  factory Beacon.fromJson(Map<String, dynamic> json, String host) => Beacon(
    host: host,
    name: _str(json['name'], host),
    secured: json['secured'] == true,
    inUseBy: _str(json['in_use_by']),
    mode: json['mode'] is String ? json['mode'] as String : null,
    battery: _num(json['battery']),
    seen: DateTime.now(),
  );

  final String host;
  final String name;
  final bool secured;
  final String inUseBy;
  final String? mode;
  final double? battery;
  final DateTime seen;
}

/// WebRTC video the robot offers (MediaMTX, WHEP): `http://<robot>:<port>/<path>/whep`.
class VideoOffer {
  const VideoOffer(this.port, this.path);

  /// Null unless `welcome.video` names a valid port and path.
  static VideoOffer? fromJson(Object? json) {
    if (json is! Map) return null;
    final port = json['port'];
    final path = json['path'];
    if (port is! int || port <= 0 || port > 65535) return null;
    if (path is! String || !RegExp(r'^[A-Za-z0-9_.~-]+(/[A-Za-z0-9_.~-]+)*$').hasMatch(path)) {
      return null;
    }
    if (path.split('/').any((segment) => segment == '.' || segment == '..')) return null;
    return VideoOffer(port, path);
  }

  final int port;
  final String path;

  /// The WHEP endpoint on the robot at [host] (the address the teleop link uses).
  Uri whep(String host) =>
      Uri(scheme: 'http', host: host, port: port, pathSegments: [...path.split('/'), 'whep']);
}

/// The robot's answer to `hello`.
class Welcome {
  const Welcome({
    required this.name,
    required this.commands,
    required this.robotCommands,
    required this.limits,
    this.video,
    this.robot = '',
    this.cameras = const [],
  });

  factory Welcome.fromJson(Map<String, dynamic> json) {
    final commands = _strings(json['commands']);
    final robot = json.containsKey('robot_commands')
        ? _strings(json['robot_commands'])
        : commands.where((c) => !pashupatiCommands.contains(c)).toList();
    final raw = json['limits'];
    final limits = raw is List && raw.length == 3 && raw.every((v) => _num(v) != null)
        ? raw.map((v) => _num(v)!).toList()
        : const [0.5, 0.3, 1.0];
    return Welcome(
      name: _str(json['name']),
      commands: commands,
      robotCommands: robot,
      limits: limits,
      video: VideoOffer.fromJson(json['video']),
      robot: _str(json['robot']),
      cameras: _strings(json['cameras']),
    );
  }

  final String name;
  final List<String> commands;

  /// The robot driver's commands (std_srvs/Trigger), in the order the robot lists them.
  final List<String> robotCommands;

  /// Speed maxima [vx m/s, vy m/s, wz rad/s].
  final List<double> limits;

  /// WebRTC video, when the robot runs MediaMTX; else the camera comes as JPEG frames only.
  final VideoOffer? video;

  /// The robot's kind ('x30'); empty for Pashupati.
  final String robot;

  /// The cameras the robot streams as JPEG frames (X30: visible, thermal), the first by default.
  final List<String> cameras;

  bool has(String command) => commands.contains(command);
}

class Pose {
  const Pose(this.x, this.y, this.yaw);

  final double x;
  final double y;
  final double yaw;
}

class Battery {
  const Battery({this.percent, this.voltage, this.current, this.temperature});

  final double? percent;
  final double? voltage;
  final double? current;
  final double? temperature;
}

/// One `state` telemetry message (10 Hz).
class RobotState {
  const RobotState({
    this.seq = 0,
    this.pose,
    this.mode = 'auto',
    this.nav = 'NAV_INACTIVE',
    this.navMessage = '',
    this.mission = '',
    this.localization = 'none',
    this.recording = false,
    this.battery,
    this.driverLevel,
    this.driverMessage = '',
    this.cmd = const [0.0, 0.0, 0.0],
    this.healthOk,
    this.healthIssues = const [],
    this.estop = false,
    this.field,
    this.tags = const [],
    this.inspection,
    this.people,
    this.load,
    this.speed,
    this.trip,
    this.net,
    this.camera = '',
    this.recorder,
    this.substation,
  });

  factory RobotState.fromJson(Map<String, dynamic> json) {
    final pose = json['pose'];
    final battery = json['battery'];
    final driver = json['driver'];
    final health = json['health'];
    final cmd = json['cmd'];
    return RobotState(
      seq: json['seq'] is int ? json['seq'] as int : 0,
      pose: pose is List && pose.length == 3 && pose.every((v) => _num(v) != null)
          ? Pose(_num(pose[0])!, _num(pose[1])!, _num(pose[2])!)
          : null,
      mode: _str(json['mode'], 'auto'),
      nav: _str(json['nav'], 'NAV_INACTIVE'),
      navMessage: _str(json['nav_msg']),
      mission: _str(json['mission']),
      localization: _str(json['localization'], 'none'),
      recording: json['recording'] == true,
      battery: battery is Map
          ? Battery(
              percent: _num(battery['pct']),
              voltage: _num(battery['v']),
              current: _num(battery['a']),
              temperature: _num(battery['temp']),
            )
          : null,
      driverLevel: driver is Map && driver['level'] is int ? driver['level'] as int : null,
      driverMessage: driver is Map ? _str(driver['msg']) : '',
      cmd: cmd is List && cmd.length == 3
          ? cmd.map((v) => _num(v) ?? 0.0).toList()
          : const [0.0, 0.0, 0.0],
      healthOk: health is Map ? health['ok'] == true : null,
      healthIssues: health is Map ? _strings(health['issues']) : const [],
      estop: json['estop'] == true,
      field: json['field'] is String ? json['field'] as String : null,
      tags: _tags(json['tags']),
      inspection: InspectionStatus.fromJson(json['inspection']),
      people: PeopleStatus.fromJson(json['people']),
      load: SystemLoad.fromJson(health),
      speed: PatrolSpeed.fromJson(json['speed']),
      trip: TripStatus.fromJson(json['trip']),
      net: NetStatus.fromJson(json['net']),
      camera: _str(json['camera']),
      recorder: RecorderStatus.fromJson(json['recorder']),
      substation: SubstationStatus.fromJson(json['substation']),
    );
  }

  final int seq;
  final Pose? pose;

  /// `auto` (navigation drives) or `remote` (the handheld drives).
  final String mode;
  final String nav;
  final String navMessage;
  final String mission;
  final String localization;
  final bool recording;
  final Battery? battery;
  final int? driverLevel;
  final String driverMessage;

  /// Velocity actually sent to the robot [vx, vy, wz].
  final List<double> cmd;
  final bool? healthOk;
  final List<String> healthIssues;
  final bool estop;

  /// Protective field: clear, limited, stop, stale, off, or null.
  final String? field;

  /// AprilTags the robot sees in the camera image now.
  final List<Tag> tags;

  /// The VLM floor inspection; null when the robot runs none.
  final InspectionStatus? inspection;

  /// Person detection; null when the robot runs none.
  final PeopleStatus? people;

  /// CPU, GPU and memory use of the robot's computer, from its health monitor.
  final SystemLoad? load;

  /// Patrol speed of the navigation; null when navigation does not run.
  final PatrolSpeed? speed;

  /// Distance and speeds since the last trip_reset, counted on the robot; null on a robot
  /// without the trip meter.
  final TripStatus? trip;

  /// The robot's own internet (a ping through its modem); null when it does not check.
  final NetStatus? net;

  /// The camera the robot streams now (X30: visible or thermal).
  final String camera;

  /// The X30's camera recorder (raw thermal, video, acoustic); null without one.
  final RecorderStatus? recorder;

  /// The X30's substation inspection (thermal and partial discharge at the stop points).
  final SubstationStatus? substation;

  bool get remote => mode == 'remote';
  bool get localized => localization.isNotEmpty && localization != 'none';

  /// Where map->odom comes from: none, start (identity at the start pose), tag, pose (RViz), other.
  String get localizationKind {
    if (!localized) return 'none';
    if (localization.startsWith('apriltag') || localization.startsWith('tag:')) return 'tag';
    if (localization.startsWith('start') || localization.startsWith('origin')) return 'start';
    if (localization.contains('Pose Estimate')) return 'pose';
    return 'other';
  }

  /// The tag frame of a tag localization ('base_map' from 'apriltag "base_map" (auto start)',
  /// 'gate' from the X30's 'tag:gate').
  String? get localizationTag => localization.startsWith('tag:')
      ? localization.substring(4)
      : RegExp(r'"([^"]+)"').firstMatch(localization)?.group(1);
  bool get navPaused => nav == 'PAUSED';
  bool get navActive => !const {'NAV_INACTIVE', 'NO_PATH', 'PAUSED'}.contains(nav);
}

/// An AprilTag in the camera image.
class Tag {
  const Tag(this.id, this.corners);

  final int id;

  /// x0, y0, ... x3, y3 as fractions of the image width and height.
  final List<double> corners;
}

class RoutePoint {
  const RoutePoint(this.x, this.y, this.dwell);

  final double x;
  final double y;

  /// Seconds the robot inspects here; 0 for a plain waypoint.
  final double dwell;

  bool get isStop => dwell > 0;
}

/// `state.inspection`: the robot's VLM floor inspection (anomaly_detector_node).
class InspectionStatus {
  const InspectionStatus({
    required this.on,
    required this.state,
    this.model = '',
    this.interval = 0,
    this.error = '',
    this.count = 0,
    this.reports = 0,
    this.queue = 0,
    this.queueMax = 0,
    this.last,
  });

  /// Null unless the robot sent an inspection object.
  static InspectionStatus? fromJson(Object? json) {
    if (json is! Map) return null;
    final last = json['last'];
    return InspectionStatus(
      on: json['on'] == true,
      state: _str(json['state'], 'offline'),
      model: _str(json['model']),
      interval: _num(json['interval']) ?? 0,
      error: _str(json['error']),
      count: _num(json['count'])?.round() ?? 0,
      reports: _num(json['reports'])?.round() ?? 0,
      queue: _num(json['queue'])?.round() ?? 0,
      queueMax: _num(json['queue_max'])?.round() ?? 0,
      last: last is Map ? InspectionResult.fromJson(last) : null,
    );
  }

  final bool on;

  /// loading, running, off, error, or offline (the robot stopped hearing from the detector).
  final String state;
  final String model;

  /// Seconds between inspections: 0 back to back, > 0 every N s, < 0 only at stop points.
  final double interval;
  final String error;

  /// Inspections since the detector started.
  final int count;

  /// Findings sent to NETRA since the detector started.
  final int reports;

  /// Interval mode: frames waiting for the model (first in first out), of at most [queueMax].
  final int queue;
  final int queueMax;
  final InspectionResult? last;

  /// continuous, interval or stops.
  String get pace => interval < 0 ? 'stops' : (interval == 0 ? 'continuous' : 'interval');
}

/// The latest inspection the robot made.
class InspectionResult {
  const InspectionResult({
    required this.category,
    this.reported = false,
    this.latencyMs = 0,
    this.age,
    this.description = '',
    this.source = '',
    this.waited = 0,
  });

  factory InspectionResult.fromJson(Map<dynamic, dynamic> json) => InspectionResult(
    category: _str(json['cat'], 'none'),
    reported: json['reported'] == true,
    latencyMs: _num(json['ms'])?.round() ?? 0,
    age: _num(json['age'])?.round(),
    description: _str(json['desc']),
    source: _str(json['source']),
    waited: _num(json['waited'])?.round() ?? 0,
  );

  /// What the model saw: none for a clean floor, else a category such as trash or spill.
  final String category;

  /// Sent to NETRA as a finding.
  final bool reported;
  final int latencyMs;

  /// Seconds since this inspection; null when unknown.
  final int? age;
  final String description;

  /// periodic or stop_point.
  final String source;

  /// Seconds the frame waited in the interval queue before the model looked at it.
  final int waited;

  bool get clear => category.isEmpty || category == 'none';
}

/// A model the robot can inspect with (`inspection_models`).
class InspectionModel {
  const InspectionModel(this.name, {this.installed, this.active = false});

  /// Entries without a name are skipped.
  static List<InspectionModel> listFromJson(Object? data) {
    if (data is! List) return const [];
    final out = <InspectionModel>[];
    for (final item in data) {
      if (item is! Map) continue;
      final name = item['name'];
      if (name is! String || name.isEmpty) continue;
      final installed = item['installed'];
      out.add(
        InspectionModel(
          name,
          installed: installed is bool ? installed : null,
          active: item['active'] == true,
        ),
      );
    }
    return out;
  }

  final String name;

  /// Pulled into Ollama on the robot; null when the robot could not ask Ollama.
  final bool? installed;

  /// The model in use when the list was fetched.
  final bool active;
}

/// `state.speed`: the patrol speed and the range the handheld may set, m/s.
class PatrolSpeed {
  const PatrolSpeed(this.target, this.min, this.max);

  /// Null unless all three are numbers and 0 < min <= max.
  static PatrolSpeed? fromJson(Object? json) {
    if (json is! Map) return null;
    final target = _num(json['target']);
    final low = _num(json['min']);
    final high = _num(json['max']);
    if (target == null || low == null || high == null || low <= 0 || high < low) return null;
    return PatrolSpeed(target, low, high);
  }

  final double target;
  final double min;
  final double max;
}

/// `state.trip`: distance and speeds since the last `trip_reset`, counted on the robot from its
/// LiDAR odometry (dharma_odometry), also while no handheld is connected.
class TripStatus {
  const TripStatus({
    required this.distance,
    required this.movingSeconds,
    required this.speed,
    required this.average,
    required this.top,
    this.since,
  });

  /// Null unless the distance and the speeds are numbers.
  static TripStatus? fromJson(Object? json) {
    if (json is! Map) return null;
    final distance = _num(json['m']);
    final speed = _num(json['v']);
    if (distance == null || speed == null) return null;
    final since = _num(json['since']);
    return TripStatus(
      distance: distance,
      movingSeconds: _num(json['s']) ?? 0,
      speed: speed,
      average: _num(json['avg']) ?? 0,
      top: _num(json['max']) ?? 0,
      since: since != null && since > 0
          ? DateTime.fromMillisecondsSinceEpoch((since * 1000).round())
          : null,
    );
  }

  /// m travelled.
  final double distance;

  /// s spent moving.
  final double movingSeconds;

  /// m/s now, average while moving, and the highest.
  final double speed;
  final double average;
  final double top;

  /// When the trip was last reset.
  final DateTime? since;
}

/// "12.3 m" below a kilometre, "1.24 km" above.
String formatDistance(double metres) =>
    metres < 1000 ? '${metres.toStringAsFixed(1)} m' : '${(metres / 1000).toStringAsFixed(2)} km';

/// "m:ss" below an hour, "h:mm:ss" above.
String formatDuration(double seconds) {
  final s = seconds.floor();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final rest = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$rest' : '$m:$rest';
}

/// `state.people`: the robot's person detection (person_detector_node).
class PeopleStatus {
  const PeopleStatus({
    required this.on,
    required this.state,
    this.count,
    this.latencyMs = 0,
    this.age,
    this.backend = '',
    this.error = '',
    this.boxes = const [],
  });

  /// Null unless the robot sent a people object.
  static PeopleStatus? fromJson(Object? json) {
    if (json is! Map) return null;
    return PeopleStatus(
      on: json['on'] == true,
      state: _str(json['state'], 'offline'),
      count: _num(json['count'])?.round(),
      latencyMs: _num(json['ms'])?.round() ?? 0,
      age: _num(json['age'])?.round(),
      backend: _str(json['backend']),
      error: _str(json['error']),
      boxes: _personBoxes(json['boxes']),
    );
  }

  static List<PersonBox> _personBoxes(Object? json) {
    if (json is! List) return const [];
    final boxes = <PersonBox>[];
    for (final row in json) {
      if (row is! List || row.length != 5) continue;
      final v = [for (final x in row) _num(x)];
      if (v.contains(null)) continue;
      boxes.add(PersonBox(v[0]!, v[1]!, v[2]!, v[3]!, v[4]!));
    }
    return boxes;
  }

  final bool on;

  /// People in the last frame, as fractions of the image; empty when that frame is old.
  final List<PersonBox> boxes;

  /// loading, running, off, error, or offline (the robot stopped hearing from the detector).
  final String state;

  /// People in the last frame the robot looked at; null before the first.
  final int? count;
  final int latencyMs;

  /// Seconds since that frame; null when unknown.
  final int? age;

  /// What runs the model, e.g. onnxruntime-cpu.
  final String backend;
  final String error;
}

/// The robot's internet check (`state.net`): a ping of [target] through its modem.
class NetStatus {
  const NetStatus({required this.online, this.ms, this.loss = 0, this.target = ''});

  /// Null unless the check reports whether the robot is online.
  static NetStatus? fromJson(Object? json) {
    if (json is! Map || json['online'] is! bool) return null;
    return NetStatus(
      online: json['online'] as bool,
      ms: _num(json['ms']),
      loss: _num(json['loss']) ?? 0,
      target: _str(json['target']),
    );
  }

  /// One of the last two pings was answered.
  final bool online;

  /// Round trip of the last answer in ms; null offline.
  final double? ms;

  /// Share of the last pings that got no answer, in percent.
  final double loss;
  final String target;

  /// Online, but slow or losing a quarter of the pings.
  bool get poor => online && (loss >= 25 || (ms ?? 0) > 300);
}

/// The robot computer's load (`state.health`): percentages, memory in GB, hottest zone in C.
class SystemLoad {
  const SystemLoad({this.cpu, this.gpu, this.ram, this.ramUsed, this.ramTotal, this.temp});

  /// Null unless the health object carries at least one figure.
  static SystemLoad? fromJson(Object? json) {
    if (json is! Map) return null;
    final load = SystemLoad(
      cpu: _num(json['cpu']),
      gpu: _num(json['gpu']),
      ram: _num(json['ram']),
      ramUsed: _num(json['ram_used']),
      ramTotal: _num(json['ram_total']),
      temp: _num(json['temp']),
    );
    final figures = [load.cpu, load.gpu, load.ram, load.ramUsed, load.temp];
    return figures.every((v) => v == null) ? null : load;
  }

  final double? cpu;

  /// Null on a computer without a Jetson GPU.
  final double? gpu;
  final double? ram;
  final double? ramUsed;
  final double? ramTotal;
  final double? temp;
}

/// A detected person: corners as fractions of the camera image, and the detector's score.
class PersonBox {
  const PersonBox(this.x1, this.y1, this.x2, this.y2, this.score);

  final double x1, y1, x2, y2, score;
}

/// Finding types with a description built into the robot (others need one of their own).
const builtinFindingTypes = {'trash', 'spill', 'stain', 'floor_damage', 'fallen_person'};

/// A finding type name the robot takes (a-z, 0-9 and _, starting with a letter), or null.
String? findingTypeName(String text) {
  final name = text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  return RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(name) && name != 'none' ? name : null;
}

/// A type of finding the robot's inspection tells apart (`inspection_categories`).
class InspectionCategory {
  const InspectionCategory({
    required this.name,
    this.desc = '',
    this.report = false,
    this.builtin = false,
    this.ownDesc = false,
  });

  static List<InspectionCategory> listFromJson(Object? json) => [
    if (json is List)
      for (final entry in json)
        if (entry is Map && entry['name'] is String)
          InspectionCategory(
            name: entry['name'] as String,
            desc: _str(entry['desc']),
            report: entry['report'] == true,
            builtin: entry['builtin'] == true,
            ownDesc: entry['own_desc'] == true,
          ),
  ];

  final String name;

  /// What the model looks for, as the robot gives it.
  final String desc;

  /// Sent to NETRA as a finding; otherwise only shown.
  final bool report;

  /// The robot has a description of its own for this type.
  final bool builtin;

  /// [desc] was written by the operator.
  final bool ownDesc;

  InspectionCategory copyWith({String? desc, bool? report, bool? ownDesc}) => InspectionCategory(
    name: name,
    desc: desc ?? this.desc,
    report: report ?? this.report,
    builtin: builtin,
    ownDesc: ownDesc ?? this.ownDesc,
  );

  /// As `inspection_set` takes it: an empty desc keeps the robot's built-in text.
  Map<String, Object> toJson() => {
    'name': name,
    'desc': ownDesc || !builtin ? desc : '',
    'report': report,
  };
}

/// `state.recorder` of the X30: the camera recorder on its perception host.
class RecorderStatus {
  const RecorderStatus({
    required this.on,
    this.reason = '',
    this.session = '',
    this.seconds = 0,
    this.frames = 0,
    this.chunks = 0,
    this.videos = 0,
    this.dropped = 0,
    this.streams = const [],
    this.freeGb,
    this.message = '',
    this.offline = false,
  });

  static RecorderStatus? fromJson(Object? json) {
    if (json is! Map) return null;
    int count(String key) => _num(json[key])?.round() ?? 0;
    return RecorderStatus(
      on: json['on'] == true,
      reason: _str(json['reason']),
      session: _str(json['session']),
      seconds: count('sec'),
      frames: count('frames'),
      chunks: count('chunks'),
      videos: count('videos'),
      dropped: count('dropped'),
      streams: _strings(json['streams']),
      freeGb: _num(json['free_gb']),
      message: _str(json['msg']),
      offline: json['offline'] == true,
    );
  }

  /// Recording now.
  final bool on;

  /// patrol (a route runs) or manual (recorder_start).
  final String reason;

  /// The session's folder on the robot (`101500_patrol`).
  final String session;
  final int seconds;

  /// Raw thermal frames (.npz), acoustic chunks and MP4 segments written.
  final int frames;
  final int chunks;
  final int videos;
  final int dropped;

  /// Each camera stream and its state (`visible: recording`).
  final List<String> streams;
  final double? freeGb;
  final String message;

  /// No status from the recorder for a while.
  final bool offline;
}

/// `state.substation` of the X30: its inspection of thermal and partial discharge.
class SubstationStatus {
  const SubstationStatus({
    required this.state,
    this.site = '',
    this.points = 0,
    this.targets = 0,
    this.thermal = false,
    this.acoustic = false,
    this.current = '',
    this.last = '',
    this.severity = 'normal',
    this.ambient,
    this.message = '',
    this.offline = false,
  });

  static SubstationStatus? fromJson(Object? json) {
    if (json is! Map) return null;
    return SubstationStatus(
      state: _str(json['state'], 'idle'),
      site: _str(json['site']),
      points: _num(json['points'])?.round() ?? 0,
      targets: _num(json['targets'])?.round() ?? 0,
      thermal: json['thermal'] == true,
      acoustic: json['acoustic'] == true,
      current: _str(json['current']),
      last: _str(json['last']),
      severity: _str(json['severity'], 'normal'),
      ambient: _num(json['ambient']),
      message: _str(json['msg']),
      offline: json['offline'] == true,
    );
  }

  /// idle, inspecting or disabled.
  final String state;
  final String site;
  final int points;
  final int targets;

  /// The thermal camera and the acoustic camera are connected.
  final bool thermal;
  final bool acoustic;

  /// The point being inspected now, and the last one with its severity.
  final String current;
  final String last;

  /// normal, attention, warning or critical.
  final String severity;
  final double? ambient;
  final String message;
  final bool offline;
}
