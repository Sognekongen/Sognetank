-- ========================================================
-- SOGNETANK - WARRIOR TANK ROTATION FOR OCTOWOW / 1.12.1
-- v6: Berserker Rage fear break | single-target + AOE rotation, auto taunt / mocking blow,
--     Shield Block, auto interrupt (Shield Bash / Pummel)
--
-- Commands:
--   /sognetank          single-target rotation
--   /sogneaoe           AOE rotation
--   /sognetank aoe      same AOE rotation, via the main command
--   /sognetank taunt    toggle auto taunt on/off
--   /sognetank debug    toggle debug messages
--   /sognetank fear     toggle Berserker Rage fear-break on/off
--   /sognetank feartest simulate a fear warning (in combat) to test the stance dance
--   /sognetank listfear | addfear <spell> | delfear <spell>   manage the fear spell library
--   /sognetank msg        toggle the small info text in chat
--   /sognetank consume    toggle Major Healthstone at low HP
--   /sognetank emergency  toggle Last Stand / Shield Wall at low HP
--   /sognetank options    show all on/off settings (they are saved)
-- ========================================================


-- Diagnostics: you should see both lines in chat when you log in / /reload
DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Sognetank:|r loading...")

-- --------------------------------------------------------
-- Slash commands (registered first; they call the rotations by name)
-- --------------------------------------------------------
local function RunSafe(fnName)
    local fn = getglobal(fnName)
    if not fn then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Sognetank:|r " .. fnName .. " is not loaded - the file stopped with an error while loading.")
        return
    end
    local ok, err = pcall(fn)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Sognetank error:|r " .. tostring(err))
    end
end

-- Toggle an option (saved between sessions). Option "NOMSG" -> global SOGNETANK_NOMSG
local function Toggle(key)
    local g = "SOGNETANK_" .. key
    local v = not getglobal(g)
    setglobal(g, v)
    SognetankDB = SognetankDB or {}
    SognetankDB.opts = SognetankDB.opts or {}
    SognetankDB.opts[key] = v
    return v
end

local function OnOff(disabledFlag)
    return disabledFlag and "|cffff4040OFF|r" or "|cff40ff40ON|r"
end

local function PrintOptions()
    local m = function(t) DEFAULT_CHAT_FRAME:AddMessage("Sognetank " .. t) end
    m("chat messages:        " .. OnOff(SOGNETANK_NOMSG)        .. "   (/sognetank msg)")
    m("Major Healthstone:     " .. OnOff(SOGNETANK_NOCONSUME)    .. "   (/sognetank consume)")
    m("Last Stand/Shield Wall: " .. OnOff(SOGNETANK_NOEMERGENCY) .. "   (/sognetank emergency)")
    m("auto taunt:           " .. OnOff(SOGNETANK_NOTAUNT)      .. "   (/sognetank taunt)")
    m("fear break:           " .. OnOff(SOGNETANK_NOFEAR)       .. "   (/sognetank fear)")
end

