//=============================================================================
// Trigger Discipline Mutator
// Weapon accuracy and damage scale linearly with player speed.
//
// Design notes:
//   * Two endpoints only:
//       - accuracy at 0% of Pawn.GroundSpeed and at 100%
//       - damage at 0% of Pawn.GroundSpeed and at 100%
//   * Accuracy 50% = vanilla spread, 100% = half spread (twice as accurate).
//   * Fire modes are only replaced when they are *exactly* a known vanilla or
//     UTClassic class.  Subclasses (i.e. custom/mod weapons) are left alone so
//     their ammo classes, projectiles and weapon-specific code keep working.
//   * Every replacement class extends the original class and only overrides
//     DoFireEffect(), so all other vanilla properties are inherited.
//=============================================================================
class TriggerDisciplineMut extends Mutator
	config(TriggerDiscipline)
	placeable;

//--- Configurable tuning (GUI exposes only these four numbers) --------------
// Accuracy percentage.  50 = vanilla spread, 100 = half spread (twice as
// accurate).  Range: 50-100.
var config float StillAccuracyPct;         // accuracy at 0% of GroundSpeed
var config float RunAccuracyPct;           // accuracy at 100% of GroundSpeed

// Damage multiplier.  Range: 0x-2x.
var config float StillDamageMult;          // damage at 0% of GroundSpeed
var config float RunDamageMult;            // damage at 100% of GroundSpeed

//--- Toggles -----------------------------------------------------------------
var config bool bStackMultiplicatively;    // Stack with UDamage (x2) instead of max()
var config bool bEnableBotAI;              // Bot AI crouch hints
var config bool bDebugDraw;                // Draw on-screen damage/accuracy

// Extra angular aim deviation applied on top of the weapon's native spread.
// At 50% accuracy a shot deviates by up to AimDeviationScale * AimError;
// at 100% accuracy there is no extra deviation.  0.5 is a good default.
var config float AimDeviationScale;

//--- Internal state ----------------------------------------------------------
var TriggerDisciplinePawn TDPawn;

// A client-side copy of this mutator is needed so the debug HUD Interaction can
// be attached on remote clients as well as on a listen server host.
simulated event PostNetBeginPlay()
{
	Super.PostNetBeginPlay();

	if (Level != None && Level.NetMode == NM_Client && bDebugDraw)
		SetTimer(1.0, true);
}

static function float ClampFloat(float Value, float Min, float Max)
{
	if (Value < Min) return Min;
	if (Value > Max) return Max;
	return Value;
}

//-----------------------------------------------------------------------------
// Static helpers used by the fire-mode subclasses.
//-----------------------------------------------------------------------------

static function TriggerDisciplineMut FindMutator(LevelInfo L)
{
	local Mutator M;

	if (L == None || L.Game == None)
		return None;

	for (M = L.Game.BaseMutator; M != None; M = M.NextMutator)
	{
		if (TriggerDisciplineMut(M) != None)
			return TriggerDisciplineMut(M);
	}

	return None;
}

// Applies the current speed-based modifiers to a fire mode.  The caller passes
// the fire mode's *current* values so vanilla per-shot behaviour (e.g. Assault
// Rifle recoil accumulation) is preserved, and restores them afterwards to
// avoid compounding the multiplier on later shots.
static function bool ApplyModifiers(WeaponFire F, float BaseSpread, float BaseAimError, float BaseDamageAtten)
{
	local TriggerDisciplineMut Mut;
	local Pawn P;
	local float DamageMult, SpreadMult;

	if (F == None || F.Weapon == None)
		return false;

	Mut = FindMutator(F.Level);
	if (Mut == None)
		return false;

	P = F.Weapon.Instigator;
	if (P == None || Mut.IsInVehicle(P))
		return false;

	// DamageAtten is applied before Pawn.TakeDamage(), which itself doubles
	// damage while the attacker has UDamage.  GetDamageAttenFor() returns the
	// pre-UDamage value so the configured total is achieved in game.
	DamageMult = Mut.GetDamageAttenFor(P, Mut.GetBaseDamageMult(P));
	SpreadMult = Mut.GetSpreadMult(P);

	F.DamageAtten = BaseDamageAtten * DamageMult;
	F.Spread = BaseSpread * SpreadMult;
	F.AimError = BaseAimError * SpreadMult;

	return true;
}

