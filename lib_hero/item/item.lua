ITEM_MAX_PLAYER_STORAGE = 16
ITEM_INVENTORY_AND_BACKPACK_STORAGE = 9
ITEM_MAX_COURIER_STORAGE = ITEM_INVENTORY_AND_BACKPACK_STORAGE

TPSCROLL_SLOT = 15
--NEUTRAL_ITEM_SLOT = 16

ITEM_END_INVENTORY_INDEX = 5
ITEM_END_BACKPACK_INDEX = 8
ITEM_END_STASH_INDEX = 14

ITEM_NAME_SEARCH_START = 6 -- "item_[.+]"

ITEM_HAVE_AGHS_SHARD_MYSTERIOUS = 114

ITEM_UPGRADES = {
	"item_abyssal_blade",
	"item_aeon_disk",
	"item_aether_lens",
	"item_ancient_janggo",
	"item_arcane_blink",
	"item_arcane_boots",
	"item_armlet",
	"item_assault",
	"item_basher",
	"item_bfury",
	"item_black_king_bar",
	"item_blade_mail",
	"item_bloodstone",
	"item_bloodthorn",
	"item_bracer",
	"item_buckler",
	"item_butterfly",
	"item_crimson_guard",
	"item_cyclone",
	"item_dagon",
	"item_desolator",
	"item_diffusal_blade",
	"item_dragon_lance",
	"item_echo_sabre",
	"item_eternal_shroud",
	"item_ethereal_blade",
	"item_falcon_blade",
	"item_force_staff",
	"item_glimmer_cape",
	"item_greater_crit",
	"item_guardian_greaves",
	"item_gungir",
	"item_hand_of_midas",
	"item_headdress",
	"item_heart",
	"item_heavens_halberd",
	"item_helm_of_the_dominator",
	"item_helm_of_the_overlord",
	"item_holy_locket",
	"item_hood_of_defiance",
	"item_hurricane_pike",
	"item_invis_sword",
	"item_kaya",
	"item_kaya_and_sange",
	"item_lesser_crit",
	"item_lotus_orb",
	"item_maelstrom",
	"item_mage_slayer",
	"item_manta",
	"item_mask_of_madness",
	"item_medallion_of_courage",
	"item_mekansm",
	"item_meteor_hammer",
	"item_mjollnir",
	"item_monkey_king_bar",
	"item_moon_shard",
	"item_null_talisman",
	"item_nullifier",
	"item_oblivion_staff",
	"item_octarine_core",
	"item_orb_of_corrosion",
	"item_orchid",
	"item_overwhelming_blink",
	"item_pers",
	"item_phase_boots",
	"item_pipe",
	"item_power_treads",
	"item_radiance",
	"item_rapier",
	"item_refresher",
	"item_ring_of_basilius",
	"item_rod_of_atos",
	"item_sange",
	"item_sange_and_yasha",
	"item_satanic",
	"item_sheepstick",
	"item_shivas_guard",
	"item_silver_edge",
	"item_skadi",
	"item_solar_crest",
	"item_soul_booster",
	"item_soul_ring",
	"item_sphere",
	"item_spirit_vessel",
	"item_swift_blink",
	"item_tranquil_boots",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_urn_of_shadows",
	"item_vanguard",
	"item_veil_of_discord",
	"item_vladmir",
	"item_wind_waker",
	"item_witch_blade",
	"item_wraith_band",
	"item_yasha",
	"item_yasha_and_kaya",
}

