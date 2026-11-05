local _ControlObject = require("wxLuma.Core.ControlObject");
local _wx            = require("wx");
local _ControlInput  = require("wxLuma.Core.ControlInput");
local Radio          = {};

-- Custom backgrounds can depend on external state, so preserve their explicit
-- redraws without exposing private rendering policy on the public component.
local _tDynamicBackgrounds = setmetatable({}, {__mode = "k"});

--[[!
@fqxn wxLuma.UI.Radio.group
@desc Holds an independent group. Selecting one member clears all others; clicking
      the selected member does not clear it. Arrow keys skip disabled members.
@ret table oGroup Group supplied in each radio's Group option; getValue returns selected Value or nil.
!]]

function Radio.group()
    local oGroup = _ControlObject.create({
        Members  = {},
        Selected = nil
    }, "wxLuma.UI.RadioGroup");

    --[[!
    @fqxn wxLuma.UI.RadioGroup.getValue
    @desc Returns the selected radio value, or nil when the group is unselected.
    @ret any vValue The current value.
    !]]
    function oGroup.getValue()
        return oGroup.Selected and oGroup.Selected.Value or nil;
    end

    --[[!
    @fqxn wxLuma.UI.RadioGroup.select
    @desc Selects one group member, clears the others and optionally notifies the newly selected radio.
    @param table oMember The radio to select.
    @param boolean|nil bNotify Whether to notify after a change; omitted means silent.
    !]]
    function oGroup.select(oMember, bNotify)
        local bChanged = oGroup.Selected ~= oMember;
        oGroup.Selected = oMember;
        for _, oOther in ipairs(oGroup.Members) do
            local bSelected = oOther == oMember;

            -- Preserve exclusivity while invalidating only members whose
            -- indicator actually changes, including repeated group selection.
            local bSelectionChanged = oOther.Selected ~= bSelected;

            if (bSelectionChanged) then
                oOther.Selected = bSelected;
            end

            if (bSelectionChanged or _tDynamicBackgrounds[oOther]) then
                oOther.Control:Refresh(false);
            end
        end
        if (bChanged and bNotify and oMember.OnChange) then
            oMember.OnChange(oMember.Value, oMember);
        end
    end
    return oGroup;
end

--[[!
@fqxn wxLuma.UI.Radio.create
@desc Creates a radio in the supplied group, with exclusive selection and arrow-key navigation.
@param wxWindow oParent Native parent.
@param table tOptions Checkbox options plus required Group and unique Value. OnChange receives selected
    group Value.
@ret table oComponent Radio component; user activation never deselects itself.
!]]

function Radio.create(oParent, tOptions)
    return _ControlInput.create(oParent, tOptions, "Radio", function(oComponent, tInput)
        local oSkin, oGroup = tOptions.Skin, tOptions.Group;
        tInput.Toggle = true;
        _tDynamicBackgrounds[oComponent] = tInput.DynamicBackground;

        --[[!
        @fqxn wxLuma.UI.Radio.getValue
        @desc Returns this radio selection flag; the group accessor returns the selected member value.
        @ret any vValue The current value.
        !]]
        function oComponent.getValue()
            return oComponent.Selected;
        end

        --[[!
        @fqxn wxLuma.UI.Radio.setValue
        @desc Selects this radio through its group, or explicitly clears it, preserving the existing
            notification contract.
        @param boolean bValue The requested selection.
        @param boolean|nil bNotify Whether to notify after a change; omitted means silent.
        @ret table oComponent This public component object.
        !]]
        function oComponent.setValue(bValue, bNotify)
            assert(type(bValue) == "boolean", "Radio selection must be boolean.");
            if (bValue) then
                oGroup.select(oComponent, bNotify);
                return oComponent;
            end
            if (oGroup.Selected == oComponent) then
                oGroup.Selected = nil;
            end
            local bChanged = oComponent.getValue() ~= bValue;
            oComponent.Selected = bValue;
            if (bChanged or tInput.DynamicBackground) then
                tInput.refresh();
            end

            if (bChanged and bNotify) then
                tInput.notify();
            end;
            return oComponent;
        end

        -- Apply user activation through the widget setter and notification path.
        tInput.activate = function()
            oGroup.select(oComponent, true);
        end;

        -- Handle the widget navigation or resize keys.
        tInput.key = function(nKey)
            if (nKey ~= _wx.WXK_LEFT and nKey ~= _wx.WXK_RIGHT and nKey ~= _wx.WXK_UP
                and nKey ~= _wx.WXK_DOWN) then
                return false;
            end
            local nCurrent;
            for nIndex, oMember in ipairs(oGroup.Members) do
                if (oMember == oComponent) then
                    nCurrent = nIndex;
                end
            end
            local nDirection = (nKey == _wx.WXK_LEFT or nKey == _wx.WXK_UP) and -1 or 1;
            for nOffset = 1, #oGroup.Members do
                local oNext = oGroup.Members[(nCurrent - 1 + nOffset * nDirection) % #oGroup.Members + 1];
                if (oNext.Control:IsEnabled()) then
                    oGroup.select(oNext, true);
                    oNext.Control:SetFocus();
                    break;
                end
            end
            return true;
        end;

        -- Draw artwork for the current value and input state.
        tInput.draw = function(oDC, nWidth, nHeight, sState)

            tInput.drawPart(oDC, "Radio" .. (oComponent.Selected and " On " or " Off ") .. sState, 0,
                math.floor((nHeight - 32) / 2));
            oSkin.text(oDC, oComponent.Text, 40, math.floor((nHeight - 18) / 2), tInput.enabled());

        end;

        -- Detach this radio from its group during disposal.
        tInput.destroy = function()
            _tDynamicBackgrounds[oComponent] = nil;
            if (oGroup.Selected == oComponent) then
                oGroup.Selected = nil;
            end
            for nIndex, oMember in ipairs(oGroup.Members) do
                if (oMember == oComponent) then
                    table.remove(oGroup.Members, nIndex);
                    break;
                end
            end
        end;
        assert(oGroup and oGroup.Members and type(oGroup.select) == "function",
            "Radio requires a Controls.radioGroup().");
        assert(oComponent.Value ~= nil, "Radio requires its group Value.");
        for _, oMember in ipairs(oGroup.Members) do
            assert(oMember.Value ~= oComponent.Value, "Radio values must be unique within a group.");
        end
        oGroup.Members[#oGroup.Members + 1] = oComponent;
        if (oComponent.Selected) then
            oGroup.select(oComponent, false);
        end
    end);
end
return Radio;
