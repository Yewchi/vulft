function Vibe_CreateVibe(thisPlayer)
	local newVibe = {}
	newVibe.greedRating = Team_GetRoleBasedGreedRating(thisPlayer) -- N.B. Intended for low-level modifiers. Use sparingly on scores from low-level code in high-level code.
	--print(thisPlayer.shortName, "have greed", newVibe.greedRating)
	newVibe.safetyRating = 1.0 -- the lean towards using attacks over mobility, heals or defensives.
	newVibe.aggressivityRating = 0.5 -- 1.0 would cause us to use all abilities and stuns per attaining a kill, 0.75 may cause us to hold a stun for attempted get-aways or key fight tempo switches and counter-plays. 0.6 is about fight_harass. 0.35 is about farm_lane. 0.0 is increase_safety, where abilities will only be used because they help us escape.
	
	return newVibe
end

function Vibe_CreateAndAllocatePlayerVibes(t_players)
	for i=1,#t_players,1 do
		t_players[i].vibe = Vibe_CreateVibe(t_players[i])
	end
end
