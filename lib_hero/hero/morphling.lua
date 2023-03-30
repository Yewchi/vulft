local hero_data = {
	"morphling",
	{3, 2, 3, 1, 1, 1, 1, 2, 3, 6, 2, 4, 2, 3, 7, 4, 4, 9, 11},
	{
		"item_tango","item_faerie_fire","item_branches","item_branches","item_branches","item_branches","item_ward_observer","item_bottle","item_magic_wand","item_gloves","item_boots","item_boots_of_elves","item_power_treads","item_falcon_blade","item_boots_of_elves","item_blade_of_alacrity","item_yasha","item_belt_of_strength","item_dragon_lance","item_ultimate_orb","item_manta","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_point_booster","item_ultimate_orb","item_ultimate_scepter","item_skadi","item_lesser_crit","item_aghanims_shard","item_gem","item_greater_crit",
	},
	{ {1,1,1,2,2,}, {1,1,1,2,2,}, 0.1 },
	{
		"Waveform","Adaptive Strike (Agility)","Attribute Shift (Agility Gain)","Morph","+15% Magic Resistance","+250 Waveform Range","+16s Morph Duration","+15 Agility","Waveform Attacks Targets","+1s Adaptive Strike Stun Duration","-40%% Waveform Cooldown","+35 Strength",
	}
}
--@EndAutomatedHeroData
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
