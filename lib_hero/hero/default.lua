-- Fall-back behavior for unknown or unimplemented heroes
DEFAULT_HERO_BEHAVIOUR_SHORT_NAME = "default"

local hero_data = {
	DEFAULT_HERO_BEHAVIOUR_SHORT_NAME,
	{24},
	{	
		"item_tango", "item_branches", "item_branches", "item_magic_stick", 
		"item_ring_of_regen", "item_recipe_magic_wand", "item_boots", "item_blades_of_attack", 
		"item_chainmail", "item_belt_of_strength", "item_robe", "item_wind_lace", 
		"item_recipe_ancient_janggo", "item_fluffy_hat", "item_recipe_headdress", "item_energy_booster",
		"item_recipe_holy_locket", "item_staff_of_wizardry", "item_fluffy_hat", "item_recipe_force_staff", "item_ogre_axe", 
		"item_boots_of_elves", "item_boots_of_elves", "item_recipe_hurricane_pike", "item_crown",
		"item_staff_of_wizardry", --[[you guessed it]] "item_recipe_dagon", "item_recipe_dagon", "item_recipe_dagon", "item_recipe_dagon", "item_recipe_dagon",
		"item_ultimate_orb", "item_mystric_staff", "item_void_stone"
	},
	{ {3, 1, 2}, {3, 4, 2, 5, 1}, 0.2 },
	{ "", }
}
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		{[0] = "fake_stun", ABILITY_TYPE_STUN}
}

local d
d = {
	["AbilityThink"] = function() end
}
local hero_access = function(key) return d[key] end

do
	print("Requireing default", hero_data, abilities, hero_access)
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
