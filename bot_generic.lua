local function print_info()
	if GetBot():GetPlayerID() == 5 then
		for i=-1,7 do
			print("Rune status:", i, GetRuneStatus(i))
		end
	end
	print("POWERUP1", RUNE_POWERUP_1, "POWERUP2", RUNE_POWERUP_2,
			"BOUNTY1", RUNE_BOUNTY_1, "BOUNTY2", RUNE_BOUNTY_2,
			"BOUNTY3", RUNE_BOUNTY_3, "BOUNTY4", RUNE_BOUNTY_4
		)
end

Think = function()
	print_info()
	if RandomInt(1,10) == 10 then
		print(GetBot():GetPlayerID(), "tries grab", GetBot():GetPlayerID() % 6)
		GetBot():Action_PickUpRune(GetBot():GetPlayerID() % 6)
	end
end
