# Trigger Discipline - Development Approach

## Architecture

The mutator uses a **fire-mode class replacement** strategy. It does not rewrite weapon
classes and it does not copy properties at runtime.

1. `CheckReplacement` sees a `Weapon` before `Weapon.PostBeginPlay`.
2. `ModifyWeapon` maps each `Weapon.FireModeClass[i]` to an enhanced class **only when
   the original class is exactly a known stock or UTClassic fire mode**.
3. Each enhanced class `extends` that exact original class and overrides only
   `DoFireEffect()` plus `AdjustAim()`.
4. `Weapon.PostBeginPlay` instantiates the enhanced class, so `Weapon.AmmoClass[i]`
   (which is taken from `FireMode[i].AmmoClass` — see `Weapon.uc:762`) is inherited
   correctly. This is why the old generic-base approach produced weapons with no ammo.

```text
FireModeClass[i] (exact stock class)
        |
        v
TriggerDiscipline<Weapon><Mode> extends <StockClass>
        |
        +-- DoFireEffect(): apply speed modifiers, call Super, restore
        +-- AdjustAim(): call Super, then add the speed-based aim cone
```

## Why exact matching

`ClassIsChildOf(OriginalClass, class'FlakFire')` also matches `ClassicFlakFire` and any
custom subclass. Replacing those with a vanilla-based wrapper loses their
`ProjectileClass`, `AmmoClass`, damage, fire rate and custom code. Exact class-name
matching keeps modded weapons fully functional. A mod weapon that needs bonuses must
get its own wrapper (see Extending below).

## Per-shot modifier application

`DoFireEffect()` is called immediately before a fire mode actually traces or spawns a
projectile, after `ModeDoFire()` has applied vanilla logic such as Assault Rifle recoil
accumulation. The generated wrappers do:

```unrealscript
function DoFireEffect()
{
    local float BaseSpread, BaseAimError, BaseDamageAtten;

    BaseSpread = Spread;
    BaseAimError = AimError;
    BaseDamageAtten = DamageAtten;

    class'TriggerDisciplineMut'.static.ApplyModifiers(
        Self, BaseSpread, BaseAimError, BaseDamageAtten);

    Super.DoFireEffect();

    // Restore so later shots do not multiply the multiplier again.
    Spread = BaseSpread;
    AimError = BaseAimError;
    DamageAtten = BaseDamageAtten;
}
```

`ApplyModifiers` uses:

- `DamageAtten` — read by `InstantFire.DoTrace`, `ProjectileFire.SpawnProjectile`,
  `RocketFire.SpawnProjectile`, `BioChargedFire`, `AssaultGrenade`, etc.
- `Spread` — used by the trace/projectile spawn when the mode defines a non-zero value.
- `AimError` — mostly an AI hint; scaled for consistency but not relied on for players.

Each wrapper also overrides `AdjustAim()`:

```unrealscript
function Rotator AdjustAim(Vector Start, float InAimError)
{
    return class'TriggerDisciplineMut'.static.ApplyAimDeviation(
        Self, Super.AdjustAim(Start, InAimError));
}
```

`Super.AdjustAim()` keeps weapon-specific behaviour (Shock combo target, Shield Gun,
Sniper, etc.) and `ApplyAimDeviation` adds the speed-based random cone on top. This is
what makes accuracy apply to weapons whose `Spread` is permanently zero.

Because the current values are captured and restored around `Super.DoFireEffect()`,
vanilla per-shot behaviour is preserved and values never compound across shots.

### Weapon-specific damage paths

A few stock/UTClassic fire modes do not use `DamageAtten`:

| Class | Damage source | Handling |
|-------|---------------|----------|
| `LinkFire` | continuous `Damage` var used in `ModeTick()` | wrapper scales `Damage` around `Super.ModeTick()` |
| `ShieldFire` | local value from `MinDamage` / `MaxDamage` | wrapper scales both vars around `Super.DoFireEffect()` |
| `ClassicGrenadeFire` | `SpawnProjectile()` override that never applies `DamageAtten` | wrapper scales `Projectile.Damage` after spawn |

`ClassicShockBeamFire` / `ClassicShockProjFire` get the same combo-averaging and
`ComboDamage` snapshot logic as their vanilla counterparts.

## Movement math

There is a single speed fraction, shared by accuracy and damage:

```text
MaxSpeed    = Pawn.GroundSpeed (fallback 800)
Speed       = |HorizontalVelocity|
SpeedFactor = Clamp(Speed / MaxSpeed, 0, 1)
```

- `0.0` = still, `1.0` = at/above `Pawn.GroundSpeed` (server-dictated max run speed).
- Only `PHYS_Walking` is considered; jumping/falling counts as full speed.
- Horizontal velocity only, so slopes/stairs do not look like movement.

Accuracy and spread:

