# Trigger Discipline - Design

## Goal

Reward deliberate shooting. Spread and damage interpolate between two configured
endpoints based on the player's current horizontal speed relative to
`Pawn.GroundSpeed`. There are no crouch/walk/stand stance tables anymore.

## Player experience

With the default settings:

| Speed | Accuracy | Native spread | Extra aim deviation | Damage |
|-------|----------|---------------|---------------------|--------|
| 0% (still) | 100% | 50% of vanilla | 0 | 1.50x |
| 50% | 75% | 75% of vanilla | 25% of `AimError` | 1.25x |
| 100% (running) | 50% | 100% of vanilla | 50% of `AimError` | 1.00x |
| Jumping / falling | 50% | 100% of vanilla | 50% of `AimError` | 1.00x |

Accuracy is expressed on a 50-100 scale: **50% = vanilla spread + a visible aim
cone**, **100% = half spread and no added aim deviation**. The HUD shows the same
value.

## Technical design

### 1. Fire-mode replacement

`CheckReplacement` runs before `Weapon.PostBeginPlay`. `ModifyWeapon` rewrites
`Weapon.FireModeClass[0..1]` for **exact** known classes only:

- Stock: `ShockBeamFire`, `ShockProjFire`, `FlakFire`, `FlakAltFire`, `RocketFire`,
  `RocketMultiFire`, `BioFire`, `BioChargedFire`, `LinkFire`, `LinkAltFire`,
  `SniperFire`, `MinigunFire`, `MinigunAltFire`, `AssaultFire`, `AssaultGrenade`,
  `TransFire`, `ShieldFire`, `ShieldAltFire`.
- UTClassic: `ClassicSniperFire`, `ClassicBioFire`, `ClassicBioChargedFire`,
  `ClassicFlakFire`, `ClassicFlakAltFire`, `ClassicRocketFire`,
  `ClassicRocketMultifire`, `ClassicGrenadeFire`, `ClassicMinigunFire`,
  `ClassicMinigunAltfire`, `ClassicShockBeamFire`, `ClassicShockProjFire`,
  `ClassicTransFire`, `ClassShieldFire`.

Every replacement class extends the matched class and adds only `DoFireEffect()` and an
`AdjustAim()` override that injects the speed-based aim deviation.

**Critical detail:** `Weapon.PostBeginPlay` assigns
`AmmoClass[m] = FireMode[m].AmmoClass` (`Weapon.uc:762`). Therefore the wrapper's
inherited `AmmoClass` must equal the original's. Extending the exact class guarantees
this; inheriting from a generic base (`InstantFire`, `ProjectileFire`) does not, and
leaves weapons with no ammo. This was the root cause of the "no ammo / can't pick up
ammo" bug and of the Classic Sniper Rifle failure.

### 2. Speed fraction

```text
MaxSpeed    = Pawn.GroundSpeed (fallback 800)
Speed       = |HorizontalVelocity|
SpeedFactor = Clamp(Speed / MaxSpeed, 0, 1)
```

- `PHYS_Walking` only; airborne and swimming return `1.0` (running endpoint).
- Horizontal velocity only, so slopes/stairs do not look like extra speed.
- No settle timer, no stance state, no shared sampling. Fully real-time.

### 3. Accuracy / spread

```text
AccPct     = StillAccuracyPct + (RunAccuracyPct - StillAccuracyPct) * SpeedFactor
AccPct     = Clamp(AccPct, 50, 100)
SpreadMult = Clamp(1.5 - AccPct / 100, 0.5, 1.0)
```

Defaults `StillAccuracyPct=100`, `RunAccuracyPct=50`, so still is twice as accurate as
running. The GUI accepts 50-100. The clamp protects against manually edited INI
values outside that range.

Applied as:

```text
F.Spread   = BaseSpread * SpreadMult
F.AimError = BaseAimError * SpreadMult   // used by bots and by the aim helper
```

### 4. Why spread scaling alone was not enough

