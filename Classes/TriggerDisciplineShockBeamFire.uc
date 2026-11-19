//=============================================================================
// Trigger Discipline Shock Beam Fire (primary)
// Extends ShockBeamFire so all vanilla properties and behaviour are inherited.
//=============================================================================
class TriggerDisciplineShockBeamFire extends ShockBeamFire;

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
