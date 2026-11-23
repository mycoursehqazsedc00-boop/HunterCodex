------------------------------------------------------
-- HunterCodex: Client DLL Mod Feature Detection & Helpers
-- Target runtime: Lua 5.0 (WoW 1.12 / Turtle WoW)
-- Detects ClassicAPI, Nampower, SuperWoW, UnitXP SP3, and VanillaHelpers at PLAYER_LOGIN
------------------------------------------------------

HC_ClientMods = HC_ClientMods or {
	detected = false,
	classicAPI = false,
	classicAPIVersion = nil,
	nampower = false,
	nampowerVersion = nil,
	superwow = false,
	superwowVersion = nil,
	unitxp = false,
	vanillaHelpers = false,
}

function HC_DetectClientMods()
	HC_ClientMods.classicAPI = (CLASSIC_API_VERSION ~= nil)
	HC_ClientMods.classicAPIVersion = CLASSIC_API_VERSION

	if type(GetNampowerVersion) == "function" then
		local ok, maj, min, pat = pcall(GetNampowerVersion)
		if ok and maj then
			HC_ClientMods.nampower = true
			HC_ClientMods.nampowerVersion = tostring(maj) .. "." .. tostring(min or 0) .. "." .. tostring(pat or 0)
		end
	end

	HC_ClientMods.superwow = (SUPERWOW_VERSION ~= nil)
	HC_ClientMods.superwowVersion = SUPERWOW_STRING or SUPERWOW_VERSION

	if type(UnitXP) == "function" then
		local ok = pcall(UnitXP, "nop", "nop")
		HC_ClientMods.unitxp = ok and true or false
	else
		HC_ClientMods.unitxp = false
	end

	HC_ClientMods.vanillaHelpers = (type(UnitDisplayInfo) == "function")
	HC_ClientMods.detected = true
	return HC_ClientMods
end

-- Resolve an item icon texture path safely using static DB icon first,
-- then GetItemInfo (stock/ClassicAPI), then Nampower GetItemStats + GetItemIconTexture.
function HC_ResolveItemIcon(itemId, staticIcon)
	if type(staticIcon) == "string" and staticIcon ~= "" then
		if string.find(staticIcon, "\\", 1, true) then
			return staticIcon
		end
		return "Interface\\Icons\\" .. staticIcon
	end

	local id = tonumber(itemId)
	if not id then return "Interface\\Icons\\INV_Misc_QuestionMark" end

	if type(GetItemInfo) == "function" then
		local _, _, _, _, _, _, _, _, tex = GetItemInfo(id)
		if type(tex) == "string" and tex ~= "" then
			return tex
		end
	end

	if HC_ClientMods.nampower and type(GetItemStats) == "function" and type(GetItemIconTexture) == "function" then
		local ok, stats = pcall(GetItemStats, id, 1)
		if ok and type(stats) == "table" and stats.displayInfoId then
			local ok2, tex = pcall(GetItemIconTexture, stats.displayInfoId)
			if ok2 and type(tex) == "string" and tex ~= "" then
				return tex
			end
		end
	end

	return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Resolve a spell icon texture path safely using static DB icon first,
-- then SuperWoW SpellInfo, then Nampower GetSpellRec + GetSpellIconTexture.
function HC_ResolveSpellIcon(spellId, staticIcon)
	if type(staticIcon) == "string" and staticIcon ~= "" then
		if string.find(staticIcon, "\\", 1, true) then
			return staticIcon
		end
		return "Interface\\Icons\\" .. staticIcon
	end

	local id = tonumber(spellId)
	if not id then return "Interface\\Icons\\INV_Misc_QuestionMark" end

	if HC_ClientMods.superwow and type(SpellInfo) == "function" then
		local ok, _, _, tex = pcall(SpellInfo, id)
		if ok and type(tex) == "string" and tex ~= "" then
			return tex
		end
	end

	if HC_ClientMods.nampower and type(GetSpellRec) == "function" and type(GetSpellIconTexture) == "function" then
		local ok, rec = pcall(GetSpellRec, id, 1)
		if ok and type(rec) == "table" and rec.spellIconID then
			local ok2, tex = pcall(GetSpellIconTexture, rec.spellIconID)
			if ok2 and type(tex) == "string" and tex ~= "" then
				return tex
			end
		end
	end

	return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Query live item stats from Nampower (copy=1) if available.
function HC_GetLiveItemStats(itemId)
	local id = tonumber(itemId)
	if not id or not HC_ClientMods.nampower or type(GetItemStats) ~= "function" then
		return nil
	end
	local ok, stats = pcall(GetItemStats, id, 1)
	if ok and type(stats) == "table" then
		return stats
	end
	return nil
end

-- Query live spell record from Nampower (copy=1) or SuperWoW SpellInfo if available.
function HC_GetLiveSpellInfo(spellId)
	local id = tonumber(spellId)
	if not id then return nil end
	local out = nil
	if HC_ClientMods.nampower and type(GetSpellRec) == "function" then
		local ok, rec = pcall(GetSpellRec, id, 1)
		if ok and type(rec) == "table" then
			out = {
				manaCost = rec.manaCost,
				castTime = rec.castTime,
				recoveryTime = rec.recoveryTime,
				source = "Nampower",
			}
		end
	end
	if not out and HC_ClientMods.superwow and type(SpellInfo) == "function" then
		local ok, name, rank, tex, minRange, maxRange = pcall(SpellInfo, id)
		if ok and name then
			out = {
				name = name,
				rank = rank,
				texture = tex,
				minRange = minRange,
				maxRange = maxRange,
				source = "SuperWoW",
			}
		end
	end
	return out
end

-- Inspect current target using stock API + optional SuperWoW/Nampower/VanillaHelpers/UnitXP SP3.
function HC_GetTargetInfo()
	if not UnitExists or not UnitExists("target") then
		return nil
	end
	local info = {
		name = UnitName("target"),
		level = UnitLevel("target"),
		family = UnitCreatureFamily and UnitCreatureFamily("target") or nil,
		classification = UnitClassification and UnitClassification("target") or nil,
		guid = nil,
		displayId = nil,
		nativeDisplayId = nil,
		distance = nil,
		inSight = nil,
	}
	if HC_ClientMods.nampower and type(GetUnitGUID) == "function" then
		local ok, guid = pcall(GetUnitGUID, "target")
		if ok and guid then info.guid = guid end
	elseif HC_ClientMods.superwow then
		local _, guid = UnitExists("target")
		if guid then info.guid = guid end
	end
	if HC_ClientMods.vanillaHelpers and type(UnitDisplayInfo) == "function" then
		local ok, disp, nativeDisp = pcall(UnitDisplayInfo, "target")
		if ok then
			info.displayId = tonumber(disp)
			info.nativeDisplayId = tonumber(nativeDisp) or tonumber(disp)
		end
	end
	if HC_ClientMods.unitxp and type(UnitXP) == "function" then
		local okD, dist = pcall(UnitXP, "distanceBetween", "player", "target")
		if okD and tonumber(dist) then info.distance = tonumber(dist) end
		local okS, sight = pcall(UnitXP, "inSight", "player", "target")
		if okS then info.inSight = sight and true or false end
	end
	return info
end

local HC_ModDetectFrame = CreateFrame("Frame", "HC_ModDetectFrame")
if HC_ModDetectFrame then
	HC_ModDetectFrame:RegisterEvent("PLAYER_LOGIN")
	HC_ModDetectFrame:SetScript("OnEvent", function()
		if event == "PLAYER_LOGIN" then
			HC_DetectClientMods()
		end
	end)
end
