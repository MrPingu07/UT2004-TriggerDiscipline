//=============================================================================
// Trigger Discipline Shock Projectile Fire (alt fire - orb)
// Extends ShockProjFire so ammo, projectile class and behaviour are inherited.
//=============================================================================
class TriggerDisciplineShockProjectileFire extends ShockProjFire;

// Every stock/UTClassic fire mode calls AdjustAim() before firing.  Most of
// them leave Spread at zero, so the spread multiplier alone has no effect on
// them.  Inject the speed-based deviation here instead.
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

function projectile SpawnProjectile(Vector Start, Rotator Dir)
{
	local Projectile P;

	P = Super.SpawnProjectile(Start, Dir);

	// Scale the combo explosion with the stance used when the orb was fired.
	if (ShockProjectile(P) != None && Default.DamageAtten != 0.0)
		ShockProjectile(P).ComboDamage *= DamageAtten / Default.DamageAtten;

	return P;
}

defaultproperties
{
}
