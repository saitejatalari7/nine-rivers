# 05 — Save checksum can be forged

**Status:** ACCEPTED — will not fix
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-21
**Resolved:** —

**Blocks release: no — accepted.**

`scenes/security_audit.tscn` reports this as CRITICAL (T02) and will continue
to. The signing salt is a plain string constant in the shipped APK, so anyone
who unpacks it can sign an arbitrary save.

This cannot be fixed client-side. A secret inside an artefact you hand to the
user is not a secret. Raising the cost is possible; making it unforgeable is
not, short of server-side validation.

T03, T04 and T08 were fixed in `49070b6`: the signature now covers the whole
sanitized profile rather than three fields, a failed check refuses the file
instead of applying it, and version stamping no longer accepts a future schema.

The audit's forger was deliberately updated to attack the *current* scheme, so
T02 keeps reporting rather than passing because the test was aimed at a retired
one.

Files: `scripts/autoload/save_manager.gd`, `scripts/tests/security_audit.gd`
