//=============================================================================
// Trigger Discipline Shock Beam Fire (primary)
// Extends ShockBeamFire so all vanilla properties and behaviour are inherited.
//=============================================================================
class TriggerDisciplineShockBeamFire extends ShockBeamFire;

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

	if (class'TriggerDisciplineMut'.static.ApplyModifiers(Self, BaseSpread, BaseAimError, BaseDamageAtten))
		ApplyComboAverage(BaseDamageAtten);

	Super.DoFireEffect();

	Spread = BaseSpread;
	AimError = BaseAimError;
	DamageAtten = BaseDamageAtten;
}

// The combo explosion uses the orb's ComboDamage; average the orb's firing
// multiplier with the beam's current multiplier (DESIGN 3.2).
function ApplyComboAverage(float BaseDamageAtten)
{
	local ShockProjectile Proj;
	local float OrbMult, BeamMult, BaseCombo;

	if (ShockRifle(Weapon) == None || ShockRifle(Weapon).ComboTarget == None)
		return;

	Proj = ShockRifle(Weapon).ComboTarget;
	if (Proj == None || Proj.bDeleteMe || Proj.ComboDamage <= 0.0)
		return;

	BaseCombo = 200.0; // ShockProjectile default ComboDamage
	OrbMult = Proj.ComboDamage / BaseCombo;
	if (BaseDamageAtten != 0.0)
		BeamMult = DamageAtten / BaseDamageAtten;
	else
		BeamMult = 1.0;

	Proj.ComboDamage = BaseCombo * (OrbMult + BeamMult) * 0.5;
}

defaultproperties
{
}
