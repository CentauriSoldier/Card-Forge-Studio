--[[!
@fqxn CardForgeEngine.Input.KeyBindings
@desc Resolves configurable shortcuts by context. User INI files contain data
    only. Missing and invalid overrides leave the corresponding defaults in place.
@example
    [GameRoom]
    TopView=Ctrl+T
    PanLeft=Shift+A
    ZoomOut=Minus,NumSubtract
    OrbitUp=None
!]]
local _wx = require("wx");
local _tDefaults = {
    GameRoom = {
        TopView = "Home",
        OrbitLeft = "Left", OrbitRight = "Right", OrbitUp = "Up", OrbitDown = "Down",
        PanLeft = "Shift+Left", PanRight = "Shift+Right", PanUp = "Shift+Up", PanDown = "Shift+Down",
        ZoomIn = "Plus,Shift+Plus,Shift+Equals,NumAdd,Add",
        ZoomOut = "Minus,NumSubtract,Subtract",
    },
};
local _tModifiers = {shift = 1, ctrl = 2, alt = 4, meta = 8};
local _tKeys = {
    home = _wx.WXK_HOME, ["end"] = _wx.WXK_END,
    left = _wx.WXK_LEFT, right = _wx.WXK_RIGHT, up = _wx.WXK_UP, down = _wx.WXK_DOWN,
    pageup = _wx.WXK_PAGEUP, pagedown = _wx.WXK_PAGEDOWN,
    escape = _wx.WXK_ESCAPE, space = _wx.WXK_SPACE, enter = _wx.WXK_RETURN,
    plus = string.byte("+"), minus = string.byte("-"), equals = string.byte("="),
    numadd = _wx.WXK_NUMPAD_ADD, numsubtract = _wx.WXK_NUMPAD_SUBTRACT,
    add = _wx.WXK_ADD, subtract = _wx.WXK_SUBTRACT,
};
for nIndex = 1, 12 do _tKeys["f"..nIndex] = _wx["WXK_F"..nIndex]; end
local KeyBindings = {};

