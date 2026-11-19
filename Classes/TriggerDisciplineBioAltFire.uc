//=============================================================================
// Trigger Discipline Bio Alt Fire (charged)
// Extends BioChargedFire so every vanilla property (ammo, damage, projectiles,
// animations, sounds and weapon-specific logic) is inherited unchanged.
//=============================================================================
class TriggerDisciplineBioAltFire extends BioChargedFire;

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
