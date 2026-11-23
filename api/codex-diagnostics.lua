------------------------------------------------------
-- HunterCodex: Debug Tracing & Regression Diagnostics
-- Slash commands: /hc, /huntercodex
-- Target runtime: Lua 5.0 (WoW 1.12 / Turtle WoW)
------------------------------------------------------

HC_TRACE_ENABLED = false

function HC_Trace(tag, msg)
	if not HC_TRACE_ENABLED then return end
	local t = (type(GetTime) == "function") and string.format("%.2f", GetTime()) or "0.00"
	local line = "|cFFABD473[HC TRACE " .. t .. "]|r [" .. tostring(tag or "CORE") .. "] " .. tostring(msg or "")
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(line)
	end
end

local function HC_Print(msg)
	local line = "|cFFFFFFFF[|r|cFFABD473HunterCodex|r|cFFFFFFFF]|r " .. tostring(msg or "")
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage(line)
	end
end

local function HC_CountTable(tbl)
	if type(tbl) ~= "table" then return 0 end
	local n = 0
	for _ in pairs(tbl) do
		n = n + 1
	end
	return n
end

function HC_PrintClientMods()
	if type(HC_DetectClientMods) == "function" and not (HC_ClientMods and HC_ClientMods.detected) then
		HC_DetectClientMods()
	end
	local m = HC_ClientMods or {}
	HC_Print("Client Mods Detected:")
	HC_Print("  ClassicAPI:     " .. (m.classicAPI and ("YES (" .. tostring(m.classicAPIVersion) .. ")") or "NO (Vanilla Lua 5.0 fallback)"))
	HC_Print("  Nampower:       " .. (m.nampower and ("YES (v" .. tostring(m.nampowerVersion) .. ")") or "NO"))
	HC_Print("  SuperWoW:       " .. (m.superwow and ("YES (" .. tostring(m.superwowVersion) .. ")") or "NO"))
	HC_Print("  UnitXP SP3:     " .. (m.unitxp and "YES" or "NO"))
	HC_Print("  VanillaHelpers: " .. (m.vanillaHelpers and "YES" or "NO"))
end

