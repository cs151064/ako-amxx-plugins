# AMXX Dev Workspace

AMX Mod X plugin workspace for rehlds / AMXX 1.10 development. This repo is organized for source control first, not as a direct `cstrike/` overwrite dump.

## Structure

```text
src/
  cheats/
    fake_aimbot.sma
  special/
    magic_circle.sma
    special_menu.sma
  weapons/
    laser_cannon.sma

model/
  models/...          # Model resources, preserving in-game cstrike path
  sound/...           # Sound resources, preserving in-game cstrike path
  sprites/...         # Sprite resources, preserving in-game cstrike path

config/
  plugins.local.ini   # Local build/deploy plugin order

amxx-dev.ps1          # Local helper for build/deploy/package
```

Example: `laser_cannon.sma` precaches `models/v_plasmagun2.mdl`, so the repo stores it at:

```text
model/models/v_plasmagun2.mdl
```

When deploying resources, copy the contents of `model/` into the server `cstrike/` directory.

## Kept Plugins

| Plugin | Source | Purpose |
|---|---|---|
| `fake_aimbot` | `src/cheats/fake_aimbot.sma` | Fake aimbot core and natives |
| `magic_circle` | `src/special/magic_circle.sma` | Ground magic circle freeze ability |
| `special_menu` | `src/special/special_menu.sma` | Chinese special menu for fake aimbot and magic circle |
| `laser_cannon` | `src/weapons/laser_cannon.sma` | AK47-based laser cannon weapon |

## AMXX Modules

For AMX Mod X 1.10, load the modules required by the enabled plugins:

```ini
engine
fakemeta
hamsandwich
cstrike
fun
```

`xs` is an include-only helper used at compile time. It is not a runtime module.

This repo manages the custom plugin block in the live server `plugins.ini` through `amxx-dev.ps1`.

## Resource Paths

Current resource files:

```text
model/models/p_plasmagun.mdl
model/models/v_plasmagun2.mdl
model/models/w_plasmagun.mdl
model/models/ref/magic_circle.mdl

model/sprites/muzzleflash27.spr
model/sprites/plasmaball.spr
model/sprites/plasmabomb.spr

model/sound/ref/freeze_hit.wav
model/sound/weapons/plasmagun-1.wav
model/sound/weapons/plasmagun_clipin1.wav
model/sound/weapons/plasmagun_clipin2.wav
model/sound/weapons/plasmagun_clipout.wav
model/sound/weapons/plasmagun_draw.wav
model/sound/weapons/plasmagun_exp.wav
```

Some default Half-Life sprites used by `laser_cannon`, such as `sprites/laserbeam.spr` and `sprites/lgtning.spr`, are expected to exist in the base game files.

## Deploy Commands

The helper script targets the Windows HLDS/ReHLDS server at `D:\CounterStrike\hlds` by default.

List detected plugins:

```powershell
.\amxx-dev.ps1 -Action List
```

Build all plugins:

```powershell
powershell -ExecutionPolicy Bypass -File .\amxx-dev.ps1 -Action Build
```

Deploy compiled plugins, resources, required AMXX modules, and the managed `plugins.ini` block:

```powershell
powershell -ExecutionPolicy Bypass -File .\amxx-dev.ps1 -Action Deploy
```

`Deploy` compiles with the AMXX compiler installed in `D:\CounterStrike\hlds`, copies `.amxx` files to `D:\CounterStrike\hlds\cstrike\addons\amxmodx\plugins`, syncs the contents of `model/` into `D:\CounterStrike\hlds\cstrike`, and writes the managed plugin list from `config/plugins.local.ini`.

Create a package zip:

```powershell
.\amxx-dev.ps1 -Action Package
```

`Package` maps the resource folder back into a package `cstrike/` layout:

```text
model/models/...   -> cstrike/models/...
model/sprites/...  -> cstrike/sprites/...
model/sound/...    -> cstrike/sound/...
```

The package intentionally does not create `plugins.ini` or `modules.ini`. Keep those in the server configuration layer.

## In-Game Commands

```text
special       Open special menu
/special      Open special menu
kkk           Open special menu
magic_circle  Toggle magic circle directly
laser_cannon  Give laser cannon
lc            Give laser cannon
```

## Future Workspace Rules

- Put new `.sma` files under the matching `src/` category.
- If a plugin needs custom includes, add an include directory later and document it here.
- Put models under `model/models/...`.
- Put sprites under `model/sprites/...`.
- Put sounds under `model/sound/...`.
- Keep unrelated server configuration outside this source workspace unless we intentionally add a deployment layer.
