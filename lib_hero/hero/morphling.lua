local hero_data = {
	"morphling",
	{4, 2, 1, 1, 1, 2, 1, 4, 4, 5, 2, 6, 2, 4, 8, 5, 5, 10, 12},
	{
		"item_tango","item_branches","item_magic_stick","item_quelling_blade","item_enchanted_mango","item_enchanted_mango","item_enchanted_mango","item_branches","item_blades_of_attack","item_fluffy_hat","item_falcon_blade","item_boots","item_magic_wand","item_boots_of_elves","item_power_treads","item_lifesteal","item_blade_of_alacrity","item_boots_of_elves","item_yasha","item_ultimate_orb","item_manta","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter","item_ultimate_orb","item_aghanims_shard","item_skadi","item_claymore","item_satanic","item_invis_sword","item_silver_edge","item_sphere","item_black_king_bar","item_ultimate_scepter_2",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Waveform","Adaptive Strike (Agility)","Adaptive Strike (Strength)","Attribute Shift (Agility Gain)","Morph","+15% Magic Resistance","+250 Waveform Range","+16s Morph Duration","+15 Agility","Waveform Attacks Targets","+1s Adaptive Strike Stun Duration","special_bonus_unique_morphling_waveform_cooldown","+35 Strength",
	}
}
--@EndAutomatedHeroData
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
