local hero_data = {
	"morphling",
	{4, 1, 1, 4, 1, 5, 1, 2, 2, 7, 2, 4, 4, 2},
	{
		"item_tango","item_circlet","item_circlet","item_branches","item_branches","item_boots","item_gloves","item_boots_of_elves","item_power_treads","item_ring_of_health","item_dragon_lance","item_pers","item_ultimate_orb","item_sphere","item_boots_of_elves","item_yasha","item_manta","item_blade_of_alacrity","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter","item_ultimate_orb","item_skadi","item_force_staff","item_hurricane_pike","item_ultimate_scepter_2","item_lesser_crit","item_silver_edge","item_black_king_bar","item_aghanims_shard","item_rapier",
	},
	{ {1,1,1,1,2,}, {1,1,1,1,2,}, 0.1 },
	{
		"Waveform","Adaptive Strike (Agility)","Adaptive Strike (Strength)","Attribute Shift (Agility Gain)","Morph","+15% Magic Resistance","+250 Waveform Range","+16s Morph Duration","+15 Agility","Waveform Attacks Targets","+1s Adaptive Strike Stun Duration","+2 Waveform Charges","+35 Strength",
	}
}
--@EndAutomatedHeroData
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