Most stock fire modes never define `Spread`, so it defaults to `0`. That includes
`ShockBeamFire`, `SniperFire`, `LinkFire`, `ShieldFire`, `RocketFire`, `BioFire` and
`ShockProjFire`. For those weapons `Spread * 0.5` is still `0`, so the first version of
the mutator had no visible accuracy effect on most of the arsenal — the Shock Rifle
being the most obvious case. `AimError` is set on every fire mode, but
`PlayerController.AdjustAim()` ignores it for human players (it is mainly an AI hint).

The fix is to inject a real angular deviation into `AdjustAim()`:

```text
Inaccuracy   = Clamp((100 - AccPct) / 50, 0, 1)
Deviation    = Inaccuracy * F.AimError * AimDeviationScale   // rotator units
Aim.Yaw     += Random(-Deviation, +Deviation)
Aim.Pitch   += Random(-Deviation, +Deviation)
```

Every stock and UTClassic fire mode funnels through `AdjustAim()` before it traces or
spawns a projectile, so each wrapper overrides it:

```unrealscript
function Rotator AdjustAim(Vector Start, float InAimError)
{
    return class'TriggerDisciplineMut'.static.ApplyAimDeviation(
        Self, Super.AdjustAim(Start, InAimError));
}
```

`Super.AdjustAim()` preserves weapon-specific behaviour (Shock combo targeting,
Shield Gun, Sniper zoom, etc.); the helper only adds the random cone. At 100% accuracy
the deviation is zero, so a still player is laser-accurate with hitscan weapons. At
the default 50% running accuracy the cone is half of the fire mode's `AimError`
(`AimDeviationScale=0.5`). The scale is configurable in the INI but deliberately not
shown in the GUI.

### 5. Damage

```text
BaseDamageMult = Clamp(StillDamageMult + (RunDamageMult - StillDamageMult)
                       * SpeedFactor, 0, 2)
```

Defaults `StillDamageMult=1.5`, `RunDamageMult=1.0`.

### 6. UDamage

`Pawn.TakeDamage()` multiplies damage by 2 whenever the attacker has UDamage
(`InstigatedBy.HasUDamage()`). The mutator must **not** add that 2x again.

- `GetFinalDamageMult()` computes the visible final multiplier:
  - Stack unchecked: `Max(BaseDamageMult, 2.0)`
  - Stack checked: `BaseDamageMult * 2.0`
- `GetDamageAttenFor()` divides the final multiplier by the engine's UDamage factor
  before writing `DamageAtten`, so the in-game damage matches the HUD.

Because UDamage is checked when damage is applied, a projectile whose UDamage
expires during flight will not receive the engine's 2x; the pre-UDamage value is used
as-is. Hitscan weapons are unaffected.

### 7. Modifier application

`TriggerDisciplineMut.static.ApplyModifiers(WeaponFire F, BaseSpread, BaseAimError,
BaseDamageAtten)`:

1. Finds the mutator through `Level.Game.BaseMutator` → `NextMutator`.
2. Reads the owner pawn; skips vehicles and Redeemer warheads.
3. Computes damage and spread multipliers.
4. Sets `F.DamageAtten`, `F.Spread`, `F.AimError`.

Accuracy is completed by the wrapper's `AdjustAim()` override, which adds the
speed-based angular deviation described in section 4.

Wrappers capture the current values, call `ApplyModifiers`, call
`Super.DoFireEffect()`, then restore the captured values. Consequences:

- Vanilla per-shot logic (Assault Rifle recoil, Minigun spin, charging) still runs.
- The multiplier is never applied twice to the same state.
- Damage is resolved when the shot is fired, not when a projectile lands.

### 8. Weapon-specific damage paths

A few fire modes do not use `DamageAtten`:

| Class | Damage source | Handling |
|-------|---------------|----------|
| `LinkFire` | continuous `Damage` var used in `ModeTick()` | wrapper scales `Damage` around `Super.ModeTick()` |
| `ShieldFire` | local value from `MinDamage` / `MaxDamage` | wrapper scales both vars around `Super.DoFireEffect()` |
| `ClassicGrenadeFire` | `SpawnProjectile()` override that never applies `DamageAtten` | wrapper scales `Projectile.Damage` after spawn |

