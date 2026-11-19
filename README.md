# Trigger Discipline

A UT2004 mutator that makes weapon accuracy and damage scale linearly with player
speed. Two endpoints are configured: one at 0% of `Pawn.GroundSpeed` and one at
100%. Everything in between is interpolated in real time.

## Features

- **Speed-based accuracy**: native spread is scaled and a real aim cone is added, so
  every weapon is affected — including the Shock Rifle, whose native `Spread` is zero.
- **Speed-based damage**: damage multiplier is interpolated the same way.
- **Speed is measured against `Pawn.GroundSpeed`** (the server-dictated max running
  speed), not hardcoded units.
- **Jumping / falling** counts as 100% speed (baseline endpoints).
- **Vehicle / Redeemer warhead immunity**.
- **Shock combo averaging**, including UTClassic weapons.
- **UDamage handling**: additive or multiplicative, without double-applying the
  engine's built-in 2x.
- **Live on-screen indicators**: `Damage: x1.38`, `Accuracy: 50%`.
- **Bot AI crouch hints**.
- **Simple Configure GUI** with four fields and three checkboxes.

## Defaults

| Setting | At 0% speed | At 100% speed |
|---------|-------------|---------------|
| Accuracy | 100% | 50% |
| Damage multiplier | 1.50x | 1.00x |

Accuracy is expressed as a percentage: **50% = vanilla spread plus a half-`AimError`
aim cone**, **100% = half spread and no added cone** (laser-accurate for hitscan
weapons). The GUI accepts 50-100%. The on-screen **Accuracy** indicator uses the same
50-100 scale.

Why an extra cone: most stock fire modes (`ShockBeamFire`, `SniperFire`, `LinkFire`,
`ShieldFire`, projectile modes) leave `Spread` at `0`, so simply scaling it did nothing
for them. The mutator overrides `AdjustAim()` in every wrapper and adds a random
angular deviation based on the weapon's `AimError`.

## Installation

1. Copy `TriggerDiscipline.u` and `TriggerDiscipline.ucl` into `UT2004/System`.
2. Launch UT2004.
3. Enable **Trigger Discipline** in the Mutators menu.
4. Click **Configure** to edit the four values and three toggles. They are saved to
   `UT2004/System/TriggerDiscipline.ini`.

## Configuration

The GUI is the recommended way. The INI keys are:

```ini
[TriggerDiscipline.TriggerDisciplineMut]
StillAccuracyPct=100.0       ; accuracy at 0% speed (50-100)
RunAccuracyPct=50.0          ; accuracy at 100% speed (50-100)
StillDamageMult=1.5          ; damage at 0% speed (0.0-2.0)
RunDamageMult=1.0            ; damage at 100% speed (0.0-2.0)
bStackMultiplicatively=False ; stack with UDamage instead of taking the max
bDebugDraw=True              ; on-screen Damage / Accuracy indicators
bEnableBotAI=True            ; bot crouch hints
AimDeviationScale=0.5        ; aim-cone size at 50% accuracy (INI only)
```

## Compatibility

- **Stock UT2004 weapons**: mapped fire modes are replaced with subclasses that
  extend the exact vanilla class, preserving ammo, projectiles, animations, sounds,
  damage types and weapon-specific logic.
- **UTClassic weapons**: dedicated wrappers extend the `UTClassic` classes and keep
  their unique projectiles and ammo (`ClassicSniperAmmo`, `ClassicBioGlob`, etc.).
- **Custom / modded weapons**: only fire modes that are exactly a known stock or
  UTClassic class are replaced. Mod weapons that reuse a stock fire mode receive the
  bonuses automatically. Mod weapons with custom fire-mode subclasses are left
  untouched so their ammo and projectiles keep working.

## Building from Source

Requires UT2004's `UCC.exe` (Windows build, e.g. via Wine):

```bash
cd /path/to/UT2004/System
cp /path/to/TriggerDiscipline/Classes/*.uc /path/to/UT2004/TriggerDiscipline/Classes/
rm -f TriggerDiscipline.u TriggerDiscipline.ucl
WINEDEBUG=-all wine UCC.exe make -ini=TriggerDisciplineBuild.ini -log=TriggerDiscipline_make.log -silent
WINEDEBUG=-all wine UCC.exe exportcache TriggerDiscipline
```

The `make` step may crash in `UCacheManager::SaveNewPackages` under Wine; the
separate `exportcache` command performs that step successfully.

`TriggerDisciplineBuild.ini` must list `UTClassic` and `XInterface` in
`EditPackages`.

## Design Principles

See [DESIGN.md](DESIGN.md), [APPROACH.md](APPROACH.md) and [ROADMAP.md](ROADMAP.md).

## License

MIT License - Feel free to use, modify, and distribute.
