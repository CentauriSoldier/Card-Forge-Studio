local ControlSelection = {};

--[[!
@fqxn wxLuma.UI.ControlSelection.copy
@desc Returns an independent selection array for getters and event payloads.
@param table tValues Ordered row identifiers.
@ret table tCopy Independent identifiers.
!]]
function ControlSelection.copy(tValues)
    local tCopy = {};

    for nIndex, vValue in ipairs(tValues) do
        tCopy[nIndex] = vValue;
    end

    return tCopy;
end

--[[!
@fqxn wxLuma.UI.ControlSelection.same
@desc Compares membership independently of display order after sorting.
@param table tLeft First selection.
@param table tRight Second selection.
@ret boolean bSame Whether both contain the same identifiers.
!]]
function ControlSelection.same(tLeft, tRight)
    if (#tLeft ~= #tRight) then
        return false;
    end

    local tSet = {};

    for _, vValue in ipairs(tLeft) do
        tSet[vValue] = true;
    end

    for _, vValue in ipairs(tRight) do
        if (not tSet[vValue]) then
            return false;
        end
    end

    return true;
end

--[[!
@fqxn wxLuma.UI.ControlSelection.validate
@desc Validates a dense array atomically and removes duplicate identifiers.
    Single-selection mode rejects more than one distinct row.
@param table tValues Requested identifiers; an empty array clears.
@param function fValid Tests whether an identifier belongs to the control.
@param boolean bMulti Whether multiple distinct rows are allowed.
@ret table tCopy Independent identifiers in request order.
!]]
function ControlSelection.validate(tValues, fValid, bMulti)
    assert(type(tValues) == "table", "Selected rows must be an array.");
    local tCopy, tSeen = {}, {};
    local nCount = #tValues;

    for vKey in pairs(tValues) do
        assert(type(vKey) == "number" and vKey % 1 == 0 and vKey >= 1
            and vKey <= nCount, "Selected rows must be a dense array.");
    end

    for nIndex = 1, nCount do
        local vValue = tValues[nIndex];
        assert(fValid(vValue), "Unknown selected row.");

        if (not tSeen[vValue]) then
            tSeen[vValue] = true;
            tCopy[#tCopy + 1] = vValue;
        end
    end

    assert(bMulti or #tCopy <= 1, "Enable multi-selection before selecting multiple rows.");
    return tCopy;
end

--[[!
@fqxn wxLuma.UI.ControlSelection.modifiers
@desc Reads platform command, Ctrl/Meta and Shift keys from a borrowed wx event.
@param wxEvent jEvent Current input event.
@ret table tModifiers Shift and Command flags for shared input routing.
!]]
function ControlSelection.modifiers(jEvent)
    return {
        Shift = jEvent:ShiftDown(),
        Command = jEvent:CmdDown() or jEvent:ControlDown() or jEvent:MetaDown()
    };
end

return ControlSelection;
