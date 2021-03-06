/*-----------------------------------------------------------
[*] NightDM v1.1
 * Copyright (C) 2015  Hartmann
 - - - - - - - - - - -
 AMX Mod X script.

          | Author  : Hartmann
          | Plugin  : NightDM
          | Version : v1.1
	  
 (!) Support : Github - https://github.com/Hartmannq
               AlliedModders - https://forums.alliedmods.net/showthread.php?t=265763

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA. 
         
	   - - - - - -
	   Description:
           - - - - - -
		Plugin puts in the time that you want dm mode.
		When the plugin is active is he doing next(when it comes your time, without changing the map):

		- Remove object on map,
		- Block round end,
		- More spawn points, 
		- Menu with weapon:
			+ New Weapons
			+ Last Weapons
			+ 2 + Dont ask again
		- Remove buy zone,
		- Remove money(hud),
		- Remove(hud) and block timer,
		- Spawn protection,
		- HP for kill, hs, screen fade and give armor and granades on spawn,
		- Remove weapon on ground,
		- Every full BPAmmo,
		- ...
		When the finish time for dm everything back to normal, without changing the map.
	   - - - - - -
	   Cvars:
           - - - - - -
		Auto-write cfg with all cvars in amxmodx/configs/NightDM.cfg
		Only this change, if you writing nodes to another CFG will have no effect.
			+ dx_start 23 // Hour at which the DM start, example 2 = 2 am and 14 = 2 pm.
			+ dx_end 9 // Hour at which the DM end, example 2 = 2 am and 14 = 2 pm.
			- TIME: 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,00
			+ dx_sptime 5 // The Player get godmode for X seconds and cant get damage.
			+ dx_time 5 // Time for removing weapon on the ground.
			+ dx_hp 15// HP for kill.
			+ dx_hp_hs 40// HP for kill HS.
			+ dx_max_hp 100// Maximum player's HP.
			+ dx_armor 100 // Amout of armor to be given.
			+ dx_prefix CSDM // Prefix
			+ dx_msg_color "0 130 0"  // Message color
			+ dx_msg_xypos "0.02 0.2" // Message X Y
			+ dx_msg 1 // Message. 1- On 0-off
			+ dx_grenades "abc" // a - he grenade, b - smoke grenade, c - flashbang 
			+ dx_change "ab" // a - change sky on space, b - change lights on d
		
           - - - - - -
           Changelog:
           - - - - - -
             v1.0 [4.jul.2015]
              - First release.
	     v1.1 [17.aug.2015]
	      - Customizable Weapons list for Primary and Secondary weapons (ini file).
	      - Added Multilingual support.
	      - Added cvar for granades.
	      - Added cvar for change space and lights.
	      - Added cvar for message enable/disable, color and xy position.
	      - Added print in color.
	      
------------------------------------------------------------*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <hamsandwich>
#include <fakemeta>
#include <cstrike>
#include <fun>

new PLUGIN[] = "NightDM";
new AUTHOR[] = "Hartmann";
new VERSION[] = "1.1";

#pragma semicolon 1

#define HUD_HIDE_MONEY (1<<5)
#define HUD_HIDE_TIMER (1<<4)
#define fm_cs_set_user_nobuy(%1)    set_pdata_int(%1, 235, get_pdata_int(%1, 235) & ~(1<<0))
#define	MAX_SPAWNS	60

new const g_objective_ents[][] = {
	"func_bomb_target",
	"info_bomb_target",
	"hostage_entity",
	"monster_scientist",
	"func_hostage_rescue",
	"info_hostage_rescue",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone"
};
new g_hWeaponMenu;
new g_hPrimaryWeaponMenu;
new g_hSecondaryWeaponMenu;
new bool:g_bRememberGuns[ 33 ];
new g_iPrimaryWeapon[ 33 ];
new g_iSecondaryWeapon[ 33 ];

new bool:g_nightdm;
new cvar_start;
new cvar_end;
new cvar_time;
new message[80];
new g_ClassName[] = "hud_info";
new g_MsgSync1;
new g_MsgSync2;
new g_MsgSync3;
new bool:g_restart;
new bool:g_restart2;
new gMaxClients;
new pCvarTime;
new normalsky[64];
new configsDir[64];
new dFile[256];
new health_add;
new health_hs_add;
new health_max;
new gmsgScreenFade;
new gCvarArmor;

new g_WeaponBPAmmo[] ={
	0, 52, 0, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90, 90, 90, 100, 120, 30,	120, 200, 32, 90, 120, 90, 2, 35, 90, 90, 0, 100
};

new g_WeaponSlots[] ={
	0, 2, 0, 1, 4, 1, 5, 1, 1, 4, 2, 2, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 1, 4, 2, 1, 1, 3, 1
};
new Float:g_SpawnVecs[MAX_SPAWNS][3];
new Float:g_SpawnAngles[MAX_SPAWNS][3];
new Float:g_SpawnVAngles[MAX_SPAWNS][3];
new g_TotalSpawns;
new CvarPrefix;
new Prefix[ 32 ];
new g_msg_color;
new g_msg_xypos;
new g_msg_enable;
new g_grenades;
new g_change;
new g_szWepFile[256];
new g_FilePointer;
new Array:g_PrimaryWeapons;
new Array:g_SecondaryWeapons;

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_cvar( "dx_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	CvarPrefix = register_cvar( "dx_prefix", "CSDM" );
	get_pcvar_string( CvarPrefix, Prefix, charsmax( Prefix ) );
	cvar_start = register_cvar("dx_start", "23");
	cvar_end = register_cvar("dx_end", "9");
	register_think(g_ClassName,"fw_Think");
	new iEnt = create_entity("info_target");
	entity_set_string(iEnt, EV_SZ_classname, g_ClassName);
	entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 1.0);
	g_MsgSync1 = CreateHudSyncObj();
	g_MsgSync2 = CreateHudSyncObj();
	g_MsgSync3 = CreateHudSyncObj();
	register_message( get_user_msgid( "HideWeapon" ), "msg_hideweapon" );
	RegisterHam( Ham_Spawn, "player", "FwdPlayerSpawnPost", 1 );
	RegisterHam(Ham_Killed, "player", "PlayerKilled", 1);
	register_message(get_user_msgid("StatusIcon"), "Message_StatusIcon");
	pCvarTime = register_cvar( "dx_time", "5" );
	RegisterHam( Ham_Touch, "weaponbox", "WeaponBox_Touch", 1 );
	register_event("CurWeapon","curweapon","be");
	cvar_time = register_cvar("dx_sptime", "5");
	gMaxClients = get_maxplayers();
	get_cvar_string("sv_skyname" , normalsky , 63); 
	register_clcmd( "say /guns", 	"CmdGunsEnable" );
	health_add = register_cvar("dx_hp", "15");
	health_hs_add = register_cvar("dx_hp_hs", "40");
	health_max = register_cvar("dx_max_hp", "100");
	gCvarArmor = register_cvar( "dx_armor",	"100" );
	register_event("DeathMsg", "eDeathMsg", "a");
	gmsgScreenFade = get_user_msgid("ScreenFade");
	register_event( "TeamInfo", "join_team", "a");
	g_msg_color = register_cvar("dx_msg_color","0 130 0");
	g_msg_xypos = register_cvar("dx_msg_xypos","0.02 0.2");
	g_msg_enable = register_cvar("dx_msg","1");
	g_grenades = register_cvar("dx_grenades","a");
	g_change = register_cvar("dx_change","ab");
	register_dictionary("nightdm.txt");
	readSpawns();
	CreateWeaponsArray();
}
public plugin_cfg() 
{ 
	get_configsdir(configsDir, charsmax(configsDir));
	formatex(dFile, charsmax(dFile), "%s/NightDM.cfg", configsDir); 
	if(!file_exists(dFile)) 
	{ 
		write_file ( dFile , "--------------------------------------------" ); 
		write_file ( dFile , "NightDM v1.1 By Hartmann" ); 
		write_file ( dFile , "Copyright (C) 2015  Hartmann" ); 
		write_file ( dFile , "--------------------------------------------" ); 
		write_file ( dFile , "" ); 
		write_file ( dFile , "// Note - After editing cvars you need to change map before changes can take effect!" ); 
		write_file ( dFile , "" );
		write_file ( dFile , "" );
		write_file ( dFile , "// TIME: 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,00" );
		write_file ( dFile , "// Hour at which the DM start, example 2 = 2 am and 14 = 2 pm." );
		write_file ( dFile , "dx_start 23" );
		write_file ( dFile , "" );
		write_file ( dFile , "Hour at which the DM end, example 2 = 2 am and 14 = 2 pm." );
		write_file ( dFile , "dx_end 9" );
		write_file ( dFile , "" );
		write_file ( dFile , "// The Player get godmode for X seconds and cant get damage." );
		write_file ( dFile , "dx_sptime 5" );
		write_file ( dFile , "" );
		write_file ( dFile , "Time for removing weapon on the ground." );
		write_file ( dFile , "dx_time 2" );
		write_file ( dFile , "" );
		write_file ( dFile , "HP for kill." );
		write_file ( dFile , "dx_hp 15" );
		write_file ( dFile , "" );
		write_file ( dFile , "// HP for kill HS." );
		write_file ( dFile , "dx_hp_hs 40" );
		write_file ( dFile , "" );
		write_file ( dFile , "// Maximum player's HP." );
		write_file ( dFile , "dx_max_hp 100" );
		write_file ( dFile , "" );
		write_file ( dFile , "// Amout of armor to be given." );
		write_file ( dFile , "dx_armor 100" );
		write_file ( dFile , "" );
		write_file ( dFile , "// Prefix" );
		write_file ( dFile , "dx_prefix CSDM" );
		write_file ( dFile , "" );
		write_file ( dFile , " // Message color" );
		write_file ( dFile , "dx_msg_color ^"0 130 0^"" );
		write_file ( dFile , "" );
		write_file ( dFile , "// Message X Y" );
		write_file ( dFile , "dx_msg_xypos ^"0.02 0.2^"" );
		write_file ( dFile , "" );
		write_file ( dFile , "// Message. 1- On 0-off" );
		write_file ( dFile , "dx_msg 1" );
		write_file ( dFile , "" );
		write_file ( dFile , "//Grenade flags" );
		write_file ( dFile , "// a - he grenade" );
		write_file ( dFile , "// b - smoke grenade" );
		write_file ( dFile , "// c - flashbang" );
		write_file ( dFile , "// ^"^" - nothing." );
		write_file ( dFile , "dx_grenades ^"a^"" );
		write_file ( dFile , "" );
		write_file ( dFile , "//Change flags" );
		write_file ( dFile , "// a - change sky on space" );
		write_file ( dFile , "// b - change lights on d" );
		write_file ( dFile , "// ^"^" - nothing." );
		write_file ( dFile , "dx_change ^"ab^"" );
		write_file ( dFile , "" );
	} 
} 
public plugin_end() 
{ 
	get_configsdir(configsDir, charsmax(configsDir)); 
	server_cmd("exec %s/NightDM.cfg", configsDir); 
} 
readSpawns(){
	//-617 2648 179 16 -22 0 0 -5 -22 0
	// Origin (x,y,z), Angles (x,y,z), vAngles(x,y,z), Team (0 = ALL) - ignore
	// :TODO: Implement team specific spawns
	
	new Map[32], config[32],  MapFile[64];
	
	get_mapname(Map, 31);
	get_configsdir(config, 31 );
	format(MapFile, 63, "%s\csdm\%s.spawns.cfg", config, Map);
	g_TotalSpawns = 0;
	
	if (file_exists(MapFile)) 
	{
		new Data[124], len;
		new line = 0;
		new pos[12][8];
		
		while(g_TotalSpawns < MAX_SPAWNS && (line = read_file(MapFile , line , Data , 123 , len) ) != 0 ) 
		{
			if (strlen(Data)<2 || Data[0] == '[')
				continue;
			
			parse(Data, pos[1], 7, pos[2], 7, pos[3], 7, pos[4], 7, pos[5], 7, pos[6], 7, pos[7], 7, pos[8], 7, pos[9], 7, pos[10], 7);
			
			// Origin
			g_SpawnVecs[g_TotalSpawns][0] = str_to_float(pos[1]);
			g_SpawnVecs[g_TotalSpawns][1] = str_to_float(pos[2]);
			g_SpawnVecs[g_TotalSpawns][2] = str_to_float(pos[3]);
			
			//Angles
			g_SpawnAngles[g_TotalSpawns][0] = str_to_float(pos[4]);
			g_SpawnAngles[g_TotalSpawns][1] = str_to_float(pos[5]);
			g_SpawnAngles[g_TotalSpawns][2] = str_to_float(pos[6]);
			
			//v-Angles
			g_SpawnVAngles[g_TotalSpawns][0] = str_to_float(pos[7]);
			g_SpawnVAngles[g_TotalSpawns][1] = str_to_float(pos[8]);
			g_SpawnVAngles[g_TotalSpawns][2] = str_to_float(pos[9]);
			
			//Team - ignore
			
			g_TotalSpawns++;
		}
		
		log_amx("Loaded %d spawn points for map %s.", g_TotalSpawns, Map);
		} else {
		log_amx("No spawn points file found (%s)", MapFile);
	}
	
	return 1;
}
public spawn_Preset(id)
{
	if (g_TotalSpawns < 2)
		return PLUGIN_CONTINUE;
	
	new list[MAX_SPAWNS];
	new num = 0; 
	new final = -1; 
	new total=0; 
	new players[32], n, x = 0;
	new Float:loc[32][3], locnum;
	
	//cache locations
	get_players(players, num);
	for (new i=0; i<num; i++)
	{
		if (is_user_alive(players[i]) && players[i] != id)
		{
			entity_get_vector(players[i], EV_VEC_origin, loc[locnum]);
			locnum++;
		}
	}
	
	num = 0;
	while (num <= g_TotalSpawns)
	{
		//have we visited all the spawns yet?
		if (num == g_TotalSpawns)
			break;
		//get a random spawn
		n = random_num(0, g_TotalSpawns-1);
		//have we visited this spawn yet?
		if (!list[n])
		{
			//yes, set the flag to true, and inc the number of spawns we've visited
			list[n] = 1;
			num++;
		} 
		else 
		{
			//this was a useless loop, so add to the infinite loop prevention counter
			total++;
			if (total > 100) // don't search forever
				break;
			continue;   //don't check again
		}
		
		new trace  = trace_hull(g_SpawnVecs[n],1);
		if (trace)
			continue;
		
		if (locnum < 1)
		{
			final = n;
			break;
		}
		
		final = n;
		for (x = 0; x < locnum; x++)
		{
			new Float:distance = get_distance_f(g_SpawnVecs[n], loc[x]);
			if (distance < 250.0)
			{
				//invalidate
				final = -1;
				break;
			}
		}
		
		if (final != -1)
			break;
	}
	
	if (final != -1)
	{
		entity_set_origin(id, g_SpawnVecs[final]);
		entity_set_int(id, EV_INT_fixangle, 1);
		entity_set_vector(id, EV_VEC_angles, g_SpawnAngles[final]);
		entity_set_vector(id, EV_VEC_v_angle, g_SpawnVAngles[final]);
		entity_set_int(id, EV_INT_fixangle, 1);
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}
public fw_Think(iEnt){
	entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 1.0);
	if(get_pcvar_num(g_msg_enable)){
		static r, g, b, Float:x,Float:y;
		HudMsgPos(x,y);
		HudMsgColor(g_msg_color, r, g, b);
		formatex(message, charsmax(message), "%L", LANG_PLAYER, "DM_MESSAGE",((g_nightdm)?"N":"FF"), get_pcvar_num(cvar_start), get_pcvar_num(cvar_end));
		set_hudmessage(r, g, b, x, y, _, _, 1.0, _, _, 1);
		ShowSyncHudMsg(0, g_MsgSync1, message);
	}
	static hour_str[3],get_hour, get_start,get_end;
	
	get_time("%H",hour_str,2);
	
	get_hour = str_to_num(hour_str);
	
	get_start = get_pcvar_num(cvar_start);
	get_end = get_pcvar_num(cvar_end);
	
	if(get_start < get_end ? (get_start <= get_hour && get_hour < get_end) : (get_start <= get_hour || get_hour < get_end)) {
		g_nightdm = true;
		new szFlags[ 27 ];
		get_pcvar_string( g_change, szFlags, charsmax( szFlags ) );
		
		if (containi(szFlags, "a") != -1){
			server_cmd("sv_skyname space");
		}
		if (containi(szFlags, "b") != -1){
			set_lights("d");
		}
		set_msg_block(get_user_msgid("RoundTime"), BLOCK_SET);
		set_msg_block(get_user_msgid("ShowTimer"), BLOCK_SET);
		g_restart2 = false;
		for (new i = 0; i < sizeof g_objective_ents; ++i) {
			RemoveEntity(g_objective_ents[i]);
		}
		restart();
		}else{
		g_nightdm = false;
		g_restart = false;
		new szFlags[ 27 ];
		get_pcvar_string( g_change, szFlags, charsmax( szFlags ) );
		if (containi(szFlags, "a") != -1){
			set_cvar_string("sv_skyname" , normalsky);
		}
		if (containi(szFlags, "b") != -1){
			set_lights("#OFF");
		}
		set_msg_block(get_user_msgid("RoundTime"), BLOCK_NOT);
		set_msg_block(get_user_msgid("ShowTimer"), BLOCK_NOT);
		for (new i = 0; i < sizeof g_objective_ents; ++i) {
			RestoreEntity(g_objective_ents[i]);
		}
		restart2();
	}  
}
public FwdPlayerSpawnPost(id){ 
	if(g_nightdm){
		if(is_user_alive( id ) )
		{
			spawn_Preset(id);
			strip_user_weapons( id );
			give_item( id, "weapon_knife" );
			new szFlags[ 27 ];
			get_pcvar_string( g_grenades, szFlags, charsmax( szFlags ) );
			
			if (containi(szFlags, "a") != -1){
				give_item( id, "weapon_hegrenade" );
			}
			if (containi(szFlags, "b") != -1){
				give_item( id, "weapon_smokegrenade" );
			}
			if (containi(szFlags, "c") != -1){
				give_item( id, "weapon_flashbang" );
			}
			cs_set_user_armor(id, get_pcvar_num(gCvarArmor), CS_ARMOR_VESTHELM); 
			new hideflags = GetHudHideFlags();
			sp_off(id);
			set_task(0.2,"protect",id);
			if( g_bRememberGuns[ id ] ){
				PreviousWeapons(id);
				}else{ 
				GunsMenu(id);
			}
			if( hideflags )
			{
				message_begin( MSG_ONE, get_user_msgid( "HideWeapon" ), _, id );
				write_byte( hideflags );
				message_end();
			}	
			
		} 
	}
}
public msg_hideweapon(){
	if(g_nightdm){
		new hideflags = GetHudHideFlags();
		
		if( hideflags ) 
			set_msg_arg_int( 1, ARG_BYTE, get_msg_arg_int( 1 ) | hideflags );
	}
}
GetHudHideFlags(){
	new iFlags;
	
	iFlags |= HUD_HIDE_MONEY;
	iFlags |= HUD_HIDE_TIMER;
	
	return iFlags;
}
public client_putinserver(id){
	g_bRememberGuns[ id ] = false;
	g_iPrimaryWeapon[ id ] = 0;
	g_iSecondaryWeapon[ id ] = 0;
}
public client_disconnect(id){
	remove_task(id);
	sp_off(id);
	return PLUGIN_HANDLED;
}
public join_team()
{
	if(g_nightdm)
	{
		new Client = read_data(1); 
		static user_team[32]; 
		
		read_data(2, user_team, 31); 
		
		if(!is_user_connected(Client)) 
			return PLUGIN_HANDLED; 
		
		switch(user_team[0]) 
		{
			case 'C':  
			{
				if(!is_user_alive(Client))
					set_task(1.0,"spawnning",Client);
			}
			
			case 'T':
			{ 
				if(!is_user_alive(Client))
					set_task(1.0,"spawnning",Client); 
			}
			
			case 'S':  
			{
				ClientPrintColor(Client, "!g[%s] %L", Prefix , LANG_PLAYER, "DM_SPEC");
			}
		}
	}
	return 0;
}
public spawnning(Client) {
	ExecuteHamB(Ham_CS_RoundRespawn, Client);
	ClientPrintColor(Client, "!g[%s] %L", Prefix , LANG_PLAYER, "DM_RASP");
	ClientPrintColor(Client, "!g[%s] %s v%s, Copyright (C) 2015 by %s",Prefix, PLUGIN, VERSION, AUTHOR);
	remove_task(Client);
}
public PlayerKilled(Victim){
	if (!is_user_alive(Victim))
		set_task(1.0, "PlayerRespawn", Victim);
}
public PlayerRespawn(id){
	if(g_nightdm){
		if (!is_user_alive(id) && CS_TEAM_T <= cs_get_user_team(id) <= CS_TEAM_CT )
		{
			ExecuteHamB(Ham_CS_RoundRespawn, id);
		}
	}
}
public restart(){
	if (g_restart){
		return PLUGIN_HANDLED;
		}else{
		g_restart = true;
		server_cmd("sv_restart 1");
		ClientPrintColor(0, "!g[%s] %L", Prefix , LANG_PLAYER, "DM_MODS");
	}
	return PLUGIN_HANDLED;
}
public restart2(){
	if (g_restart2){
		return PLUGIN_HANDLED;
		}else{
		g_restart2 = true;
		server_cmd("sv_restart 1");
		ClientPrintColor(0, "!g[%s] %L", Prefix , LANG_PLAYER, "DM_MODE");
	}
	return PLUGIN_HANDLED;
}	
public Message_StatusIcon(iMsgId, iMsgDest,id) 
{
	if(g_nightdm){
		static szIcon[8];  
		get_msg_arg_string(2, szIcon, charsmax(szIcon));
		if(equal(szIcon, "buyzone"))
		{  
			if(get_msg_arg_int(1))
			{  
				set_pdata_int(id, 235, get_pdata_int(id, 235) & ~(1<<0));
				return PLUGIN_HANDLED;  
			}  
		}
	}
	
	return PLUGIN_CONTINUE;  
}  
public WeaponBox_Touch ( const WeaponBox, const Other ){
	if(g_nightdm){
		if ( !Other || Other > gMaxClients )
		{
			set_pev( WeaponBox, pev_nextthink, get_gametime() + get_pcvar_float( pCvarTime ) );
		}
	}
}
public curweapon(id) {
	if(g_nightdm){
		new iWeapon = read_data(2); 
		
		if(g_WeaponSlots[iWeapon] == 1 || g_WeaponSlots[iWeapon] == 2)
		{
			if(cs_get_user_bpammo(id, iWeapon) < g_WeaponBPAmmo[iWeapon])
			{
				cs_set_user_bpammo(id, iWeapon, g_WeaponBPAmmo[iWeapon]); 
			}
		}
		return PLUGIN_CONTINUE;
	}
	return PLUGIN_CONTINUE;
}
public protect(id) {
	new SPSecs = get_pcvar_num(cvar_time);
	set_user_godmode(id, 1);
	
	switch(cs_get_user_team( id )){
		case CS_TEAM_CT:{
			set_user_rendering(id, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 25);
		}
		case CS_TEAM_T:{
			set_user_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25);
		}
	}
	set_hudmessage(255, 1, 1, -1.0, -1.0, 0, 6.0, get_pcvar_float(cvar_time), 0.1, 0.2, 4);
	ShowSyncHudMsg(id, g_MsgSync2, "%L", LANG_PLAYER, "DM_PROTECT", SPSecs);
	
	set_task(get_pcvar_float(cvar_time), "sp_off", id);
	return PLUGIN_HANDLED;
}
public sp_off(id) {
	if(is_user_alive(id))
	{
		set_user_godmode(id, 0);
		set_user_rendering(id, kRenderFxGlowShell, 0, 0,0, kRenderNormal, 25);
	}
	return PLUGIN_HANDLED;
}
public CmdGunsEnable( id )
{
	if( g_bRememberGuns[ id ] )
	{
		ClientPrintColor(id, "!g[%s] %L", Prefix, LANG_PLAYER, "DM_GUN");
		g_bRememberGuns[ id ] = false;
	}
	
	else
		ClientPrintColor(id, "!g[%s] %L", Prefix, LANG_PLAYER, "DM_GUN2");
}
public GunsMenu(id)
{
	new itemmenu[64];
	formatex(itemmenu, charsmax(itemmenu), "\r%L\w", LANG_PLAYER, "DM_TITLE");
	g_hWeaponMenu = menu_create(itemmenu , "WeaponMainMenu_Handler" );
	formatex(itemmenu, charsmax(itemmenu), "%L", LANG_PLAYER, "DM_ITEM");
	menu_additem( g_hWeaponMenu, itemmenu, "0" );
	formatex(itemmenu, charsmax(itemmenu), "%L", LANG_PLAYER, "DM_ITEM2");
	menu_additem( g_hWeaponMenu, itemmenu, "1" );
	formatex(itemmenu, charsmax(itemmenu), "%L", LANG_PLAYER, "DM_ITEM3");
	menu_additem( g_hWeaponMenu, itemmenu, "2" );
	menu_setprop(g_hWeaponMenu , MPROP_EXIT , MEXIT_NEVER);
	menu_display( id,g_hWeaponMenu, 0 );
}
public WeaponMainMenu_Handler( id, hMenu, iItem )
{
	switch( iItem )
	{
		case 0: menu_display( id,g_hPrimaryWeaponMenu, 0 );
			case 1: 
		{
			PreviousWeapons(id);
		}
		
		case 2: 
		{
			PreviousWeapons(id);
			g_bRememberGuns[ id ] = true;
			ClientPrintColor(id, "!g[%s] %L", Prefix, LANG_PLAYER, "DM_GUNS");
		}
	}
}
public PreviousWeapons(id) 
{
	new szpData[32], szsData[32];
	ArrayGetString(g_PrimaryWeapons, g_iPrimaryWeapon[id], szpData, charsmax(szpData)); 
	ArrayGetString(g_SecondaryWeapons, g_iSecondaryWeapon[id], szsData, charsmax(szsData));
	strtolower(szpData); 
	strtolower(szsData); 
	replace_all(szpData, charsmax(szpData), " ", ""); 
	replace_all(szsData, charsmax(szsData), " ", ""); 
	format(szpData, charsmax(szpData), "weapon_%s", szpData); 
	format(szsData, charsmax(szsData), "weapon_%s", szsData);
	GiveWeapons(id, szpData); 
	GiveWeapons(id, szsData); 
}

public CreateWeaponsArray()
{
	get_configsdir(g_szWepFile, charsmax(g_szWepFile));  //gets addons/amxmodx/configs directory
	format(g_szWepFile, charsmax(g_szWepFile), "%s/NightDM_Weapon.ini", g_szWepFile); //formats the file name for the Weapons order INI
	g_FilePointer = fopen(g_szWepFile, "r"); 
	
	g_PrimaryWeapons = ArrayCreate(15); 
	g_SecondaryWeapons = ArrayCreate(15); 
	
	
	new itemmenu[64];
	formatex(itemmenu, charsmax(itemmenu), "\r%L\w", LANG_PLAYER, "DM_TITLE2");
	g_hPrimaryWeaponMenu = menu_create( itemmenu, "PrimaryWeapons_Handler" );
	formatex(itemmenu, charsmax(itemmenu), "\r%L\w", LANG_PLAYER, "DM_TITLE3");
	g_hSecondaryWeaponMenu = menu_create( itemmenu, "SecondaryWeapons_Handler" );
	
	new szData[32], szWeaponName[32], szpNum[3], szsNum[3];
	new pCounter, sCounter;
	if(g_FilePointer) 
	{
		while(!feof(g_FilePointer))
		{
			fgets(g_FilePointer, szData, charsmax(szData)); 
			trim(szData); 
			if(containi(szData, ";") != -1) 
				continue;
			
			copy(szWeaponName, charsmax(szWeaponName), szData); 
			replace_all(szWeaponName, charsmax(szWeaponName), " ", ""); 
			format(szWeaponName, charsmax(szWeaponName), "weapon_%s", szWeaponName); 
			strtolower(szWeaponName); 
			new iWeaponID = get_weaponid(szWeaponName); 
			
			switch(g_WeaponSlots[iWeaponID]) 
			{
				case 1: 
				{
					ArrayPushString(g_PrimaryWeapons, szData); 
					num_to_str(pCounter, szpNum, charsmax(szpNum));
					menu_additem(g_hPrimaryWeaponMenu, szData, szpNum, 0); 
					++pCounter;
				}
				case 2: 
				{
					ArrayPushString(g_SecondaryWeapons, szData); 
					num_to_str(sCounter, szsNum, charsmax(szsNum));
					menu_additem(g_hSecondaryWeaponMenu, szData, szsNum, 0);
					++sCounter;
				}
			}
		}
	}
	else
	{
		set_fail_state("Failed to Open Weapons List");
	}
	menu_setprop(g_hPrimaryWeaponMenu , MPROP_EXIT , MEXIT_NEVER);
	menu_setprop(g_hSecondaryWeaponMenu , MPROP_EXIT , MEXIT_NEVER);
	
	fclose(g_FilePointer); 
}

public PrimaryWeapons_Handler(id, iMenu, iItem)
{
	new szKey[3], iSelectedWeapon, Dummy;
	menu_item_getinfo(iMenu, iItem, Dummy, szKey, 2, "", 0, Dummy); 
	
	iSelectedWeapon = str_to_num(szKey);
	g_iPrimaryWeapon[id] = iSelectedWeapon; 
	
	new WeaponName[32], szArrayData[32];
	ArrayGetString(g_PrimaryWeapons, iSelectedWeapon, szArrayData, charsmax(szArrayData)); 
	replace_all(szArrayData, charsmax(szArrayData), " ", ""); 
	format(WeaponName, charsmax(WeaponName), "weapon_%s", szArrayData); 
	strtolower(WeaponName);
	GiveWeapons(id, WeaponName); 
	
	menu_display(id, g_hSecondaryWeaponMenu); 
}

public SecondaryWeapons_Handler(id, iMenu, iItem)
{
	new szKey[3], iSelectedWeapon, Dummy;
	menu_item_getinfo(iMenu, iItem, Dummy, szKey, 2, "", 0, Dummy); 
	
	iSelectedWeapon = str_to_num(szKey);
	g_iSecondaryWeapon[id] = iSelectedWeapon; 
	
	new WeaponName[32], szArrayData[32];
	ArrayGetString(g_SecondaryWeapons, iSelectedWeapon, szArrayData, charsmax(szArrayData)); 
	replace_all(szArrayData, charsmax(szArrayData), " ", ""); 
	format(WeaponName, charsmax(WeaponName), "weapon_%s", szArrayData); 
	strtolower(WeaponName);
	GiveWeapons(id, WeaponName);
}
public eDeathMsg() {
	if(g_nightdm){
		new KillerId = read_data(1);
		new VictimId = read_data(2);
		if(!KillerId || KillerId > gMaxClients)
			return;
		
		if(KillerId == VictimId || get_user_team(KillerId) == get_user_team(VictimId))
			return;
		
		new KillerHealth = get_user_health(KillerId);
		new NewKillerHealth = min(   ( read_data(3) ? 
		get_pcvar_num(health_hs_add) : 
		get_pcvar_num(health_add) ) + 
		KillerHealth ,
		
		get_pcvar_num(health_max));
		
		set_user_health(KillerId, NewKillerHealth);
		
		set_hudmessage(0, 255, 0, -1.0, 0.15, 0, 1.0, 1.0, 0.1, 0.1, -1);
		ShowSyncHudMsg(KillerId, g_MsgSync3,"Healed +%d hp", NewKillerHealth - KillerHealth);
		
		message_begin(MSG_ONE, gmsgScreenFade, _, KillerId);
		write_short(1<<10);
		write_short(1<<10);
		write_short(0x0000);
		write_byte(0);
		write_byte(0);
		write_byte(200);
		write_byte(75);
		message_end();
	} 
}
RemoveEntity( const szClassName[ ] ){
	new szFakeClassName[ 32 ];
	GetFakeClassName( szClassName, szFakeClassName, charsmax( szFakeClassName ) );
	
	new iEntity = -1;
	while( ( iEntity = find_ent_by_class( iEntity, szClassName ) ) )
	{
		entity_set_string( iEntity, EV_SZ_classname, szFakeClassName );
	}
}

RestoreEntity( const szClassName[ ] ){
	new szFakeClassName[ 32 ];
	GetFakeClassName( szClassName, szFakeClassName, charsmax( szFakeClassName ) );
	
	new iEntity = -1;
	while( ( iEntity = find_ent_by_class( iEntity, szFakeClassName ) ) )
	{
		entity_set_string( iEntity, EV_SZ_classname, szClassName );
	}
}

GetFakeClassName( const szClassName[ ], szFakeClassName[ ], const iLen ){
	formatex( szFakeClassName, iLen, "___%s", szClassName );
}
stock GiveWeapons(id, szWeapon[])
{
	if(is_user_connected(id))
	{
		new iWeaponId = get_weaponid(szWeapon); 
		give_item(id, szWeapon); 
		cs_set_user_bpammo(id, iWeaponId, g_WeaponBPAmmo[iWeaponId]); 
	}
}
public HudMsgColor(cvar, &r, &g, &b)
{
	static color[16], piece[5];
	get_pcvar_string(cvar, color, 15);
	
	strbreak( color, piece, 4, color, 15);
	r = str_to_num(piece);
	
	strbreak( color, piece, 4, color, 15);
	g = str_to_num(piece);
	b = str_to_num(color);
}

public HudMsgPos(&Float:x, &Float:y)
{
	static coords[16], piece[10];
	get_pcvar_string(g_msg_xypos, coords, 15);
	
	strbreak(coords, piece, 9, coords, 15);
	x = str_to_float(piece);
	y = str_to_float(coords);
}
ClientPrintColor( id, String[ ], any:... ){
	new szMsg[ 190 ];
	vformat( szMsg, charsmax( szMsg ), String, 3 );
	
	replace_all( szMsg, charsmax( szMsg ), "!n", "^1" );
	replace_all( szMsg, charsmax( szMsg ), "!t", "^3" );
	replace_all( szMsg, charsmax( szMsg ), "!g", "^4" );
	
	static msgSayText = 0;
	static fake_user;
	
	if( !msgSayText )
	{
		msgSayText = get_user_msgid( "SayText" );
		fake_user = get_maxplayers( ) + 1;
	}
	
	message_begin( id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgSayText, _, id );
	write_byte( id ? id : fake_user );
	write_string( szMsg );
	message_end( );
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg1252\\ deff0\\ deflang1033{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ f0\\ fs16 \n\\ par }
*/
