# 15 — Keystore password stored in plaintext

**Blocks release: no. Hygiene.**

The release keystore password sits in plaintext in `export_presets.cfg`. That
file is gitignored, so it is not in version control, but it is readable by
anything with access to the working directory.

Losing or leaking a release keystore is unrecoverable: Play Store will not
accept an app signed with a different key, and the app cannot be updated.

Worth doing regardless of this release:

- Back the keystore up somewhere durable and separate.
- Consider Godot's environment-variable overrides for the password so it does
  not sit on disk.
- Note that `export_presets.cfg` being gitignored also means export filter
  changes are not version-controlled — a fresh clone will not have them.
