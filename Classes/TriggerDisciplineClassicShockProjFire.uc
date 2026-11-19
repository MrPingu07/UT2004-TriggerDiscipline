//=============================================================================
// Trigger Discipline Classic Shock Orb Fire
// Extends ClassicShockProjFire so every vanilla property (ammo, damage, projectiles,
// animations, sounds and weapon-specific logic) is inherited unchanged.
//=============================================================================
class TriggerDisciplineClassicShockProjFire extends ClassicShockProjFire;

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

	if (ShockProjectile(P) != None && Default.DamageAtten != 0.0)
		ShockProjectile(P).ComboDamage *= DamageAtten / Default.DamageAtten;

	return P;
}

defaultproperties
{
}
