//=============================================================================
// Trigger Discipline Debug Display
// A per-player Interaction that draws live damage/accuracy indicators.
//=============================================================================
class TriggerDisciplineDebugDisplay extends Interaction;

var TriggerDisciplineMut TDMut;

event Initialized()
{
	bVisible = true;
	bRequiresTick = true;
	bActive = false;
}

function string FormatTwoDecimals(float Value)
{
	local int Whole, Frac;
	local string FracStr;

	Whole = int(Value);
	Frac = int((Value - Whole) * 100.0 + 0.5);
	if (Frac >= 100)
	{
		Whole++;
		Frac -= 100;
	}

	if (Frac < 10)
		FracStr = "0" $ string(Frac);
	else
		FracStr = string(Frac);

	return string(Whole) $ "." $ FracStr;
}

function PostRender(Canvas C)
{
	local PlayerController PC;
	local Pawn P;
	local float DamageMult, AccuracyPct;

	if (TDMut == None || !TDMut.bDebugDraw)
		return;

	if (ViewportOwner == None)
		return;

	PC = ViewportOwner.Actor;
	if (PC == None)
		return;

	P = PC.Pawn;
	if (P == None || P.bDeleteMe || TDMut.IsInVehicle(P))
		return;

	DamageMult = TDMut.GetFinalDamageMult(P, TDMut.GetBaseDamageMult(P));
	AccuracyPct = TDMut.GetAccuracyPercent(P);

	C.Font = class'HUD'.static.GetConsoleFont(C);
	C.SetDrawColor(255, 255, 255);

	C.SetPos(10.0, 10.0);
	C.DrawText("Damage: x" $ FormatTwoDecimals(DamageMult));

	C.SetPos(10.0, 30.0);
	C.DrawText("Accuracy: " $ string(int(AccuracyPct + 0.5)) $ "%");
}

defaultproperties
{
}
