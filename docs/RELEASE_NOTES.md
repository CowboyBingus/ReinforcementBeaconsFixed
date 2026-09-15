# Reinforcement Beacons Fixed — release notes

## data-v4 — loader compatibility candidate

Accept API 1 or newer instead of requiring exactly API 1. Missing, malformed
and older API metadata still fail. Regression tests exercise current and
newer loaders and preserve update callback returns. Gameplay behavior is
unchanged from data-v3; in-game validation remains pending.

[Download data-v4](https://github.com/CowboyBingus/ReinforcementBeaconsFixed/releases/tag/data-v4).

## data-v3 release

Renamed from Reinforcement Beacon Fix, with matching banner and square manager artwork. Existing manager and module identifiers are preserved.

This candidate corrects association with teammate-owned beacons whose local use bit remains unset when a pod is queued. Startup recovery and solo automatic-anchor correction are retained. It changes only the local pending X/Y in existing writable data.

Install `Reinforcement-Beacons-Fixed-v4.zip` with `Bingus-Shared-Loader-v9.zip`. Replace previous entries, then Purge and Deploy with the game closed. Each diver needs both packages for their own pod.

Offline regression, loader/HUD compatibility and isolated Arsenal/HD2MM checks passed. Installed multiplayer verification is pending, and a small solo landing offset remains unresolved. This release is marked as a release.

The source distribution includes authored code, synthetic fixtures, documentation and artwork. It excludes development caches, native prototypes, live captures, manager profiles, game resources and repository history.

[Download this release](https://github.com/CowboyBingus/ReinforcementBeaconsFixed/releases/tag/data-v3) · [Download the required loader](https://github.com/CowboyBingus/BingusSharedLoader/releases/tag/loader-v2)