SLASH_SOGNETANK1 = "/sognetank"
SlashCmdList["SOGNETANK"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "debug" then
        SOGNETANK_DEBUG = not SOGNETANK_DEBUG
        DEFAULT_CHAT_FRAME:AddMessage("Sognetank debug: " .. (SOGNETANK_DEBUG and "ON" or "OFF"))
    elseif msg == "taunt" then
        DEFAULT_CHAT_FRAME:AddMessage("Sognetank auto taunt: " .. OnOff(Toggle("NOTAUNT")))
    elseif msg == "fear" then
        DEFAULT_CHAT_FRAME:AddMessage("Sognetank Berserker Rage (fear): " .. OnOff(Toggle("NOFEAR")))
    elseif msg == "msg" or msg == "text" then
        DEFAULT_CHAT_FRAME:AddMessage("Sognetank chat messages: " .. OnOff(Toggle("NOMSG")))
    elseif msg == "consume" then
        DEFAULT_CHAT_FRAME:AddMessage("Sognetank Major Healthstone: " .. OnOff(Toggle("NOCONSUME")))
    elseif msg == "emergency" then
        DEFAULT_CHAT_FRAME:AddMessage("Sognetank Last Stand / Shield Wall: " .. OnOff(Toggle("NOEMERGENCY")))
    elseif msg == "options" or msg == "help" then
        PrintOptions()
    elseif msg == "fearstatus" then
        if Sognetank_FearStatus then Sognetank_FearStatus() end
    elseif msg == "listfear" then
        if Sognetank_ListFear then Sognetank_ListFear() end
    elseif string.find(msg, "^addfear%s+") then
        local _, _, n = string.find(msg, "^addfear%s+(.+)$")
        if n and Sognetank_AddFear then Sognetank_AddFear(n) end
    elseif string.find(msg, "^delfear%s+") then
        local _, _, n = string.find(msg, "^delfear%s+(.+)$")
        if n and Sognetank_DelFear then Sognetank_DelFear(n) end
    elseif msg == "feartest" then
        if Sognetank_FearWarn then Sognetank_FearWarn() end
        DEFAULT_CHAT_FRAME:AddMessage("Sognetank: simulated fear warning (needs to be in combat)")
    elseif msg == "aoe" then
        RunSafe("furyTankAoe")
    else
        RunSafe("furyTank")
    end
end

-- Stand-alone AOE command
SLASH_SOGNETANKAOE1 = "/sogneaoe"
SLASH_SOGNETANKAOE2 = "/sognetankaoe"
SlashCmdList["SOGNETANKAOE"] = function()
    RunSafe("furyTankAoe")
end

-- --------------------------------------------------------
-- SETTINGS (edit these to fit OctoWoW)
-- --------------------------------------------------------
-- Stances: 1 = Battle, 2 = Defensive, 3 = Berserker
local SHIELD_BASH_STANCES   = { [1] = true, [2] = true }
local PUMMEL_STANCES        = { [3] = true }
local SHIELD_BLOCK_STANCES  = { [2] = true }
local THUNDER_CLAP_STANCES  = { [1] = true, [2] = true }
local TAUNT_STANCES         = { [2] = true }            -- add [1]/[3] if OctoWoW allows Taunt there
local MOCKING_BLOW_STANCES  = { [1] = true }            -- Battle Stance only
local DEMO_SHOUT_STANCES    = { [1] = true, [2] = true, [3] = true }

local RAGE_THUNDER_CLAP     = 20
local RAGE_DEMO_SHOUT       = 10
local RAGE_CLEAVE_SINGLE    = 70
local RAGE_CLEAVE_AOE       = 40
local DEMO_SHOUT_CHANCE     = 10     -- 1 in 10 per press when conditions are met

-- Emergency / survival (HP in percent)
local SHIELD_WALL_HP_PCT    = 25     -- Shield Wall at or below this HP% (Defensive Stance + shield)
local LAST_STAND_HP_PCT     = 20     -- Last Stand at or below this HP%
local CONSUME_HP_PCT        = 15     -- Major Healthstone at or below this HP%
local SHIELD_WALL_STANCES   = { [2] = true }
local LAST_STAND_STANCES    = { [1] = true, [2] = true, [3] = true }
-- Only the Major Healthstone is used (no potions, so potion cooldowns stay free).
local HEALTHSTONES = { "Major Healthstone" }

-- Seconds an enemy is considered "casting" after seeing the start
-- (only used when the cast duration is unknown, i.e. combat log detection)
local DEFAULT_CAST_WINDOW = 2.0


local function dbg(msg)
    if SOGNETANK_DEBUG then DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Sognetank:|r " .. msg) end
end

-- Short info text in chat (turn off with /sognetank msg)
local function Say(msg)
    if SOGNETANK_NOMSG then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffSognetank:|r " .. msg)
end

-- --------------------------------------------------------
-- Helpers
-- --------------------------------------------------------

-- Safe spellbook scanner (is the spell known and off cooldown?)
local function IsSpellReady(spellName)
    for i = 1, 300 do
        local name = GetSpellName(i, "spell")
        if name and string.lower(name) == string.lower(spellName) then
            local start, duration = GetSpellCooldown(i, "spell")
            return (start == 0 and duration == 0)
        end
    end
    return false
end

-- Is Battle Shout active on yourself?
local function HasBattleShout()
    for i = 1, 32 do
        local tex = UnitBuff("player", i)
        if tex and (string.find(string.lower(tex), "battleshout") or string.find(string.lower(tex), "battle shout")) then
            return true
        end
    end
    return false
end

-- Does the target already have Demoralizing Shout? (icon: Ability_Warrior_WarCry)
-- If the icon name is wrong on your client this simply returns false and the
-- 1-in-10 roll alone decides.
local function TargetHasDemoShout()
    for i = 1, 16 do
        local tex = UnitDebuff("target", i)
        if not tex then break end
        if string.find(string.lower(tex), "warcry") then
            return true
        end
    end
    return false
end

-- Do we have a shield in the off-hand slot (slot 17)?
local function HasShieldEquipped()
    local link = GetInventoryItemLink("player", 17)
    if not link then return false end
    local _, _, itemString = string.find(link, "(item:[%-%d:]+)")
    if not itemString then return false end
    local _, _, _, _, itemType, itemSubType = GetItemInfo(itemString)
    if itemSubType then
        return itemSubType == "Shields"
    end
    -- item info not cached: assume shield since something is in the slot
    return true
end

-- --------------------------------------------------------
-- Enemy cast detection
-- Order: UnitCastingInfo (if client has it) -> SuperWoW
-- UNIT_CASTEVENT -> combat log "begins to cast"
-- --------------------------------------------------------
local castUntil = 0
local castSourceName = nil

local function TargetIsCasting()
    if UnitCastingInfo then
        local ok, name = pcall(UnitCastingInfo, "target")
        if ok and name then return true end
    end
    if UnitChannelInfo then
        local ok, name = pcall(UnitChannelInfo, "target")
        if ok and name then return true end
    end
    if GetTime() < castUntil then
        local tName = UnitName("target")
        if tName and castSourceName and tName == castSourceName then
            return true
        end
    end
    return false
end

-- --------------------------------------------------------
-- BERSERKER RAGE (fear break) with automatic stance dance
-- Triggers: you are feared  OR  a fear warning is active
--   (target casts a fear spell / BigWigs "fear" message / raid warning "fear").
-- Flow: remember stance -> Berserker Stance -> Berserker Rage -> back to old stance.
-- --------------------------------------------------------
local BERSERKER_RAGE_STANCES = { [3] = true }  -- stances where Berserker Rage can be cast
local FEAR_WARNING_WINDOW    = 6.0             -- seconds a fear warning stays active

-- Debuff icon names (part of texture path) that mean "you are feared"
local FEAR_DEBUFF_ICONS = { "possession", "psychicscream", "deathscream", "golemthunderclap" }

-- ===================== FEAR SPELL LIBRARY (all lowercase) =====================
-- You can add more in game:  /sognetank addfear <spell name>
-- Unknown fears are also learned automatically when you actually get feared.

-- Fears that count when your CURRENT TARGET casts them (and when you are afflicted)
local FEAR_SPELLS = {
    -- player / class abilities (hostile players, NPC casters)
    ["fear"] = true,
    ["howl of terror"] = true,
    ["psychic scream"] = true,
    ["intimidating shout"] = true,
    -- NPC fears
    ["terrify"] = true,
    ["terrifying screech"] = true,   -- Death Singer (Eastern Plaguelands)
    ["intimidating roar"] = true,
    ["blood fear"] = true,
    ["incendiary terror"] = true,
    ["incindiary terror"] = true,
    ["frightening shriek"] = true,
}

-- Fears that count no matter WHO casts them (raid-wide boss fears)
local RAIDWIDE_FEAR_SPELLS = {
    ["bellowing roar"] = true,       -- Onyxia, Nefarian, Dragons of Nightmare (Taerar etc.), Nightbane
    ["terrifying roar"] = true,      -- Gluth (Naxxramas)
    ["panic"] = true,                -- Magmadar (Molten Core)
}
-- ==============================================================================

local STANCE_NAMES = { [1] = "Battle Stance", [2] = "Defensive Stance", [3] = "Berserker Stance" }

local fearWarnUntil = 0
local fearState = "idle"     -- idle / switching / raging / returning
local fearPrevStance = nil
local fearStateTime = 0
local fearLastTry = 0
local fearLastDbg = 0
local fearReason = "broke"
local fearAfflictedUntil = 0   -- set when the combat log says "You are afflicted by <fear>"

local function FearWarn(reason)
    fearWarnUntil = GetTime() + FEAR_WARNING_WINDOW
    dbg("fear warning: " .. tostring(reason))
end

local function NormalizeSpell(name)
    local n = string.lower(name or "")
    n = string.gsub(n, "%s*%(%d+%)$", "")   -- remove stack count like " (2)"
    return n
end

local function IsFearName(name)
    local n = NormalizeSpell(name)
    return (FEAR_SPELLS[n] or RAIDWIDE_FEAR_SPELLS[n]) and true or false
end

local function LearnFear(name)
    local n = NormalizeSpell(name)
    if n == "" or IsFearName(n) then return end
    FEAR_SPELLS[n] = true
    if SognetankDB and SognetankDB.learned then SognetankDB.learned[n] = true end
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Sognetank:|r learned new fear spell: " .. n)
end

-- Combat log: "You are afflicted by X." / "X fades from you."
local function OnAfflicted(name)
    if IsFearName(name) then
        fearAfflictedUntil = GetTime() + 10
        dbg("afflicted by fear: " .. name)
    end
end

local function OnFaded(name)
    if IsFearName(name) then
        fearAfflictedUntil = 0
        dbg("fear faded: " .. name)
    end
end

-- /sognetank listfear | addfear <name> | delfear <name>
function Sognetank_ListFear()
    local out = ""
    for k in pairs(FEAR_SPELLS) do out = out .. k .. ", " end
    local out2 = ""
    for k in pairs(RAIDWIDE_FEAR_SPELLS) do out2 = out2 .. k .. ", " end
    DEFAULT_CHAT_FRAME:AddMessage("Sognetank fear (target/afflicted): " .. out)
    DEFAULT_CHAT_FRAME:AddMessage("Sognetank fear (raid-wide): " .. out2)
end

function Sognetank_AddFear(name)
    local n = NormalizeSpell(name)
    if n == "" then return end
    FEAR_SPELLS[n] = true
    if SognetankDB and SognetankDB.learned then SognetankDB.learned[n] = true end
    DEFAULT_CHAT_FRAME:AddMessage("Sognetank: added fear spell: " .. n)
end

function Sognetank_DelFear(name)
    local n = NormalizeSpell(name)
    FEAR_SPELLS[n] = nil
    RAIDWIDE_FEAR_SPELLS[n] = nil
    if SognetankDB and SognetankDB.learned then SognetankDB.learned[n] = nil end
    DEFAULT_CHAT_FRAME:AddMessage("Sognetank: removed fear spell: " .. n)
end

-- global so /sognetank feartest can call it
function Sognetank_FearWarn()
    FearWarn("manual test")
end

local function CheckFearCast(caster, spell)
    local sp = string.lower(spell)
    if RAIDWIDE_FEAR_SPELLS[sp] then
        FearWarn(caster .. " casts " .. spell)
    elseif FEAR_SPELLS[sp] and UnitExists("target") and UnitName("target") == caster then
        FearWarn(caster .. " casts " .. spell)
    end
end

-- Hidden tooltip used to read the text of your debuffs
local scanTip = nil
local function GetScanTip()
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "SognetankScanTip", nil, "GameTooltipTemplate")
        scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return scanTip
