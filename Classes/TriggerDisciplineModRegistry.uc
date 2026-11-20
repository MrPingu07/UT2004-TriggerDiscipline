//=============================================================================
// Optional weapon-pack registry.
//
// The core mutator never references the mod packages directly.  If the
// optional TriggerDisciplineWeaponPacks package is installed, a subclass of
// this Info class is spawned at runtime and used to map mod fire modes to
// their Trigger Discipline wrappers.  If it is missing, mod weapons are simply
// left untouched.
//=============================================================================
class TriggerDisciplineModRegistry extends Info;

function class<WeaponFire> GetModFireModeClass(class<WeaponFire> OriginalClass)
{
	return None;
}

defaultproperties
{
	bHidden=True
	bAlwaysRelevant=False
	bOnlyOwnerSee=False
	RemoteRole=ROLE_None
	CollisionRadius=0.0
	CollisionHeight=0.0
	bBlockActors=False
	bBlockPlayers=False
	bCollideActors=False
	bCollideWorld=False
}