// Adds a random angular deviation to an already computed aim direction.
// Every vanilla/UTClassic fire mode funnels through AdjustAim(), but most of
// them have Spread == 0 (notably ShockBeamFire and SniperFire), so scaling
// Spread alone does nothing for them.  AimError is a per-weapon magnitude
// expressed in rotator units and is unused by PlayerController.AdjustAim for
// human players, which makes it a convenient baseline cone for this mutator.
static function Rotator ApplyAimDeviation(WeaponFire F, Rotator Aim)
{
	local TriggerDisciplineMut Mut;
	local Pawn P;
	local float Accuracy, Inaccuracy, Magnitude;

	if (F == None || F.Weapon == None)
		return Aim;

	Mut = FindMutator(F.Level);
	if (Mut == None)
		return Aim;

	P = F.Weapon.Instigator;
	if (P == None || Mut.IsInVehicle(P))
		return Aim;

	Accuracy = Mut.GetAccuracyPct(P);
	Inaccuracy = Mut.ClampFloat((100.0 - Accuracy) / 50.0, 0.0, 1.0);
	if (Inaccuracy <= 0.0)
		return Aim;

	Magnitude = Inaccuracy * F.AimError * Mut.AimDeviationScale;
	if (Magnitude <= 0.0)
		return Aim;

	Aim.Yaw += int((FRand() * 2.0 - 1.0) * Magnitude);
	Aim.Pitch += int((FRand() * 2.0 - 1.0) * Magnitude);

	return Aim;
}

// Damage multiplier to write into a fire mode's DamageAtten (or into a custom
// damage variable such as LinkFire.Damage or ShieldFire.MinDamage).
static function float GetCurrentDamageAttenMult(WeaponFire F)
{
	local TriggerDisciplineMut Mut;
	local Pawn P;

	if (F == None || F.Weapon == None)
		return 1.0;

	Mut = FindMutator(F.Level);
	if (Mut == None)
		return 1.0;

	P = F.Weapon.Instigator;
	if (P == None || Mut.IsInVehicle(P))
		return 1.0;

	return Mut.GetDamageAttenFor(P, Mut.GetBaseDamageMult(P));
}

//-----------------------------------------------------------------------------

function PostBeginPlay()
{
	Super.PostBeginPlay();

	FindTDPawn();

	// The debug HUD is an Interaction; (re)attach it for the local player.
	if (bDebugDraw)
		SetTimer(1.0, true);
}

function FindTDPawn()
{
	local TriggerDisciplinePawn TDP;

	foreach AllActors(class'TriggerDisciplinePawn', TDP)
	{
		TDPawn = TDP;
		break;
	}
}

function Timer()
{
	local PlayerController PC;
	local Interaction I;
	local TriggerDisciplineDebugDisplay Existing;

	if (!bDebugDraw)
		return;

	PC = Level.GetLocalPlayerController();
	if (PC == None || PC.Player == None || PC.Player.InteractionMaster == None)
		return;

	Existing = FindDebugInteraction(PC);
	if (Existing != None)
	{
		if (Existing.TDMut == None)
			Existing.TDMut = Self;
		return;
	}

	I = PC.Player.InteractionMaster.AddInteraction("TriggerDiscipline.TriggerDisciplineDebugDisplay", PC.Player);
	if (TriggerDisciplineDebugDisplay(I) != None)
		TriggerDisciplineDebugDisplay(I).TDMut = Self;
}

function TriggerDisciplineDebugDisplay FindDebugInteraction(PlayerController PC)
{
	local int i;

	if (PC == None || PC.Player == None)
		return None;

	for (i = 0; i < PC.Player.LocalInteractions.Length; i++)
	{
		if (TriggerDisciplineDebugDisplay(PC.Player.LocalInteractions[i]) != None)
			return TriggerDisciplineDebugDisplay(PC.Player.LocalInteractions[i]);
	}

	return None;
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
	local Weapon W;
	local Pawn P;
	local TriggerDisciplinePawn TDP, NewTDP;

	if (Weapon(Other) != None)
	{
		W = Weapon(Other);
		ModifyWeapon(W);
		return true;
	}

	if (Pawn(Other) != None)
	{
		P = Pawn(Other);

		// Spawn our pawn helper for bots (AI hooks / future per-pawn state)
		if (xBot(P.Controller) != None)
		{
			foreach AllActors(class'TriggerDisciplinePawn', TDP)
			{
				if (TDP.OwnerPawn == P)
					break;
			}
			if (TDP == None)
			{
				NewTDP = Spawn(class'TriggerDisciplinePawn', None, '', P.Location, P.Rotation);
				if (NewTDP != None)
					NewTDP.InitFor(P);
			}
		}
	}

	return Super.CheckReplacement(Other, bSuperRelevant);
}

