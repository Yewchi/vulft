local hero_data = {
	"naga_siren",
	{1, 3, 1, 3, 1, 3, 1, 3, 2, 7, 5, 2, 2, 2, 9, 5, 5, 11, 6},
	{
		"item_tango","item_slippers","item_circlet","item_quelling_blade","item_branches","item_wraith_band","item_boots","item_boots_of_elves","item_power_treads","item_blade_of_alacrity","item_boots_of_elves","item_yasha","item_wind_lace","item_manta","item_blitz_knuckles","item_orchid","item_ultimate_orb","item_skadi","item_vitality_booster","item_reaver","item_heart","item_helm_of_iron_will","item_nullifier","item_bloodthorn","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter_2","item_aghanims_shard","item_boots","item_boots",
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
