# X30 Controller

**The handheld for the Deep Robotics Jueying X30 ([x30_ros](https://github.com/DarmawanRobotics/x30_ros)):
drive it, teach and run its routes, inspect a substation and record its cameras, from a Skydroid
H12 or any Android device in landscape.**

The app talks the teleop protocol v1 straight to the robot's `teleop_udp_node` (x30_bridge,
[PROTOCOL.md](https://github.com/DarmawanRobotics/x30_ros/blob/main/x30_bridge/PROTOCOL.md)) over
the robot's Wi-Fi; there is no ROS on the handheld. It started from
[PashupatiController](https://github.com/DarmawanRobotics/PashupatiController) (the same protocol,
so it drives a Pashupati robot too) and adds the X30's own parts.

## Features

**Drive**
- The Skydroid H12's own sticks (through Skydroid's SDK, [below](#skydroid-h12)): left stick drives
  and strafes, right stick turns; key A switches AUTO / REMOTE, B is STOP, C / D and switch E set
  the speed level.
- Or a gamepad (a Retroid, any Bluetooth pad), or touch sticks on the screen when there are no
  physical ones (any phone or tablet).
- AUTO / REMOTE, three speed levels, the X30's actions (stand up, sit down, stepping, gaits) as
  icons. **STOP** is the software e-stop, released by holding the button for a second.

**See**
- The inspection camera, visible or thermal (one tap switches), and the map: the route with its
  stop points, the robot's trail, the LiDAR and the robot.

**Patrol and inspect**
- Record a route and its stop points, record tags, localize, pick a route, start, pause, resume
  or end the patrol, set its speed.
- **Inspect** where the robot stands: the PTZ camera and the acoustic camera at every target of
  that inspection point (minutes); the last point and its severity on the screen.
- **Record**: the camera recorder of the robot's perception host (raw thermal frames, video,
  acoustic data) on and off by hand; it records every patrol by itself. Time, frames and the disk
  left are on the screen.

**Monitor**
- Battery, link quality, protective field, health, localization, the computer's load and the trip.

Indonesian and English.

## Install

**From CI.** Every push builds a release APK: open
[Actions](https://github.com/DarmawanRobotics/X30Controller/actions/workflows/ci.yml), pick the
latest green run, download the `x30-controller-apk` artifact, unzip it and install:

```bash
adb install -r app-release.apk
```

That APK has no Skydroid SDK: on the H12 build it yourself ([Skydroid H12](#skydroid-h12)).

**From source.** Flutter 3.35 or newer, the handheld on USB in `adb devices`:

```bash
git clone git@github.com:DarmawanRobotics/X30Controller.git && cd X30Controller
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**First connection.** Join the robot's Wi-Fi (`X30*****`, Application Manual 3.1). On the start
screen tap the version three times: the robot is `192.168.1.106:9870` (its navigation host), and
the token is the robot's `X30_TELEOP_TOKEN` (`/etc/x30/navigation.env`).

## Skydroid H12

The H12 sends its sticks over its own radio, not as an Android gamepad: only Skydroid's RC SDK
reads them on the handheld. The SDK is Skydroid's and proprietary, so it is not in this
repository:

1. Get `rcsdk-v1.9.2.aar` from Skydroid's demo, https://gitee.com/skydroid/rcsdk-demo
   (`app/libs`).
2. Put it in `android/app/libs/` and build as above. The build finds it (`build.gradle.kts`) and
   compiles the SDK reader (`android/app/src/skydroid`); without it a stub says there is none.
3. On the H12: Settings (gear), *Skydroid H12 sticks* shows the link and the channels live. Pick
   the channels of forward, strafe and turn (default 2, 1, 3: the left stick drives, the right
   stick turns) and reverse those that go the wrong way.

**A stick that does not spring back** (a throttle stick without a centring spring) must not drive:
map forward to a stick that centres by itself (CH4, the right stick's up and down, for example),
or set the stick's centring in the H12's own assistant. A released stick must read about 1500.

The keys: A (CH5) AUTO / REMOTE, B (CH6) STOP, C (CH9) / D (CH10) speed down / up, switch E
(CH7) the speed level. The robot only takes the sticks in REMOTE, and the control mux zeroes them
when the handheld falls silent.

## Controls

| | H12 | Gamepad | Touch |
|---|---|---|---|
| Drive and strafe | left stick | left stick | left touch stick |
| Turn | right stick | right stick | right touch stick |
| STOP (software e-stop) | B | B, on every page | red button |
| AUTO / REMOTE | A | Start | switch on top |
| Speed level | C / D, switch E | D-pad up / down | Settings |
| Visible / thermal camera | | | camera button by the small view |
| Robot actions | | L1 + A stand up, L1 + Y sit down | icons under STOP |

**Teach and patrol.** REMOTE, Record, drive the route, Point at each stop, Finish; then Routes,
pick it, AUTO, Start. On a stop with an inspection point the robot inspects it by itself
(x30_inspection).

## Develop

```
lib/
├── protocol/   messages.dart (JSON of the teleop protocol, the X30's recorder and substation)
├── net/        teleop_client.dart (session, commands, sticks, the camera chosen), discovery.dart
├── input/      skydroid_input.dart (the H12 through its SDK), gamepad_input.dart, sticks.dart
├── widgets/    hud, camera, map, glance, x30_panel (recorder, inspection), touch_stick, trip
├── screens/    connect, drive (home), patrol, routes, settings
├── robot_actions.dart   icons and labels of known robot commands (the X30's too)
└── l10n.dart            Indonesian and English text
android/app/src/
├── main/kotlin/…/MainActivity.kt   gamepad events, the x30/skydroid channels
├── skydroid/java/…                 the H12 reader (with the SDK)
└── noskydroid/java/…               its stub
```

```bash
flutter analyze
flutter test
```

CI runs on every push: analysis, tests (failures as annotations), formatting notices, the APK.

## License

Apache 2.0. Skydroid's SDK, when you add it, is under Skydroid's own terms.
