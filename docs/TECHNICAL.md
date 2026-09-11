# Data-only reinforcement correction

The build checks Steam build 24826606 / EXE 1.8.45317.0 through exact file hashes. The Windows adapter permits writes only to already committed, private, read/write pages. It does not allocate executable storage, change page protection or patch instructions.

## Placement boundary

The native handler at game.dll RVA `0xAB6DA0` stores the local player's pending spawn at player-manager global `0x276C190`, record offset `0x10C`. State 2 indicates a pending reinforcement, with a countdown at `0x12C`. The later consumer at `0xAB71B0` uses the pending XY to create the pod. Only those eight XY bytes are writable through this mod.

Before writing, the module checks mission mode, local identity, ownership, player count, unit reference, spawn state, remaining time, original XY and beacon association. A fresh read must confirm the same pending spawn. Failed writes stop correction and attempt restoration of the same original XY while still pending. Unsupported or ambiguous data is left unchanged.

## Teammate-owned beacons

Native selection at `0xAB5C40` uses the first beacon whose local-player use bit is clear. The commit handler marks usage only in its local-player and locally-owned-beacon branch. A teammate-owned beacon can therefore stay unmarked after a local queue commit.

Data-v3 accepts either one new use-bit transition or the guarded remote-beacon path. The latter requires a dead-to-queued multiplayer transition. A previously observed first unused remote beacon must retain its identity and XY; if none was observable before the transition, exactly one unused candidate must exist afterward. The fresh snapshot checks order, ownership, use bit and position again.

This affects the local consumer only. Correcting an unmodded peer is outside this implementation; each diver needs their own installation.

## Solo automatic reinforcement

Solo reinforcement has two randomized stages: creation of an automatic type `0x7A` anchor and subsequent pod placement around that anchor. The mod freezes the original source position when the automatic anchor appears, then associates that anchor with the selected beacon. Following unit and scene-graph data is read-only; no native placement function is called.

Initial deployment, unsupported mission modes and stale identities are excluded. Missing startup pointers or transiently unavailable data reset associations and retry; invalid layouts and failed writes stop the module.

## Loader contract

Bingus Shared Loader provides `CowboyBingusModLoader.api == 1`. The stable gameplay resource is `mods/cowboybingus/reinforcement_beacon_fix_data`; its resource hash is `0x4F1BA22DAA1EAB5C`. The manager GUID remains `80a03e3b-a671-4e54-a2ce-52c35bb64c91`. These are compatibility identifiers, independent of the display name.

The gameplay package owns no boot or Wwise resource. Its update wrapper preserves the prior function and all return values. The in-VM `ReinforcementBeaconFixData` guard remains stable to prevent duplicate initialization across the rename.

## Validation boundaries

Three prior live solo tests confirmed the corrected XY persisted through the roughly five-second queue. The current multiplayer repair and startup recovery pass synthetic tests through the actual reader and update wrapper. Combined resource ownership, HUD callback preservation and manager deployment are tested separately.

Installed data-v3 multiplayer behavior remains unverified. The observed near-ground player position still differed by roughly 2–3 metres from the corrected queue in solo testing; its cause remains unresolved. Steering, collision and descent remain native, and terrain validation is not repeated at the corrected position. Source tests use synthetic values; private captures and investigation databases are excluded.
