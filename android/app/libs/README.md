# Skydroid's SDK

Skydroid's RC SDK goes here, `rcsdk-v1.9.2.aar`: `tool/skydroid_sdk.sh fetch` gets it (from
https://gitee.com/skydroid/rcsdk-demo, `app/libs`, or a copy, checked by sha256). Then build: the
app reads the H12's own sticks, keys and switches. Without it the app builds as well and drives
with a gamepad or the touch sticks. The AAR is Skydroid's, proprietary: it is not in this
repository (`.gitignore`).