function HC_RunRegressionTest()
	local pass = 0
	local fail = 0
	local function check(name, cond, detail)
		if cond then
			pass = pass + 1
			HC_Trace("TEST", "PASS: " .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
		else
			fail = fail + 1
			HC_Print("|cFFFF4040FAIL:|r " .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
		end
	end

	-- 1. Core Databases
	local beastCount = HC_CountTable(MTH_DS_Beasts)
	local famCount = HC_CountTable(MTH_DS_Families)
	local vendorCount = HC_CountTable(MTH_DS_Vendors)
	local itemCount = HC_CountTable(MTH_DS_AmmoItems)
	local bagCount = HC_CountTable(MTH_DS_BagItems or MTH_DS_Bags)
	local petSpellCount = (MTH_DS_PetSpells and MTH_DS_PetSpells.allSpells) and table.getn(MTH_DS_PetSpells.allSpells) or 0
	local hunterSpellCount = HC_CountTable(MTH_DS_HunterSpells)

	check("MTH_DS_Beasts loaded", beastCount >= 800, beastCount)
	check("MTH_DS_Families loaded", famCount >= 20, famCount)
	check("MTH_DS_Vendors loaded", vendorCount >= 190, vendorCount)
	check("MTH_DS_AmmoItems loaded", itemCount >= 28, itemCount)
	check("MTH_DS_BagItems loaded", bagCount >= 20, bagCount)
	check("MTH_DS_PetSpells loaded", petSpellCount >= 50, petSpellCount)
	check("MTH_DS_HunterSpells loaded", hunterSpellCount >= 1, hunterSpellCount)

	-- 2. New & Updated Beasts Verification
	check("New beast [4660] Maraudine Bonepaw", MTH_DS_Beasts and MTH_DS_Beasts[4660] and MTH_DS_Beasts[4660].attackSpeed == "1.62")
	check("New beast [63140] Tamed Ice Claw Bear", MTH_DS_Beasts and MTH_DS_Beasts[63140] and MTH_DS_Beasts[63140].lvl == "13-15")
	check("New beast [63033] Old Whispershell", MTH_DS_Beasts and MTH_DS_Beasts[63033] and MTH_DS_Beasts[63033].displayId == 7114)
	check("Updated beast [8303] Grunter speed 1.23", MTH_DS_Beasts and MTH_DS_Beasts[8303] and MTH_DS_Beasts[8303].attackSpeed == "1.23")
	check("Updated beast [92147] Silver Coast Crawler", MTH_DS_Beasts and MTH_DS_Beasts[92147] and MTH_DS_Beasts[92147].lvl == "50-52")

	-- 3. Vendor 3D DisplayID Coverage
	local vendorDisplayCount = 0
	if type(MTH_DS_Vendors) == "table" then
		for _, v in pairs(MTH_DS_Vendors) do
			if type(v) == "table" and tonumber(v.displayId) then
				vendorDisplayCount = vendorDisplayCount + 1
			end
		end
	end
	check("Vendor displayId coverage >= 180", vendorDisplayCount >= 180, vendorDisplayCount)

	-- 4. 3D Model & Icon Viewer APIs
	check("ModelViewer SetFamily", type(MTH_BOOK_ModelViewer_SetFamily) == "function")
	check("ModelViewer SetDisplayId", type(MTH_BOOK_ModelViewer_SetDisplayId) == "function")
	check("ModelViewer SetItem", type(MTH_BOOK_ModelViewer_SetItem) == "function")
	check("Icon Resolver", type(HC_ResolveItemIcon) == "function" and type(HC_ResolveSpellIcon) == "function")

	-- 5. zButtons Frames
	local zbNames = { "zButtonAmmo", "zButtonAspect", "zButtonTrack", "zButtonTrap", "zButtonRanged", "zButtonPet" }
	local zbFound = 0
	for i = 1, table.getn(zbNames) do
		if getglobal(zbNames[i]) then
			zbFound = zbFound + 1
		end
	end
	check("zButtons frames created", zbFound == table.getn(zbNames), tostring(zbFound) .. "/" .. tostring(table.getn(zbNames)))

	-- 6. Realm block removed, Minimap button & Target lookup
	check("Realm gate unblocked", MTH and type(MTH.IsRealmGateBlocked) == "function" and not MTH:IsRealmGateBlocked())
	check("Minimap button created", getglobal("MTH_MinimapBtn") ~= nil)
	check("Target lookup ready", type(HC_LookupTargetInCodex) == "function")

	HC_Print("Self-test complete: |cFF00FF00" .. tostring(pass) .. " PASS|r, |cFFFF4040" .. tostring(fail) .. " FAIL|r")
	return pass, fail
end

-- Hook HunterBook tab switches and detail updates for tracing
local HC_HooksInstalled = false
local function HC_InstallTraceHooks()
	if HC_HooksInstalled then return end
	HC_HooksInstalled = true
	if type(MTH_BOOK_SetMode) == "function" then
		local origSetMode = MTH_BOOK_SetMode
		MTH_BOOK_SetMode = function(mode)
			HC_Trace("BOOK", "Switch tab -> " .. tostring(mode))
			return origSetMode(mode)
		end
	end
end

local HC_InitFrame = CreateFrame("Frame", "HC_DiagInitFrame")
if HC_InitFrame then
	HC_InitFrame:RegisterEvent("PLAYER_LOGIN")
	HC_InitFrame:SetScript("OnEvent", function()
		if event == "PLAYER_LOGIN" then
			HC_InstallTraceHooks()
		end
	end)
end

SLASH_HUNTERCODEX1 = "/hc"
SLASH_HUNTERCODEX2 = "/huntercodex"
SlashCmdList["HUNTERCODEX"] = function(msg)
	local cmd = string.lower(string.gsub(tostring(msg or ""), "^%s*(.-)%s*$", "%1"))
	if cmd == "trace" or cmd == "trace on" or cmd == "trace off" then
		if cmd == "trace on" then
			HC_TRACE_ENABLED = true
		elseif cmd == "trace off" then
			HC_TRACE_ENABLED = false
		else
			HC_TRACE_ENABLED = not HC_TRACE_ENABLED
		end
		HC_Print("Debug tracing: " .. (HC_TRACE_ENABLED and "|cFF00FF00ON|r" or "|cFFFF4040OFF|r"))
		return
	end
	if cmd == "test" then
		HC_RunRegressionTest()
		return
	end
	if cmd == "mods" then
		HC_PrintClientMods()
		return
	end
	if cmd == "options" or cmd == "opt" or cmd == "config" then
		if type(MTH_OpenOptions) == "function" then
			MTH_OpenOptions()
		end
		return
	end
	if cmd == "target" then
		if type(HC_LookupTargetInCodex) == "function" then
			HC_LookupTargetInCodex()
		end
		return
	end
	if cmd == "minimap" then
		if MTH_MinimapButton and MTH_MinimapButton.Initialize then
			MTH_MinimapButton:Initialize()
		end
		local btn = getglobal("MTH_MinimapBtn")
		if btn then
			if btn:IsShown() then
				btn:Hide()
				HC_Print("Minimap button hidden. Run /hc minimap to show.")
			else
				btn:Show()
				HC_Print("Minimap button shown.")
			end
		end
		return
	end
	if cmd == "help" then
		HC_Print("Commands:")
		HC_Print("  /hc           - Toggle HunterCodex Book")
		HC_Print("  /hc options   - Open Options (zButtons, Profiles, etc.)")
		HC_Print("  /hc target    - Lookup current target in HunterCodex")
		HC_Print("  /hc minimap   - Toggle Minimap button")
		HC_Print("  /hc trace     - Toggle debug tracing")
		HC_Print("  /hc test      - Run in-game database & UI self-test")
		HC_Print("  /hc mods      - Show detected client DLL mods")
		return
	end
	if type(MTH_BOOK_Toggle) == "function" then
		MTH_BOOK_Toggle()
	elseif MTH_BOOK_Browser and MTH_BOOK_Browser.Show then
		if MTH_BOOK_Browser:IsShown() then MTH_BOOK_Browser:Hide() else MTH_BOOK_Browser:Show() end
	end
end