end

-- Words in a debuff's name/description that mean "this is a fear"
local FEAR_TEXT = { "fleeing in fear", "fear", "terrif", "horrif", "flee" }

local function PlayerIsFeared()
    local tip = GetScanTip()
    for i = 1, 16 do
        local tex = UnitDebuff("player", i)
        if not tex then break end

        -- 1) icon name check
        local ltex = string.lower(tex)
        for j = 1, table.getn(FEAR_DEBUFF_ICONS) do
            if string.find(ltex, FEAR_DEBUFF_ICONS[j]) then
                dbg("feared (icon): " .. tex)
                return true, nil, false
            end
        end

        -- 2) tooltip text check (works for ANY fear, e.g. "Fleeing in fear.")
        tip:ClearLines()
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        tip:SetUnitDebuff("player", i)
        for line = 1, 4 do
            local fs = getglobal("SognetankScanTipTextLeft" .. line)
            local txt = fs and fs:GetText()
            if txt then
                txt = string.lower(txt)
                for j = 1, table.getn(FEAR_TEXT) do
                    if string.find(txt, FEAR_TEXT[j], 1, true) then
                        local nameFs = getglobal("SognetankScanTipTextLeft1")
                        local dName = nameFs and nameFs:GetText()
                        local strong = string.find(txt, "fleeing in fear", 1, true) and true or false
                        dbg("feared (tooltip): " .. tostring(dName) .. " / " .. txt)
                        return true, dName, strong
                    end
                end
            end
        end
    end
    return false