`ClassicShockBeamFire` / `ClassicShockProjFire` get the same combo-averaging and
`ComboDamage` snapshot logic as their vanilla counterparts.

### 9. HUD

`TriggerDisciplineDebugDisplay extends Interaction`, registered per local player by a
1 Hz timer (`PC.Player.InteractionMaster.AddInteraction`). It renders:

```text
Damage: x1.38        (two decimals, includes UDamage)
Accuracy: 50%        (50-100%)
```

`Accuracy` is the same 50-100 value used by the GUI and by `GetSpreadMult`.

The mutator is replicated (`bAlwaysRelevant`, `RemoteRole=ROLE_SimulatedProxy`) so
remote clients can run their own HUD interaction. `bDebugDraw` defaults to `True`.

### 10. Configure GUI

`TriggerDisciplineConfig extends GUIPage` (`XInterface`) exposes exactly:

- `StillAccuracyPct` — 50-100
- `RunAccuracyPct` — 50-100
- `StillDamageMult` — 0.0-2.0
- `RunDamageMult` — 0.0-2.0
- `bStackMultiplicatively`, `bDebugDraw`, `bEnableBotAI`

`AimDeviationScale` (default `0.5`) is an INI-only tuning value.

OK validates, writes `class'TriggerDisciplineMut'.default.*`, and calls
`StaticSaveConfig()`. **Restore Defaults** repopulates the fields without saving until
OK. **Cancel** closes without saving.

### 11. Vehicles / warheads

`IsInVehicle` returns true when the controller's current pawn is a `Vehicle`, or when
the controller pawn differs from the checked pawn and is a `RedeemerWarhead`. No
bonuses are applied in either case.

### 12. Bots

`TriggerDisciplinePawn` is spawned for bot-controlled pawns and periodically asks bots
at medium-long range to crouch. Optional (`bEnableBotAI`).

## Edge cases

| Case | Behaviour |
|------|-----------|
| Slopes / stairs | Horizontal velocity only |
| Jump / fall / swim | 100% speed endpoint |
| Moving platforms | World-space velocity is used as-is |
| Overlapping speed | Linear interpolation, no stance thresholds |
| Shotgun pellets | Whole-volley spread is scaled |
| Vehicles | No bonus |
| Redeemer warhead | No bonus |
| Custom/mod fire modes | Left untouched (exact-class mapping only) |
| Modded shock projectile | Base combo damage assumed 200 (vanilla) |

## Testing checklist

- [ ] Stock weapon spawns with full ammo; ammo pickups work.
- [ ] Classic Sniper Rifle spawns with ammo; Classic Sniper Ammo pickups work.
- [ ] Assault Rifle damages and has ammo.
- [ ] Minigun spins up and fires.
- [ ] Flak / Rocket / Bio / Link projectiles spawn correct classes.
- [ ] Spread and damage interpolate smoothly while accelerating/decelerating.
- [ ] Jumping gives the 100% speed endpoint.
- [ ] HUD `Damage` / `Accuracy` update live.
- [ ] Configure GUI opens; only four fields and three toggles are shown.
- [ ] Restore Defaults works; OK saves to INI.
- [ ] UDamage respects the Stack toggle without double-dipping.
- [ ] Vehicle and Redeemer warhead give no bonus.
- [ ] Shock combo uses averaged multiplier.

## File layout

```text
Classes/
  TriggerDisciplineMut.uc                    # core mutator, mapping, math
  TriggerDisciplineConfig.uc                 # Configure GUI
  TriggerDisciplineDebugDisplay.uc           # on-screen HUD interaction
  TriggerDisciplinePawn.uc                   # bot AI helper
  TriggerDiscipline<StockFireMode>.uc        # 18 stock wrappers
  TriggerDisciplineClassic<FireMode>.uc      # 14 UTClassic wrappers
  TriggerDisciplineClassShieldFire.uc        # UTClassic shield primary
```
