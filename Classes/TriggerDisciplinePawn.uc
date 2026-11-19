//=============================================================================
// Trigger Discipline Pawn Helper
// Attaches to pawns to provide bot AI hooks and state tracking
//=============================================================================
class TriggerDisciplinePawn extends Actor;

var Pawn OwnerPawn;
var TriggerDisciplineMut TDMut;
var float LastCrouchTime;
var float LastStandStillTime;
var bool bWantsToCrouch;
var float NextAIDecisionTime;

function InitFor(Pawn P)
{
	local TriggerDisciplineMut M;

	OwnerPawn = P;
	SetLocation(P.Location);
	SetBase(P);

	// Find mutator
	foreach AllActors(class'TriggerDisciplineMut', M)
	{
		TDMut = M;
		break;
	}
}

simulated function Tick(float DeltaTime)
{
	Super.Tick(DeltaTime);

	if (OwnerPawn == None || OwnerPawn.bDeleteMe)
	{
		Destroy();
		return;
	}

	// Update location to follow pawn
	SetLocation(OwnerPawn.Location);

	// Bot AI: Encourage crouching/holding position at range
	if (TDMut != None && TDMut.bEnableBotAI && xBot(OwnerPawn.Controller) != None)
	{
		BotAITick(DeltaTime);
	}
}

function BotAITick(float DeltaTime)
{
	local xBot Bot;
	local Pawn Enemy;
	local float Dist;
	local Vector EnemyLoc;

	Bot = xBot(OwnerPawn.Controller);
	if (Bot == None) return;

	// Only make decisions periodically
	if (Level.TimeSeconds < NextAIDecisionTime) return;
	NextAIDecisionTime = Level.TimeSeconds + 2.0 + FRand() * 3.0; // 2-5 seconds

	Enemy = Bot.Enemy;
	if (Enemy == None) return;

	Dist = VSize(OwnerPawn.Location - Enemy.Location);
	EnemyLoc = Enemy.Location;

	// At medium-long range (>1000uu), occasionally crouch
	if (Dist > 1000.0)
	{
		if (FRand() < 0.3) // 30% chance to crouch
		{
			bWantsToCrouch = true;
			LastCrouchTime = Level.TimeSeconds;
			OwnerPawn.bWantsToCrouch = true;
		}
	}
	else if (Dist < 500.0)
	{
		// Close range - don't crouch, stay mobile
		bWantsToCrouch = false;
		OwnerPawn.bWantsToCrouch = false;
	}

	// Apply crouch desire
	if (bWantsToCrouch && Level.TimeSeconds - LastCrouchTime < 3.0)
	{
		// Keep crouching for up to 3 seconds
		OwnerPawn.bWantsToCrouch = true;
	}
	else
	{
		bWantsToCrouch = false;
		OwnerPawn.bWantsToCrouch = false;
	}
}

function bool IsGoodCrouchSpot()
{
	// Simple check: not in the open, has some cover
	local Actor HitActor;
	local Vector HitLocation, HitNormal;
	local Vector Start, End;

	Start = OwnerPawn.Location + vect(0,0,50);
	End = Start + vect(0,0,-200);

	// Check for ceiling above (indoor/cover) - use zero extent trace
	HitActor = Trace(HitLocation, HitNormal, End, Start, true);
	if (HitActor != None)
	{
		return true;
	}

	return false;
}

function Destroyed()
{
	Super.Destroyed();
}

defaultproperties
{
	bCollideWorld=False
	bCollideActors=False
	bHidden=True
	RemoteRole=ROLE_None
}