end

-- True when the spell is on its REAL cooldown (not just the 1.5s global cooldown)
local function SpellOnRealCooldown(spellName)
    for i = 1, 300 do
        local name = GetSpellName(i, "spell")
        if not name then break end
        if string.lower(name) == string.lower(spellName) then
            local start, duration = GetSpellCooldown(i, "spell")
            return (start and start > 0 and duration and duration > 2)
        end
    end
    return false
end

-- ---------- "ability used" chat messages (only printed when the spell really went on cooldown) ----------
local pendingAnnounce = {}
local function Announce(spell, text)
    if SOGNETANK_NOMSG then return end
    if not pendingAnnounce[spell] then
        pendingAnnounce[spell] = { t = GetTime(), text = text }
    end
end

local function ProcessAnnounce()
    local now = GetTime()
    for spell, a in pairs(pendingAnnounce) do
        local age = now - a.t
        if age >= 0.15 then
            if SpellOnRealCooldown(spell) then
                Say(a.text)
                pendingAnnounce[spell] = nil
            elseif age > 1.0 then
                pendingAnnounce[spell] = nil
            end
        end
    end
end

-- ---------- Emergency: Shield Wall / Last Stand / Major Healthstone ----------
local emTry = {}
local emNextScan = 0

local function FindBagItem(names)
    for n = 1, table.getn(names) do
        local want = string.lower(names[n])
        for bag = 0, 4 do
            local slots = GetContainerNumSlots(bag)
            for slot = 1, slots do
                local link = GetContainerItemLink(bag, slot)
                if link then
                    local _, _, iname = string.find(link, "%[(.-)%]")
                    if iname and string.lower(iname) == want then
                        return bag, slot, iname
                    end
                end
            end
        end
    end
    return nil
end

local function TryConsumable(label, names, hp)
    local bag, slot, iname = FindBagItem(names)
    if not bag then return false end
    local start = GetContainerItemCooldown(bag, slot)
    if start and start > 0 then return false end
    UseContainerItem(bag, slot)
    Say(label .. " used: " .. iname .. " (HP " .. math.floor(hp) .. "%)")
    return true
