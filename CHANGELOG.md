# v4.6

- Aboard the ship a check reads the mission mode first and stops there: 2 memory reads per frame instead of 4.
- Alive in a co-op mission it skips beacon positions unless a reinforcement is queued or pending: 10 reads per frame instead of 14 with one beacon out.
- Alive solo it reads the death-anchor source position only when capturing a new anchor: 9 reads per frame instead of 14.
- Each beacon list is read in one read instead of one read per beacon.
- Game data is read into kept buffers and decoded in place, so a frame creates less Lua garbage (aboard the ship 496 to 240 bytes, alive in a co-op mission 2408 to 1448 bytes).
- After an error in the game's update or another mod's, it puts back the original position of a pending correction, pauses and checks again once 60 frames run cleanly.
- Eight errors in a burst, its own or in the updates below it, stop the mod; it used to ignore errors below it, and an unsupported memory layout or failed write still stops it at once.
- When it stops, it puts back a pending correction that still holds the position it wrote; quitting the game writes nothing.
- It notices again when the player manager changes between checks; the old comparison never saw a change.
- A NaN or infinite position or countdown in game data now counts as unavailable instead of possibly stopping the mod.
- The game-state reader, the reinforcement plan and the correction are split into named steps that make the same reads and writes and give the same results.
- Memory access comes from Bingus Shared Runtime v1, vendored unchanged; module hashes are computed once per session for every mod that uses it.
- The mod is now licensed under the Zero-Clause BSD license (0BSD).
- Requires Bingus Shared Loader v18 or newer.
- Measured in live play: 0.021 ms per frame in client missions and 0.009 on the ship.

# v4.5

- Checks memory protection only immediately before its single write instead of on every snapshot, twice per frame; in game that query costs about 0.3 ms each.
- Repeats the after-update check only while a reinforcement is in progress, reads the automatic stratagem rows in one read, and reuses one read buffer.
- Measured in real play: about 0.99 ms to 0.03 ms of main-thread time per frame in missions, and 0.59 ms to 0.02 ms aboard the ship. Corrections are unchanged; a beacon correction was confirmed live.

# v4.4

- Refresh the game-build checks for Steam build 25480438.
- Preserve solo beacon anchoring and co-op reinforcement corrections.
- Offline builds and package checks pass; live gameplay validation remains pending.

# v4.3

- Update compatibility for game build 25327279.
- Fix solo reinforcement placement around the current death anchor.
- Restore reinforcement corrections for co-op clients.

# v4.1

- Fixes reinforcement placement on defense and other supported mission types.
- Restores beacon and solo death-anchor correction while rejecting stale mission data.
- Moves logs to `%LOCALAPPDATA%\CowboyBingus\Helldivers2\Logs`.
- Requires Bingus Shared Loader v14 for the shared log folder.
