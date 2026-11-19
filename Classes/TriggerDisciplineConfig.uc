//=============================================================================
// Trigger Discipline Configuration Page
// Shown by the "Configure" button in the Mutators menu.
//
// Only four numbers and three toggles are exposed.  Both numbers interpolate
// linearly between 0% and 100% of Pawn.GroundSpeed.
//=============================================================================
class TriggerDisciplineConfig extends GUIPage;

var moEditBox StillAccuracyBox, RunAccuracyBox, StillDamageBox, RunDamageBox;
var moCheckBox StackBox, DebugBox, BotBox;

function InitComponent(GUIController MyController, GUIComponent MyOwner)
{
	Super.InitComponent(MyController, MyOwner);

	StillAccuracyBox = moEditBox(Controls[4]);
	RunAccuracyBox   = moEditBox(Controls[5]);
	StillDamageBox = moEditBox(Controls[7]);
	RunDamageBox   = moEditBox(Controls[8]);
	StackBox       = moCheckBox(Controls[9]);
	DebugBox       = moCheckBox(Controls[10]);
	BotBox         = moCheckBox(Controls[11]);

	LoadCurrentValues();
}

function LoadCurrentValues()
{
	StillAccuracyBox.SetText(string(class'TriggerDisciplineMut'.default.StillAccuracyPct));
	RunAccuracyBox.SetText(string(class'TriggerDisciplineMut'.default.RunAccuracyPct));
	StillDamageBox.SetText(string(class'TriggerDisciplineMut'.default.StillDamageMult));
	RunDamageBox.SetText(string(class'TriggerDisciplineMut'.default.RunDamageMult));
	StackBox.Checked(class'TriggerDisciplineMut'.default.bStackMultiplicatively);
	DebugBox.Checked(class'TriggerDisciplineMut'.default.bDebugDraw);
	BotBox.Checked(class'TriggerDisciplineMut'.default.bEnableBotAI);
}

function float ReadFloat(moEditBox Box, float MinValue, float MaxValue)
{
	local float V;

	V = float(Box.GetText());
	if (V < MinValue) V = MinValue;
	if (V > MaxValue) V = MaxValue;
	Box.SetText(string(V));
	return V;
}

// OK button
function bool InternalOnClick(GUIComponent Sender)
{
	class'TriggerDisciplineMut'.default.StillAccuracyPct = ReadFloat(StillAccuracyBox, 50.0, 100.0);
	class'TriggerDisciplineMut'.default.RunAccuracyPct = ReadFloat(RunAccuracyBox, 50.0, 100.0);
	class'TriggerDisciplineMut'.default.StillDamageMult = ReadFloat(StillDamageBox, 0.0, 2.0);
	class'TriggerDisciplineMut'.default.RunDamageMult = ReadFloat(RunDamageBox, 0.0, 2.0);
	class'TriggerDisciplineMut'.default.bStackMultiplicatively = StackBox.IsChecked();
	class'TriggerDisciplineMut'.default.bDebugDraw = DebugBox.IsChecked();
	class'TriggerDisciplineMut'.default.bEnableBotAI = BotBox.IsChecked();

	class'TriggerDisciplineMut'.static.StaticSaveConfig();
	Controller.CloseMenu(false);
	return true;
}

// Restore Defaults button
function bool ResetToDefaults(GUIComponent Sender)
{
	StillAccuracyBox.SetText("100");
	RunAccuracyBox.SetText("50");
	StillDamageBox.SetText("1.5");
	RunDamageBox.SetText("1");
	StackBox.Checked(False);
	DebugBox.Checked(True);
	BotBox.Checked(True);
	return true;
}

function bool InternalOnCancel(GUIComponent Sender)
{
	Controller.CloseMenu(true);
	return true;
}

