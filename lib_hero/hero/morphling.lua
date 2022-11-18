local hero_data = {
	"morphling",
	{4, 2, 1, 5, 1, 1, 4, 1, 2, 7, 2, 2, 4, 4},
	{
		"item_tango","item_circlet","item_branches","item_branches","item_magic_stick","item_branches","item_blades_of_attack","item_magic_wand","item_lifesteal","item_fluffy_hat","item_falcon_blade","item_boots","item_gloves","item_boots_of_elves","item_power_treads","item_boots_of_elves","item_yasha","item_ultimate_orb","item_manta","item_blade_of_alacrity","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_shadow_amulet","item_satanic","item_silver_edge","item_ultimate_orb","item_ultimate_scepter_2","item_sphere","item_blink","item_swift_blink","item_moon_shard","item_refresher","item_boots",
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
