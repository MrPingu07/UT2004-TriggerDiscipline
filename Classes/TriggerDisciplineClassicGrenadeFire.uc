//=============================================================================
// Trigger Discipline Classic Grenade Fire
// Extends ClassicGrenadeFire so every vanilla property (ammo, damage, projectiles,
// animations, sounds and weapon-specific logic) is inherited unchanged.
//=============================================================================
class TriggerDisciplineClassicGrenadeFire extends ClassicGrenadeFire;

// Every stock/UTClassic fire mode calls AdjustAim() before firing.  Most of
// them leave Spread at zero, so the spread multiplier alone has no effect on
// them.  Inject the speed-based deviation here instead.
function Rotator AdjustAim(Vector Start, float InAimError)
{
	return class'TriggerDisciplineMut'.static.ApplyAimDeviation(Self, Super.AdjustAim(Start, InAimError));
}

// ClassicGrenadeFire overrides SpawnProjectile() and does not apply
// DamageAtten itself (unlike AssaultGrenade), so do it here.
function Projectile SpawnProjectile(Vector Start, Rotator Dir)
{
	local Projectile P;

	P = Super.SpawnProjectile(Start, Dir);
	if (P != None)
		P.Damage *= DamageAtten;

	return P;
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

defaultproperties
{
}