end

local function EmergencyTick()
    if UnitIsDeadOrGhost("player") or not UnitAffectingCombat("player") then return end
    local maxhp = UnitHealthMax("player")
    if not maxhp or maxhp <= 0 then return end
    local hp = UnitHealth("player") / maxhp * 100
    if hp > math.max(SHIELD_WALL_HP_PCT, LAST_STAND_HP_PCT, CONSUME_HP_PCT) then return end

    local now = GetTime()
    local s = GetBonusBarOffset()

    if not SOGNETANK_NOEMERGENCY then
        if hp <= SHIELD_WALL_HP_PCT and SHIELD_WALL_STANCES[s]
           and (not emTry["sw"] or now - emTry["sw"] > 1.5)
           and HasShieldEquipped() and IsSpellReady("Shield Wall") then
            emTry["sw"] = now
            CastSpellByName("Shield Wall")
            Announce("Shield Wall", "Shield Wall activated (HP " .. math.floor(hp) .. "%)")
            return
        end
        if hp <= LAST_STAND_HP_PCT and LAST_STAND_STANCES[s]
           and (not emTry["ls"] or now - emTry["ls"] > 1.5)
           and IsSpellReady("Last Stand") then
            emTry["ls"] = now
            CastSpellByName("Last Stand")
            Announce("Last Stand", "Last Stand activated (HP " .. math.floor(hp) .. "%)")
            return
        end
    end

    if not SOGNETANK_NOCONSUME and hp <= CONSUME_HP_PCT and now >= emNextScan then
        emNextScan = now + 0.5
        TryConsumable("Healthstone", HEALTHSTONES, hp)
    end
end

local function FearTick()
    if SOGNETANK_NOFEAR then fearState = "idle" return end
    local now = GetTime()
    local s = GetBonusBarOffset()

    if fearState == "idle" then
        local feared, fname, strong = PlayerIsFeared()
        if feared and strong and fname then LearnFear(fname) end
        if now < fearAfflictedUntil then feared = true end
        local warned = (now < fearWarnUntil) and UnitAffectingCombat("player")
        if not (feared or warned) then return end
        if not IsSpellReady("Berserker Rage") then
            if now - fearLastDbg > 1 then
                fearLastDbg = now
                dbg("fear seen, but Berserker Rage is not ready (cooldown/GCD)")
            end
            return
        end

        fearReason = feared and "broke" or "prevented"

        if BERSERKER_RAGE_STANCES[s] then
            dbg("Berserker Rage!")
            CastSpellByName("Berserker Rage")
            fearPrevStance = nil
            fearState = "raging"
            fearStateTime = now
        else
            dbg("Fear: switching to Berserker Stance (from " .. tostring(s) .. ")")
            fearPrevStance = s
            CastSpellByName(STANCE_NAMES[3])
            fearState = "switching"
            fearStateTime = now
        end

    elseif fearState == "switching" then
        if BERSERKER_RAGE_STANCES[s] then
            dbg("Berserker Rage!")
            CastSpellByName("Berserker Rage")
            fearState = "raging"
            fearStateTime = now
        elseif now - fearStateTime > 2 then
            dbg("Fear: stance switch failed, giving up")
            fearState = "idle"
            fearWarnUntil = 0
            fearAfflictedUntil = 0
            fearPrevStance = nil
        elseif now - fearLastTry > 0.3 then
            fearLastTry = now
            CastSpellByName(STANCE_NAMES[3])
        end

    elseif fearState == "raging" then
        if SpellOnRealCooldown("Berserker Rage") then
            if fearReason == "broke" then
                Say("Warrior broke fear successfully! (Berserker Rage)")
            else
                Say("Berserker Rage used - fear prevented.")
            end
            fearWarnUntil = 0
            fearAfflictedUntil = 0
            if fearPrevStance and fearPrevStance ~= s then
                dbg("Fear: returning to stance " .. tostring(fearPrevStance))
                CastSpellByName(STANCE_NAMES[fearPrevStance])
                fearState = "returning"
                fearStateTime = now
            else
                fearState = "idle"
            end
        elseif now - fearStateTime > 2 then
            dbg("Fear: Berserker Rage failed")
            fearWarnUntil = 0
            fearAfflictedUntil = 0
            if fearPrevStance and fearPrevStance ~= s then
                CastSpellByName(STANCE_NAMES[fearPrevStance])
                fearState = "returning"
                fearStateTime = now
            else
                fearState = "idle"
            end
        elseif now - fearLastTry > 0.3 then
            fearLastTry = now
            CastSpellByName("Berserker Rage")
        end

    elseif fearState == "returning" then
        if s == fearPrevStance or now - fearStateTime > 3 then
            fearState = "idle"
            fearPrevStance = nil
        elseif now - fearLastTry > 0.3 then
            fearLastTry = now
            CastSpellByName(STANCE_NAMES[fearPrevStance])
        end
    end
