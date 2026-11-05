local _wx     = require("wx");
local _Input  = require("wxLuma.Core.ControlInput");
local _Events = require("wxLuma.Core.ControlEvents");
local _Artwork = require("wxLuma.Core.ControlArtwork");
local Switch = {};

--[[!
@fqxn wxLuma.UI.Switch.create
@desc Creates a binary lever. Horizontal on points right; vertical on points up.
    Reversed swaps physical endpoints without changing the boolean value. Skin
    families follow Orientation and Reversed automatically, including at runtime.
@param table tOptions Skin; Value false; Orientation horizontal/vertical;
    Reversed false; Text (empty); Artwork Switch; OnChange(value, component).
!]]
function Switch.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "Switch requires Skin.");
    local sOrientation = tOptions.Orientation or (tOptions.Vertical and "vertical" or "horizontal");
    assert(sOrientation == "horizontal" or sOrientation == "vertical", "Invalid switch orientation.");
    assert(tOptions.Reversed == nil or type(tOptions.Reversed) == "boolean", "Reversed must be boolean.");
    assert(tOptions.Value == nil or type(tOptions.Value) == "boolean", "Value must be boolean.");
    local tEvents;
    local oComponent = _Input.create(oParent, tOptions, "Switch", function(oSwitch, tInput)
        local bReversed = tOptions.Reversed == true;
        local sArtwork = tOptions.Artwork or "Switch";
        local tArt = _Artwork.create(tOptions.Skin, sArtwork);
        oSwitch.Value = tOptions.Value == true;
        tInput.Toggle, tInput.Enter = true, true;
        -- Widget-owned materials replace shared fallback colors and focus.
        tInput.background = function(oDC, nWidth, nHeight, sState)
            tArt.part(oDC, "Surface "..sState, 0, 0, nWidth, nHeight);
        end;
        tInput.focus = function(oDC, nWidth, nHeight)
            tArt.part(oDC, "Focus", 0, 0, nWidth, nHeight);
        end;
        tInput.destroy = tArt.destroy;

        --[[!
        @fqxn wxLuma.UI.Switch.getOrientation
        @desc Returns horizontal or vertical; artwork selection uses this value.
        !]]
        function oSwitch.getOrientation() return sOrientation; end

        --[[!
        @fqxn wxLuma.UI.Switch.setOrientation
        @desc Cancels an active press and switches the entire artwork family.
            Layout bounds remain controlled by the application. Optional notify
            emits orientationChanged after an actual change; default is silent.
        !]]
        function oSwitch.setOrientation(sValue, bNotify)
            assert(not oSwitch.Disposed, "Switch is disposed.");
            assert(sValue == "horizontal" or sValue == "vertical", "Invalid switch orientation.");
            if (sValue ~= sOrientation) then
                local sOld = sOrientation;
                tInput.release();
                sOrientation = sValue;
                oSwitch.Vertical = sValue == "vertical";
                tInput.refresh();
                if (bNotify) then tEvents.emit("orientationChanged", {Orientation = sValue, OldOrientation = sOld}); end
            end
            return oSwitch;
        end

        --[[!
        @fqxn wxLuma.UI.Switch.getReversed
        @desc Reports whether physical on/off endpoints are reversed.
        !]]
        function oSwitch.getReversed() return bReversed; end

        --[[!
        @fqxn wxLuma.UI.Switch.setReversed
        @desc Reverses artwork and directional keys without changing Value.
            Optional notify emits reversedChanged after an actual change.
        !]]
        function oSwitch.setReversed(bValue, bNotify)
            assert(not oSwitch.Disposed, "Switch is disposed.");
            assert(type(bValue) == "boolean", "Reversed must be boolean.");
            if (bValue ~= bReversed) then
                local bOld = bReversed;
                tInput.release();
                bReversed = bValue;
                tInput.refresh();
                if (bNotify) then tEvents.emit("reversedChanged", {Reversed = bValue, OldReversed = bOld}); end
            end
            return oSwitch;
        end

        --[[!
        @fqxn wxLuma.UI.Switch.setValue
        @desc Stores a boolean; optional notification emits valueChanged and
            OnChange once after an actual change. Omitted notification is silent.
        !]]
        function oSwitch.setValue(bValue, bNotify)
            assert(not oSwitch.Disposed, "Switch is disposed.");
            assert(type(bValue) == "boolean", "Switch value must be boolean.");
            local bOld = oSwitch.Value;
            if (bOld ~= bValue) then
                oSwitch.Value = bValue;
                tInput.refresh();
                if (bNotify) then
                    tEvents.emit("valueChanged", {Value = bValue, OldValue = bOld});
                    tInput.notify();
                end
            end
            return oSwitch;
        end

        -- Directional keys select the endpoint they visually point toward.
        tInput.key = function(nKey)
            local bForward, bBackward;
            if (sOrientation == "horizontal") then
                bForward, bBackward = nKey == _wx.WXK_RIGHT, nKey == _wx.WXK_LEFT;
            else
                bForward, bBackward = nKey == _wx.WXK_UP, nKey == _wx.WXK_DOWN;
            end
            if (bForward or bBackward) then
                oSwitch.setValue(bForward ~= bReversed, true);
                return true;
            end
            return false;
        end;
        tInput.activate = function() oSwitch.setValue(not oSwitch.Value, true); end;
        tInput.draw = function(oDC, nWidth, nHeight, sState)
            local sFamily = sArtwork..(sOrientation == "vertical" and " Vertical" or " Horizontal")
                ..(bReversed and " Reversed" or " Standard");
            -- Contain the artwork so a direction change never stretches a lever.
            local nScale = math.min(nWidth / (sOrientation == "vertical" and 48 or 112),
                nHeight / (sOrientation == "vertical" and 112 or 48));
            local nW = math.max(1, math.floor((sOrientation == "vertical" and 48 or 112) * nScale));
            local nH = math.max(1, math.floor((sOrientation == "vertical" and 112 or 48) * nScale));
            oSwitch.Skin.draw(oDC, sFamily..(oSwitch.Value and " On " or " Off ")..sState,
                math.floor((nWidth - nW) / 2), math.floor((nHeight - nH) / 2), nW, nH);
            if (oSwitch.Text ~= "") then
                -- Captions are application text, never baked into artwork.
                -- Keep them upright when the switch changes orientation.
                oDC:SetFont(oSwitch.Skin.Font);
                local nTextWidth, nTextHeight = oDC:GetTextExtent(oSwitch.Text);
                local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, math.max(1, nWidth), math.max(1, nHeight)));
                tArt.text(oDC, oSwitch.Text, math.floor((nWidth - nTextWidth) / 2),
                    math.floor((nHeight - nTextHeight) / 2), tInput.enabled());
                oClip:delete();
            end
        end;
        oSwitch.Skin = tOptions.Skin;
        oSwitch.Vertical = sOrientation == "vertical";
    end);
    tEvents = _Events.attach(oComponent, nil, {"orientationChanged", "reversedChanged"});
    return oComponent;
end

return Switch;