ITEM_COOLDOWN = {
	["item_abyssal_blade"] = 35,
	["item_ancient_janggo"] = 30,
	["item_arcane_boots"] = 55,
	["item_black_king_bar"] = 70,
	["item_blade_mail"] = 25,
	["item_blink"] = 15,
	["item_bloodstone"] = 85,
	["item_bloodthorn"] = 15,
	["item_dagon"] = 35,
	["item_dagon_2"] = 35,
	["item_dagon_3"] = 35,
	["item_dagon_4"] = 35,
	["item_dagon_5"] = 35,
	["item_diffusal_blade"] = 15,
	["item_echo_sabre"] = 5,
	["item_etheral_blade"] = 20,
	["item_force_staff"] = 23,
	["item_glimmer_cape"] = 14,
	["item_guardian_greaves"] = 40,
	["item_hand_of_midas"] = 90,
	["item_heavens_halberd"] = 18,
	["item_helm_of_the_dominator"] = 45,
	["item_hood_of_defiance"] = 60,
	["item_hurricane_pike"] = 23,
	["item_manta"] = 45,
	["item_mask_of_madness"] = 16,
	["item_mekansm"] = 65,
	["item_meteor_hammer"] = 24,
	["item_necronomicon"] = 80,
	["item_necronomicon_2"] = 80,
	["item_necronomicon_3"] = 80,
	["item_nullifier"] = 11,
	["item_orchid"] = 18,
	["item_phase_boots"] = 8,
	["item_pipe"] = 60,
	["item_refresher"] = 160,
	["item_satanic"] = 35,
	["item_sheepstick"] = 22,
	["item_shivas_guard"] = 30,
	["item_silver_edge"] = 18,
	["item_solar_crest"] = 12,
	["item_soul_ring"] = 25,
	["item_sphere"] = 12,
	["item_tpscroll"] = 80,
	["item_urn_of_shadows"] = 7,
	["item_veil_of_discord"] = 25,
}

USABLE_ITEMS_FOR_INDEXING = {
	["item_abyssal_blade"] = "abyssalBlade",
	["item_ancient_janggo"] = "drums",
	["item_arcane_blink"] = "blink",
	["item_armlet"] = "armlet",
	["item_bfury"] = "hatchet",
	["item_black_king_bar"] = "bkb",
	["item_blade_mail"] = "bladeMail",
	["item_blink"] = "blink",
	["item_bloodstone"] = "bloodstone",
	["item_bloodthorn"] = "bloodthorn",
	["item_branches"] = "branches",
	["item_buckler"] = "buckler",
	["item_cheese"] = "cheese",
	["item_crimson_guard"] = "crimsonGuard",
	["item_cyclone"] = "euls",
	["item_dagon"] = "dagon",
	["item_dagon_2"] = "dagon",
	["item_dagon_3"] = "dagon",
	["item_dagon_4"] = "dagon",
	["item_dagon_5"] = "dagon",
	["item_diffusal_blade"] = "diffusalBlade",
	["item_dust"] = "dust",
	["item_eternal_shroud"] = "hood",
	["item_ethereal_blade"] = "etherealBlade",
	["item_force_staff"] = "forceStaff",
	["item_ghost"] = "ghostScepter",
	["item_glimmer_cape"] = "glimmerCape",
	["item_gungir"] = "gungir",
	["item_hand_of_midas"] = "midas",
	["item_heavens_halberd"] = "heavensHalberd",
	["item_helm_of_the_dominator"] = "hotd",
	["item_helm_of_the_overlord"] = "hoto",
	["item_hood_of_defiance"] = "hood",
	["item_hurricane_pike"] = "forceStaff",
	["item_invis_sword"] = "shadowBlade",
	["item_lotus_orb"] = "lotusOrb",
	["item_manta"] = "manta",
	["item_mask_of_madness"] = "mom",
	["item_medallion_of_courage"] = "medallion",
	["item_meteor_hammer"] = "meteorHammer",
	["item_mjollnir"] = "mjollnir",
	["item_moon_shard"] = "moonShard",
	["item_necronomicon"] = "necronomicon",
	["item_nullifier"] = "nullifier",
	["item_orchid"] = "orchid",
	["item_overwhelming_blink"] = "blink",
	["item_phase_boots"] = "phaseBoots",
	["item_pipe"] = "pipe",
	["item_power_treads"] = "powerTreads",
	["item_quelling_blade"] = "hatchet",
	["item_radiance"] = "radiance",
	["item_refresher"] = "refresher",
	["item_refresher_shard"] = "refresherShard",
	["item_rod_of_atos"] = "rodOfAtos",
	["item_satanic"] = "satanic",
	["item_shadow_amulet"] = "shadowAmulet",
	["item_sheepstick"] = "sheepstick",
	["item_shivas_guard"] = "shivas",
	["item_silver_edge"] = "shadowBlade",
	["item_solar_crest"] = "medallion",
	["item_soul_ring"] = "soulRing",
	["item_sphere"] = "linkens",
	["item_spirit_vessel"] = "urn",
	["item_swift_blink"] = "blink",
	["item_urn_of_shadows"] = "urn",
	["item_veil_of_discord"] = "veil",
	["item_ward_dispenser"] = "wards",
	["item_ward_observer"] = "wards",
	["item_ward_sentry"] = "wards",
	["item_wind_waker"] = "euls",
}

