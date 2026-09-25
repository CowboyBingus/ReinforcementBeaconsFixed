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
