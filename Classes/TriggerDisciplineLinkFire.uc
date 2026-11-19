//=============================================================================
// Trigger Discipline Link Fire (primary)
// Extends LinkFire so every vanilla property (ammo, damage, projectiles,
// animations, sounds and weapon-specific logic) is inherited unchanged.
//=============================================================================
class TriggerDisciplineLinkFire extends LinkFire;

// LinkFire deals damage continuously from ModeTick(), not from DoFireEffect(),
// so the damage bonus has to be applied around each tick.
simulated function ModeTick(float dt)
{
	local float BaseDamage, Mult;

	BaseDamage = Damage;
	Mult = class'TriggerDisciplineMut'.static.GetCurrentDamageAttenMult(Self);
	Damage = BaseDamage * Mult;

	Super.ModeTick(dt);

	Damage = BaseDamage;
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
