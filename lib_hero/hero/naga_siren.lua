local hero_data = {
	"naga_siren",
	{1, 3, 1, 2, 1, 3, 1, 3, 3, 7, 5, 2, 2, 2, 9, 5, 5, 11, 13},
	{
		"item_circlet","item_tango","item_quelling_blade","item_slippers","item_branches","item_branches","item_boots_of_elves","item_boots","item_gloves","item_power_treads","item_ring_of_basilius","item_wind_lace","item_wraith_band","item_blade_of_alacrity","item_boots_of_elves","item_yasha","item_manta","item_void_stone","item_blitz_knuckles","item_orchid","item_mage_slayer","item_bloodthorn","item_reaver","item_heart","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter","item_sheepstick","item_blink","item_ultimate_scepter_2","item_black_king_bar","item_swift_blink","item_moon_shard","item_boots","item_desolator",
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
