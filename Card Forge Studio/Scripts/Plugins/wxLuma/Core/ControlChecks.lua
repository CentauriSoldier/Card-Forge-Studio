local ControlChecks = {};

--[[!
@fqxn wxLuma.UI.ControlChecks.attach
@desc Installs independent checkbox state on a visual component. The adapter
    supplies ordered keys, validation, row refresh and event identity snapshots.
    Visibility defaults off; hiding checkboxes never erases their stored state.
@param table oComponent Public component.
@param table tEvents Semantic event emitter.
@param table tOptions Checkboxes, Checked and optional OnCheckChange.
@param table tAdapter keys/valid/refresh/payload callbacks.
@ret table tChecks Private prune/remap/draw helpers.
!]]
function ControlChecks.attach(oComponent, tEvents, tOptions, tAdapter)
    assert(tOptions.Checkboxes == nil or type(tOptions.Checkboxes) == "boolean", "Checkboxes must be boolean.");
    local bEnabled = tOptions.Checkboxes == true;
    local tChecked = {};
    local tChecks = {};

    --[[!
    @fqxn wxLuma.UI.ControlChecks.getChecked
    @desc Returns checked item references in data order, including hidden tree nodes.
    @ret table tKeys Independent checked references.
    !]]
    function oComponent.getChecked()
        local tKeys = {};
        for _, vKey in ipairs(tAdapter.keys()) do
            if (tChecked[vKey]) then
                tKeys[#tKeys + 1] = vKey;
            end
        end
        return tKeys;
    end

    --[[!
    @fqxn wxLuma.UI.ControlChecks.isChecked
    @desc Returns one item's boolean check state independently of selection.
    @param number|string vKey Existing item reference.
    @ret boolean bChecked Current check state.
    !]]
    function oComponent.isChecked(vKey)
        assert(tAdapter.valid(vKey), "Unknown checkbox item.");
        return tChecked[vKey] == true;
    end

    --[[!
    @fqxn wxLuma.UI.ControlChecks.getCheckState
    @desc Returns the independent two-state checkbox value as a descriptive string.
    @param number|string vKey Existing item reference.
    @ret string sState checked or unchecked.
    !]]
    function oComponent.getCheckState(vKey)
        return oComponent.isChecked(vKey) and "checked" or "unchecked";
    end

    --[[!
    @fqxn wxLuma.UI.ControlChecks.fNotify
    @desc Publishes one completed state change with stable adapter identity.
    !]]
    local function fNotify(vKey, bOld, bNew)
        local tData = tAdapter.payload(vKey);
        tData.Checked, tData.OldChecked = bNew, bOld;
        tData.State = bNew and "checked" or "unchecked";
        tData.OldState = bOld and "checked" or "unchecked";
        tEvents.emit("checkChanged", tData);
        if (tOptions.OnCheckChange) then
            tOptions.OnCheckChange(vKey, bNew, oComponent);
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlChecks.setChecked
    @desc Changes one check state, even when checkboxes are hidden. Selection is
        unaffected. Identical values neither refresh nor notify.
    @param number|string vKey Existing item reference.
    @param boolean bChecked New state.
    @param boolean|nil bNotify Emit checkChanged and OnCheckChange after change.
    @ret table oComponent This object.
    !]]
    function oComponent.setChecked(vKey, bChecked, bNotify)
        assert(not oComponent.Disposed and tAdapter.valid(vKey) and type(bChecked) == "boolean", "Invalid checkbox update.");
        local bOld = tChecked[vKey] == true;
        if (bOld ~= bChecked) then
            tChecked[vKey] = bChecked or nil;
            tAdapter.refresh(vKey);
            if (bNotify) then
                fNotify(vKey, bOld, bChecked);
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlChecks.setCheckedItems
    @desc Atomically replaces checked membership. All references validate before
        mutation; per-item change events follow data order after the set is applied.
    @param table tKeys Dense array of existing item references.
    @param boolean|nil bNotify Notify each effective check change.
    @ret table oComponent This object.
    !]]
    function oComponent.setCheckedItems(tKeys, bNotify)
        assert(not oComponent.Disposed and type(tKeys) == "table", "Checked items must be an array.");
        local tNew, nCount = {}, 0;
        for nKey in pairs(tKeys) do
            nCount = nCount + 1;
            assert(type(nKey) == "number" and nKey % 1 == 0 and nKey >= 1 and nKey <= #tKeys,
                "Checked items must be a dense array.");
        end
        assert(nCount == #tKeys, "Checked items must be a dense array.");
        for _, vKey in ipairs(tKeys) do
            assert(tAdapter.valid(vKey), "Invalid checked item.");
            tNew[vKey] = true;
        end
        local tChanged = {};
        for _, vKey in ipairs(tAdapter.keys()) do
            local bOld, bNew = tChecked[vKey] == true, tNew[vKey] == true;
            if (bOld ~= bNew) then
                tChanged[#tChanged + 1] = {Key = vKey, Old = bOld, New = bNew};
            end
        end
        tChecked = tNew;
        if (#tChanged > 0 and tAdapter.refreshMany) then
            tAdapter.refreshMany(tChanged);
        else
            for _, tChange in ipairs(tChanged) do
                tAdapter.refresh(tChange.Key);
            end
        end
        if (bNotify) then
            for _, tChange in ipairs(tChanged) do
                if (oComponent.Disposed or not tAdapter.valid(tChange.Key)) then
                    break;
                end
                fNotify(tChange.Key, tChange.Old, tChange.New);
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlChecks.isCheckboxesEnabled
    @desc Reports checkbox visibility/input policy; creation defaults to false.
    @ret boolean bEnabled Whether checkboxes are presented.
    !]]
    function oComponent.isCheckboxesEnabled()
        return bEnabled;
    end

    --[[!
    @fqxn wxLuma.UI.ControlChecks.setCheckboxesEnabled
    @desc Toggles checkbox presentation while preserving check/selection state.
    @param boolean bFlag Visibility/input policy.
    @param boolean|nil bNotify Emit checkboxesChanged after a change.
    @ret table oComponent This object.
    !]]
    function oComponent.setCheckboxesEnabled(bFlag, bNotify)
        assert(not oComponent.Disposed and type(bFlag) == "boolean", "Checkboxes flag must be boolean.");
        if (bEnabled ~= bFlag) then
            bEnabled = bFlag;
            oComponent.cancel();
            oComponent.refresh();
            if (bNotify) then
                tEvents.emit("checkboxesChanged", {Enabled = bEnabled});
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlChecks.prune
    @desc Drops state for removed data without reporting deletion as a user toggle.
    !]]
    function tChecks.prune()
        for vKey in pairs(tChecked) do
            if (not tAdapter.valid(vKey)) then
                tChecked[vKey] = nil;
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlChecks.remap
    @desc Moves index-keyed state after row deletion; nil destinations are removed.
    !]]
    function tChecks.remap(fMap)
        local tNew = {};
        for vKey in pairs(tChecked) do
            local vNew = fMap(vKey);
            if (vNew ~= nil) then
                tNew[vNew] = true;
            end
        end
        tChecked = tNew;
    end
    return tChecks;
end

return ControlChecks;
