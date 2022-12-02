local hero_data = {
	"naga_siren",
	{1, 3, 1, 5, 1, 3, 1, 3, 3, 7, 2, 2, 2, 2},
	{
		"item_quelling_blade","item_circlet","item_slippers","item_tango","item_branches","item_branches","item_wraith_band","item_boots","item_gloves","item_boots_of_elves","item_wind_lace","item_power_treads","item_boots_of_elves","item_blade_of_alacrity","item_yasha","item_manta","item_void_stone","item_blitz_knuckles","item_orchid","item_vitality_booster","item_heart","item_ultimate_orb","item_ultimate_orb","item_point_booster","item_skadi","item_mage_slayer","item_bloodthorn","item_quarterstaff","item_mystic_staff","item_ultimate_orb","item_void_stone","item_sheepstick",
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
