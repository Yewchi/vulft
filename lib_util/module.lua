-- local index_of_module = 0
-- function Module_RegisterAndGetIndexOfModule()
	-- index_of_module = index_of_module + 1
	-- return index_of_module
-- end

-- function Module_InitSafeUnitProcessing(moduleIndex, safeUnit)
	-- safeUnit.moduleHasProcessed[moduleIndex] = 1
-- end

-- function Module_ContinueSafeUnitUse(moduleIndex, safeUnit)
	-- if safeUnit.modeHasProcessed[moduleIndex] then
		-- return true -- Keep using that safeUnit if needed.
	-- end
	-- -- Module must tidy up and dealloc their safeUnit!!
-- end

-- DONT DO THIS -- Use two-step safeUnit indexing with the hUnitRef that returns nil if a unit has been made null.