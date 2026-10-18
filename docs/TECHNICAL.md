# Data-only reinforcement correction

The build checks Steam build 25480438 / EXE 1.8.46015.0 through exact file hashes. The Windows adapter permits writes only to already committed, private, read/write pages. It does not allocate executable storage, change page protection or patch instructions.

## Placement boundary

The native handler at game.dll RVA `0xAC83F0` stores the local player's pending spawn at player-manager global `0x3326468`, record offset `0x10C`. State 2 indicates a pending reinforcement, with a countdown at `0x12C`. The later consumer at `0xAC8800` uses the pending XY to create the pod. Only those eight XY bytes are writable through this mod.

Before writing, the module checks mission mode, local identity, ownership, player count, unit reference, spawn state, remaining time, original XY and beacon association. A fresh read must confirm the same pending spawn. Failed writes stop correction and attempt restoration of the same original XY while still pending. Unsupported or ambiguous data is left unchanged.

## Teammate-owned beacons

Native selection at `0xAC7280` uses the first beacon whose local-player use bit is clear. The commit handler marks usage only in its local-player and locally-owned-beacon branch. A teammate-owned beacon can therefore stay unmarked after a local queue commit.

Data-v3 accepts either one new use-bit transition or the guarded remote-beacon path. The latter requires a dead-to-queued multiplayer transition. A previously observed first unused remote beacon must retain its identity and XY; if none was observable before the transition, exactly one unused candidate must exist afterward. The fresh snapshot checks order, ownership, use bit and position again.

This affects the local consumer only. Correcting an unmodded peer is outside this implementation; each diver needs their own installation.

## Solo automatic reinforcement

Solo reinforcement has two randomized stages: creation of an automatic type `0x7C` anchor and subsequent pod placement around that anchor. The mod freezes the original source position when the automatic anchor appears, then associates that anchor with the selected beacon. Following unit and scene-graph data is read-only; no native placement function is called.

Initial deployment, unsupported mission modes and stale identities are excluded. Missing startup pointers or transiently unavailable data reset associations and retry; invalid layouts and failed writes stop the module.

## Waiting for a death

Only the local player's own spawn state (player manager `+0x2E0`: 3 alive, 1 dead and queued, 2 pod pending, 0 before the first deployment) starts work. Between deaths each check reads the player-manager global and that state, two reads with no Lua allocation. When the state becomes 1 or 2 the full snapshot runs, and it keeps running every check until the state leaves 1 and 2. The death's first snapshot is compared with a baseline: the state the gate saw last (so the initial deployment, 0 to 2, stays excluded), no beacons, and the automatic rows of the last solo landing on the same player manager. A jump from alive straight to pending (3 to 2) is left unchanged, because no beacon use bits were read before it. With no solo landing seen and several automatic rows listed at the death, no anchor is captured.

## Loader contract

Bingus Shared Loader provides `CowboyBingusModLoader.api == 1`. The stable gameplay resource is `mods/cowboybingus/reinforcement_beacon_fix_data`; its resource hash is `0x4F1BA22DAA1EAB5C`. The manager GUID remains `80a03e3b-a671-4e54-a2ce-52c35bb64c91`. These are compatibility identifiers, independent of the display name.

The gameplay package owns no boot or Wwise resource. Its update wrapper preserves the prior function and all return values. The in-VM `ReinforcementBeaconFixData` guard remains stable to prevent duplicate initialization across the rename.

## Update chain

The loader installs the update guard of `bingus_runtime.lua`, the family's update-chain policy, around `update` and `shutdown`; the build passes the vendored runtime to the loader. The earlier update runs outside pcall, so its errors reach the game unchanged. The mod checks once before the earlier update, and again after it only while a reinforcement is in progress.

- The reader refuses an unsupported layout, and a failed write stops the correction, by raising. Either stops the mod at once, as before. Errors in the mod's own code stop it after 8 in a burst; a count starts again after 3600 error-free frames.
- After an error in an update below it, the mod puts back the original XY of a pending correction and forgets every association. It restores only while the same player manager's spawn is still pending and its XY still holds exactly the bytes the mod wrote. Once the updates below have returned on 60 frames in a row, it checks again from a fresh start; a queue seen first after the pause is not corrected. Eight such errors in a burst stop it.
- When the mod stops, it puts back a pending correction the same way. At shutdown it writes nothing.
- The guard's status is in `BingusRuntime.statuses.ReinforcementBeaconsFixed`; the first failure survives shutdown.

## Validation boundaries

Three prior live solo tests confirmed the corrected XY persisted through the roughly five-second queue. The current multiplayer repair and startup recovery pass synthetic tests through the actual reader and update wrapper. Combined resource ownership, HUD callback preservation and manager deployment are tested separately.

Installed data-v3 multiplayer behavior remains unverified. The observed near-ground player position still differed by roughly 2–3 metres from the corrected queue in solo testing; its cause remains unresolved. Steering, collision and descent remain native, and terrain validation is not repeated at the corrected position. Source tests use synthetic values; private captures and investigation databases are excluded.


## Build 25327279 anchor repair (data-v4.3)

The current automatic producer compares type 0x7C at game.dll +0xACCC96 and creates that same type at +0xACCEC5. The prior 0x7A reader never saved its source. The 64-byte active rows, type offset 12, position offset 16 and manager count/array offsets 0x34/0x78 remain unchanged. The regression uses the production snapshot and update wrapper: obsolete type ignored, current type recognized, source frozen before later movement, queued XY corrected once, Z/timer/use flags preserved, and associations cleared on landing. It fails against v4.2 and passes against v4.3.

The client path still selects the first unused record and marks only locally owned beacons. Those branches and queued XY offsets were checked in the saved current native code; the existing remote-beacon regression passes. This is not installed co-op confirmation. Current installed testing remains pending for both solo and clients.