INVIS_ITEMS = {
	"item_glimmer",
	"item_invis_sword",
	"item_shadow_amulet",
	"item_silver_edge"
}

ITEMS_JUNGLE = {
	["item_keen_optic"] = true,
	["item_grove_bow"] = true,
	["item_quickening_charm"] = true,
	["item_philosophers_stone"] = true,
	["item_force_boots"] = true,
	["item_desolator_2"] = true,
	["item_seer_stone"] = true,
	["item_greater_mango"] = true,
	["item_elixer_healing"] = true,
	["item_vampire_fangs"] = true,
	["item_craggy_coat"] = true,
	["item_timeless_relic"] = true,
	["item_mirror_shield"] = true,
	["item_ironwood_tree"] = true,
	["item_royal_jelly"] = true,
	["item_pupils_gift"] = true,
	["item_repair_kit"] = true,
	["item_mind_breaker"] = true,
	["item_third_eye"] = true,
	["item_spell_prism"] = true,
	["item_horizon"] = true,
	["item_princes_knife"] = true,
	["item_spider_legs"] = true,
	["item_helm_of_the_undying"] = true,
	["item_mango_tree"] = true,
	["item_imp_claw"] = true,
	["item_flicker"] = true,
	["item_spy_gadget"] = true,
	["item_ocean_heart"] = true,
	["item_broom_handle"] = true,
	["item_trusty_shovel"] = true,
	["item_nether_shawl"] = true,
	["item_dragon_scale"] = true,
	["item_essence_ring"] = true,
	["item_clumsy_net"] = true,
	["item_enchanted_quiver"] = true,
	["item_ninja_gear"] = true,
	["item_illusionsts_cape"] = true, -- as spelt
	["item_havoc_hammer"] = true,
	["item_panic_button"] = true,
	["item_apex"] = true,
	["item_ballista"] = true,
	["item_woodland_striders"] = true,
	["item_trident"] = true,
	["item_demonicon"] = true,
	["item_fallen_sky"] = true,
	["item_pirate_hat"] = true,
	["item_dimentional_doorway"] = true,
	["item_ex_machina"] = true,
	["item_faded_broach"] = true,
	["item_paladin_sword"] = true,
	["item_minotaur_horn"] = true,
	["item_orb_of_destruction"] = true,
	["item_the_leveller"] = true,
	["item_titan_sliver"] = true,
	["item_chipped_vest"] = true,
	["item_wizard_glass"] = true,
	["item_gloves_of_travel"] = true,
	["item_sorcerers_staff"] = true,
	["item_elven_tunic"] = true,
	["item_cloak_of_flames"] = true,
	["item_venom_gland"] = true,
	["item_trickster_cloak"] = true,
	["item_gladiator_helm"] = true,
	["item_possessed_mask"] = true,
	["item_force_field"] = true,
	["item_black_powder_bag"] = true,
	["item_ascetic_cap"] = true,
	["item_pogo_stick"] = true,
	["item_paintball"] = true,
	["item_heavy_blade"] = true,
	["item_unstable_wand"] = true,
	["item_misericorde"] = true,
	["item_ancient_perseverance"] = true,
	["item_oakheart"] = true,
	["item_stormcrafter"] = true,
	["item_overflowing_elixir"] = true,
	["item_mysterious_hat"] = true,
	["item_satchel"] = true,
	["item_star_mace"] = true,
	["item_penta_edged_sword"] = true,
	["item_vambrace"] = true,
	["item_witless_shako"] = true
}

