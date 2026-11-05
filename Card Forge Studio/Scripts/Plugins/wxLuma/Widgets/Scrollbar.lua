local _wx           = require("wx");
local Scrollbar     = {};
local createSurface = require("wxLuma.Core.ControlSurface").create;
local drawFrame     = require("wxLuma.Core.ControlDrawing").frame;
local finite        = require("wxLuma.Core.ControlNumeric").finite;

--[[!
@fqxn wxLuma.UI.Scrollbar.create
@param table tOptions Skin, Min, Max, Page, Value; optional Step (1), Vertical (true), Enabled, OnChange.
@desc Max is the last integer scroll offset; Page is the visible amount. Supports
      arrows, track paging, thumb dragging, wheel and Home/End/Page keys.
@ret table oComponent Standard component plus setRange(Min,Max,Page) and getThumb.
!]]
function Scrollbar.create(oParent, tOptions)
    local oComponent = createSurface(oParent, tOptions, "Scrollbar");
    oComponent.PointerRefresh      = true;
    oComponent.PointerStateRefresh = true;
    oComponent.Vertical            = tOptions.Vertical ~= false;
    oComponent.Step                = tOptions.Step or 1;
    assert(finite(oComponent.Step) and oComponent.Step > 0 and oComponent.Step % 1 == 0,
        "Scrollbar Step must be a positive integer.");

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
        assert(finite(nMin) and finite(nMax) and finite(nPage) and nMax >= nMin and nPage > 0
            and nMin % 1 == 0 and nMax % 1 == 0 and nPage % 1 == 0, "Invalid scrollbar range/page.");
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
        local nThumb          = math.min(nTrack, math.max(18,
            math.floor(nTrack * oComponent.Page / (oComponent.Max - oComponent.Min + oComponent.Page))));
        local nTravel         = nTrack - nThumb;
        return 18 + (oComponent.Max == oComponent.Min and 0
            or math.floor(nTravel * (oComponent.Value - oComponent.Min) / (oComponent.Max - oComponent.Min))), nThumb, nTravel;
    end
    local nDrag;

    -- Apply widget policy after shared pointer-state handling.
    oComponent.pointer = function(sEvent, nX, nY)
        local nAt                     = oComponent.Vertical and nY or nX;
        local nWidth, nHeight         = oComponent.Control:GetClientSizeWH();
        local nLength                 = oComponent.Vertical and nHeight or nWidth;
        local nStart, nThumb, nTravel = oComponent.getThumb();
        if (sEvent == "down" and oComponent.Hover) then
            nDrag = nil;
            if (nAt < 18) then
                oComponent.setValue(oComponent.Value - oComponent.Step, true);
            elseif (nAt >= nLength - 18) then
                oComponent.setValue(oComponent.Value + oComponent.Step, true);
            elseif (nAt >= nStart and nAt < nStart + nThumb) then
                nDrag = nAt - nStart;
            else
                oComponent.setValue(oComponent.Value + (nAt < nStart and -oComponent.Page
                    or oComponent.Page), true);
            end
        elseif ((sEvent == "move" or sEvent == "up") and oComponent.Pressed and nDrag and nTravel > 0) then
            oComponent.setValue(oComponent.Min + (nAt - 18 - nDrag) / nTravel * (oComponent.Max - oComponent.Min), true);
        end
        if (sEvent == "up" or sEvent == "cancel" or not oComponent.Pressed) then
            nDrag = nil;
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
            oComponent.setValue(oComponent.Value + tDelta[nKey], true);
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
        oComponent.setValue(oComponent.Value - nSteps * oComponent.Step * 3, true);
    end;

    -- Draw widget content inside the shared frame; shared code owns the paint DC.
    oComponent.drawContent = function(oDC, nWidth, nHeight)
        local nAt, nThumb = oComponent.getThumb();
        local sState      = oComponent.getState();
        if (oComponent.Vertical) then
            oComponent.Skin.drawOpaque(oDC, "Spinner Up " .. sState, 0, 0, nWidth, 18);
            oComponent.Skin.drawOpaque(oDC, "Spinner Down " .. sState, 0, nHeight - 18, nWidth, 18);
            drawFrame(oDC, 2, nAt, nWidth - 4, nThumb, oComponent.isEnabled(), oComponent.Hover);
            oComponent.Skin.text(oDC, "=", math.max(2, (nWidth - 10) / 2), nAt + (nThumb - 18) / 2,
                oComponent.isEnabled());
        else
            drawFrame(oDC, nAt, 2, nThumb, nHeight - 4, oComponent.isEnabled(), oComponent.Hover);
            oComponent.Skin.text(oDC, "<", 3, 2, oComponent.isEnabled());
            oComponent.Skin.text(oDC, ">", nWidth - 15, 2, oComponent.isEnabled());
        end
    end;
    oComponent.setRange(tOptions.Min, tOptions.Max, tOptions.Page);
    oComponent.setValue(tOptions.Value);
    return oComponent;
end

return Scrollbar;
