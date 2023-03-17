local hero_data = {
	"naga_siren",
	{1, 3, 2, 1, 1, 3, 1, 3, 3, 7, 5, 5, 2, 2, 9, 2, 5, 11, 13},
	{
		"item_slippers","item_branches","item_quelling_blade","item_circlet","item_enchanted_mango","item_wraith_band","item_gloves","item_wraith_band","item_boots_of_elves","item_power_treads","item_boots_of_elves","item_blade_of_alacrity","item_yasha","item_blitz_knuckles","item_manta","item_void_stone","item_orchid","item_vitality_booster","item_heart","item_eagle","item_quarterstaff","item_butterfly","item_cloak","item_bloodthorn","item_ultimate_orb","item_sheepstick","item_black_king_bar","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter_2",
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
