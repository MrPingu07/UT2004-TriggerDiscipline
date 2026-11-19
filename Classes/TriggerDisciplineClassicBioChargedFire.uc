//=============================================================================
// Trigger Discipline Classic Bio Alt Fire (charged)
// Extends ClassicBioChargedFire so every vanilla property (ammo, damage, projectiles,
// animations, sounds and weapon-specific logic) is inherited unchanged.
//=============================================================================
class TriggerDisciplineClassicBioChargedFire extends ClassicBioChargedFire;

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

defaultproperties
{
}
