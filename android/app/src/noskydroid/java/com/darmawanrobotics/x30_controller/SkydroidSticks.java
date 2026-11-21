package com.darmawanrobotics.x30_controller;

import android.content.Context;

/**
 * Built without Skydroid's SDK (no rcsdk-*.aar in android/app/libs): no Skydroid sticks, the app
 * drives with a gamepad or the touch sticks.
 */
public final class SkydroidSticks {
    /** Channel values and the link state, on the main thread. */
    public interface Listener {
        void onChannels(int[] channels);

        void onState(String state);
    }

    public SkydroidSticks(Context context) {}

    /** False: this build has no Skydroid SDK. */
    public static boolean available() {
        return false;
    }

    /** No SDK, no handheld to recognize. */
    public static String device() {
        return "none";
    }

    public void start(Listener listener, boolean force) {
        listener.onState("no Skydroid SDK in this build");
    }

    public void stop() {}
}