function ModifyWeapon(Weapon W)
{
	local int i;
	local class<WeaponFire> OldClass, NewClass;

	if (W == None) return;

	for (i = 0; i < 2; i++)
	{
		OldClass = W.FireModeClass[i];
		if (OldClass != None)
		{
			NewClass = GetEnhancedFireModeClass(OldClass);
			if (NewClass != None && NewClass != OldClass)
				W.FireModeClass[i] = NewClass;
		}
	}
}

// Returns the enhanced replacement for a fire mode class, or None if the
// weapon is not one we know how to enhance safely.
function class<WeaponFire> GetEnhancedFireModeClass(class<WeaponFire> OriginalClass)
{
	local string N;

	if (OriginalClass == None)
		return None;

	N = string(OriginalClass);

	//--- Stock UT2004 weapons ---------------------------------------------
	if (N == "XWeapons.ShockBeamFire")          return class'TriggerDisciplineShockBeamFire';
	if (N == "XWeapons.ShockProjFire")          return class'TriggerDisciplineShockProjectileFire';
	if (N == "XWeapons.FlakFire")               return class'TriggerDisciplineFlakFire';
	if (N == "XWeapons.FlakAltFire")            return class'TriggerDisciplineFlakAltFire';
	if (N == "XWeapons.RocketFire")             return class'TriggerDisciplineRocketFire';
	if (N == "XWeapons.RocketMultiFire")        return class'TriggerDisciplineRocketAltFire';
	if (N == "XWeapons.BioFire")                return class'TriggerDisciplineBioFire';
	if (N == "XWeapons.BioChargedFire")         return class'TriggerDisciplineBioAltFire';
	if (N == "XWeapons.LinkFire")               return class'TriggerDisciplineLinkFire';
	if (N == "XWeapons.LinkAltFire")            return class'TriggerDisciplineLinkAltFire';
	if (N == "XWeapons.SniperFire")             return class'TriggerDisciplineSniperFire';
	if (N == "XWeapons.MinigunFire")            return class'TriggerDisciplineMinigunFire';
	if (N == "XWeapons.MinigunAltFire")         return class'TriggerDisciplineMinigunAltFire';
	if (N == "XWeapons.AssaultFire")            return class'TriggerDisciplineAssaultFire';
	if (N == "XWeapons.AssaultGrenade")         return class'TriggerDisciplineAssaultAltFire';
	if (N == "XWeapons.TransFire")              return class'TriggerDisciplineTransFire';
	if (N == "XWeapons.ShieldFire")             return class'TriggerDisciplineShieldFire';
	if (N == "XWeapons.ShieldAltFire")          return class'TriggerDisciplineShieldAltFire';

	//--- UTClassic weapons ------------------------------------------------
	if (N == "UTClassic.ClassicSniperFire")      return class'TriggerDisciplineClassicSniperFire';
	if (N == "UTClassic.ClassicBioFire")         return class'TriggerDisciplineClassicBioFire';
	if (N == "UTClassic.ClassicBioChargedFire")  return class'TriggerDisciplineClassicBioChargedFire';
	if (N == "UTClassic.ClassicFlakFire")        return class'TriggerDisciplineClassicFlakFire';
	if (N == "UTClassic.ClassicFlakAltFire")     return class'TriggerDisciplineClassicFlakAltFire';
	if (N == "UTClassic.ClassicRocketFire")      return class'TriggerDisciplineClassicRocketFire';
	if (N == "UTClassic.ClassicRocketMultifire") return class'TriggerDisciplineClassicRocketMultiFire';
	if (N == "UTClassic.ClassicGrenadeFire")     return class'TriggerDisciplineClassicGrenadeFire';
	if (N == "UTClassic.ClassicMinigunFire")     return class'TriggerDisciplineClassicMinigunFire';
	if (N == "UTClassic.ClassicMinigunAltfire")  return class'TriggerDisciplineClassicMinigunAltFire';
	if (N == "UTClassic.ClassicShockBeamFire")   return class'TriggerDisciplineClassicShockBeamFire';
	if (N == "UTClassic.ClassicShockProjFire")   return class'TriggerDisciplineClassicShockProjFire';
	if (N == "UTClassic.ClassicTransFire")       return class'TriggerDisciplineClassicTransFire';
	if (N == "UTClassic.ClassShieldFire")        return class'TriggerDisciplineClassShieldFire';

	// Unknown/modded fire mode: leave it untouched so nothing breaks.
	return None;
}

