# 15 — Keystore password stored in plaintext

**Status:** PENDING — needs the owner, tooling is ready
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-25
**Resolved:** —

**Blocks release: no. Hygiene — but the expensive kind.**

The release keystore password sits in plaintext in `export_presets.cfg`. That
file is gitignored, so it is not in version control, but it is readable by
anything that can read the working directory.

Losing or leaking a release keystore is unrecoverable. Play will not accept an
app signed with a different key, so the app can never be updated again — not
patched, not fixed, not re-released under the same listing.

## Why this is not done for you

Moving the password means reading it, and that is refused here by design. The
value should pass from the file to your password manager without going through
a transcript. Everything around it is built and tested.

## The move — once, about two minutes

Godot 4.6.2 reads these three environment variables and they take precedence
over the preset, so the preset fields can be left empty. Verified present in
the shipping binary:

    GODOT_ANDROID_KEYSTORE_RELEASE_PATH
    GODOT_ANDROID_KEYSTORE_RELEASE_USER
    GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD

1. Open `export_presets.cfg`, find `keystore/release_password` under
   `[preset.0]`, and put the value somewhere durable — a password manager, not
   a file beside the project.
2. Create `%USERPROFILE%\.ninerivers\android_release.env`:

       GODOT_ANDROID_KEYSTORE_RELEASE_PATH=D:/path/to/nine_rivers.jks
       GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias>
       GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<password>

3. Blank the three `keystore/release*` fields in `export_presets.cfg` for both
   presets.
4. Build with `tools/build_android.sh aab` (or `apk`). It refuses to run
   without the env file, checks all three values are set, checks the keystore
   file actually exists, and never echoes any of them.

## Also worth doing, and not done by any of the above

- **Back the `.jks` file up somewhere separate.** This is the part that cannot
  be recovered. The password can be changed; the key cannot be replaced.
- `export_presets.cfg` being gitignored also means export filter changes are
  not version controlled — a fresh clone will not have them.

Files: `export_presets.cfg` (gitignored), `tools/build_android.sh`
