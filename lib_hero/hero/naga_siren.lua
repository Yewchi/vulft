local hero_data = {
	"naga_siren",
	{1, 3, 2, 1, 1, 3, 1, 3, 3, 6, 4, 4, 2, 2, 7, 2, 4, 10, 11},
	{
		"item_ward_observer","item_magic_stick","item_quelling_blade","item_tango","item_branches","item_branches","item_branches","item_enchanted_mango","item_enchanted_mango","item_gloves","item_boots","item_boots_of_elves","item_power_treads","item_blade_of_alacrity","item_yasha","item_wind_lace","item_talisman_of_evasion","item_radiance","item_reaver","item_heart","item_mage_slayer","item_void_stone","item_blitz_knuckles","item_claymore","item_bloodthorn","item_manta","item_sheepstick","item_aghanims_shard",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Mirror Image","Ensnare","Rip Tide","Song of the Siren","-2s Ensnare Cooldown","+30 Rip Tide Damage","+13% Mirror Image Damage","+15 Strength","+500 Song of the Siren Radius","+1 Mirror Image Illusion","-10s Mirror Image Cooldown","--7 Rip Tide Armor",
	}
}
--@EndAutomatedHeroData
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
