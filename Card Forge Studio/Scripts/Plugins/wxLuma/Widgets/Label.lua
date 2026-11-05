local _wx             = require("wx");
local _ControlSurface = require("wxLuma.Core.ControlSurface");
local _ControlEvents  = require("wxLuma.Core.ControlEvents");
local Label           = {};

--[[!
@fqxn wxLuma.UI.Label.create
@desc Creates a plain text surface using the shared skin font. Explicit newlines
    are preserved; optional word wrapping clips words wider than the available
    width rather than splitting UTF-8 bytes. The parent owns the native control.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Value (string), Wrap, Padding (4), Align
    (left/center/right), VerticalAlign (top/center/bottom), Enabled and OnChange.
@ret table oComponent An independent public proxy with standard surface/events API.
!]]
function Label.create(oParent, tOptions)
    local sValue = tOptions.Value or "";
    local nPadding = tOptions.Padding or 4;
    assert(type(sValue) == "string", "Label Value must be a string.");
    assert(type(nPadding) == "number" and nPadding >= 0 and nPadding < math.huge
        and nPadding % 1 == 0, "Label Padding must be a nonnegative integer.");

    local oComponent = _ControlSurface.create(oParent, tOptions, "Label");
    local tEvents    = _ControlEvents.attach(oComponent);
    local oBrush     = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    local tLines, tWidths;
    local nCachedWidth, nLineHeight;
    local sAlign, sVerticalAlign;
    oComponent.Value = sValue;

    -- Rebuild only when text or available width changes. Native text measurement
    -- keeps wrapping consistent with the font used by the drawing pass.
    local function fLines(oDC, nWidth)
        oDC:SetFont(oComponent.Skin.Font);

        if (tLines and nCachedWidth == nWidth) then
            return;
        end

        tLines, tWidths = {}, {};
        nCachedWidth = nWidth;
        local nUnused;
        nUnused, nLineHeight = oDC:GetTextExtent("Ag");

        local function fAppend(sLine)
            tLines[#tLines + 1] = sLine;
            tWidths[#tWidths + 1] = oDC:GetTextExtent(sLine);
        end

        for sLine in (oComponent.Value.."\n"):gmatch("(.-)\n") do
            sLine = sLine:gsub("\r$", "");

            if (tOptions.Wrap and sLine:find("%S")) then
                local sCurrent = "";

                for sWord in sLine:gmatch("%S+") do
                    local sCandidate = sCurrent == "" and sWord or sCurrent.." "..sWord;
                    local nTextWidth = oDC:GetTextExtent(sCandidate);

                    if (sCurrent ~= "" and nTextWidth > nWidth) then
                        fAppend(sCurrent);
                        sCurrent = sWord;
                    else
                        sCurrent = sCandidate;
                    end
                end

                fAppend(sCurrent);
            else
                fAppend(sLine);
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.Label.setValue
    @desc Changes text, invalidates measured lines and optionally notifies once.
    @param string sText The text, including optional newlines.
    @param boolean|nil bNotify Whether to emit OnChange and valueChanged; default silent.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(sText, bNotify)
        assert(type(sText) == "string", "Label value must be a string.");

        if (not oComponent.Disposed and sText ~= oComponent.Value) then
            local sOldValue = oComponent.Value;
            oComponent.Value = sText;
            tLines = nil;
            oComponent.refresh();

            if (bNotify) then
                if (oComponent.OnChange) then
                    oComponent.OnChange(sText, oComponent);
                end

                tEvents.emit("valueChanged", {Value = sText, OldValue = sOldValue});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Label.setAlignment
    @desc Sets horizontal and vertical text alignment without changing the value.
    @param string sHorizontal left, center or right.
    @param string sVertical top, center or bottom.
    @ret table oComponent This component.
    !]]
    function oComponent.setAlignment(sHorizontal, sVertical)
        assert(sHorizontal == "left" or sHorizontal == "center" or sHorizontal == "right",
            "Invalid horizontal alignment.");
        assert(sVertical == "top" or sVertical == "center" or sVertical == "bottom",
            "Invalid vertical alignment.");

        if (sAlign ~= sHorizontal or sVerticalAlign ~= sVertical) then
            sAlign, sVerticalAlign = sHorizontal, sVertical;
            oComponent.refresh();
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Label.measure
    @desc Measures wrapped text at the current control width, including padding.
    @ret number nWidth The measured width, followed by height, in pixels.
    !]]
    function oComponent.measure()
        assert(not oComponent.Disposed, "Cannot measure a disposed label.");
        local nWidth = oComponent.Control:GetClientSizeWH();
        local oDC = _wx.wxClientDC(oComponent.Control);
        fLines(oDC, math.max(1, nWidth - nPadding * 2));
        local nMeasured = 0;

        for _, nLineWidth in ipairs(tWidths) do
            nMeasured = math.max(nMeasured, nLineWidth);
        end

        oDC:delete();
        return nMeasured + nPadding * 2, #tLines * nLineHeight + nPadding * 2;
    end

    -- Draw into a clipped content area so text cannot spill across sibling controls.
    --[[!
    @fqxn wxLuma.UI.Label.draw
    @desc Draws the current value into a borrowed DC without owning that DC.
    @param wxDC oDC The destination drawing context.
    @param number nWidth The available width in pixels.
    @param number nHeight The available height in pixels.
    !]]
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end

        oDC:SetBackground(oBrush);
        oDC:Clear();
        local nInnerWidth  = math.max(1, nWidth - nPadding * 2);
        local nInnerHeight = math.max(1, nHeight - nPadding * 2);
        fLines(oDC, nInnerWidth);
        local nTextHeight = #tLines * nLineHeight;
        local nY = nPadding;

        if (sVerticalAlign == "center") then
            nY = nPadding + math.floor((nInnerHeight - nTextHeight) / 2);
        elseif (sVerticalAlign == "bottom") then
            nY = nPadding + nInnerHeight - nTextHeight;
        end

        oDC:SetClippingRegion(nPadding, nPadding, nInnerWidth, nInnerHeight);

        for nIndex, sLine in ipairs(tLines) do
            local nX = nPadding;

            if (sAlign == "center") then
                nX = nPadding + math.floor((nInnerWidth - tWidths[nIndex]) / 2);
            elseif (sAlign == "right") then
                nX = nPadding + nInnerWidth - tWidths[nIndex];
            end

            oComponent.Skin.text(oDC, sLine, nX, nY, oComponent.isEnabled());
            nY = nY + nLineHeight;
        end

        oDC:DestroyClippingRegion();
    end;
    oComponent.onDestroy = function()
        tLines, tWidths = nil, nil;
        oBrush:delete();
    end;
    oComponent.setAlignment(tOptions.Align or "left", tOptions.VerticalAlign or "top");
    return oComponent;
end

return Label;