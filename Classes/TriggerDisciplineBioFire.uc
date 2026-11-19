//=============================================================================
// Trigger Discipline Bio Fire (primary)
// Extends BioFire so every vanilla property (ammo, damage, projectiles,
// animations, sounds and weapon-specific logic) is inherited unchanged.
//=============================================================================
class TriggerDisciplineBioFire extends BioFire;

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