```text
AccPct     = StillAccuracyPct + (RunAccuracyPct - StillAccuracyPct) * SpeedFactor
AccPct     = Clamp(AccPct, 50, 100)
SpreadMult = Clamp(1.5 - AccPct / 100, 0.5, 1.0)
Inaccuracy = Clamp((100 - AccPct) / 50, 0, 1)
Deviation  = Inaccuracy * F.AimError * AimDeviationScale
```

`Spread` scaling alone only works for the handful of fire modes that define a non-zero
`Spread` (Assault Rifle, Minigun, Flak). `ShockBeamFire`, `SniperFire`, `LinkFire`,
`ShieldFire` and most projectile modes leave it at `0`, and `PlayerController.AdjustAim`
ignores `AimError` for human players. The wrappers therefore override `AdjustAim()` and
call `ApplyAimDeviation`, which adds a random cone of `Deviation` rotator units around
the vanilla aim direction. Every stock/UTClassic fire mode calls `AdjustAim()` before
tracing or spawning, so this affects the whole arsenal, Shock Rifle included.

Damage:

```text
BaseDamageMult = Clamp(StillDamageMult + (RunDamageMult - StillDamageMult)
                       * SpeedFactor, 0, 2)
```

The HUD shows `AccPct` directly: 50% = vanilla spread plus a half-`AimError` cone,
100% = half spread and no added cone.

## UDamage

`Pawn.TakeDamage()` multiplies damage by 2 whenever the attacker has UDamage
(`InstigatedBy.HasUDamage()`). The mutator therefore must **not** add that 2x again.
`GetFinalDamageMult()` computes the desired final multiplier for the HUD, and
`GetDamageAttenFor()` divides it by the engine's UDamage factor before writing
`DamageAtten`.

- Stack unchecked: `Max(BaseDamageMult, 2.0)`
- Stack checked: `BaseDamageMult * 2.0`

Because UDamage is checked when damage is applied, a projectile whose UDamage expires
during flight will not receive the engine's 2x. Hitscan weapons are unaffected.

## Shock combo

- Orb (`TriggerDisciplineShockProjectileFire.SpawnProjectile` / Classic counterpart):
  scales `ShockProjectile.ComboDamage` by the orb's firing multiplier.
- Beam (`TriggerDisciplineShockBeamFire` / Classic counterpart): reads the orb's
  encoded multiplier, averages it with the beam's current multiplier and writes it
  back to `ComboDamage`.
- Base combo damage is 200 (vanilla `ShockProjectile` default).

## Debug HUD

`TriggerDisciplineDebugDisplay extends Interaction` is registered with
`PC.Player.InteractionMaster.AddInteraction(...)` from the mutator's 1 Hz timer. It
draws, in real time:

```text
Damage: x1.38
Accuracy: 50%
```

`Accuracy` comes from the same spread multiplier used by the weapons. Set
`bDebugDraw=False` to disable. The mutator is replicated so remote clients can attach
their own HUD interaction.

## Configure GUI

`TriggerDisciplineConfig extends GUIPage` exposes exactly four numeric fields and
three checkboxes:

- Accuracy at 0% speed (50-100)
- Accuracy at 100% speed (50-100)
- Damage at 0% speed (0.0-2.0)
- Damage at 100% speed (0.0-2.0)
- Stack with UDamage
- Show onscreen indicators
- Bot AI crouch hints

`AimDeviationScale` (default `0.5`, INI only) controls the size of the random aim cone
relative to each fire mode's `AimError`.

**OK** writes `class'TriggerDisciplineMut'.default.*` and calls `StaticSaveConfig()`.
**Restore Defaults** fills the fields with the shipped defaults (without saving until
OK). **Cancel** closes without saving.

The mutator exposes it with:

```unrealscript
ConfigMenuClassName="TriggerDiscipline.TriggerDisciplineConfig"
```

## Building

```bash
cd /home/jdmr/Juegos/UT2004/System
cp /path/to/TriggerDiscipline/Classes/*.uc ../TriggerDiscipline/Classes/
rm -f TriggerDiscipline.u TriggerDiscipline.ucl
WINEDEBUG=-all wine UCC.exe make -ini=TriggerDisciplineBuild.ini -log=TriggerDiscipline_make.log -silent
WINEDEBUG=-all wine UCC.exe exportcache TriggerDiscipline
```

Required `EditPackages`: `Core`, `Engine`, `Fire`, `GamePlay`, `UnrealGame`, `XGame`,
`XWeapons`, `UTClassic`, `XInterface`, `TriggerDiscipline`.

## Extending for a modded weapon

1. Add `EditPackages=<ModPackage>` to the build INI.
2. Create `TriggerDiscipline<Name> extends <ModFireMode>` with the standard
   `DoFireEffect` block shown above.
3. Add an exact match in `GetEnhancedFireModeClass`:

```unrealscript
if (N == "MyMod.MyCustomFire") return class'TriggerDisciplineMyCustomFire';
```

Do **not** use `ClassIsChildOf`; it silently steals subclasses of stock classes.