end

-- /sognetank fearstatus : prints everything the fear module sees
function Sognetank_FearStatus()
    local say = function(m) DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Sognetank status:|r " .. m) end
    local now = GetTime()
    say("fear module " .. (SOGNETANK_NOFEAR and "OFF (disabled)" or "ON") .. ", state=" .. tostring(fearState))
    say("stance (GetBonusBarOffset) = " .. tostring(GetBonusBarOffset()))
    say("afflicted flag seconds left = " .. string.format("%.1f", fearAfflictedUntil - now)
        .. ", warning seconds left = " .. string.format("%.1f", fearWarnUntil - now))

    local found = false
    for i = 1, 300 do
        local name = GetSpellName(i, "spell")
        if not name then break end
        if string.lower(name) == "berserker rage" then
            found = true
            local st, du = GetSpellCooldown(i, "spell")
            say("Berserker Rage in spellbook slot " .. i .. ", cooldown start=" .. tostring(st) .. " duration=" .. tostring(du))
        end
    end
    if not found then say("Berserker Rage NOT FOUND in spellbook!") end
    say("IsSpellReady(Berserker Rage) = " .. tostring(IsSpellReady("Berserker Rage")))

    local feared, fname, strong = PlayerIsFeared()
    say("PlayerIsFeared = " .. tostring(feared) .. ", debuff=" .. tostring(fname))

    local tip = GetScanTip()
    local n = 0
    for i = 1, 16 do
        local tex = UnitDebuff("player", i)
        if not tex then break end
        n = n + 1
        tip:ClearLines()
        tip:SetOwner(UIParent, "ANCHOR_NONE")
        tip:SetUnitDebuff("player", i)
        local l1 = getglobal("SognetankScanTipTextLeft1")
        local l2 = getglobal("SognetankScanTipTextLeft2")
        say("debuff " .. i .. ": " .. tostring(tex) .. " | " .. tostring(l1 and l1:GetText())
            .. " | " .. tostring(l2 and l2:GetText()))
    end
    if n == 0 then say("no debuffs on you right now") end
end

-- BigWigs hook (if BigWigs/Ace2 is present): any message containing "fear"
local bwHooked = false
local bwObj = {}
local function TryHookBigWigs()
    if bwHooked then return end
    if not AceLibrary or not AceLibrary.HasInstance then return end
    if not AceLibrary:HasInstance("AceEvent-2.0") then return end
    local ok = pcall(function()
        AceLibrary("AceEvent-2.0"):embed(bwObj)
        bwObj:RegisterEvent("BigWigs_Message", function(a, b)
            local msg = a
            if type(a) == "table" then msg = b end
            if type(msg) == "string" and string.find(string.lower(msg), "fear") then
                FearWarn("BigWigs: " .. msg)
            end
        end)
    end)
    if ok then
        bwHooked = true
        dbg("BigWigs hooked")
    end
end

local eventFrame = CreateFrame("Frame")

local logEvents = {
    "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF",
    "CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_PARTY_BUFF",
    "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE",
    "CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF",
    "CHAT_MSG_SPELL_HOSTILE_PLAYER_DAMAGE",
    "CHAT_MSG_SPELL_HOSTILE_PLAYER_BUFF",
}
for i = 1, table.getn(logEvents) do
    eventFrame:RegisterEvent(logEvents[i])
end
eventFrame:RegisterEvent("UNIT_CASTEVENT") -- SuperWoW (never fires otherwise)
eventFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
eventFrame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")  -- "You are afflicted by X."
eventFrame:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")        -- "X fades from you."
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function()
    if event == "UNIT_CASTEVENT" then
        local _, targetGuid = UnitExists("target")
        if targetGuid and arg1 == targetGuid then
            if arg3 == "START" or arg3 == "CHANNEL" then
                local dur = (arg5 and arg5 > 0) and (arg5 / 1000) or DEFAULT_CAST_WINDOW
                castUntil = GetTime() + dur
                castSourceName = UnitName("target")
                dbg("cast start (SuperWoW) " .. tostring(castSourceName))
            elseif arg3 == "CAST" or arg3 == "FAIL" then
                castUntil = 0
            end
        end
        return
    end

    if event == "VARIABLES_LOADED" then
        SognetankDB = SognetankDB or {}
        SognetankDB.learned = SognetankDB.learned or {}
        for name in pairs(SognetankDB.learned) do FEAR_SPELLS[name] = true end
        SognetankDB.opts = SognetankDB.opts or {}
        local keys = { "NOMSG", "NOCONSUME", "NOEMERGENCY", "NOTAUNT", "NOFEAR" }
        for i = 1, table.getn(keys) do
            local v = SognetankDB.opts[keys[i]]
            if v ~= nil then setglobal("SOGNETANK_" .. keys[i], v) end
        end
        return
    end

    if event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
        if arg1 then
            local _, _, n = string.find(arg1, "^You are afflicted by (.+)%.$")
            if n then OnAfflicted(n) end
        end
        return
    end

    if event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        if arg1 then
            local _, _, n = string.find(arg1, "^(.+) fades from you%.$")
            if n then OnFaded(n) end
        end
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        TryHookBigWigs()
        return
    end

    if event == "CHAT_MSG_RAID_WARNING" then
        if arg1 and string.find(string.lower(arg1), "fear") then
            FearWarn("raid warning: " .. arg1)
        end
        return
    end

    if arg1 then
        local _, _, aff = string.find(arg1, "^You are afflicted by (.+)%.$")
        if aff then OnAfflicted(aff) end

        local _, _, caster, spell = string.find(arg1, "^(.+) begins to cast (.+)%.$")
        if not caster then
            _, _, caster = string.find(arg1, "^(.+) begins to perform .+%.$")
        end
        if caster then
            castSourceName = caster
            castUntil = GetTime() + DEFAULT_CAST_WINDOW
            dbg("cast start (log) " .. caster)
            if spell then CheckFearCast(caster, spell) end
        end
    end
