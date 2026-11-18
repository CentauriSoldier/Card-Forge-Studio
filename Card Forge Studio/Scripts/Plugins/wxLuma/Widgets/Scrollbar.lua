local _Theme = require("wxLuma.Core.ControlTheme");
local _wx           = require("wx");
local Scrollbar     = {};
local createSurface = require("wxLuma.Core.ControlSurface").create;
local drawFrame     = require("wxLuma.Core.ControlDrawing").frame;
local finite        = require("wxLuma.Core.ControlNumeric").finite;
local advance       = require("wxLuma.Core.ControlNumeric").advance;

--[[!
@fqxn wxLuma.UI.Scrollbar.validateRange
@desc Validates integer scroll geometry and rejects overflowing spans before mutation or native allocation.
!]]
local function validateRange(nMin, nMax, nPage)
    assert(finite(nMin) and finite(nMax) and finite(nPage) and nMax >= nMin and nPage > 0
        and finite(nMax - nMin) and nMin % 1 == 0 and nMax % 1 == 0 and nPage % 1 == 0,
        "Invalid scrollbar range/page.");
end

--[[!
@fqxn wxLuma.UI.Scrollbar.create
@param table tOptions Skin, Min, Max, Page, Value; optional Step (1), Vertical (true), Enabled, OnChange.
@desc Max is the last integer scroll offset; Page is the visible amount. Supports
      arrows, track paging, thumb dragging, wheel and Home/End/Page keys.
@ret table oComponent Standard component plus setRange(Min,Max,Page) and getThumb.
!]]
function Scrollbar.create(oParent, tOptions)
    tOptions = _Theme.options(tOptions, oParent);
    local nStep = tOptions.Step == nil and 1 or tOptions.Step;
    validateRange(tOptions.Min, tOptions.Max, tOptions.Page);
    assert(finite(nStep) and nStep > 0 and nStep % 1 == 0, "Scrollbar Step must be a positive integer.");
    assert(finite(tOptions.Value), "Scrollbar value must be finite.");
    local oComponent = createSurface(oParent, tOptions, "Scrollbar");
    oComponent.PointerRefresh      = true;
    oComponent.PointerStateRefresh = true;
    oComponent.Vertical            = tOptions.Vertical ~= false;
    oComponent.Step                = nStep;

    --[[!
    @fqxn wxLuma.UI.Scrollbar.setValue
    @desc Rounds and clamps the offset, invalidates the old and new thumb rectangles and optionally
        notifies.
    @param number nValue The requested value or index.
    @param boolean|nil bNotify Whether to notify after a change; omitted means silent.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setValue(nValue, bNotify)
        assert(finite(nValue), "Scrollbar value must be finite.");
        nValue = math.max(oComponent.Min, math.min(oComponent.Max, math.floor(nValue + 0.5)));
        local nOldAt, nOldSize;
        if (oComponent.Value ~= nil) then
            nOldAt, nOldSize = oComponent.getThumb();
        end
        local bChanged = oComponent.Value ~= nValue;
        oComponent.Value = nValue;
        if (bChanged) then
            if (nOldAt) then
                local nAt, nSize      = oComponent.getThumb();
                local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
                for _, tThumb in ipairs({
                    {
                        nOldAt,
                        nOldSize
                    },
                    {
                        nAt,
                        nSize
                    }
                }) do
                    oComponent.Control:RefreshRect(oComponent.Vertical and _wx.wxRect(1, tThumb[1] - 1,
                        math.max(1, nWidth - 2), tThumb[2] + 2)
                        or _wx.wxRect(tThumb[1] - 1, 1, tThumb[2] + 2, math.max(1, nHeight - 2)), false);
                end
            else
                oComponent.refresh();
            end
            if (bNotify and oComponent.OnChange) then
                oComponent.OnChange(nValue, oComponent);
            end
        end;
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Scrollbar.setRange
    @desc Validates integer scroll bounds and page size, clamps the offset and refreshes.
    @param number nMin The minimum integer offset.
    @param number nMax The maximum integer offset.
    @param number nPage The positive integer page size.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setRange(nMin, nMax, nPage)
        validateRange(nMin, nMax, nPage);
        oComponent.Min, oComponent.Max, oComponent.Page = nMin, nMax, nPage;
        oComponent.setValue(oComponent.Value or nMin);
        oComponent.refresh();
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Scrollbar.getThumb
    @desc Calculates the thumb position, length and available travel from current range and client size.
    @ret number nOffset Thumb offset, followed by length and travel.
    !]]
    function oComponent.getThumb()
        local nWidth, nHeight = oComponent.Control:GetClientSizeWH();
        local nLength         = oComponent.Vertical and nHeight or nWidth;
        local nTrack          = math.max(1, nLength - 36);
        local nSpan = oComponent.Max - oComponent.Min;
        local nScale = math.max(nSpan, oComponent.Page);
        -- Normalize before summing or multiplying large finite range values.
        local nRatio = (oComponent.Page / nScale) / (nSpan / nScale + oComponent.Page / nScale);
        local nThumb          = math.min(nTrack, math.max(18,
            math.floor(nTrack * nRatio)));
        local nTravel         = nTrack - nThumb;
        return 18 + (oComponent.Max == oComponent.Min and 0
            or math.floor(nTravel * ((oComponent.Value - oComponent.Min) / nSpan))), nThumb, nTravel;
    end
    local nDrag, nHoverPart, nPressedPart, nPointerAt;

    -- Apply widget policy after shared pointer-state handling.
    oComponent.pointer = function(sEvent, nX, nY)
        local nAt                     = oComponent.Vertical and nY or nX;
        local nWidth, nHeight         = oComponent.Control:GetClientSizeWH();
        local nLength                 = oComponent.Vertical and nHeight or nWidth;
        nPointerAt = nAt;
        nHoverPart = oComponent.Hover and (nAt < 18 and 1 or nAt >= nLength - 18 and 2 or 0) or 0;
        if (sEvent == "down") then nPressedPart = nHoverPart; end
        local nStart, nThumb, nTravel = oComponent.getThumb();
        if (sEvent == "down" and oComponent.Hover) then
            nDrag = nil;
            if (nAt < 18) then
                oComponent.setValue(advance(oComponent.Value, oComponent.Min, oComponent.Max, oComponent.Step, -1), true);
            elseif (nAt >= nLength - 18) then
                oComponent.setValue(advance(oComponent.Value, oComponent.Min, oComponent.Max, oComponent.Step, 1), true);
            elseif (nAt >= nStart and nAt < nStart + nThumb) then
                nDrag = nAt - nStart;
            else
                oComponent.setValue(advance(oComponent.Value, oComponent.Min, oComponent.Max, oComponent.Page,
                    nAt < nStart and -1 or 1), true);
            end
        elseif ((sEvent == "move" or sEvent == "up") and oComponent.Pressed and nDrag and nTravel > 0) then
            local nFraction = math.max(0, math.min(1, (nAt - 18 - nDrag) / nTravel));
            oComponent.setValue(oComponent.Min + nFraction * (oComponent.Max - oComponent.Min), true);
        end
        if (sEvent == "up" or sEvent == "cancel" or not oComponent.Pressed) then
            nDrag, nPressedPart = nil, nil;
        end
    end;

    -- Handle the widget navigation or resize keys.
    oComponent.key = function(nKey)
        local tDelta = {
            [_wx.WXK_LEFT] = -oComponent.Step,
            [_wx.WXK_UP] = -oComponent.Step,
            [_wx.WXK_RIGHT] = oComponent.Step,
            [_wx.WXK_DOWN] = oComponent.Step,
            [_wx.WXK_PAGEUP] = -oComponent.Page,
            [_wx.WXK_PAGEDOWN] = oComponent.Page
        };
        if (tDelta[nKey]) then
            local nDelta = tDelta[nKey];
            oComponent.setValue(advance(oComponent.Value, oComponent.Min, oComponent.Max, math.abs(nDelta), nDelta > 0 and 1 or -1), true);
        elseif (nKey == _wx.WXK_HOME) then
            oComponent.setValue(oComponent.Min, true);
        elseif (nKey == _wx.WXK_END) then
            oComponent.setValue(oComponent.Max, true);
        else
            return false;
        end;
        return true;
    end;

    -- Apply wheel movement to the value or scroll offset.
    oComponent.wheel = function(nSteps)
        oComponent.setValue(advance(oComponent.Value, oComponent.Min, oComponent.Max, oComponent.Step, -nSteps * 3), true);
    end;

    --[[!
    @fqxn wxLuma.UI.Scrollbar.drawNativeContent
    @desc Shares native arrow-button and thumb rendering with lists/dropdowns.
        Only the hovered/pressed end changes state; range limits disable the
        corresponding arrow. Image skins return false and retain their artwork.
    !]]
    function oComponent.drawNativeContent(oDC, nWidth, nHeight)
        if (not _Theme.isTheme(oComponent.Skin) or oComponent.Skin.getName() ~= "System") then return false; end
        oComponent.Skin.fill(oDC, "Background", 0, 0, nWidth, nHeight);
        local nAt, nThumb = oComponent.getThumb();
        for nPart = 1, 2 do
            local sState = (not oComponent.isEnabled() or oComponent.Min == oComponent.Max
                or nPart == 1 and oComponent.Value <= oComponent.Min or nPart == 2 and oComponent.Value >= oComponent.Max) and "Disabled"
                or oComponent.Pressed and nPressedPart == nPart and nHoverPart == nPart and "Pressed"
                or nHoverPart == nPart and "Hover" or "Normal";
            oComponent.Skin.arrowButton(oComponent, oDC,
                oComponent.Vertical and (nPart == 1 and "Up" or "Down") or (nPart == 1 and "Left" or "Right"),
                oComponent.Vertical and 0 or (nPart == 1 and 0 or nWidth - 18),
                oComponent.Vertical and (nPart == 1 and 0 or nHeight - 18) or 0,
                oComponent.Vertical and nWidth or 18, oComponent.Vertical and 18 or nHeight, sState);
        end
        local nFlags = not oComponent.isEnabled() and _wx.wxCONTROL_DISABLED
            or nDrag and oComponent.Pressed and _wx.wxCONTROL_PRESSED
            or oComponent.Hover and nPointerAt and nPointerAt >= nAt and nPointerAt < nAt + nThumb and _wx.wxCONTROL_CURRENT or 0;
        local oRect = oComponent.Vertical and _wx.wxRect(2, nAt, math.max(1, nWidth - 4), nThumb)
            or _wx.wxRect(nAt, 2, nThumb, math.max(1, nHeight - 4));
        _wx.wxRendererNative.Get():DrawPushButton(oComponent.Control, oDC, oRect, nFlags); oRect:delete();
        return true;
    end

    -- Draw widget content inside the shared frame; shared code owns the paint DC.
    oComponent.drawContent = function(oDC, nWidth, nHeight)
        if (oComponent.drawNativeContent(oDC, nWidth, nHeight)) then return; end
        local nAt, nThumb = oComponent.getThumb();
        local sState      = oComponent.getState();
        if (oComponent.Vertical) then
            oComponent.Skin.drawOpaque(oDC, "Spinner Up " .. sState, 0, 0, nWidth, 18);
            oComponent.Skin.drawOpaque(oDC, "Spinner Down " .. sState, 0, nHeight - 18, nWidth, 18);
            drawFrame(oDC, 2, nAt, nWidth - 4, nThumb, oComponent.isEnabled(), oComponent.Hover, oComponent.Skin);
            oComponent.Skin.text(oDC, "=", math.max(2, (nWidth - 10) / 2), nAt + (nThumb - 18) / 2,
                oComponent.isEnabled());
        else
            drawFrame(oDC, nAt, 2, nThumb, nHeight - 4, oComponent.isEnabled(), oComponent.Hover, oComponent.Skin);
            oComponent.Skin.drawOpaque(oDC, "Spinner Down "..sState, 0, 0, 18, nHeight, true);
            oComponent.Skin.drawOpaque(oDC, "Spinner Up "..sState, nWidth - 18, 0, 18, nHeight, true);
        end
    end;
    oComponent.setRange(tOptions.Min, tOptions.Max, tOptions.Page);
    oComponent.setValue(tOptions.Value);
    _Theme.finish(oComponent, tOptions);
    return oComponent;
end

return Scrollbar;
