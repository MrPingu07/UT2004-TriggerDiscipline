# Trigger Discipline - Complete Technical Documentation

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Architecture](#architecture)
5. [Core Systems](#core-systems)
6. [Weapon Compatibility](#weapon-compatibility)
7. [Optional Weapon Pack Support](#optional-weapon-pack-support)
8. [Building from Source](#building-from-source)
9. [Extending the Mutator](#extending-the-mutator)
10. [Troubleshooting](#troubleshooting)
11. [API Reference](#api-reference)

---

## Overview

**Trigger Discipline** is a UT2004 mutator that makes weapon accuracy and damage scale linearly with player speed. The philosophy is simple: reward deliberate, stationary shooting while penalizing run-and-gun play.

### Key Features

| Feature | Description |
|---------|-------------|
| **Speed-based accuracy** | Native spread + aim cone scale from 0% to 100% of `Pawn.GroundSpeed` |
| **Speed-based damage** | Damage multiplier interpolates between two configured endpoints |
| **Crouching bonus** | Extra damage multiplier applied only when fully crouched |
| **UDamage handling** | Configurable stacking (additive vs. multiplicative) without double-dipping |
| **Live HUD** | On-screen `Damage: xN.NN` and `Accuracy: N%` indicators |
| **Bot AI hints** | Bots at range periodically crouch for accuracy |
| **Simple GUI** | Configure window with 5 fields, 3 toggles, Restore Defaults |
| **Universal coverage** | Works on Shock Rifle, Sniper, Link Gun, Shield Gun, projectiles — not just spread-based weapons |
| **Optional weapon packs** | UC1, UC2, UT3, UT2341 weapons supported via dynamic-load package |

### Design Goals

1. **No ammo breakage** — Every wrapper extends the exact original fire mode class
2. **No projectile loss** — Custom projectiles, damage types, sounds, animations preserved
3. **Real-time interpolation** — No stance tables, no settle timers, pure speed fraction
4. **Opt-in mod support** — Exact class matching only; unknown subclasses left untouched
5. **Network-friendly** — HUD replicates to clients, damage resolved on server

---

## Installation

### Standard Installation (Core Only)

```bash
# 1. Copy compiled packages to UT2004 System folder
cp TriggerDiscipline.u TriggerDiscipline.ucl /path/to/UT2004/System/

# 2. Launch UT2004
# 3. Open Mutators menu → Enable "Trigger Discipline"
# 4. Click "Configure" to adjust settings
```

### Full Installation (With Weapon Packs)

```bash
# 1. Copy core packages
cp TriggerDiscipline.u TriggerDiscipline.ucl /path/to/UT2004/System/

# 2. Copy weapon pack packages
cp TriggerDisciplineWeaponPacks.u /path/to/UT2004/System/

# 3. Copy required weapon pack dependencies
cp UC1Weapons.u UC2Weapons.u UT3Common.u UT3Style.u UT2341Weapons_BETA3.u /path/to/UT2004/System/

# 4. Launch UT2004 and enable both mutators if needed:
#    - Trigger Discipline
#    - UT3 Weapons (or UC2 Weapons, etc.)
```

### Configuration File Location

Settings are saved to:
```
UT2004/System/TriggerDiscipline.ini
```

---

## Configuration

### GUI Fields (Mutators → Configure)

| Field | Range | Default | Description |
|-------|-------|---------|-------------|
| **Accuracy at 0% speed** | 0–100% | 100% | Accuracy when stationary. 100% = half native spread, no aim cone. |
| **Accuracy at 100% speed** | 0–100% | 50% | Accuracy at max run speed. 50% = native spread + half `AimError` cone. |
| **Damage at 0% speed** | 0.0x–10.0x | 1.5x | Damage multiplier when stationary. |
| **Damage at 100% speed** | 0.0x–10.0x | 1.0x | Damage multiplier at max run speed. |
| **Crouching bonus** | 0.0x–10.0x | 1.0x | Extra multiplier when fully crouched (applied last). |

### Checkboxes

| Toggle | Default | Description |
|--------|---------|-------------|
| **Stack with UDamage** | Off | If on, UDamage multiplies (×2). If off, takes max(configured, 2.0). |
| **Show onscreen indicators** | On | Draws `Damage: xN.NN` and `Accuracy: N%` in top-left. |
| **Bot AI crouch hints** | On | Bots at medium-long range will crouch for accuracy. |

### INI Format (`TriggerDiscipline.ini`)

```ini
[TriggerDiscipline.TriggerDisciplineMut]
StillAccuracyPct=100.0
RunAccuracyPct=50.0
StillDamageMult=1.5
RunDamageMult=1.0
CrouchingDamageMult=1.0
bStackMultiplicatively=False
bDebugDraw=True
bEnableBotAI=True
AimDeviationScale=1.0
```

### Accuracy Scale Explained

The accuracy percentage maps to gameplay as follows:

| Accuracy % | Native Spread | Aim Cone | Feel |
|------------|---------------|----------|------|
| 0% | 1.5× vanilla | Full `AimError` | Very inaccurate |
| 25% | 1.25× vanilla | 75% `AimError` | Inaccurate |
| 50% | 1.0× vanilla | 50% `AimError` | **Vanilla baseline** |
| 75% | 0.75× vanilla | 25% `AimError` | Accurate |
| 100% | 0.5× vanilla | None | **Laser-accurate** (hitscan) |

The HUD shows the same 0–100% value.

---

## Architecture

### High-Level Flow

```
Game Start
    │
    ├─► CheckReplacement() fires for every actor
    │       ├─ Weapon → ModifyWeapon() rewrites FireModeClass[0..1]
    │       ├─ WeaponPickup → rewrites InventoryType.default.FireModeClass
    │       ├─ xWeaponBase → rewrites WeaponType.default.FireModeClass
    │       └─ WeaponLocker → rewrites Weapons[].WeaponClass.default.FireModeClass
    │
    ├─ PostBeginPlay() → timer starts for HUD attachment
    │
    └─ Runtime (per shot)
            │
            ├─ FireMode.DoFireEffect() called
            │       ├─ Capture base Spread, AimError, DamageAtten
            │       ├─ ApplyModifiers() computes speed-based multipliers
            │       ├─ Super.DoFireEffect() fires with modified values
            │       └─ Restore base values (no compounding)
            │
            ├─ FireMode.AdjustAim() called (every shot)
            │       ├─ Super.AdjustAim() gets vanilla aim (with auto-aim)
            │       └─ ApplyAimDeviation() adds speed-based random cone
            │
            └─ Damage resolved via DamageAtten / custom paths
```

### Package Structure

```
TriggerDiscipline.u (core)
├── TriggerDisciplineMut              # Main mutator class
├── TriggerDisciplineConfig           # Configure GUI page
├── TriggerDisciplineDebugDisplay     # HUD Interaction
├── TriggerDisciplinePawn             # Bot AI helper
├── TriggerDisciplineModRegistry      # Base class for weapon pack registry
├── TriggerDiscipline*Fire            # 32 vanilla/UTClassic wrappers
│
TriggerDisciplineWeaponPacks.u (optional)
├── TriggerDisciplineWeaponPacksRegistry  # Maps mod fire modes → wrappers
├── TriggerDisciplineWP_*             # 81 generated wrappers for UC1/UC2/UT3/UT2341
```

---

## Core Systems

### 1. Speed Fraction Calculation

```unrealscript
function float GetSpeedFraction(Pawn P)
{
    if (P.Physics != PHYS_Walking)
        return 1.0;  // Airborne/swimming = full speed penalty

    MaxSpeed = P.GroundSpeed;  // Server-dictated max run speed
    if (MaxSpeed <= 0) MaxSpeed = 800.0;

    Speed = VSize(P.Velocity * vect(1,1,0));  // Horizontal only
    return Clamp(Speed / MaxSpeed, 0.0, 1.0);
}
```

- **0.0** = completely stationary
- **1.0** = at or above `Pawn.GroundSpeed`
- Only horizontal velocity counted (slopes/stairs don't inflate speed)
- Jumping, falling, swimming → instantly 1.0 (running endpoint)

### 2. Accuracy → Spread Multiplier

```unrealscript
function float GetAccuracyPct(Pawn P)
{
    T = GetSpeedFraction(P);
    Pct = StillAccuracyPct + (RunAccuracyPct - StillAccuracyPct) * T;
    return Clamp(Pct, 0.0, 100.0);
}

function float GetSpreadMult(Pawn P)
{
    // 0% → 1.5, 50% → 1.0, 100% → 0.5
    return Clamp(1.5 - GetAccuracyPct(P) / 100.0, 0.5, 1.5);
}
```

Applied in `ApplyModifiers()`:
```unrealscript
F.Spread   = BaseSpread   * SpreadMult;
F.AimError = BaseAimError * SpreadMult;  // Scales AI hint consistently
```

### 3. Aim Deviation (The Key Fix)

Most UT2004 fire modes have `Spread = 0` (ShockBeamFire, SniperFire, LinkFire, ShieldFire, all projectile modes). Scaling `Spread` alone does nothing for them.

**Solution:** Every wrapper overrides `AdjustAim()`:

```unrealscript
function Rotator AdjustAim(Vector Start, float InAimError)
{
    return class'TriggerDisciplineMut'.static.ApplyAimDeviation(
        Self, Super.AdjustAim(Start, InAimError));
}
```

`ApplyAimDeviation()` adds a random cone on top of vanilla aim:

```unrealscript
static function Rotator ApplyAimDeviation(WeaponFire F, Rotator Aim)
{
    Accuracy = Mut.GetAccuracyPct(P);
    Inaccuracy = Clamp((100.0 - Accuracy) / 100.0, 0.0, 1.0);
    if (Inaccuracy <= 0.0) return Aim;

    Magnitude = Inaccuracy * F.AimError * Mut.AimDeviationScale;
    Aim.Yaw   += int((FRand()*2.0 - 1.0) * Magnitude);
    Aim.Pitch += int((FRand()*2.0 - 1.0) * Magnitude);
    return Aim;
}
```

- `Super.AdjustAim()` preserves weapon-specific behavior (Shock combo targeting, Shield Gun, Sniper zoom, etc.)
- `AimDeviationScale` (default 1.0, INI-only) controls cone size
- At 100% accuracy → `Inaccuracy = 0` → no deviation (laser accurate)
- At 50% accuracy → `Inaccuracy = 0.5` → half-`AimError` cone
- Works on **every** fire mode because all funnel through `AdjustAim()`

### 4. Damage Multiplier

```unrealscript
function float GetBaseDamageMult(Pawn P)
{
    T = GetSpeedFraction(P);
    return Clamp(StillDamageMult + (RunDamageMult - StillDamageMult) * T, 0.0, 10.0);
}

function float GetFinalDamageMult(Pawn P, float BaseMult)
{
    FinalMult = BaseMult;
    if (GetUDamageFactor(P) > 1.0) {
        if (bStackMultiplicatively) FinalMult *= 2.0;
        else FinalMult = Max(FinalMult, 2.0);
    }
    if (IsFullyCrouched(P)) FinalMult *= CrouchingDamageMult;
    return FinalMult;
}

function float GetDamageAttenFor(Pawn P, float BaseMult)
{
    // Pawn.TakeDamage() applies UDamage ×2, so we pre-divide
    return GetFinalDamageMult(P, BaseMult) / GetUDamageFactor(P);
}
```

**UDamage handling:**
- Engine doubles damage in `Pawn.TakeDamage()` when attacker has UDamage
- Mutator computes final multiplier for HUD (`GetFinalDamageMult`)
- Writes pre-UDamage value to `DamageAtten` (`GetDamageAttenFor`)
- Result: in-game damage matches HUD exactly

### 5. Crouching Detection

```unrealscript
function bool IsFullyCrouched(Pawn P)
{
    return P.bIsCrouched && P.bWantsToCrouch;
}
```

- `bIsCrouched` = physics has finished crouch transition
- `bWantsToCrouch` = player still holding crouch key
- **Excludes** both crouch-in and crouch-out transitions
- Only fully settled crouch gets the bonus

### 6. Per-Shot Modifier Application (No Compounding)

```unrealscript
function DoFireEffect()
{
    local float BaseSpread, BaseAimError, BaseDamageAtten;
    BaseSpread = Spread;
    BaseAimError = AimError;
    BaseDamageAtten = DamageAtten;

    class'TriggerDisciplineMut'.static.ApplyModifiers(Self, BaseSpread, BaseAimError, BaseDamageAtten);
    Super.DoFireEffect();

    Spread = BaseSpread;
    AimError = BaseAimError;
    DamageAtten = BaseDamageAtten;
}
```

- Captures **current** values (includes vanilla per-shot logic like Assault Rifle recoil)
- Applies multipliers
- Calls `Super.DoFireEffect()` which fires the shot
- **Restores** base values so next shot starts fresh
- Vanilla behavior (recoil buildup, Minigun spin, charge) fully preserved

### 7. Weapon-Specific Damage Paths

Some fire modes don't use `DamageAtten`:

| Fire Mode | Damage Source | Wrapper Handling |
|-----------|---------------|------------------|
| `LinkFire` | `Damage` var in `ModeTick()` | Scale `Damage` around `Super.ModeTick()` |
| `ShieldFire` | Local `MinDamage`/`MaxDamage` | Scale both around `Super.DoFireEffect()` |
| `ClassicGrenadeFire` | `Projectile.Damage` after spawn | Scale projectile damage in `SpawnProjectile()` |
| `ShockBeamFire` / `ShockProjFire` | `ComboDamage` on orb | Average orb/beam multipliers, snapshot on orb spawn |

### 8. HUD System

`TriggerDisciplineDebugDisplay extends Interaction`

- Added via `PC.Player.InteractionMaster.AddInteraction()` from 1 Hz timer
- `Initialized()` sets `bVisible=true`, `bRequiresTick=true` (Interaction defaults to invisible)
- Draws in `PostRender()`:
  ```
  Damage: x1.38
  Accuracy: 75%
  ```
- Replicated to clients via `bAlwaysRelevant`, `RemoteRole=ROLE_SimulatedProxy`, `PostNetBeginPlay()`

### 9. Bot AI Crouch Hints

`TriggerDisciplinePawn` spawned for bot-controlled pawns:

- Ticks periodically
- At medium-long range, sets `OwnerPawn.bWantsToCrouch = true`
- Bots crouch → get accuracy/damage bonus → more challenging
- Optional via `bEnableBotAI`

---

## Weapon Compatibility

### Core Mappings (32 Fire Modes)

#### Stock UT2004 (18)
| Weapon | Primary Fire Mode | Alt Fire Mode |
|--------|-------------------|---------------|
| Shock Rifle | `ShockBeamFire` | `ShockProjFire` |
| Flak Cannon | `FlakFire` | `FlakAltFire` |
| Rocket Launcher | `RocketFire` | `RocketMultiFire` |
| Bio Rifle | `BioFire` | `BioChargedFire` |
| Link Gun | `LinkFire` | `LinkAltFire` |
| Sniper Rifle | `SniperFire` | — |
| Minigun | `MinigunFire` | `MinigunAltFire` |
| Assault Rifle | `AssaultFire` | `AssaultGrenade` |
| Translocator | `TransFire` | — |
| Shield Gun | `ShieldFire` | `ShieldAltFire` |

#### UTClassic (14)
| Weapon | Primary Fire Mode | Alt Fire Mode |
|--------|-------------------|---------------|
| Classic Sniper | `ClassicSniperFire` | — |
| Classic Bio Rifle | `ClassicBioFire` | `ClassicBioChargedFire` |
| Classic Flak | `ClassicFlakFire` | `ClassicFlakAltFire` |
| Classic Rocket | `ClassicRocketFire` | `ClassicRocketMultifire` |
| Classic Grenade | — | `ClassicGrenadeFire` |
| Classic Minigun | `ClassicMinigunFire` | `ClassicMinigunAltfire` |
| Classic Shock | `ClassicShockBeamFire` | `ClassicShockProjFire` |
| Classic Translocator | `ClassicTransFire` | — |
| Classic Shield | `ClassShieldFire` | — (uses `XWeapons.ShieldAltFire`) |

### Mapping Strategy: Exact Class Matching

```unrealscript
N = string(OriginalClass);
if (N == "XWeapons.ShockBeamFire") return class'TriggerDisciplineShockBeamFire';
```

**Why exact matching?**
- `ClassIsChildOf()` would also match subclasses (e.g., a mod's `MyShockBeamFire extends ShockBeamFire`)
- Replacing a subclass with a vanilla wrapper loses: custom projectiles, ammo, damage, fire rate, special logic
- Exact match guarantees only the **exact stock class** is wrapped
- Mod weapons that subclass stock fire modes are **left untouched** → their ammo/projectiles work
- Mod weapons that **reuse** stock fire modes get bonuses automatically

---

## Optional Weapon Pack Support

### Overview

The `TriggerDisciplineWeaponPacks` package adds support for 81 fire modes from four popular weapon ports:

| Pack | Package | Weapons | Fire Modes |
|------|---------|---------|------------|
| Unreal Championship 1 | `UC1Weapons` | 10 | 18 |
| Unreal Championship 2 | `UC2Weapons` | 7 | 14 |
| Unreal Tournament 3 | `UT3Style` | 13 | 26 |
| Unreal Tournament 2341 | `UT2341Weapons_BETA3` | 12 | 23 |

### Dynamic Loading

Core mutator never references the pack packages directly:

```unrealscript
function TriggerDisciplineModRegistry GetModRegistry()
{
    if (ModRegistry != None) return ModRegistry;
    if (bTriedLoadModRegistry) return None;
    bTriedLoadModRegistry = True;

    RegistryClass = class<TriggerDisciplineModRegistry>(
        DynamicLoadObject("TriggerDisciplineWeaponPacks.TriggerDisciplineWeaponPacksRegistry", class'Class'));

    if (RegistryClass != None) ModRegistry = Spawn(RegistryClass);
    return ModRegistry;
}
```

- If `TriggerDisciplineWeaponPacks.u` not installed → `DynamicLoadObject` returns `None` → mod weapons ignored
- If installed → registry spawned → `GetModFireModeClass()` queried for unknown fire modes
- Zero coupling, zero risk to base game

### Generator Script

`tools/generate_weaponpack_support.py` automates wrapper creation:

```bash
python3 tools/generate_weaponpack_support.py \
    /path/to/ut2k4weaponsdecompiled/Output \
    --target /path/to/TriggerDiscipline/WeaponPacks/Classes
```

**What it does:**
1. Scans decompiled `.uc` files in `UnrealChampionship1Weapons/`, `UnrealChampionship2Weapons/`, `UnrealTournament3Weapons/`, `UnrealTournament99Weapons/`
2. Finds every `FireModeClass` reference in weapon defaultproperties
3. For each unique fire mode class:
   - Generates `TriggerDisciplineWP_<ClassName>.uc` extending the exact original
   - Adds standard `DoFireEffect()` + `AdjustAim()` overrides
4. Emits `TriggerDisciplineWeaponPacksRegistry.uc` with mapping table

**Generated wrapper template:**
```unrealscript
class TriggerDisciplineWP_UT3ShockFire extends UT3ShockFire;

function Rotator AdjustAim(Vector Start, float InAimError)
{
    return class'TriggerDisciplineMut'.static.ApplyAimDeviation(Self, Super.AdjustAim(Start, InAimError));
}

function DoFireEffect()
{
    local float BaseSpread, BaseAimError, BaseDamageAtten;
    BaseSpread = Spread;
    BaseAimError = AimError;
    BaseDamageAtten = DamageAtten;
    class'TriggerDisciplineMut'.static.ApplyModifiers(Self, BaseSpread, BaseAimError, BaseDamageAtten);
    Super.DoFireEffect();
    Spread = BaseSpread;
    AimError = BaseAimError;
    DamageAtten = BaseDamageAtten;
}
```

### Registry Mapping (Excerpt)

```unrealscript
function class<WeaponFire> GetModFireModeClass(class<WeaponFire> OriginalClass)
{
    local string N;
    N = string(OriginalClass);

    if (N == "UT3Style.UT3ShockFire")        return class'TriggerDisciplineWP_UT3ShockFire';
    if (N == "UT3Style.UT3ShockAltFire")     return class'TriggerDisciplineWP_UT3ShockAltFire';
    if (N == "UT3Style.UT3RocketFire")       return class'TriggerDisciplineWP_UT3RocketFire';
    if (N == "UT3Style.UT3RocketMultiFire")  return class'TriggerDisciplineWP_UT3RocketMultiFire';
    // ... 77 more mappings ...
    return None;
}
```

### Build Requirements

**Core build INI** (`TriggerDisciplineBuild.ini`):
```ini
EditPackages=Core
EditPackages=Engine
EditPackages=Fire
EditPackages=GamePlay
EditPackages=UnrealGame
EditPackages=XGame
EditPackages=XWeapons
EditPackages=UTClassic
EditPackages=XInterface
EditPackages=TriggerDiscipline
```

**Weapon packs build INI** (`TriggerDisciplineWeaponPacksBuild.ini`):
```ini
EditPackages=Core
EditPackages=Engine
EditPackages=Fire
EditPackages=GamePlay
EditPackages=UnrealGame
EditPackages=XGame
EditPackages=XWeapons
EditPackages=UTClassic
EditPackages=XInterface
EditPackages=UC1Weapons
EditPackages=UC2Weapons
EditPackages=UT3Common
EditPackages=UT3Style
EditPackages=UT2341Weapons_BETA3
EditPackages=TriggerDiscipline
EditPackages=TriggerDisciplineWeaponPacks
```

---

## Building from Source

### Prerequisites

- UT2004 installed (Windows build)
- `UCC.exe` in `UT2004/System/`
- Wine (on Linux/macOS)
- Decompiled weapon sources (for weapon packs): `ut2k4weaponsdecompiled/Output/`

### Directory Layout

```
UT2004/
├── System/
│   ├── UCC.exe
│   ├── UT2004.ini
│   ├── TriggerDisciplineBuild.ini
│   ├── TriggerDisciplineWeaponPacksBuild.ini
│   ├── UC1Weapons.u
│   ├── UC2Weapons.u
│   ├── UT3Common.u
│   ├── UT3Style.u
│   ├── UT2341Weapons_BETA3.u
│   └── ...
├── TriggerDiscipline/
│   └── Classes/*.uc          (core sources)
└── TriggerDisciplineWeaponPacks/
    └── Classes/*.uc          (generated wrappers)
```

### Build Commands (Linux/Wine)

```bash
cd /path/to/UT2004/System

# 1. Copy core sources
cp /path/to/TriggerDiscipline/Classes/*.uc ../TriggerDiscipline/Classes/

# 2. Clean previous builds
rm -f TriggerDiscipline.u TriggerDiscipline.ucl

# 3. Compile core
WINEDEBUG=-all wine UCC.exe make -ini=TriggerDisciplineBuild.ini -log=TriggerDiscipline_make.log -silent

# 4. Export cache (make crashes in UCacheManager under Wine)
WINEDEBUG=-all wine UCC.exe exportcache TriggerDiscipline

# 5. Copy weapon pack sources (if building packs)
cp /path/to/TriggerDiscipline/WeaponPacks/Classes/*.uc ../TriggerDisciplineWeaponPacks/Classes/

# 6. Clean weapon pack build
rm -f TriggerDisciplineWeaponPacks.u

# 7. Compile weapon packs
WINEDEBUG=-all wine UCC.exe make -ini=TriggerDisciplineWeaponPacksBuild.ini -log=TriggerDisciplineWeaponPacks_make.log -silent

# 8. Copy to project root for distribution
cp TriggerDiscipline.u TriggerDiscipline.ucl /path/to/TriggerDiscipline/
cp TriggerDisciplineWeaponPacks.u /path/to/TriggerDiscipline/WeaponPacks/
```

### Common Build Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| `UCacheManager::SaveNewPackages` crash | Wine bug in package finalization | Run `exportcache` separately after `make` |
| "Package not found" for UC1/UC2/UT3 | `.u` files not in `System/` | Copy all dependency `.u` files to `System/` |
| Case sensitivity errors | Linux filesystem vs. Windows paths | Ensure folder names match exactly (`Classes/`, not `classes/`) |
| Stale `.u` not rebuilt | `ucc make` skips existing packages | Always `rm -f Package.u` before building |

---

## Extending the Mutator

### Adding a Single Mod Weapon

For a mod with a custom fire mode `MyMod.MyCustomFire`:

1. **Add to build INI:**
   ```ini
   EditPackages=MyMod
   ```

2. **Create wrapper** (`TriggerDisciplineMyCustomFire.uc`):
   ```unrealscript
   class TriggerDisciplineMyCustomFire extends MyCustomFire;

   function Rotator AdjustAim(Vector Start, float InAimError)
   {
       return class'TriggerDisciplineMut'.static.ApplyAimDeviation(Self, Super.AdjustAim(Start, InAimError));
   }

   function DoFireEffect()
   {
       local float BaseSpread, BaseAimError, BaseDamageAtten;
       BaseSpread = Spread;
       BaseAimError = AimError;
       BaseDamageAtten = DamageAtten;
       class'TriggerDisciplineMut'.static.ApplyModifiers(Self, BaseSpread, BaseAimError, BaseDamageAtten);
       Super.DoFireEffect();
       Spread = BaseSpread;
       AimError = BaseAimError;
       DamageAtten = BaseDamageAtten;
   }
   ```

3. **Register in `GetEnhancedFireModeClass()`:**
   ```unrealscript
   if (N == "MyMod.MyCustomFire") return class'TriggerDisciplineMyCustomFire';
   ```

4. **Rebuild core package.**

### Adding a New Weapon Pack

1. **Place pack's `.u` file** in `UT2004/System/`

2. **Decompile** pack to `.uc` files (using UTPT, UE Explorer, or `ucc batchexport` if source included)

3. **Organize decompiled sources** to match generator expectations:
   ```
   ut2k4weaponsdecompiled/Output/
   ├── NewWeaponPack/
   │   ├── NewWeaponFire.uc
   │   └── ...
   ```

4. **Add to `PACKAGES` dict** in `tools/generate_weaponpack_support.py`:
   ```python
   PACKAGES = {
       ...
       "NewWeaponPack": "NewWeaponPack",
   }
   ```

5. **Run generator:**
   ```bash
   python3 tools/generate_weaponpack_support.py \
       /path/to/ut2k4weaponsdecompiled/Output \
       --target /path/to/TriggerDiscipline/NewWeaponPackSupport/Classes
   ```

6. **Create build INI** with new pack + `TriggerDisciplineNewWeaponPackSupport` in `EditPackages`

7. **Compile** new support package

8. **Deploy** `TriggerDisciplineNewWeaponPackSupport.u` to `UT2004/System/`

---

## Troubleshooting

### Weapons Have No Ammo / Can't Pick Up Ammo

**Cause:** Wrapper extends wrong base class (e.g., `InstantFire` instead of exact original).

**Fix:** Wrapper must `extends` the exact original fire mode class:
```unrealscript
// CORRECT
class TriggerDisciplineShockBeamFire extends ShockBeamFire;

// WRONG - loses AmmoClass
class TriggerDisciplineShockBeamFire extends InstantFire;
```

### Shock Rifle Still Perfectly Accurate While Running

**Cause:** Only `Spread` was scaled, but `ShockBeamFire.Spread = 0`.

**Fix:** Ensure wrapper overrides `AdjustAim()` and calls `ApplyAimDeviation()` (already done in all generated wrappers).

### UDamage Damage Doesn't Match HUD

**Cause:** Mutator applies UDamage multiplier on top of engine's built-in ×2.

**Fix:** Use `GetDamageAttenFor()` which divides by engine's UDamage factor before writing `DamageAtten`.

### Mod Weapon Not Getting Bonuses

**Cause:** Mod uses custom fire mode subclass not in mapping table.

**Options:**
1. Add wrapper + mapping (see Extending section)
2. If mod reuses stock fire mode class exactly → works automatically
3. If mod subclasses stock fire mode → intentionally left alone to preserve ammo/projectiles

### HUD Not Showing on Client

**Cause:** Mutator not replicated to client.

**Fix:** Core mutator has:
```unrealscript
bAlwaysRelevant=True
bAddToServerPackages=True
RemoteRole=ROLE_SimulatedProxy
```
And `PostNetBeginPlay()` starts HUD timer on clients.

### Server Crashes / ScriptWarnings

**Check:** `CheckReplacement` must not assume `Weapon` has valid `FireModeClass`:
```unrealscript
if (W.FireModeClass[i] != None) { ... }
```

### Build Fails with "Error, 'Var' is not allowed here"

**Cause:** `var` declarations after functions/events.

**Fix:** All `var` must be at class top, before any `function`/`event`/`state`.

---

## API Reference

### TriggerDisciplineMut (Static Functions)

| Function | Description |
|----------|-------------|
| `FindMutator(LevelInfo)` | Find mutator instance in mutator chain |
| `ApplyModifiers(WeaponFire, BaseSpread, BaseAimError, BaseDamageAtten)` | Apply speed multipliers to fire mode |
| `GetCurrentDamageAttenMult(WeaponFire)` | Get damage multiplier for custom paths (Link, Shield) |
| `GetSpreadMult(Pawn)` | Get native spread multiplier (0.5–1.5) |
| `GetAccuracyPct(Pawn)` | Get accuracy percentage (0–100) |
| `GetBaseDamageMult(Pawn)` | Get base damage multiplier (0–10) |
| `GetFinalDamageMult(Pawn, BaseMult)` | Get final multiplier including UDamage + crouch |
| `GetDamageAttenFor(Pawn, BaseMult)` | Get DamageAtten value (pre-UDamage) |
| `GetUDamageFactor(Pawn)` | Returns 2.0 if pawn has UDamage, else 1.0 |
| `GetAccuracyPercent(Pawn)` | HUD accuracy (same as GetAccuracyPct) |
| `IsFullyCrouched(Pawn)` | True if fully crouched (not transitioning) |
| `IsInVehicle(Pawn)` | True if in vehicle or Redeemer warhead |
| `ApplyAimDeviation(WeaponFire, Rotator)` | Add speed-based aim cone to aim direction |

### TriggerDisciplineMut (Config Variables)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `StillAccuracyPct` | float | 100.0 | Accuracy at 0% speed (0–100) |
| `RunAccuracyPct` | float | 50.0 | Accuracy at 100% speed (0–100) |
| `StillDamageMult` | float | 1.5 | Damage at 0% speed (0–10) |
| `RunDamageMult` | float | 1.0 | Damage at 100% speed (0–10) |
| `CrouchingDamageMult` | float | 1.0 | Bonus when fully crouched (0–10) |
| `bStackMultiplicatively` | bool | False | UDamage stacks multiplicatively |
| `bEnableBotAI` | bool | True | Bot crouch hints enabled |
| `bDebugDraw` | bool | True | Show on-screen HUD |
| `AimDeviationScale` | float | 1.0 | Aim cone scale factor (INI only) |

### TriggerDisciplineModRegistry

Base class for optional weapon pack registry.

| Function | Description |
|----------|-------------|
| `GetModFireModeClass(class<WeaponFire>)` | Returns wrapper class for mod fire mode, or `None` |

### TriggerDisciplineWeaponPacksRegistry

Generated registry mapping 81 mod fire modes to wrappers.

| Function | Description |
|----------|-------------|
| `GetModFireModeClass(class<WeaponFire>)` | Exact class-name mapping table |

### TriggerDisciplineConfig

Configure GUI page (`GUIPage` from XInterface).

| Function | Description |
|----------|-------------|
| `InternalOnClick(OK)` | Validate, save to `class'TriggerDisciplineMut'.default.*`, `StaticSaveConfig()` |
| `ResetToDefaults()` | Repopulate fields with defaults (no save until OK) |
| `InternalOnCancel()` | Close without saving |

### TriggerDisciplineDebugDisplay (Interaction)

| Event/Function | Description |
|----------------|-------------|
| `Initialized()` | Sets `bVisible=true`, `bRequiresTick=true` |
| `PostRender(Canvas)` | Draws `Damage: xN.NN` and `Accuracy: N%` |

### TriggerDisciplinePawn

Bot AI helper spawned for bot-controlled pawns.

| Function | Description |
|----------|-------------|
| `InitFor(Pawn)` | Binds pawn to helper |
| `Tick(DeltaTime)` | Periodic AI evaluation |
| `BotAITick(DeltaTime)` | Sets `bWantsToCrouch` at range |

---

## File Reference

### Core Package (`TriggerDiscipline.u`)

```
Classes/
├── TriggerDisciplineMut.uc              # Main mutator (~480 lines)
├── TriggerDisciplineConfig.uc           # Configure GUI (~270 lines)
├── TriggerDisciplineDebugDisplay.uc     # HUD Interaction (~80 lines)
├── TriggerDisciplinePawn.uc             # Bot AI helper (~130 lines)
├── TriggerDisciplineModRegistry.uc      # Mod registry base (~30 lines)
├── TriggerDisciplineAssaultFire.uc
├── TriggerDisciplineAssaultAltFire.uc
├── TriggerDisciplineBioFire.uc
├── TriggerDisciplineBioAltFire.uc
├── TriggerDisciplineFlakFire.uc
├── TriggerDisciplineFlakAltFire.uc
├── TriggerDisciplineRocketFire.uc
├── TriggerDisciplineRocketAltFire.uc
├── TriggerDisciplineLinkFire.uc
├── TriggerDisciplineLinkAltFire.uc
├── TriggerDisciplineSniperFire.uc
├── TriggerDisciplineMinigunFire.uc
├── TriggerDisciplineMinigunAltFire.uc
├── TriggerDisciplineTransFire.uc
├── TriggerDisciplineShieldFire.uc
├── TriggerDisciplineShieldAltFire.uc
├── TriggerDisciplineShockBeamFire.uc
├── TriggerDisciplineShockProjectileFire.uc
├── TriggerDisciplineClassicSniperFire.uc
├── TriggerDisciplineClassicBioFire.uc
├── TriggerDisciplineClassicBioChargedFire.uc
├── TriggerDisciplineClassicFlakFire.uc
├── TriggerDisciplineClassicFlakAltFire.uc
├── TriggerDisciplineClassicRocketFire.uc
├── TriggerDisciplineClassicRocketMultiFire.uc
├── TriggerDisciplineClassicGrenadeFire.uc
├── TriggerDisciplineClassicMinigunFire.uc
├── TriggerDisciplineClassicMinigunAltFire.uc
├── TriggerDisciplineClassicShockBeamFire.uc
├── TriggerDisciplineClassicShockProjFire.uc
├── TriggerDisciplineClassicTransFire.uc
├── TriggerDisciplineClassShieldFire.uc
```

### Weapon Packs Package (`TriggerDisciplineWeaponPacks.u`)

```
Classes/
├── TriggerDisciplineWeaponPacksRegistry.uc  # 81 mappings
├── TriggerDisciplineWP_UCAssaultFire.uc
├── TriggerDisciplineWP_UCAssaultGrenade.uc
├── TriggerDisciplineWP_UCBioFire.uc
├── TriggerDisciplineWP_UCBioChargedFire.uc
├── TriggerDisciplineWP_UCFlakFire.uc
├── TriggerDisciplineWP_UCFlakAltFire.uc
├── TriggerDisciplineWP_UCLinkFire.uc
├── TriggerDisciplineWP_UCLinkAltFire.uc
├── TriggerDisciplineWP_UCMinigunFire.uc
├── TriggerDisciplineWP_UCMinigunAltFire.uc
├── TriggerDisciplineWP_UCRocketFire.uc
├── TriggerDisciplineWP_UCRocketMultiFire.uc
├── TriggerDisciplineWP_UCShockFire.uc
├── TriggerDisciplineWP_UCShockAltFire.uc
├── TriggerDisciplineWP_UCSniperFire.uc
├── TriggerDisciplineWP_UCSuperShockBeamFire.uc
├── TriggerDisciplineWP_UCTransFire.uc
├── TriggerDisciplineWP_UT2003ShieldFire.uc
├── TriggerDisciplineWP_UT2003ShieldAltFire.uc
├── TriggerDisciplineWP_UC2Bio_PrimaryFire.uc
├── TriggerDisciplineWP_UC2Bio_AltFire.uc
├── TriggerDisciplineWP_UC2Flak_PrimaryFire.uc
├── TriggerDisciplineWP_UC2Flak_AltFire.uc
├── TriggerDisciplineWP_UC2Gren_PrimaryFire.uc
├── TriggerDisciplineWP_UC2Gren_AltFire.uc
├── TriggerDisciplineWP_UC2RL_PrimaryFire.uc
├── TriggerDisciplineWP_UC2RL_AltFire.uc
├── TriggerDisciplineWP_UC2Shock_PrimaryFire.uc
├── TriggerDisciplineWP_UC2Shock_AltFire.uc
├── TriggerDisciplineWP_UC2Sniper_PrimaryFire.uc
├── TriggerDisciplineWP_UC2Stinger_PrimaryFire.uc
├── TriggerDisciplineWP_UC2Stinger_AltFire.uc
├── TriggerDisciplineWP_UT3AVRiLFire.uc
├── TriggerDisciplineWP_UT3AVRiLAltFire.uc
├── TriggerDisciplineWP_UT3BioFire.uc
├── TriggerDisciplineWP_UT3BioChargedFire.uc
├── TriggerDisciplineWP_UT3EnforcerFire.uc
├── TriggerDisciplineWP_UT3EnforcerAltFire.uc
├── TriggerDisciplineWP_UT3FlakFire.uc
├── TriggerDisciplineWP_UT3FlakAltFire.uc
├── TriggerDisciplineWP_UT3ImpactHammerFire.uc
├── TriggerDisciplineWP_UT3ImpactHammerEMPFire.uc
├── TriggerDisciplineWP_UT3LinkGunFire.uc
├── TriggerDisciplineWP_UT3LinkGunAltFire.uc
├── TriggerDisciplineWP_UT3MinigunFire.uc
├── TriggerDisciplineWP_UT3MinigunAltFire.uc
├── TriggerDisciplineWP_UT3RedeemerFire.uc
├── TriggerDisciplineWP_UT3RedeemerGuidedFire.uc
├── TriggerDisciplineWP_UT3RocketFire.uc
├── TriggerDisciplineWP_UT3RocketMultiFire.uc
├── TriggerDisciplineWP_UT3ShockFire.uc
├── TriggerDisciplineWP_UT3ShockAltFire.uc
├── TriggerDisciplineWP_UT3SniperFire.uc
├── TriggerDisciplineWP_UT3SuperShockBeamFire.uc
├── TriggerDisciplineWP_UT3TranslocatorFire.uc
├── TriggerDisciplineWP_UT3TranslocatorActivate.uc
├── TriggerDisciplineWP_UT2341BioFire.uc
├── TriggerDisciplineWP_UT2341BioChargedFire.uc
├── TriggerDisciplineWP_UT2341EnforcerFire.uc
├── TriggerDisciplineWP_UT2341EnforcerAltFire.uc
├── TriggerDisciplineWP_UT2341FlakFire.uc
├── TriggerDisciplineWP_UT2341FlakAltFire.uc
├── TriggerDisciplineWP_UT2341HammerFire.uc
├── TriggerDisciplineWP_UT2341HammerAltFire.uc
├── TriggerDisciplineWP_UT2341MinigunFire.uc
├── TriggerDisciplineWP_UT2341MinigunAltFire.uc
├── TriggerDisciplineWP_UT2341PulseFire.uc
├── TriggerDisciplineWP_UT2341PulseAltFire.uc
├── TriggerDisciplineWP_UT2341RedeemerFire.uc
├── TriggerDisciplineWP_UT2341RedeemerGuidedFire.uc
├── TriggerDisciplineWP_UT2341RipperFire.uc
├── TriggerDisciplineWP_UT2341RipperAltFire.uc
├── TriggerDisciplineWP_UT2341RocketFire.uc
├── TriggerDisciplineWP_UT2341RocketGrenadeFire.uc
├── TriggerDisciplineWP_UT2341ShockRifleBeamFire.uc
├── TriggerDisciplineWP_UT2341ShockRifleProjectileFire.uc
├── TriggerDisciplineWP_UT2341SniperRifleFire.uc
├── TriggerDisciplineWP_UT2341SniperZoomFire.uc
├── TriggerDisciplineWP_UT2341SuperShockRifleBeamFire.uc
├── TriggerDisciplineWP_UT2341TransFire.uc
├── TriggerDisciplineWP_UT2341TransRecall.uc
```

### Tools

```
tools/
└── generate_weaponpack_support.py    # Generator script
```

### Documentation

```
README.md         # User-facing documentation
DESIGN.md         # Technical design document
APPROACH.md       # Development approach & rationale
ROADMAP.md        # Feature status & future work
```

---

## Changelog

### Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-11-19 | Initial release: speed-based accuracy/damage, HUD, GUI, bot AI |
| 1.1 | 2026-11-19 | Accuracy 0–100%, Damage 0–10x, crouching bonus, weapon pack support |

### Key Fixes

- **Ammo breakage fixed** by extending exact original fire mode classes
- **Shock Rifle accuracy fixed** by injecting aim deviation via `AdjustAim()` override
- **UDamage double-dipping fixed** by pre-dividing `DamageAtten` by engine's ×2
- **Non-compounding modifiers** by capture/restore pattern in `DoFireEffect()`
- **Weapon pickup/base support** for map-spawned weapons
- **Dynamic weapon pack loading** via `DynamicLoadObject` for zero coupling

---

## License

MIT License - Feel free to use, modify, and distribute.

---

## Credits

- Original UT2004 weapon code by Epic Games
- UTClassic weapon code by UTClassic team
- UC1/UC2/UT3/UT2341 weapon ports by respective authors
- Trigger Discipline mutator by [Author]

---

*End of Documentation*