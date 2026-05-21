# ARPG SDK Staging

This directory is workspace-local SDK staging for the ARPG package.

Included from the existing MonsterMod redo source:

- `hlsdk/common`
- `hlsdk/engine`
- `hlsdk/pm_shared`
- `hlsdk/dlls` headers
- `metamod`

Added from upstream SDK/source packages:

- `rehlds/` from `rehlds/ReHLDS` `rehlds/public`
- `regamedll/` from `rehlds/ReGameDLL_CS` `regamedll/public`
- `amxx/` from `alliedmodders/amxmodx` `public/sdk`
- `amxxmodule.h` mirror at the SDK root for the current spec layout
- `sqlite/` from SQLite amalgamation 3.53.1

`arpg_monsters` can start from the local HLSDK/Metamod headers because it is a Hutao-only MonsterMod fork.
