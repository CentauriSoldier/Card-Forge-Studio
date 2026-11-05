local _wx     = require("wx");
local _Input  = require("wxLuma.Core.ControlInput");
local _Events = require("wxLuma.Core.ControlEvents");
local ToggleButton = {};

--[[!
@fqxn wxLuma.UI.ToggleButton.create
@desc Creates a persistent boolean button. Mouse, Enter and Space toggle once
    on release. Programmatic setters notify only when explicitly requested.
@param wxWindow oParent Native owner.
@param table tOptions Skin; optional Text, Value (false), Enabled, Artwork
    (Toggle Button), OnChange(value, component).
@ret table oComponent Independent actual/decoy button with shared input/containment.
!]]
function ToggleButton.create(oParent, tOptions)
    assert(tOptions and tOptions.Skin, "ToggleButton requires Skin.");
    assert(tOptions.Value == nil or type(tOptions.Value) == "boolean", "Value must be boolean.");
    local sArtwork = tOptions.Artwork or "Toggle Button";
    local tEvents;
    local oComponent = _Input.create(oParent, tOptions, "ToggleButton", function(oButton, tInput)
        oButton.Value = tOptions.Value == true;
        oButton.Skin  = tOptions.Skin;
        tInput.Toggle, tInput.Enter = true, true;

        --[[!
        @fqxn wxLuma.UI.ToggleButton.isEnabled
        @desc Reports whether the button is alive and accepts input.
        @ret boolean bEnabled Current availability.
        !]]
        oButton.isEnabled = tInput.enabled;

        --[[!
        @fqxn wxLuma.UI.ToggleButton.setValue
        @desc Stores a boolean without changing transient press state. Identical
            values preserve cached artwork and produce no notification.
        @param boolean bValue Persistent selected state.
        @param boolean|nil bNotify Emit valueChanged and OnChange after a change.
        @ret table oComponent This public object.
        !]]
        function oButton.setValue(bValue, bNotify)
            assert(type(bValue) == "boolean", "ToggleButton value must be boolean.");
            assert(not oButton.Disposed, "ToggleButton is disposed.");
            local bOld = oButton.Value;

            if (bOld ~= bValue) then
                oButton.Value = bValue;
                tInput.refresh();

                if (bNotify) then
                    tEvents.emit("valueChanged", {Value = bValue, OldValue = bOld});
                    if (oButton.OnChange) then
                        oButton.OnChange(bValue, oButton);
                    end
                end
            end
            return oButton;
        end

        -- Reuse capture cancellation and key-repeat handling from ControlInput.
        tInput.activate = function()
            oButton.setValue(not oButton.Value, true);
        end;
        tInput.draw = function(oDC, nWidth, nHeight, sState)
            local sName = sArtwork..(oButton.Value and " On " or " Off ")..sState;
            tInput.drawPart(oDC, sName, 0, 0, math.max(1, nWidth), math.max(1, nHeight));
            oDC:SetFont(oButton.Skin.Font);
            local nTextWidth, nTextHeight = oDC:GetTextExtent(oButton.Text);
            local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(4, 2,
                math.max(1, nWidth - 8), math.max(1, nHeight - 4)));
            oButton.Skin.text(oDC, oButton.Text, (nWidth - nTextWidth) / 2,
                (nHeight - nTextHeight) / 2, tInput.enabled());
            oClip:delete();
        end;
    end);

    -- Observe native input after policy handlers so both paths receive events.
    tEvents = _Events.attach(oComponent);
    return oComponent;
end

return ToggleButton;
