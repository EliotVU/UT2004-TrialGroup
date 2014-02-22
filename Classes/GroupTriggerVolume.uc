/*==============================================================================
   TrialGroup
   Copyright (C) 2010 - 2014 Eliot Van Uytfanghe

   This program is free software; you can redistribute and/or modify
   it under the terms of the Open Unreal Mod License version 1.1.
==============================================================================*/
class GroupTriggerVolume extends PhysicsVolume
	hidecategories(Lighting,LightColor,Karma,Force,Sound,PhysicsVolume)
	placeable;

var editconst GroupManager Manager;
var() protected editconst const noexport string Info;

/**
 * Amount of group members required for this volume to be considered full.
 * If set to 0 then @MaxGroupSize will be used instead.
 */
var() int RequiredMembersCount;

/** Whether this volume wants any HUD rendering at all. */
var() bool bDisplayOnHUD;

/** If this and @bDisplayOnHUD is true, the location and distance from the viewer will be rendered on the HUD. */
var() bool bDisplayTrackingOnHUD;

/** If this and @bDisplayOnHUD is true, the progress will be rendered to any group members. */
var() bool bDisplayInfoOnHUD;

/** Minimum time before this volume can be triggered again. */
var() float ReTriggerDelay;
var float TriggerTime;

// Fallback for outdated maps.
var deprecated string LastTriggeredByGroupName;

// Operator from ServerBTimes.u
static final operator(102) string $( Color B, coerce string A )
{
	return (Chr( 0x1B ) $ (Chr( Max( B.R, 1 ) ) $ Chr( Max( B.G, 1 ) ) $ Chr( Max( B.B, 1 ) ))) $ A;
}

/**
 * Returns a list of all xPawn(Players) that are touching this volume.
 * #Client: Returns only the touches of local actors such as a player's own pawn but not any others.
 * #Server: Returns any touching xPawn.
 */
final simulated function GetPlayersInVolume( out array<Pawn> players )
{
	local int i;

	for( i = 0; i < Touching.Length; ++ i )
	{
    	if( xPawn(Touching[i]) == none )
    	{
    		continue;
    	}
		players[players.Length] = Pawn(Touching[i]);
	}
}

final function FilterPlayersByGroup( int groupIndex, out array<Pawn> members )
{
	local int i;

	for( i = 0; i < members.Length; ++ i )
	{
		if( Manager.GetMemberIndexByGroupIndex( members[i].Controller, groupIndex ) == -1 )
		{
			members.Remove(i, 1);
			-- i;
		}
	}
}

final simulated function int GetRequiredMembersCount( GroupManager groupManager )
{
	if( RequiredMembersCount > 0 )
		return RequiredMembersCount;
	return groupManager.MaxGroupSize;
}

final simulated function int GetMissingMembersCount( int membersCount, GroupManager groupManager )
{
	return GetRequiredMembersCount( groupManager ) - membersCount;
}

final function bool HasAllRequiredMembers( array<Pawn> foundMembers, out int missingCount )
{
	missingCount = GetMissingMembersCount( foundMembers.Length, Manager );
	// The group is full and all of them are in the volume!, then triggerevent...
	if( foundMembers.Length >= GetRequiredMembersCount( Manager ) && missingCount <= 0 )
	{
		return true;
	}
	return false;
}

simulated function bool AllowRendering( GroupInstance group, PlayerController viewer )
{
	return bDisplayOnHUD || (!bDisplayInfoOnHUD && !bDisplayTrackingOnHUD);
}

simulated function bool AllowInfoRendering( GroupInstance group, PlayerController viewer )
{
	return bDisplayInfoOnHUD;
}

simulated function RenderInfo( Canvas C, GroupInstance group, PlayerController viewer )
{
	local int membersIn;
	local array<Pawn> members;

	// temp
	local int i;
	local string s;
	local float xl, yl;
	local Vector screenPos;

	GetPlayersInVolume( members );
	for( i = 0; i < members.Length; ++ i )
	{
		if( !group.IsMember( members[i] ) )
		{
			continue;
		}
		++ membersIn;
	}
	s = membersIn $ "/" $ GetRequiredMembersCount( group.Manager );

	screenPos = C.WorldToScreen( Location );
	C.StrLen( s, xl, yl );
	C.SetPos( screenPos.X - xl*0.5, screenPos.Y - yl*0.5 );
	C.DrawColor = group.GroupColor;
	C.DrawText( s );
}

simulated function bool AllowTrackingRendering( GroupInstance group, PlayerController viewer )
{
	return bDisplayTrackingOnHUD;
}

simulated function RenderTracking( Canvas C, HUD_Assault hud, GroupInstance group, PlayerController viewer )
{
	local Vector screenPos;

	screenPos = C.WorldToScreen( Location );
	C.DrawColor = group.GroupColor;
	C.DrawColor.A = 50;
	hud.DrawActorTracking( C, self, false, screenPos );
}

event PawnEnteredVolume( Pawn Other )
{
	local int i, missingMembersCount, groupIndex;
	local array<Pawn> members;

	if( xPawn(Other) == none || Other.Controller == none )
	{
		return;
	}

    groupIndex = Manager.GetGroupIndexByPlayer( Other.Controller );
	if( groupIndex == -1 )
	{
		xPawn(Other).ClientMessage( Class'GroupManager'.Default.GroupColor
			$ "Sorry you cannot contribute to this volume because you are not in a group!" );
		return;
	}

	GetPlayersInVolume( members );
	// Because we are comparing by members length to find out whether the group is full, it is important to clear all None references.
	Manager.ClearEmptyGroup( groupIndex );
	FilterPlayersByGroup( groupIndex, members );

	if( Manager.Groups[groupIndex].Members.Length == Manager.MaxGroupSize
		&& HasAllRequiredMembers( members, missingMembersCount ) )
	{
		if( Level.TimeSeconds - TriggerTime < ReTriggerDelay )
		{
			return;
		}
		TriggerTime = Level.TimeSeconds;
		TriggerEvent( Event, self, Other );
	}
	else
	{
		for( i = 0; i < members.Length; ++ i )
		{
			Manager.SendPlayerMessage( members[i].Controller, Eval(
				missingMembersCount > 1,
				members.Length $ "/" $ GetRequiredMembersCount( Manager ) $ ", " $ missingMembersCount $ " more members required",
				members.Length $ "/" $ GetRequiredMembersCount( Manager ) $ ", one more member required"
			), Manager.GroupProgressMessageClass );
		}
	}
}

defaultproperties
{
	Info="All members of a group(group must also be full) have to enter this volume to trigger its event."

	bDisplayOnHUD=true
	bDisplayTrackingOnHUD=true
	bDisplayInfoOnHUD=true

	ReTriggerDelay=0.0
}
