local hero_data = {
	"morphling",
	{4, 1, 4, 1, 4, 1, 4, 1, 5, 7, 2, 2, 2, 2, 9, 5, 5, 11, 3},
	{
		"item_circlet","item_circlet","item_tango","item_tango","item_branches","item_branches","item_tango","item_branches","item_lifesteal","item_gloves","item_hand_of_midas","item_boots","item_boots_of_elves","item_power_treads","item_magic_wand","item_ring_of_basilius","item_yasha","item_manta","item_ultimate_orb","item_ultimate_orb","item_skadi","item_claymore","item_satanic","item_quarterstaff","item_talisman_of_evasion","item_eagle","item_butterfly",
	},
	{ {1,1,1,1,2,}, {1,1,1,1,2,}, 0.1 },
	{
		"Waveform","Adaptive Strike (Agility)","Adaptive Strike (Strength)","Attribute Shift (Agility Gain)","Morph","+15% Magic Resistance","+250 Waveform Range","+16s Morph Duration","+15 Agility","+20 Strength","Waveform Attacks Targets","+2 Waveform Charges","Attribute Shift While Stunned",
	}
}
--@EndAutomatedHeroData
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
