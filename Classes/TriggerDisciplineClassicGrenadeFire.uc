//=============================================================================
// Trigger Discipline Classic Grenade Fire
// Extends ClassicGrenadeFire so every vanilla property (ammo, damage, projectiles,
// animations, sounds and weapon-specific logic) is inherited unchanged.
//=============================================================================
class TriggerDisciplineClassicGrenadeFire extends ClassicGrenadeFire;

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
