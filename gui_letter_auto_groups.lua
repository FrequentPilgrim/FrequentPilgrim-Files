 function widget:GetInfo()
    return {
        name      = "Letter UnitType Multi Auto Groups",
        desc      = "Assign multiple unit types to letter groups, select/add/filter units with modifiers, persistent across matches. Open Debug Panel to see results (f8). alt + Space + Letter = assign units. space + letter = select units. backspace + space + letter = clear group. shift + space + letter = add group to selection. Ctrl + space + letter = filter from current selection instead of globally.",
        author    = "FrequentPilgrim",
        date      = "2025-06-01",
        license   = "GNU GPL v2",
        layer     = 0,
        enabled   = true
    }
end

local assignedGroups = {} -- letter -> set of unitDefNames { [unitDefName] = true, ... }
local keycodeToLetter = {}
local backspaceKey = Spring.GetKeyCode("backspace")
local backspaceDown = false

-- Fill keycodeToLetter for letters A-Z
for i = 65, 90 do -- ASCII A-Z
    local ch = string.char(i)
    keycodeToLetter[Spring.GetKeyCode(ch:lower())] = ch
end

local function ShowMessage(msg)
    Spring.Echo("[LetterUnitTypeGroups] " .. msg)
end

local function AssignLetterGroup(letter)
    local selUnits = Spring.GetSelectedUnits()
    if #selUnits == 0 then
        ShowMessage("No units selected to assign group " .. letter)
        return
    end

    assignedGroups[letter] = assignedGroups[letter] or {}
    local addedCount = 0
    for _, unitID in ipairs(selUnits) do
        local udid = Spring.GetUnitDefID(unitID)
        if udid then
            local defName = UnitDefs[udid].name
            if defName and not assignedGroups[letter][defName] then
                assignedGroups[letter][defName] = true
                addedCount = addedCount + 1
            end
        end
    end

    if addedCount > 0 then
        ShowMessage("Added " .. addedCount .. " unit types to group " .. letter)
    else
        ShowMessage("No new unit types added to group " .. letter)
    end
end

local function ClearLetterGroup(letter)
    if assignedGroups[letter] then
        assignedGroups[letter] = nil
        ShowMessage("Cleared group " .. letter)
    else
        ShowMessage("Group " .. letter .. " is not assigned")
    end
end

local function GetUnitsInGroup(letter)
    local defNameSet = assignedGroups[letter]
    if not defNameSet then return {} end

    local myTeam = Spring.GetMyTeamID()
    local units = Spring.GetTeamUnits(myTeam)
    local toSelect = {}
    for _, unitID in ipairs(units) do
        local udid = Spring.GetUnitDefID(unitID)
        if udid then
            local defName = UnitDefs[udid].name
            if defNameSet[defName] then
                table.insert(toSelect, unitID)
            end
        end
    end
    return toSelect
end

local function SelectLetterGroup(letter)
    local toSelect = GetUnitsInGroup(letter)
    if #toSelect == 0 then
        ShowMessage("No alive units of group " .. letter)
        return
    end
    Spring.SelectUnitArray(toSelect, false)
    ShowMessage("Selected " .. #toSelect .. " units from group " .. letter)
end

local function AddToSelection(letter)
    local toSelect = GetUnitsInGroup(letter)
    if #toSelect == 0 then
        ShowMessage("No units to add from group " .. letter)
        return
    end
    Spring.SelectUnitArray(toSelect, true)
    ShowMessage("Added " .. #toSelect .. " units from group " .. letter)
end

local function FilterSelection(letter)
    local current = Spring.GetSelectedUnits()
    if #current == 0 then return end

    local defNameSet = assignedGroups[letter]
    if not defNameSet then
        ShowMessage("Group " .. letter .. " not assigned")
        return
    end

    local filtered = {}
    for _, unitID in ipairs(current) do
        local udid = Spring.GetUnitDefID(unitID)
        if udid then
            local defName = UnitDefs[udid].name
            if defNameSet[defName] then
                table.insert(filtered, unitID)
            end
        end
    end

    Spring.SelectUnitArray(filtered, false)
    ShowMessage("Filtered selection to " .. #filtered .. " units in group " .. letter)
end

function widget:KeyPress(key, mods, isRepeat)
    if key == backspaceKey then
        backspaceDown = true
        return false
    end

    local letter = keycodeToLetter[key]
    if not letter or not mods.meta then return false end

    if backspaceDown then
        ClearLetterGroup(letter)
        return true
    elseif mods.alt then
        AssignLetterGroup(letter)
        return true
    elseif mods.shift then
        AddToSelection(letter)
        return true
    elseif mods.ctrl then
        FilterSelection(letter)
        return true
    else
        SelectLetterGroup(letter)
        return true
    end
end

function widget:KeyRelease(key)
    if key == backspaceKey then
        backspaceDown = false
    end
end

function widget:GetConfigData()
    local saved = {}
    for letter, defSet in pairs(assignedGroups) do
        saved[letter] = {}
        for defName in pairs(defSet) do
            table.insert(saved[letter], defName)
        end
    end
    return saved
end

function widget:SetConfigData(data)
    if type(data) == "table" then
        assignedGroups = {}
        for letter, defList in pairs(data) do
            assignedGroups[letter] = {}
            for _, defName in ipairs(defList) do
                assignedGroups[letter][defName] = true
            end
        end
        Spring.Echo("[LetterUnitTypeGroups] Loaded saved groups")
    end
end