//-----------------------------------------------------------------------------
// Speed-based math
//-----------------------------------------------------------------------------

// 0.0 = completely still, 1.0 = at (or above) Pawn.GroundSpeed.
// Only ground movement counts; jumping/falling counts as full speed.
function float GetSpeedFraction(Pawn P)
{
	local float Speed, MaxSpeed;

	if (P == None)
		return 1.0;

	if (P.Physics != PHYS_Walking)
		return 1.0;

	MaxSpeed = P.GroundSpeed;
	if (MaxSpeed <= 0)
		MaxSpeed = 800.0;

	// Ignore the artificial vertical component added when walking up slopes.
	Speed = VSize(P.Velocity * vect(1, 1, 0));

	return ClampFloat(Speed / MaxSpeed, 0.0, 1.0);
}

// Accuracy percentage interpolated by speed.  50 = vanilla spread,
// 100 = half spread.
function float GetAccuracyPct(Pawn P)
{
	local float Pct, T;

	if (P == None)
		return 50.0;

	T = GetSpeedFraction(P);
	Pct = StillAccuracyPct + (RunAccuracyPct - StillAccuracyPct) * T;

	return ClampFloat(Pct, 50.0, 100.0);
}

// Convert the accuracy percentage into a spread multiplier.
//   50%  -> 1.0 (vanilla spread)
//   100% -> 0.5 (half spread / twice as accurate)
function float GetSpreadMult(Pawn P)
{
	return ClampFloat(1.5 - GetAccuracyPct(P) / 100.0, 0.5, 1.0);
}

// Base damage multiplier before UDamage is taken into account.
function float GetBaseDamageMult(Pawn P)
{
	local float T;

	if (P == None)
		return 1.0;

	T = GetSpeedFraction(P);
	return ClampFloat(StillDamageMult + (RunDamageMult - StillDamageMult) * T, 0.0, 2.0);
}

// HUD accuracy, using the same 50-100 scale as the config fields.
function float GetAccuracyPercent(Pawn P)
{
	return GetAccuracyPct(P);
}

// UDamage is applied by Pawn.TakeDamage() (Damage *= 2), not by the weapon.
function float GetUDamageFactor(Pawn P)
{
	local xPawn XP;

	XP = xPawn(P);
	if (XP != None && XP.HasUDamage())
		return 2.0;

	return 1.0;
}

// Final in-game damage multiplier, including UDamage and the "Stack" toggle.
// Used by the HUD and as the basis for GetDamageAttenFor().
function float GetFinalDamageMult(Pawn P, float BaseMult)
{
	local float FinalMult;

	if (P == None) return BaseMult;

	FinalMult = BaseMult;

	if (GetUDamageFactor(P) > 1.0)
	{
		if (bStackMultiplicatively)
			FinalMult *= 2.0;
		else
			FinalMult = Max(FinalMult, 2.0);
	}

	return FinalMult;
}

// DamageAtten value that produces the desired final damage after the engine's
// UDamage doubling.  With UDamage active: atten = final / 2.
function float GetDamageAttenFor(Pawn P, float BaseMult)
{
	local float Factor;

	Factor = GetUDamageFactor(P);
	if (Factor <= 0.0)
		Factor = 1.0;

	return GetFinalDamageMult(P, BaseMult) / Factor;
}

function bool IsInVehicle(Pawn P)
{
	local Controller C;

	if (P == None) return false;
	C = P.Controller;
	if (C == None) return false;

	if (Vehicle(C.Pawn) != None)
		return true;

	if (C.Pawn != None && C.Pawn != P && C.Pawn.IsA('RedeemerWarhead'))
		return true;

	return false;
}

defaultproperties
{
	StillAccuracyPct=100.0
	RunAccuracyPct=50.0
	StillDamageMult=1.5
	RunDamageMult=1.0
	bStackMultiplicatively=False
	bEnableBotAI=True
	bDebugDraw=True
	AimDeviationScale=0.5
	bAlwaysRelevant=True
	bAddToServerPackages=True
	RemoteRole=ROLE_SimulatedProxy
	GroupName="TriggerDiscipline"
	FriendlyName="Trigger Discipline"
	Description="Weapon accuracy and damage scale with player speed."
	ConfigMenuClassName="TriggerDiscipline.TriggerDisciplineConfig"
}
