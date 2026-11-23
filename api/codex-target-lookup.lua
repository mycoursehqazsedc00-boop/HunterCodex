------------------------------------------------------
-- HunterCodex: Target Lookup & Live Client-Mod Telemetry
-- Target runtime: Lua 5.0 (WoW 1.12 / Turtle WoW)
------------------------------------------------------

local function HC_TargetPrint(msg)
	local line = "|cFFFFFFFF[|r|cFFABD473HunterCodex|r|cFFFFFFFF]|r " .. tostring(msg or "")
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(line)
	end
end

local function HC_FindBeastByName(name)
	if type(MTH_DS_Beasts) ~= "table" or not name then return nil, nil end
	local needle = string.lower(name)
	for id, beast in pairs(MTH_DS_Beasts) do
		if type(beast) == "table" and beast.name and string.lower(beast.name) == needle then
			return id, beast
		end
	end
	return nil, nil
end

local function HC_FindVendorByName(name)
	if type(MTH_DS_Vendors) ~= "table" or not name then return nil, nil end
	local needle = string.lower(name)
	for id, npc in pairs(MTH_DS_Vendors) do
		if type(npc) == "table" and npc.name and string.lower(npc.name) == needle then
			return id, npc
		end
	end
	return nil, nil
end

function HC_LookupTargetInCodex()
	if type(HC_GetTargetInfo) ~= "function" then return end
	local info = HC_GetTargetInfo()
	if not info or not info.name or info.name == "" then
		HC_TargetPrint("No target selected.")
		return
	end

	if type(HC_Trace) == "function" then
		HC_Trace("TARGET", "Lookup: " .. tostring(info.name) .. " (lvl " .. tostring(info.level) .. ")")
	end

	local beastId, beast = HC_FindBeastByName(info.name)
	local npcId, npc = nil, nil
	if not beastId then
		npcId, npc = HC_FindVendorByName(info.name)
	end

	-- Open HunterBook if closed
	if MTH_BOOK_Browser and not MTH_BOOK_Browser:IsShown() then
		if type(MTH_BOOK_Toggle) == "function" then
			MTH_BOOK_Toggle()
		else
			MTH_BOOK_Browser:Show()
		end
	end

	local searchBox = getglobal("MTH_BOOK_SearchBox")
	if beastId and beast then
		if type(MTH_BOOK_SetMode) == "function" then
			MTH_BOOK_SetMode("pets")
		end
		if searchBox and searchBox.SetText then
			searchBox:SetText(beast.name or info.name)
		end
		if info.distance then
			HC_TargetPrint(string.format("Beast [%d] %s | Distance: %.1f yd | LoS: %s",
				beastId, tostring(beast.name), info.distance, info.inSight and "Yes" or "No"))
		end
		return
	end

	if npcId and npc then
		if type(MTH_BOOK_SetMode) == "function" then
			MTH_BOOK_SetMode("npcs")
		end
		if searchBox and searchBox.SetText then
			searchBox:SetText(npc.name or info.name)
		end
		if info.distance then
			HC_TargetPrint(string.format("NPC [%d] %s | Distance: %.1f yd | LoS: %s",
				npcId, tostring(npc.name), info.distance, info.inSight and "Yes" or "No"))
		end
		return
	end

	-- Not in static DB: report live telemetry + preview 3D model if VanillaHelpers is loaded
	local parts = { "Target not in DB: " .. tostring(info.name) }
	if info.level then table.insert(parts, "Lvl " .. tostring(info.level)) end
	if info.family then table.insert(parts, "Family " .. tostring(info.family)) end
	if info.nativeDisplayId then table.insert(parts, "DisplayID " .. tostring(info.nativeDisplayId)) end
	if info.guid then table.insert(parts, "GUID " .. tostring(info.guid)) end
	if info.distance then table.insert(parts, string.format("%.1f yd", info.distance)) end
	HC_TargetPrint(table.concat(parts, " | "))

	if info.nativeDisplayId and type(MTH_BOOK_ModelViewer_SetDisplayId) == "function" then
		MTH_BOOK_ModelViewer_SetDisplayId(info.nativeDisplayId, info.name)
	end
end

local function HC_EnsureTargetLookupButton()
	if getglobal("HC_TargetLookupBtn") then return end
	local book = MTH_BOOK_Browser or getglobal("MTH_BOOK_Browser")
	if not book then return end

	local btn = CreateFrame("Button", "HC_TargetLookupBtn", book, "UIPanelButtonTemplate")
	btn:SetWidth(92)
	btn:SetHeight(20)
	btn:SetPoint("TOPRIGHT", book, "TOPRIGHT", -42, -14)
	btn:SetText("Lookup Target")
	btn:SetScript("OnClick", function()
		HC_LookupTargetInCodex()
	end)
	btn:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:SetText("Lookup Current Target", 1, 0.82, 0)
		GameTooltip:AddLine("Jump to your target in Beast Lore or NPC Finder.", 1, 1, 1)
		GameTooltip:AddLine("Uses SuperWoW / Nampower / VanillaHelpers / UnitXP SP3 if installed.", 0.75, 0.75, 0.75)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local HC_TL_Frame = CreateFrame("Frame", "HC_TargetLookupFrame")
if HC_TL_Frame then
	HC_TL_Frame:RegisterEvent("PLAYER_LOGIN")
	HC_TL_Frame:SetScript("OnEvent", function()
		if event == "PLAYER_LOGIN" then
			HC_EnsureTargetLookupButton()
		end
	end)
end
