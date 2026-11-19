//=============================================================================
// Trigger Discipline Shock Projectile Fire (alt fire - orb)
// Extends ShockProjFire so ammo, projectile class and behaviour are inherited.
//=============================================================================
class TriggerDisciplineShockProjectileFire extends ShockProjFire;

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
