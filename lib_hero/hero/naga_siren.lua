local hero_data = {
	"naga_siren",
	{1, 3, 1, 2, 1, 3, 1, 3, 3, 6, 4, 2, 2, 2, 7, 4, 4, 10, 11},
	{
		"item_branches","item_quelling_blade","item_branches","item_branches","item_branches","item_slippers","item_slippers","item_gloves","item_boots_of_elves","item_power_treads","item_blade_of_alacrity","item_yasha","item_manta","item_wind_lace","item_ultimate_orb","item_skadi","item_invis_sword","item_silver_edge","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter","item_lifesteal","item_eagle","item_quarterstaff","item_butterfly","item_ultimate_scepter_2","item_reaver","item_lifesteal","item_claymore","item_satanic",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Mirror Image","Ensnare","Rip Tide","Song of the Siren","+20 Movement Speed","+30 Rip Tide Damage","+13% Mirror Image Damage","+15 Strength","-1 Rip Tide Hits","+1 Mirror Image Illusion","-10s Mirror Image Cooldown","-7 Rip Tide Armor",
	}
}
--@EndAutomatedHeroData
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
