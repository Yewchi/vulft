local hero_data = {
	"morphling",
	{4, 2, 1, 4, 1, 1, 1, 4, 2, 3, 4, 2, 2, 5, 8, 5, 5, 10, 12},
	{
		"item_tango","item_branches","item_branches","item_circlet","item_quelling_blade","item_magic_stick","item_branches","item_blades_of_attack","item_magic_wand","item_falcon_blade","item_wraith_band","item_boots","item_power_treads","item_blade_of_alacrity","item_belt_of_strength","item_dragon_lance","item_boots_of_elves","item_yasha","item_ultimate_orb","item_manta","item_point_booster","item_staff_of_wizardry","item_ultimate_scepter","item_black_king_bar","item_ultimate_orb","item_skadi","item_boots",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Waveform","Adaptive Strike (Agility)","Adaptive Strike (Strength)","Attribute Shift (Agility Gain)","Morph","+15% Magic Resistance","+250 Waveform Range","+16s Morph Duration","+15 Agility","Waveform Attacks Targets","+1s Adaptive Strike Stun Duration","+2 Waveform Charges","+35 Strength",
	}
}
--@EndAutomatedHeroData
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
