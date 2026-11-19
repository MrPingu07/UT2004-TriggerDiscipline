//=============================================================================
// Trigger Discipline Classic Rocket Fire
// Extends ClassicRocketFire so every vanilla property (ammo, damage, projectiles,
// animations, sounds and weapon-specific logic) is inherited unchanged.
//=============================================================================
class TriggerDisciplineClassicRocketFire extends ClassicRocketFire;

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
