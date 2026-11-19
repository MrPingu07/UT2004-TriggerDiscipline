# Trigger Discipline - Roadmap

## Done

- [x] Single speed-based interpolation for spread and damage
- [x] Endpoint config: accuracy at 0%/100% of `Pawn.GroundSpeed`
- [x] Endpoint config: damage at 0%/100% of `Pawn.GroundSpeed`
- [x] Accuracy input range 0-100% (0 = worst, 100 = laser)
- [x] Damage input range 0x-10x
- [x] Real-time interpolation while accelerating/decelerating
- [x] Jumping / falling uses the 100% speed endpoint
- [x] Fire-time damage resolution
- [x] Shock combo averaging (stock + UTClassic)
- [x] UDamage stacking toggle without double-dipping
- [x] Vehicle / Redeemer warhead immunity
- [x] Bot crouch hints
- [x] Stock UT2004 fire-mode wrappers that extend the exact vanilla classes
- [x] UTClassic wrappers (Classic Sniper/Rocket/Flak/Bio/Shock/Minigun/Shield/Trans)
- [x] Ammo fix: wrappers inherit `AmmoClass` from the original fire mode
- [x] Link beam, Shield Gun charge and Classic grenade damage scaling
- [x] Simple Configure GUI (four fields, three toggles, Restore Defaults)
- [x] Live on-screen indicators (`Damage: x1.38`, `Accuracy: 50%`)
- [x] HUD replication to network clients
- [x] Non-compounding per-shot modifier application
- [x] Universal aim deviation via `AdjustAim()` so zero-`Spread` weapons (Shock Rifle,
      Sniper, Link, Shield, projectiles) are affected too

## Next

- [ ] Apply bonuses to custom/mod fire modes that subclass stock classes.
      Requires a per-weapon wrapper or a different runtime hook; the current
      exact-class mapping deliberately leaves them untouched to avoid breaking ammo
      and projectiles.
- [ ] Add instagib / arena mutator interaction checks.
- [ ] Verify behaviour on dedicated servers (client-side HUD, server-side damage).
- [ ] Optional per-player announcements when a crouched shot lands.
- [ ] Statistics tracking (average speed, bonus damage dealt).
- [ ] Automated in-game regression map.