end)

-- Fear module driver (runs on its own, so it works even while you are feared)
local lastFearTick = 0
local lastEmTick = 0
local lastHookTry = 0
local hookStart = GetTime()
eventFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    if now - lastFearTick >= 0.1 then
        lastFearTick = now
        local ok, err = pcall(FearTick)
        if not ok then
            SOGNETANK_NOFEAR = true
            fearState = "idle"
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Sognetank fear module error (disabled):|r " .. tostring(err))
        end
    end
    if now - lastEmTick >= 0.1 then
        lastEmTick = now
        local ok2, err2 = pcall(EmergencyTick)
        if not ok2 then
            SOGNETANK_NOEMERGENCY = true
            SOGNETANK_NOCONSUME = true
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Sognetank emergency module error (disabled):|r " .. tostring(err2))
        end
        ProcessAnnounce()
    end
    if not bwHooked and now - lastHookTry >= 3 and now - hookStart < 180 then
        lastHookTry = now
        TryHookBigWigs()
    end
end)

-- --------------------------------------------------------
-- Shared actions
-- --------------------------------------------------------

-- Interrupt: Pummel (Berserker) / Shield Bash (Battle, Defensive + shield).
-- Never ends the rotation.
local function TryInterrupt(s, rage)
    if not UnitExists("target") or not UnitCanAttack("player", "target") then return end
    if not TargetIsCasting() then return end

    if PUMMEL_STANCES[s] and rage >= 10 and IsSpellReady("Pummel") then
        dbg("Pummel!")
        CastSpellByName("Pummel")
        castUntil = 0
        return
    end

    if SHIELD_BASH_STANCES[s] and rage >= 10 and HasShieldEquipped() and IsSpellReady("Shield Bash") then
        dbg("Shield Bash!")
        CastSpellByName("Shield Bash")
        castUntil = 0
        return
    end
end

-- Taunt / Mocking Blow when the target is no longer attacking you.
-- Returns true if a taunt-type spell was cast.
local function TryTaunt(s, rage)
    if SOGNETANK_NOTAUNT then return false end
    if not UnitAffectingCombat("player") then return false end
    if not UnitExists("target") or not UnitCanAttack("player", "target") then return false end
    if UnitIsPlayer("target") then return false end            -- taunts only work on NPCs
    if not UnitExists("targettarget") then return false end    -- target has no target (leashing etc.)
    if UnitIsUnit("targettarget", "player") then return false end -- you still have threat

    if TAUNT_STANCES[s] and IsSpellReady("Taunt") then
        dbg("Taunt!")
        CastSpellByName("Taunt")
        Announce("Taunt", "Taunt used - target had turned away from you")
        return true
    end

    if MOCKING_BLOW_STANCES[s] and rage >= 10 and IsSpellReady("Mocking Blow") then
        dbg("Mocking Blow!")
        CastSpellByName("Mocking Blow")
        Announce("Mocking Blow", "Mocking Blow used - target had turned away from you")
        return true
    end

    return false
end

-- Common start: targeting, auto-attack. Returns stance + rage, or nil to abort.
local function Prepare()
    -- run the fear module right now too (also visible if it errors), then
    -- pause the rotation while it is switching stances
    if not SOGNETANK_NOFEAR then FearTick() end
    if fearState ~= "idle" then return nil end

    if not UnitExists("target") or UnitIsDead("target") or UnitHealth("target") <= 0 then
        ClearTarget()
        TargetNearestEnemy()
        if not UnitExists("target") or UnitIsDead("target") then return nil end
    end

    if not PlayerFrame.inCombat and not UnitAffectingCombat("player") then
        AttackTarget()
    end

    -- 1 = Battle, 2 = Defensive, 3 = Berserker
    local s = GetBonusBarOffset()
    local rage = UnitMana("player") or 0
    return s, rage