require(GetScriptDirectory().."/lib_hero/item/item_logic")

local ITEM_MAX_PLAYER_STORAGE = ITEM_MAX_PLAYER_STORAGE
local ITEM_INVENTORY_AND_BACKPACK_STORAGE = ITEM_INVENTORY_AND_BACKPACK_STORAGE
local ITEM_MAX_COURIER_STORAGE = ITEM_INVENTORY_AND_BACKPACK_STORAGE

local TPSCROLL_SLOT = TPSCROLL_SLOT
local NEUTRAL_ITEM_SLOT = NEUTRAL_ITEM_SLOT

local ITEM_END_INVENTORY_INDEX = ITEM_END_BACKPACK_INDEX
local ITEM_END_BACKPACK_INDEX = ITEM_END_BACKPACK_INDEX
local ITEM_END_STASH_INDEX = ITEM_END_STASH_INDEX

local ITEM_NAME_SEARCH_START = ITEM_NAME_SEARCH_START

local DEFAULT_ITEM_EXISTS_PNOT = 1

local ITEM_COOLDOWN = ITEM_COOLDOWN
local Math_GetRandStandardDeviation = Math_GetRandStandardDeviation

-- TODO complete / automate value determination
ITEM_DEFINES = {
	["BLINK_DISTANCE"] = 1200
}

local t_inventory = {} -- 
local t_enemy_last_seen_inventory = {}

do
	for i=1,ENEMY_TEAM_NUMBER_OF_PLAYERS do
		t_enemy_last_seen_inventory[i] = {}
	end
end

function Item_UpdateKnownInventory(gsiEnemy)
	local pnot = gsiEnemy.nOnTeam
	local hUnit = gsiEnemy.hUnit
	local thisEnemyInventory = t_enemy_last_seen_inventory[pnot]
	for i=0,ITEM_END_BACKPACK_INDEX do
		local thisSlotItem = hUnit:GetItemInSlot(i)
		if thisSlotItem and not thisEnemyInventory[thisSlotItem:GetName()] then
			-- Create this new item
			local newItemKnownTable = {}
			-- Delete old components for the item
			-- - destructive to non-active use compnoents, but they aren't tracked for cooldowns anyways.
			local itemComponents = GetItemComponents(thisSlotItem:GetName())
			local checkCooldownGuessed = true
			for i=1,#itemComponents do
				local component = itemComponents[i]
				if thisEnemyInventory[component] then
					local cooldownGuessed = thisEnemyInventory[component][DEFAULT_ITEM_EXISTS_PNOT]
					if checkCooldownGuessed and cooldownGuessed > 0 then
						for pnot=1,TEAM_NUMBER_OF_PLAYERS do
							newItemKnownTable[pnot] = thisEnemyInventory[component][pnot]
						end
					end
				end
				thisEnemyInventory[component] = nil -- TODO no reason not to use recycling
			end
		end
	end
end

function Item_UpdateKnownCooldown(gsiEnemy, hItem)
	local pnot = gsiEnemy.nOnTeam
	local storedCooldownTime = ITEM_COOLDOWN[hItem:GetName()]
	if storedCooldownTime then
		local playerItemTable = t_enemy_last_seen_inventory[pnot][hItem:GetName()]
		if not playerItemTable then
			local thisEnemyInventory = t_enemy_last_seen_inventory[pnot]
			local thisEnemyInventoryItem = {}
			for i=1,TEAM_NUMBER_OF_PLAYERS do
				thisEnemyInventoryItem[i] = 0
			end
			thisEnemyInventory[hItem:GetName()] = thisEnemyInventoryItem
		end
	end
end
