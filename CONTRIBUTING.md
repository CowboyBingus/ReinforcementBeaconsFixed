# Build from source

Use Windows x64, Python 3.10+ and the LuaJIT revision pinned in `dependencies.json`. Compile LuaJIT from an x64 Visual Studio Native Tools prompt with `msvcbuild.bat nogc64`. Supply that compiler through `HD2_LUAJIT`.

The builder checks the supported game files. Set `HD2_GAME_ROOT` if the game is outside the standard Steam installation. No live process, extracted game scripts or native prototype tools are needed to build this gameplay module.

```powershell
$env:HD2_LUAJIT = (Resolve-Path 'tools/src/LuaJIT/src/luajit.exe').Path
python -B scripts/build.py
```

The result is `releases/ReinforcementBeaconsFixed.zip`; intermediates and test results go into `build/`. The build does not install the mod or launch the game.

Only `windows_api.lua`, `spawn_data.lua` and `archive_loader.lua` are compiled. Checks cover startup retries, mission transitions, three synthetic solo scenarios, teammate-owned beacons, ambiguous or stale associations, an eight-byte write boundary, rollback and original update return values. The final ZIP must contain one Lua resource, its manager metadata and the square artwork.

The source fixtures are synthetic; they contain no recorded player identifiers, process addresses, session timestamps or live position captures. Preserve the supported hashes and layout guards when changing the runtime. A new game hash alone does not establish compatibility.

For combined loader/HUD/manager checks, build Bingus Shared Loader and follow its contribution guide. Offline checks do not replace multiplayer or landing tests. Test both hosting and joining before broadening the documented support.

Source publication should include authored source, tests, dependency pins, documentation and the two images. Build output, caches, game resources, manager profiles and local captures are ignored. Upload release ZIPs separately. No repository-wide license has been selected.
