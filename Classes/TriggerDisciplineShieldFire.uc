//=============================================================================
// Trigger Discipline Shield Fire (primary)
// Extends ShieldFire so every vanilla property (ammo, damage, projectiles,
// animations, sounds and weapon-specific logic) is inherited unchanged.
//=============================================================================
class TriggerDisciplineShieldFire extends ShieldFire;

// ShieldFire computes damage locally from MinDamage/MaxDamage instead of using
// DamageAtten, so scale those around the vanilla implementation.
function DoFireEffect()
{
	local float BaseMinDamage, BaseMaxDamage, BaseSpread, BaseAimError, BaseDamageAtten, Mult;

	BaseSpread = Spread;
	BaseAimError = AimError;
	BaseDamageAtten = DamageAtten;
	BaseMinDamage = MinDamage;
	BaseMaxDamage = MaxDamage;

	class'TriggerDisciplineMut'.static.ApplyModifiers(Self, BaseSpread, BaseAimError, BaseDamageAtten);

	Mult = class'TriggerDisciplineMut'.static.GetCurrentDamageAttenMult(Self);
	MinDamage = BaseMinDamage * Mult;
	MaxDamage = BaseMaxDamage * Mult;

	Super.DoFireEffect();

	Spread = BaseSpread;
	AimError = BaseAimError;
	DamageAtten = BaseDamageAtten;
	MinDamage = BaseMinDamage;
	MaxDamage = BaseMaxDamage;
}

defaultproperties
{
}
