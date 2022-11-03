local hero_data = {
	"naga_siren",
	{1, 3, 1, 3, 1, 3, 1, 2, 3, 7, 5, 2, 2, 2, 9, 5, 5, 11, 13},
	{
		"item_slippers","item_circlet","item_tango","item_branches","item_branches","item_quelling_blade","item_wraith_band","item_magic_wand","item_gloves","item_boots_of_elves","item_ring_of_basilius","item_wind_lace","item_power_treads","item_blade_of_alacrity","item_boots_of_elves","item_yasha","item_ultimate_orb","item_blitz_knuckles","item_manta","item_orchid","item_reaver","item_heart","item_mage_slayer","item_bloodthorn","item_aghanims_shard","item_eagle","item_quarterstaff","item_butterfly","item_skadi","item_point_booster","item_ultimate_scepter_2","item_boots","item_moon_shard","item_sheepstick","item_rapier","item_rapier",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Mirror Image","Ensnare","Rip Tide","Reel In","Song of the Siren","-2s Ensnare Cooldown","+30 Rip Tide Damage","+13% Mirror Image Damage","+15 Strength","+500 Song of the Siren Radius","+1 Mirror Image Illusion","-10s Mirror Image Cooldown","-7 Rip Tide Armor",
	}
}
--@EndAutomatedHeroData
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
