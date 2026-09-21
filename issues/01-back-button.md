# 01 — Android back button does nothing on device

**Blocks release: yes.** Owner-reported, reproduced on hardware only.

Pressing back on an Android device does nothing at any screen. Three fixes have
been attempted and none worked.

## What has been ruled out

- `application/config/quit_on_go_back = false` — set, and verified present in
  the built `project.binary`.
- Predictive back — `android:enableOnBackInvokedCallback="false"` at
  `android/build/src/main/AndroidManifest.xml:26`. `aapt2 dump xmltree` on the
  built APK confirms the attribute ships, and gradle's merge blame names that
  file as its source. `gradle_build/use_gradle_build=true`, so the custom build
  is the one being used.
- Event consumption — handling moved from `_unhandled_input` to `_input` so a
  focused Button cannot eat the key first. Nothing else in the project touches
  `KEY_BACK`, `ui_cancel` or `NOTIFICATION_WM_GO_BACK_REQUEST`, and nothing
  calls `set_input_as_handled()` ahead of `Main`.
- Godot 4.6 delivery path traced end to end: `GodotActivity.kt` →
  `onBackPressedDispatcher` → `Godot.kt:1134` → `GodotLib.back()` →
  `java_godot_lib_jni.cpp:264` → `WINDOW_EVENT_GO_BACK_REQUEST` →
  `_propagate_window_notification`, which reaches `Main`.

No code-level break was found, which is why no fourth blind fix has been made.

## Known dead end

The `KEY_BACK` fallback in `scripts/main.gd` is dead code on Android:
`GodotInputHandler.java` maps `KEYCODE_BACK` only for gamepads. A system back
press never becomes an `InputEventKey`. If the diagnostic ever reports
"BACK via KEY", something unexpected is happening.

## Next step — needs the device

A diagnostic build is with the owner. `_handle_back_action()` names the route
and outcome on a banner drawn above the HUD and above all modals, and prints to
`adb logcat`. See [02](02-back-diagnostic-still-on.md).

- **Banner appears** → the event arrives; the fault is in our handling. Quick fix.
- **Nothing appears** → the event never reaches Godot. Android-side problem.

Also worth capturing: whether the device uses gesture navigation or 3-button,
the phone model, and the Android version.

Files: `scripts/main.gd`, `android/build/src/main/AndroidManifest.xml`
