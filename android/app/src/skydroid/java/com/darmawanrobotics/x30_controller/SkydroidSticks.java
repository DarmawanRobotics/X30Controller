package com.darmawanrobotics.x30_controller;

import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;

import com.skydroid.rcsdk.KeyManager;
import com.skydroid.rcsdk.RCSDKManager;
import com.skydroid.rcsdk.SDKManagerCallBack;
import com.skydroid.rcsdk.common.DeviceType;
import com.skydroid.rcsdk.common.callback.CompletionCallbackWith;
import com.skydroid.rcsdk.common.callback.KeyListener;
import com.skydroid.rcsdk.common.error.SkyException;
import com.skydroid.rcsdk.key.RemoteControllerKey;
import com.skydroid.rcsdk.utils.RCSDKUtils;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

/**
 * The sticks, keys and switches of a Skydroid handheld (H12, H12 Pro, H16, ...) through
 * Skydroid's RC SDK (rcsdk-*.aar in android/app/libs). The H12 answers a request for its
 * channel values (asked every PERIOD_MS, one request at a time); the H16 pushes them.
 *
 * On any other device (a phone, a tablet) the SDK is never started: it knows the handhelds by
 * their model, and on an unknown one it would only fail. Every call into it is guarded, so a
 * problem of the SDK reports a state and never stops the app.
 */
public final class SkydroidSticks {
    /** Channel values (about 1050..1950, 1500 centred) and the link state, on the main thread. */
    public interface Listener {
        void onChannels(int[] channels);

        void onState(String state);
    }

    private static final long PERIOD_MS = 50;
    private static final long STUCK_MS = 400; // a request without an answer: ask again

    private final Context context;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final AtomicLong asked = new AtomicLong(0);
    private Listener listener;
    private ScheduledExecutorService poller;
    private boolean initialized;
    private boolean reading;

    private final KeyListener<int[]> pushed = (old, value) -> {
        if (value != null) deliver(value);
    };

    private final CompletionCallbackWith<int[]> answer = new CompletionCallbackWith<int[]>() {
        @Override
        public void onSuccess(int[] value) {
            asked.set(0);
            if (value != null) deliver(value);
        }

        @Override
        public void onFailure(SkyException error) {
            asked.set(0);
        }
    };

    public SkydroidSticks(Context context) {
        this.context = context.getApplicationContext();
    }

    /** True: this build has Skydroid's SDK and runs on a Skydroid handheld. */
    public static boolean available() {
        try {
            return RCSDKUtils.getDeviceType() != DeviceType.UNKNOWN;
        } catch (Throwable error) {
            return false;
        }
    }

    /** The handheld the SDK recognizes (H12, H12Pro, H16, ...), UNKNOWN on any other device. */
    public static String device() {
        try {
            return RCSDKUtils.getDeviceType().name();
        } catch (Throwable error) {
            return "UNKNOWN";
        }
    }

    /**
     * Read the sticks for listener. force: also on a model the SDK does not recognize (the H12's
     * sticks chosen in the app's settings), for a handheld with an unexpected model name.
     */
    public synchronized void start(Listener listener, boolean force) {
        this.listener = listener;
        if (!force && !available()) {
            report("not a Skydroid handheld (" + Build.MODEL + ")");
            return;
        }
        try {
            connect();
        } catch (Throwable error) {
            report("failed: " + error);
        }
    }

    private void connect() {
        if (!initialized) {
            initialized = true;
            RCSDKManager.INSTANCE.initSDK(context, new SDKManagerCallBack() {
                @Override
                public void onRcConnected() {
                    report("connected");
                    read();
                }

                @Override
                public void onRcConnectFail(SkyException error) {
                    report("failed: " + (error == null ? "?" : error.getMessage()));
                }

                @Override
                public void onRcDisconnect() {
                    report("disconnected");
                }
            });
        }
        report("connecting");
        RCSDKManager.INSTANCE.connectToRC();
    }

    public synchronized void stop() {
        listener = null;
        if (poller != null) {
            poller.shutdownNow();
            poller = null;
        }
        if (!initialized) return; // never started: nothing to release
        try {
            KeyManager.INSTANCE.cancelListen(pushed);
            RCSDKManager.INSTANCE.disconnectRC(); // else the port stays taken
        } catch (Throwable error) {
            // the app goes on; the SDK is started again with the next listener
        }
        reading = false;
    }

    private synchronized void read() {
        if (reading) return;
        reading = true;
        try {
            if (RCSDKManager.INSTANCE.getDeviceType() == DeviceType.H16) {
                KeyManager.INSTANCE.listen(RemoteControllerKey.INSTANCE.getKeyH16Channels(), pushed);
                return;
            }
        } catch (Throwable error) {
            report("failed: " + error);
            reading = false;
            return;
        }
        poller = Executors.newSingleThreadScheduledExecutor();
        poller.scheduleAtFixedRate(this::ask, 0, PERIOD_MS, TimeUnit.MILLISECONDS);
    }

    private void ask() {
        long now = System.currentTimeMillis();
        long last = asked.get();
        if (last != 0 && now - last < STUCK_MS) return; // the previous answer is still coming
        asked.set(now);
        try {
            KeyManager.INSTANCE.get(RemoteControllerKey.INSTANCE.getKeyChannels(), answer);
        } catch (Throwable error) {
            asked.set(0); // a scheduled task that throws is never run again: keep asking
        }
    }

    private void deliver(int[] channels) {
        final int[] copy = channels.clone();
        main.post(() -> {
            Listener l = listener;
            if (l != null) l.onChannels(copy);
        });
    }

    private void report(String state) {
        main.post(() -> {
            Listener l = listener;
            if (l != null) l.onState(state);
        });
    }
}
