package com.darmawanrobotics.x30_controller;

import android.content.Context;
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

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

/**
 * The sticks, keys and switches of a Skydroid handheld (H12, H12 Pro, H16, ...) through
 * Skydroid's RC SDK (rcsdk-*.aar in android/app/libs). The H12 answers a request for its
 * channel values (asked every PERIOD_MS, one request at a time); the H16 pushes them.
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

    /** True: this build has Skydroid's SDK. */
    public static boolean available() {
        return true;
    }

    public synchronized void start(Listener listener) {
        this.listener = listener;
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
        KeyManager.INSTANCE.cancelListen(pushed);
        reading = false;
        RCSDKManager.INSTANCE.disconnectRC(); // else the port stays taken
    }

    private synchronized void read() {
        if (reading) return;
        reading = true;
        if (RCSDKManager.INSTANCE.getDeviceType() == DeviceType.H16) {
            KeyManager.INSTANCE.listen(RemoteControllerKey.INSTANCE.getKeyH16Channels(), pushed);
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
        KeyManager.INSTANCE.get(RemoteControllerKey.INSTANCE.getKeyChannels(), answer);
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