--[[!
@fqxn CardForgeEngine.Input.KeyBindings.parse
@desc Parses one or more modifier/key chords into exact lookup signatures.
!]]
local function parse(sBinding)
    if (string.trim(sBinding):lower() == "none") then return {}; end

    local tChords, tSeen = {}, {};
    for sChord in (sBinding..","):gmatch("(.-),") do
        local nModifiers, nKey = 0, nil;
        for sPart in (sChord.."+"):gmatch("(.-)%+") do
            local sToken = string.trim(sPart):lower();
            local nModifier = _tModifiers[sToken];

            if (nKey) then return nil; end
            if (nModifier) then
                if ((nModifiers & nModifier) ~= 0) then return nil; end
                nModifiers = nModifiers | nModifier;
            else
                nKey = _tKeys[sToken] or (#sToken == 1 and sToken:match("^[a-z0-9]$") and sToken:upper():byte());
                if (not nKey) then return nil; end
            end
        end

        if (not nKey) then return nil; end
        local sKey = math.tointeger(nKey)..":"..nModifiers;
        if (tSeen[sKey]) then return nil; end

        tSeen[sKey] = true;
        tChords[#tChords + 1] = {Key = sKey, Label = string.trim(sChord)};
    end
    return tChords;
end

--[[!
@fqxn CardForgeEngine.Input.KeyBindings.compileContext
@desc Applies valid overrides together. Conflicting entries are restored to
    defaults, including any conflict introduced by another entry falling back.
!]]
local function compileContext(sContext, tDefaults, oIni, tIssues)
    local tBase, tOverrides = {}, {};
    for sAction, sDefault in pairs(tDefaults) do tBase[sAction] = assert(parse(sDefault)); end

    if (oIni) then
        for _, sAction in ipairs(oIni.GetValueNames(sContext)) do
            if (not tBase[sAction]) then
                tIssues[#tIssues + 1] = sContext.."."..sAction.." is not a recognized action.";
            else
                local tChords = parse(oIni.GetValue(sContext, sAction));
                if (tChords) then
                    tOverrides[sAction] = tChords;
                else
                    tIssues[#tIssues + 1] = sContext.."."..sAction.." has an invalid shortcut. The default was kept.";
                end
            end
        end
    end

    repeat
        local tActions, tLabels, tConflicts = {}, {}, {};
        for sAction, tFallback in pairs(tBase) do
            local tChords = tOverrides[sAction] or tFallback;
            local tActionLabels = {};
            for _, tChord in ipairs(tChords) do
                local sOther = tActions[tChord.Key];

                if (sOther) then
                    assert(tOverrides[sAction] or tOverrides[sOther], "Conflicting default keybindings.");
                    if (tOverrides[sAction]) then tConflicts[sAction] = true; end
                    if (tOverrides[sOther]) then tConflicts[sOther] = true; end
                else
                    tActions[tChord.Key] = sAction;
                end

                tActionLabels[#tActionLabels + 1] = tChord.Label;
            end
            tLabels[sAction] = table.concat(tActionLabels, " / ");
        end

        if (not next(tConflicts)) then return tActions, tLabels; end

        for sAction in pairs(tConflicts) do
            tOverrides[sAction] = nil;
            tIssues[#tIssues + 1] = sContext.."."..sAction.." conflicts with another shortcut. The default was kept.";
        end
    until false
end

--[[!
@fqxn CardForgeEngine.Input.KeyBindings.fromIni
@desc Builds a shortcut profile from optional INI text and returns its diagnostics.
@param string|nil sText User configuration, or nil for defaults.
@ret table Binding profile exposing resolve and getLabel.
@ret table Independent diagnostic messages.
!]]
function KeyBindings.fromIni(sText)
    local oIni;
    local tIssues, tContexts, tLabels = {}, {}, {};

    if (sText ~= nil) then
        local bOK, vResult = pcall(LuaEx.Classes.Ini, sText);
        if (bOK) then
            oIni = vResult;
        else
            tIssues[#tIssues + 1] = "Unable to read keybinding settings: "..tostring(vResult);
        end
    end

    for sContext, tDefaults in pairs(_tDefaults) do
        tContexts[sContext], tLabels[sContext] = compileContext(sContext, tDefaults, oIni, tIssues);
    end
    table.sort(tIssues);

    local Profile = {};

    --[[!
    @fqxn CardForgeEngine.Input.KeyBindings.resolve
    @desc Resolves a wx key event in one context with exact modifier matching.
    !]]
    function Profile.resolve(sContext, jEvent)
        local tActions = tContexts[sContext];
        if (not tActions) then return; end

        local nKey = math.tointeger(jEvent:GetKeyCode());
        if (not nKey) then return; end
        if (nKey >= 97 and nKey <= 122) then nKey = nKey - 32; end

        local nModifiers = (jEvent:ShiftDown() and 1 or 0) + (jEvent:ControlDown() and 2 or 0)
            + (jEvent:AltDown() and 4 or 0) + (jEvent:MetaDown() and 8 or 0);
        return tActions[nKey..":"..nModifiers];
    end

    --[[!
    @fqxn CardForgeEngine.Input.KeyBindings.getLabel
    @desc Returns the assigned chord labels, empty for a disabled action.
    !]]
    function Profile.getLabel(sContext, sAction)
        return tLabels[sContext] and tLabels[sContext][sAction];
    end

    return Profile, tIssues;
end

--[[!
@fqxn CardForgeEngine.Input.KeyBindings.load
@desc Loads ~/Card Forge Engine/KeyBindings.ini unless a path is supplied.
    An absent file is normal and does not create a directory or file.
@param string|nil pFile Optional path for an alternate profile.
@ret table Effective binding profile.
@ret table Diagnostic messages for invalid or unreadable overrides.
!]]
function KeyBindings.load(pFile)
    pFile = pFile or io.getuserdir():gsub("[/\\]+$", "").."/Card Forge Engine/KeyBindings.ini";
    local bFile, sReason, nCode = io.isfile(pFile);

    if (not bFile) then
        local Profile, tIssues = KeyBindings.fromIni();
        if (nCode ~= 2 and nCode ~= 3) then
            tIssues[1] = "Cannot read "..pFile..": "..tostring(sReason or "expected a file");
        end
        return Profile, tIssues;
    end

    local hFile, sOpenError = io.open(pFile, "rb");
    local sText, sReadError;
    if (hFile) then
        sText, sReadError = hFile:read(65537);
        hFile:close();
        if (sText == nil and not sReadError) then sText = ""; end
    end

    if (sText and #sText <= 65536) then
        return KeyBindings.fromIni((sText:gsub("^\239\187\191", "")));
    end

    local Profile, tIssues = KeyBindings.fromIni();
    tIssues[1] = "Cannot read "..pFile..": "..tostring(sOpenError or sReadError or "file exceeds 64 KiB");
    return Profile, tIssues;
end

return KeyBindings;
