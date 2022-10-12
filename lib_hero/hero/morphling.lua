local hero_data = {
	"morphling",
	{4, 1, 4, 1, 1, 4, 1, 2, 5, 7, 2, 4, 2, 2},
	{
		"item_tango","item_branches","item_branches","item_branches","item_faerie_fire","item_ward_observer","item_bottle","item_boots","item_wraith_band","item_fluffy_hat","item_magic_wand","item_boots_of_elves","item_power_treads","item_falcon_blade","item_blade_of_alacrity","item_dragon_lance","item_yasha","item_ultimate_orb","item_manta","item_aghanims_shard","item_ultimate_orb","item_ring_of_health","item_pers","item_pers","item_skadi","item_ultimate_orb","item_pers","item_sphere","item_blink","item_swift_blink",
	},
	{ {1,1,1,2,2,}, {1,1,1,2,2,}, 0.1 },
	{
		"Waveform","Adaptive Strike (Agility)","Adaptive Strike (Strength)","Attribute Shift (Agility Gain)","Morph","+15% Magic Resistance","+250 Waveform Range","+16s Morph Duration","+15 Agility","Waveform Attacks Targets","+1s Adaptive Strike Stun Duration","+2 Waveform Charges","+35 Strength",
	}
}
--@EndAutomatedHeroData
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
