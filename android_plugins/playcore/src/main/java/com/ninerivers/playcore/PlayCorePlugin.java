package com.ninerivers.playcore;

import android.app.Activity;
import android.content.Intent;

import androidx.annotation.NonNull;

import com.google.android.play.core.appupdate.AppUpdateInfo;
import com.google.android.play.core.appupdate.AppUpdateManager;
import com.google.android.play.core.appupdate.AppUpdateManagerFactory;
import com.google.android.play.core.appupdate.AppUpdateOptions;
import com.google.android.play.core.install.InstallStateUpdatedListener;
import com.google.android.play.core.install.model.AppUpdateType;
import com.google.android.play.core.install.model.InstallStatus;
import com.google.android.play.core.install.model.UpdateAvailability;
import com.google.android.play.core.review.ReviewManager;
import com.google.android.play.core.review.ReviewManagerFactory;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

/**
 * Play's flexible in-app update - Play shows its own "update available" sheet,
 * downloads in the background while the game keeps running, and the game asks
 * the player when to restart into the new version - and Play's in-app review
 * card.
 *
 * The plugin only reports and acts; when to ask, and how often, is decided in
 * GDScript (scripts/autoload/update_manager.gd, review_manager.gd).
 */
public class PlayCorePlugin extends GodotPlugin {
    private static final int UPDATE_REQUEST_CODE = 0x4E52;

    private AppUpdateManager manager;
    private AppUpdateInfo lastInfo;
    private boolean listening;

    private final InstallStateUpdatedListener installListener = state -> {
        int status = state.installStatus();
        if (status == InstallStatus.DOWNLOADED) {
            emitSignal("update_downloaded");
        } else if (status == InstallStatus.FAILED) {
            emitSignal("update_failed", "install status " + state.installErrorCode());
            stopListening();
        } else if (status == InstallStatus.CANCELED || status == InstallStatus.INSTALLED) {
            stopListening();
        }
    };

    public PlayCorePlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "NineRiversPlayCore";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("update_available", Integer.class));
        signals.add(new SignalInfo("update_not_available"));
        signals.add(new SignalInfo("update_downloaded"));
        signals.add(new SignalInfo("update_declined"));
        signals.add(new SignalInfo("update_failed", String.class));
        signals.add(new SignalInfo("review_done"));
        signals.add(new SignalInfo("review_failed", String.class));
        return signals;
    }

    private AppUpdateManager manager() {
        if (manager == null) {
            Activity activity = getActivity();
            if (activity == null) {
                return null;
            }
            manager = AppUpdateManagerFactory.create(activity);
        }
        return manager;
    }

    /** Emits exactly one of update_available, update_downloaded, update_not_available or update_failed. */
    @UsedByGodot
    public void checkForUpdate() {
        AppUpdateManager m = manager();
        if (m == null) {
            emitSignal("update_failed", "no activity");
            return;
        }
        m.getAppUpdateInfo()
                .addOnSuccessListener(info -> {
                    lastInfo = info;
                    if (info.installStatus() == InstallStatus.DOWNLOADED) {
                        emitSignal("update_downloaded");
                    } else if (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
                            && info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) {
                        emitSignal("update_available", info.availableVersionCode());
                    } else {
                        emitSignal("update_not_available");
                    }
                })
                .addOnFailureListener(e -> emitSignal("update_failed", String.valueOf(e.getMessage())));
    }

    /** Opens Play's update sheet for the update found by the last checkForUpdate(). */
    @UsedByGodot
    public void startUpdate() {
        final Activity activity = getActivity();
        final AppUpdateManager m = manager();
        final AppUpdateInfo info = lastInfo;
        if (activity == null || m == null || info == null) {
            emitSignal("update_failed", "nothing to start");
            return;
        }
        lastInfo = null;
        runOnUiThread(() -> {
            try {
                if (!listening) {
                    m.registerListener(installListener);
                    listening = true;
                }
                boolean started = m.startUpdateFlowForResult(info, activity,
                        AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build(), UPDATE_REQUEST_CODE);
                if (!started) {
                    emitSignal("update_failed", "flow not started");
                }
            } catch (Exception e) {
                emitSignal("update_failed", String.valueOf(e.getMessage()));
            }
        });
    }

    /** Restarts into the downloaded version. */
    @UsedByGodot
    public void completeUpdate() {
        AppUpdateManager m = manager();
        if (m != null) {
            m.completeUpdate();
        }
    }

    /**
     * Shows Play's rating card. Play decides whether it actually appears (it
     * has its own quota) and never says what the player did, so review_done
     * only means the flow is over.
     */
    @UsedByGodot
    public void requestReview() {
        final Activity activity = getActivity();
        if (activity == null) {
            emitSignal("review_failed", "no activity");
            return;
        }
        final ReviewManager reviews = ReviewManagerFactory.create(activity);
        reviews.requestReviewFlow().addOnCompleteListener(request -> {
            if (!request.isSuccessful()) {
                emitSignal("review_failed", String.valueOf(request.getException()));
                return;
            }
            reviews.launchReviewFlow(activity, request.getResult())
                    .addOnCompleteListener(flow -> emitSignal("review_done"));
        });
    }

    @Override
    public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        super.onMainActivityResult(requestCode, resultCode, data);
        if (requestCode == UPDATE_REQUEST_CODE && resultCode != Activity.RESULT_OK) {
            emitSignal("update_declined");
        }
    }

    @Override
    public void onMainDestroy() {
        stopListening();
        super.onMainDestroy();
    }

    private void stopListening() {
        if (listening && manager != null) {
            manager.unregisterListener(installListener);
        }
        listening = false;
    }
}