defaultproperties
{
	Begin Object Class=GUIButton Name=DialogBackground
		WinWidth=1.0
		WinHeight=1.0
		WinTop=0
		WinLeft=0
		bAcceptsInput=false
		bNeverFocus=true
		StyleName="ComboListBox"
		bBoundToParent=true
		bScaleToParent=true
	End Object
	Controls(0)=GUIButton'DialogBackground'

	Begin Object Class=GUILabel Name=TitleLabel
		Caption="Trigger Discipline"
		TextAlign=TXTA_Center
		TextColor=(R=220,G=180,B=0,A=255)
		TextFont="UT2HeaderFont"
		WinWidth=1.0
		WinHeight=0.06
		WinLeft=0.0
		WinTop=0.08
		bBoundToParent=true
	End Object
	Controls(1)=GUILabel'TitleLabel'

	Begin Object Class=GUILabel Name=HintLabel
		Caption="Accuracy: 50 = vanilla spread, 100 = half spread. Damage: 0x-2x. Both scale linearly with speed."
		TextAlign=TXTA_Center
		TextColor=(R=200,G=200,B=200,A=255)
		TextFont="UT2SmallFont"
		WinWidth=1.0
		WinHeight=0.05
		WinLeft=0.0
		WinTop=0.15
		bBoundToParent=true
	End Object
	Controls(2)=GUILabel'HintLabel'

	Begin Object Class=GUILabel Name=SpreadLabel
		Caption="ACCURACY"
		TextAlign=TXTA_Center
		TextColor=(R=220,G=180,B=0,A=255)
		TextFont="UT2SmallFont"
		WinWidth=1.0
		WinHeight=0.04
		WinLeft=0.0
		WinTop=0.21
		bBoundToParent=true
	End Object
	Controls(3)=GUILabel'SpreadLabel'

	Begin Object Class=moEditBox Name=StillAccuracyBoxEdit
		WinWidth=0.42
		WinHeight=0.05
		WinLeft=0.05
		WinTop=0.26
		Caption="At 0% speed (50-100%)"
		bReadOnly=false
		bBoundToParent=true
	End Object
	Controls(4)=moEditBox'StillAccuracyBoxEdit'

	Begin Object Class=moEditBox Name=RunAccuracyBoxEdit
		WinWidth=0.42
		WinHeight=0.05
		WinLeft=0.53
		WinTop=0.26
		Caption="At 100% speed (50-100%)"
		bReadOnly=false
		bBoundToParent=true
	End Object
	Controls(5)=moEditBox'RunAccuracyBoxEdit'

	Begin Object Class=GUILabel Name=DamageLabel
		Caption="DAMAGE"
		TextAlign=TXTA_Center
		TextColor=(R=220,G=180,B=0,A=255)
		TextFont="UT2SmallFont"
		WinWidth=1.0
		WinHeight=0.04
		WinLeft=0.0
		WinTop=0.36
		bBoundToParent=true
	End Object
	Controls(6)=GUILabel'DamageLabel'

	Begin Object Class=moEditBox Name=StillDamageBoxEdit
		WinWidth=0.42
		WinHeight=0.05
		WinLeft=0.05
		WinTop=0.41
		Caption="At 0% speed (x)"
		bReadOnly=false
		bBoundToParent=true
	End Object
	Controls(7)=moEditBox'StillDamageBoxEdit'

	Begin Object Class=moEditBox Name=RunDamageBoxEdit
		WinWidth=0.42
		WinHeight=0.05
		WinLeft=0.53
		WinTop=0.41
		Caption="At 100% speed (x)"
		bReadOnly=false
		bBoundToParent=true
	End Object
	Controls(8)=moEditBox'RunDamageBoxEdit'

	Begin Object Class=moCheckBox Name=StackBoxEdit
		WinWidth=0.42
		WinHeight=0.05
		WinLeft=0.05
		WinTop=0.55
		Caption="Stack with UDamage"
		bBoundToParent=true
	End Object
	Controls(9)=moCheckBox'StackBoxEdit'

	Begin Object Class=moCheckBox Name=DebugBoxEdit
		WinWidth=0.42
		WinHeight=0.05
		WinLeft=0.05
		WinTop=0.63
		Caption="Show onscreen indicators"
		bBoundToParent=true
	End Object
	Controls(10)=moCheckBox'DebugBoxEdit'

	Begin Object Class=moCheckBox Name=BotBoxEdit
		WinWidth=0.42
		WinHeight=0.05
		WinLeft=0.53
		WinTop=0.63
		Caption="Bot AI crouch hints"
		bBoundToParent=true
	End Object
	Controls(11)=moCheckBox'BotBoxEdit'

	Begin Object Class=GUIButton Name=OkButton
		Caption="OK"
		WinWidth=0.2
		WinHeight=0.05
		WinLeft=0.65
		WinTop=0.90
		OnClick=InternalOnClick
		bBoundToParent=true
	End Object
	Controls(12)=GUIButton'OkButton'

	Begin Object Class=GUIButton Name=ResetButton
		Caption="Restore Defaults"
		WinWidth=0.2
		WinHeight=0.05
		WinLeft=0.15
		WinTop=0.90
		OnClick=ResetToDefaults
		bBoundToParent=true
	End Object
	Controls(13)=GUIButton'ResetButton'

	Begin Object Class=GUIButton Name=CancelButton
		Caption="Cancel"
		WinWidth=0.2
		WinHeight=0.05
		WinLeft=0.40
		WinTop=0.90
		OnClick=InternalOnCancel
		bBoundToParent=true
	End Object
	Controls(14)=GUIButton'CancelButton'

	WinLeft=0.05
	WinTop=0.1
	WinWidth=0.9
	WinHeight=0.8
	bRequire640x480=True
}
