local _copy = require("wxLuma.State").copy;
local ControlOptions = {};

--[[!
@fqxn wxLuma.UI.ControlOptions.same
@desc Compares acyclic normalized option/data records by value.
!]]
function ControlOptions.same(vLeft, vRight)
    if (type(vLeft) ~= "table" or type(vRight) ~= "table") then return vLeft == vRight; end
    for vKey, vValue in pairs(vLeft) do if (not ControlOptions.same(vValue, vRight[vKey])) then return false; end end
    for vKey in pairs(vRight) do if (vLeft[vKey] == nil) then return false; end end
    return true;
end

--[[!
@fqxn wxLuma.UI.ControlOptions.boolean
@desc Validates an explicit boolean setting, preserving false.
!]]
function ControlOptions.boolean(vValue)
    assert(type(vValue) == "boolean", "Setting must be boolean."); return vValue;
end

--[[!
@fqxn wxLuma.UI.ControlOptions.text
@desc Validates text, including empty strings and UTF-8 content.
!]]
function ControlOptions.text(vValue)
    assert(type(vValue) == "string" and utf8.len(vValue), "Setting must be valid UTF-8 text."); return vValue;
end

--[[!
@fqxn wxLuma.UI.ControlOptions.number
@desc Builds a finite bounded numeric validator, optionally requiring integers.
!]]
function ControlOptions.number(nMin, nMax, bInteger)
    return function(vValue)
        assert(type(vValue) == "number" and vValue == vValue and vValue >= nMin
            and vValue <= nMax and math.abs(vValue) < math.huge and (not bInteger or vValue % 1 == 0), "Invalid numeric setting.");
        return vValue;
    end;
end

--[[!
@fqxn wxLuma.UI.ControlOptions.enum
@desc Builds a validator for a documented set of string settings.
!]]
function ControlOptions.enum(tNames)
    local tSet = {}; for _, sName in ipairs(tNames) do tSet[sName] = true; end
    return function(vValue) assert(tSet[vValue], "Invalid setting: "..tostring(vValue)); return vValue; end;
end

--[[!
@fqxn wxLuma.UI.ControlOptions.array
@desc Requires a dense plain sequence rather than silently truncating sparse data.
!]]
function ControlOptions.array(tValue)
    assert(type(tValue) == "table" and getmetatable(tValue) == nil, "Expected a plain array.");
    local nKeys = 0;
    for vKey in pairs(tValue) do
        assert(type(vKey) == "number" and vKey % 1 == 0 and vKey >= 1 and vKey <= #tValue, "Expected a dense array.");
        nKeys = nKeys + 1;
    end
    assert(nKeys == #tValue, "Expected a dense array without holes.");
    return tValue;
end

--[[!
@fqxn wxLuma.UI.ControlOptions.create
@desc Installs independent get/set APIs for documented settings and an atomic
    aggregate setter. Validators return normalized plain data. Only known settings
    are copied from constructor options; aggregate setters reject unknown keys.
    Changed-only notifications follow mutation/layout and include old/new values.
@param string sGroup Aggregate suffix, for example ChartOptions or LogOptions.
@ret table tValues Private normalized settings; never expose this mutable table.
!]]
function ControlOptions.create(oComponent, tEvents, tDefaults, tValidators, tInitial, sGroup, fChanged, fValidate)
    local tValues, tNames = {}, {};
    for sName, vDefault in pairs(tDefaults) do
        local vInitial = tInitial[sName];
        if (vInitial == nil) then vInitial = vDefault; end
        tValues[sName] = tValidators[sName](_copy(vInitial));
        tNames[#tNames + 1] = sName;
    end
    table.sort(tNames);
    if (fValidate) then fValidate(tValues); end
    local tEventNames = {"optionsChanged"};
    for _, sName in ipairs(tNames) do tEventNames[#tEventNames + 1] = sName:sub(1, 1):lower()..sName:sub(2).."Changed"; end
    require("wxLuma.Core.ControlEvents").attach(oComponent, nil, tEventNames);

    --[[!
    @fqxn wxLuma.UI.ControlOptions.equal
    @desc Compares normalized option records without depending on table identity.
    !]]
    local function fEqual(vLeft, vRight)
        if (type(vLeft) ~= "table" or type(vRight) ~= "table") then return vLeft == vRight; end
        for sKey, vValue in pairs(vLeft) do if (not fEqual(vValue, vRight[sKey])) then return false; end end
        for sKey in pairs(vRight) do if (vLeft[sKey] == nil) then return false; end end
        return true;
    end

    --[[!
    @fqxn wxLuma.UI.ControlOptions.getOptions
    @desc Returns an independent plain snapshot of all settings in this group.
    !]]
    oComponent["get"..sGroup] = function() return _copy(tValues); end;

    --[[!
    @fqxn wxLuma.UI.ControlOptions.setOptions
    @desc Applies a partial settings record after validating every requested
        value. Optional notifications emit each property event and optionsChanged.
    !]]
    oComponent["set"..sGroup] = function(tNext, bNotify)
        assert(not oComponent.Disposed and type(tNext) == "table", "Invalid options or disposed control.");
        local tPrepared, tChanges = {}, {};
        for sName, vValue in pairs(tNext) do
            assert(tValidators[sName], "Unknown setting: "..tostring(sName));
            tPrepared[sName] = tValidators[sName](_copy(vValue));
        end
        if (fValidate) then
            local tMerged = _copy(tValues);
            for sName, vValue in pairs(tPrepared) do tMerged[sName] = vValue; end
            fValidate(tMerged);
        end
        for _, sName in ipairs(tNames) do
            if (tPrepared[sName] ~= nil and not fEqual(tValues[sName], tPrepared[sName])) then
                tChanges[#tChanges + 1] = {Property = sName, Value = _copy(tPrepared[sName]), OldValue = _copy(tValues[sName])};
            end
        end
        if (#tChanges > 0) then
            for _, tChange in ipairs(tChanges) do tValues[tChange.Property] = tPrepared[tChange.Property]; end
            if (fChanged) then fChanged(tChanges, bNotify); end
            oComponent.refresh();
            if (bNotify) then
                for _, tChange in ipairs(tChanges) do
                    local sName = tChange.Property;
                    tEvents.emit(sName:sub(1, 1):lower()..sName:sub(2).."Changed", _copy(tChange));
                end
                tEvents.emit("optionsChanged", {Changes = _copy(tChanges)});
            end
        end
        return oComponent;
    end;
    for _, sProperty in ipairs(tNames) do
        local sName = sProperty;
        --[[!
        @fqxn wxLuma.UI.ControlOptions.getSetting
        @desc Generated get<Property>() returns an independent normalized setting.
        !]]
        oComponent["get"..sName] = function() return _copy(tValues[sName]); end;
        --[[!
        @fqxn wxLuma.UI.ControlOptions.setSetting
        @desc Generated set<Property>(value, notify) uses the atomic settings path.
        !]]
        oComponent["set"..sName] = function(vValue, bNotify)
            local vNext = tValidators[sName](_copy(vValue));
            return oComponent["set"..sGroup]({[sName] = vNext}, bNotify);
        end;
    end
    return tValues;
end

return ControlOptions;