end

local function TryShieldBlock(s, rage)
    if SHIELD_BLOCK_STANCES[s] and rage >= 10 and UnitAffectingCombat("player")
       and HasShieldEquipped() and IsSpellReady("Shield Block") then
        CastSpellByName("Shield Block")
        return true
    end
    return false
end

local function TryExecute(s, rage)
    if (s == 1 or s == 3) and UnitHealth("target") and UnitHealthMax("target") then
        local healthPct = UnitHealth("target") / UnitHealthMax("target") * 100
        if healthPct <= 20 and rage >= 15 and IsSpellReady("Execute") then
            CastSpellByName("Execute")
            return true
        end
    end
    return false
end

-- --------------------------------------------------------
-- Single-target rotation
-- --------------------------------------------------------
function furyTank()
    local s, rage = Prepare()
    if not s then return end

    -- 1. Interrupt (does not stop the rotation)
    TryInterrupt(s, rage)

    -- 2. Taunt / Mocking Blow if target lost aggro
    if TryTaunt(s, rage) then return end

    -- 3. Shield Block (Defensive)
    if TryShieldBlock(s, rage) then return end

    -- 4. Battle Shout
    if not HasBattleShout() and rage >= 10 and IsSpellReady("Battle Shout") then
        CastSpellByName("Battle Shout")
        return
    end

    -- 5. Execute
    if TryExecute(s, rage) then return end

    -- 6. Shield Slam
    if rage >= 20 and IsSpellReady("Shield Slam") then
        CastSpellByName("Shield Slam")
        return
    end

    -- 7. Concussion Blow
    if rage >= 15 and IsSpellReady("Concussion Blow") then
        CastSpellByName("Concussion Blow")
        return
    end

    -- 9. Whirlwind (Berserker only)
    if s == 3 and rage >= 30 and IsSpellReady("Whirlwind") then
        CastSpellByName("Whirlwind")
        return
    end

    -- 10. Cleave rage dump
    if rage >= RAGE_CLEAVE_SINGLE then
        CastSpellByName("Cleave")
        return
    end

    -- 11. Sunder Armor filler
    if rage >= 10 and math.random(1, 6) == 1 then
        CastSpellByName("Sunder Armor")
        return
    end
end

-- --------------------------------------------------------
-- AOE rotation
-- --------------------------------------------------------
function furyTankAoe()
    local s, rage = Prepare()
    if not s then return end

    -- 1. Interrupt
    TryInterrupt(s, rage)

    -- 2. Taunt / Mocking Blow if target lost aggro
    if TryTaunt(s, rage) then return end

    -- 3. Shield Block (Defensive)
    if TryShieldBlock(s, rage) then return end

    -- 4. Battle Shout
    if not HasBattleShout() and rage >= 10 and IsSpellReady("Battle Shout") then
        CastSpellByName("Battle Shout")
        return
    end

    -- 5. Thunder Clap (top AOE threat, Battle + Defensive)
    if THUNDER_CLAP_STANCES[s] and rage >= RAGE_THUNDER_CLAP and IsSpellReady("Thunder Clap") then
        CastSpellByName("Thunder Clap")
        return
    end

    -- 6. Demoralizing Shout (1-in-N roll, skipped if target already has it)
    if DEMO_SHOUT_STANCES[s] and rage >= RAGE_DEMO_SHOUT
       and math.random(1, DEMO_SHOUT_CHANCE) == 1
       and not TargetHasDemoShout() and IsSpellReady("Demoralizing Shout") then
        CastSpellByName("Demoralizing Shout")
        return
    end

    -- 7. Whirlwind (Berserker only, hits everything)
    if s == 3 and rage >= 30 and IsSpellReady("Whirlwind") then
        CastSpellByName("Whirlwind")
        return
    end

    -- 8. Shield Slam
    if rage >= 20 and IsSpellReady("Shield Slam") then
        CastSpellByName("Shield Slam")
        return
    end

    -- 9. Execute
    if TryExecute(s, rage) then return end

    -- 10. Concussion Blow
    if rage >= 15 and IsSpellReady("Concussion Blow") then
        CastSpellByName("Concussion Blow")
        return
    end

    -- 12. Cleave (lower threshold than single target)
    if rage >= RAGE_CLEAVE_AOE then
        CastSpellByName("Cleave")
        return
    end

    -- 13. Sunder Armor filler
    if rage >= 10 and math.random(1, 6) == 1 then
        CastSpellByName("Sunder Armor")
        return
    end
end

-- --------------------------------------------------------
DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Sognetank:|r loaded. Use /sognetank (single) or /sogneaoe (AOE).")
