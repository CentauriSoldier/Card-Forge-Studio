local _Reserve = require("wxLuma.Core.ControlProgressReserve");
local _wx           = require("wx");
local _ControlEvents = require("wxLuma.Core.ControlEvents");
local Progress      = {};
local createSurface = require("wxLuma.Core.ControlSurface").create;
local finite        = require("wxLuma.Core.ControlNumeric").finite;

--[[!
@fqxn wxLuma.UI.Progress.create
@param table tOptions Skin, Min, Max, Value; optional Text, Colour ({R,G,B}),
    Appearance (colour/skin, default colour), Artwork (material prefix, default
    Progress), Orientation (horizontal/vertical), Origin (left/right/top/bottom),
    Reserved (capacity units, default 0), ReserveOrigin (optional independent edge),
    Enabled and OnChange. Default is horizontal from left; vertical defaults to
    bottom. Origin alone infers orientation; conflicting explicit options fail.
@desc Determinate progress/resource meter. Value clamps to usable capacity. Text
      supports %v/current and %m/max. No input or automatic timing.
!]]
function Progress.create(oParent, tOptions)
    local sAppearance = tOptions.Appearance or "colour";
    local sOrigin = tOptions.Origin;
    local sOrientation = tOptions.Orientation;

    if (sOrientation == nil) then
        sOrientation = (sOrigin == "top" or sOrigin == "bottom") and "vertical" or "horizontal";
    end
    assert(sOrientation == "horizontal" or sOrientation == "vertical", "Invalid progress orientation.");
    if (sOrigin == nil) then
        sOrigin = sOrientation == "vertical" and "bottom" or "left";
    end
    assert(sOrigin == "left" or sOrigin == "right" or sOrigin == "top" or sOrigin == "bottom",
        "Invalid progress origin.");
    assert((sOrientation == "horizontal") == (sOrigin == "left" or sOrigin == "right"),
        "Progress Origin conflicts with Orientation.");
    local sArtwork = tOptions.Artwork or "Progress";
    assert(sAppearance == "skin" or sAppearance == "colour", "Appearance must be skin or colour.");
    assert(type(sArtwork) == "string" and sArtwork:find("%S"), "Artwork must be a material prefix.");
    _Reserve.validate(tOptions, "Progress");
    local oComponent = createSurface(oParent, tOptions, "Progress");
    local tExtraEvents = {"appearanceChanged", "orientationChanged", "originChanged"};

    for _, sEvent in ipairs(_Reserve.Events) do
        tExtraEvents[#tExtraEvents + 1] = sEvent;
    end

    local tEvents = _ControlEvents.attach(oComponent, nil, tExtraEvents);
    assert(finite(tOptions.Min) and finite(tOptions.Max) and tOptions.Max > tOptions.Min,
        "Invalid progress range.");
    oComponent.Min, oComponent.Max = tOptions.Min, tOptions.Max;
    oComponent.Text                = tOptions.Text or "%v / %m";
    local tReserve = _Reserve.attach(oComponent, tOptions, tEvents, "Progress");
    oComponent.Colour              = tOptions.Colour or {
        R = 88,
        G = 120,
        B = 148
    };

    -- Change both related fields before callbacks so observers always see a
    -- coherent orientation/origin pair. Layout and progress remain untouched.
    local function fGeometry(sNewOrientation, sNewOrigin, bNotify)
        if (oComponent.Disposed) then
            return oComponent;
        end

        local sOldOrientation = sOrientation;
        local sOldOrigin = sOrigin;
        sOrientation, sOrigin = sNewOrientation, sNewOrigin;

        if (sOldOrientation ~= sOrientation or sOldOrigin ~= sOrigin) then
            oComponent.refresh();

            if (bNotify) then
                if (sOldOrientation ~= sOrientation) then
                    tEvents.emit("orientationChanged", {
                        Orientation = sOrientation, OldOrientation = sOldOrientation
                    });
                end

                if (sOldOrigin ~= sOrigin) then
                    tEvents.emit("originChanged", {Origin = sOrigin, OldOrigin = sOldOrigin});
                end
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Progress.getOrientation
    @desc Returns horizontal or vertical, independently of the control's size.
    @ret string sOrientation Current fill axis.
    !]]
    function oComponent.getOrientation()
        return sOrientation;
    end

    --[[!
    @fqxn wxLuma.UI.Progress.setOrientation
    @desc Changes the fill axis without changing layout, progress or appearance.
        Forward origins map left/bottom; reverse origins map right/top.
    @param string sValue horizontal or vertical.
    @param boolean|nil bNotify Emit orientationChanged/originChanged when changed.
    @ret table oComponent This component.
    !]]
    function oComponent.setOrientation(sValue, bNotify)
        assert(sValue == "horizontal" or sValue == "vertical", "Invalid progress orientation.");
        local bReverse = sOrigin == "right" or sOrigin == "top";
        local sNewOrigin = sValue == "vertical" and (bReverse and "top" or "bottom")
            or (bReverse and "right" or "left");
        return fGeometry(sValue, sNewOrigin, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Progress.getOrigin
    @desc Returns the edge from which the filled region grows.
    @ret string sOrigin left, right, top or bottom.
    !]]
    function oComponent.getOrigin()
        return sOrigin;
    end

    --[[!
    @fqxn wxLuma.UI.Progress.setOrigin
    @desc Selects the fill edge and its matching axis atomically. Value and native
        size remain unchanged. Top/bottom imply vertical; left/right horizontal.
    @param string sValue left, right, top or bottom.
    @param boolean|nil bNotify Emit originChanged/orientationChanged when changed.
    @ret table oComponent This component.
    !]]
    function oComponent.setOrigin(sValue, bNotify)
        assert(sValue == "left" or sValue == "right" or sValue == "top" or sValue == "bottom",
            "Invalid progress origin.");
        local sNewOrientation = (sValue == "top" or sValue == "bottom") and "vertical" or "horizontal";
        return fGeometry(sNewOrientation, sValue, bNotify);
    end

    --[[!
    @fqxn wxLuma.UI.Progress.getAppearance
    @desc Returns colour for the original gradient meter or skin for bitmap materials.
    @ret string sAppearance Current appearance.
    !]]
    function oComponent.getAppearance()
        return sAppearance;
    end

    --[[!
    @fqxn wxLuma.UI.Progress.setAppearance
    @desc Switches colour and skin rendering at runtime without changing progress.
    @param string sMode colour or skin.
    @param boolean|nil bNotify Emit appearanceChanged on an effective change.
    @ret table oComponent This component.
    !]]
    function oComponent.setAppearance(sMode, bNotify)
        assert(sMode == "skin" or sMode == "colour", "Appearance must be skin or colour.");

        if (not oComponent.Disposed and sAppearance ~= sMode) then
            local sOld = sAppearance;
            sAppearance = sMode;
            oComponent.refresh();

            if (bNotify) then
                tEvents.emit("appearanceChanged", {Appearance = sMode, OldAppearance = sOld});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.Progress.setValue
    @desc Clamps finite values to Min and the reserve-adjusted effective maximum.
        Refreshes and optionally notifies only when the stored value changes.
    @param number nValue The requested value or index.
    @param boolean|nil bNotify Whether to notify after a change; omitted means silent.
    @ret table oComponent This public component object.
    !]]
    function oComponent.setValue(nValue, bNotify)
        assert(finite(nValue), "Progress value must be finite.");
        nValue = math.max(oComponent.Min, math.min(oComponent.getEffectiveMax(), nValue));
        local nOldValue = oComponent.Value;
        local bChanged = nOldValue ~= nValue;
        oComponent.Value = nValue;
        if (bChanged) then
            oComponent.refresh();
            if (bNotify) then
                if (oComponent.OnChange) then
                    oComponent.OnChange(nValue, oComponent);
                end

                tEvents.emit("valueChanged", {Value = nValue, OldValue = nOldValue});
            end
        end;
        return oComponent;
    end

    local oReserveRaster;
    local sReserveKey;

    --[[!
    @fqxn wxLuma.UI.Progress.reserveRaster
    @desc Caches rectangular reserve masks, including perpendicular origins.
        Skin bitmaps are borrowed; the cached composed bitmap belongs to this control.
    !]]
    local function fReserveRaster(nWidth, nHeight)
        local bEnabled = oComponent.isEnabled();
        local sState = bEnabled and "Normal" or "Disabled";
        local tOpposite = {left = "right", right = "left", top = "bottom", bottom = "top"};
        local sReserveOrigin = tReserve.ReserveOrigin or tOpposite[sOrigin];
        local sKey = table.concat({nWidth, nHeight, oComponent.Value, tReserve.Reserved,
            sOrigin, sReserveOrigin, sState, sAppearance}, ":");

        if (sKey == sReserveKey) then
            return;
        end

        local tBrushes = {};

        for _, sPart in ipairs({"Track", "Fill", "Reserve"}) do
            if (sAppearance == "skin") then
                tBrushes[sPart] = _wx.wxBrush(oComponent.Skin.getBitmap(sArtwork.." "..sPart.." "..sState,
                    nWidth, nHeight, sOrientation == "vertical"));
            else
                local tColour = sPart == "Reserve" and {R = 142, G = 99, B = 164}
                    or (sPart == "Fill" and oComponent.Colour or {R = 43, G = 50, B = 59});
                tBrushes[sPart] = _wx.wxBrush(bEnabled and _wx.wxColour(tColour.R, tColour.G, tColour.B)
                    or (sPart == "Reserve" and _wx.wxColour(72, 65, 78) or _wx.wxColour(61, 67, 73)));
            end
        end

        --[[!
        @fqxn wxLuma.UI.Progress.reserveRaster.coordinate
        @desc Measures normalized distance from an edge at pixel centers.
        !]]
        local function fCoordinate(sEdge, nX, nY)
            if (sEdge == "left") then
                return (nX + 0.5) / nWidth;
            elseif (sEdge == "right") then
                return 1 - (nX + 0.5) / nWidth;
            elseif (sEdge == "top") then
                return (nY + 0.5) / nHeight;
            end

            return 1 - (nY + 0.5) / nHeight;
        end

        local oBitmap = _wx.wxBitmap(nWidth, nHeight);
        local oMemory = _wx.wxMemoryDC();
        oMemory:SelectObject(oBitmap);
        oMemory:SetPen(_wx.wxTRANSPARENT_PEN);
        local nUsable = oComponent.getEffectiveMax() - oComponent.Min;
        _Reserve.drawMask(oMemory, nWidth, nHeight, function(nX, nY)
            return fCoordinate(sOrigin, nX, nY), fCoordinate(sReserveOrigin, nX, nY);
        end, tReserve.Reserved / (oComponent.Max - oComponent.Min),
            nUsable > 0 and (oComponent.Value - oComponent.Min) / nUsable or 0, tBrushes,
            {Kind = "bar", Origin = sOrigin, ReserveOrigin = sReserveOrigin});
        oMemory:SelectObject(_wx.wxNullBitmap);
        oMemory:delete();

        for _, oBrush in pairs(tBrushes) do
            oBrush:delete();
        end

        if (oReserveRaster) then
            oReserveRaster:delete();
        end

        oReserveRaster, sReserveKey = oBitmap, sKey;
    end

    oComponent.onDestroy = function()
        if (oReserveRaster) then
            oReserveRaster:delete();
            oReserveRaster = nil;
        end
    end;

    -- Draw widget content inside the shared frame; shared code owns the paint DC.
    oComponent.drawContent = function(oDC, nWidth, nHeight)
        local nInnerWidth  = math.max(1, nWidth - 8);
        local nInnerHeight = math.max(1, nHeight - 8);
        local bVertical    = sOrientation == "vertical";
        local nLength      = bVertical and nInnerHeight or nInnerWidth;
        local nFill        = math.floor(nLength * (oComponent.Value - oComponent.Min)
            / (oComponent.Max - oComponent.Min));
        local nFillX, nFillY = 4, 4;
        local nFillWidth  = bVertical and nInnerWidth or nFill;
        local nFillHeight = bVertical and nFill or nInnerHeight;

        if (sOrigin == "right") then
            nFillX = 4 + nInnerWidth - nFill;
        elseif (sOrigin == "bottom") then
            nFillY = 4 + nInnerHeight - nFill;
        end

        if (tReserve.Reserved > 0) then
            fReserveRaster(nInnerWidth, nInnerHeight);
            oDC:DrawBitmap(oReserveRaster, 4, 4, false);
        elseif (sAppearance == "skin") then
            local sState = oComponent.isEnabled() and "Normal" or "Disabled";
            oComponent.Skin.draw(oDC, sArtwork.." Track "..sState, 4, 4,
                nInnerWidth, nInnerHeight, bVertical);

            if (nFill > 0) then
                -- Rotate the material for vertical bars. Clip its full extent
                -- from the chosen edge so texture does not slide with progress.
                local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(nFillX, nFillY, nFillWidth, nFillHeight));
                oComponent.Skin.draw(oDC, sArtwork.." Fill "..sState, 4, 4,
                    nInnerWidth, nInnerHeight, bVertical);
                oClip:delete();
            end
        elseif (nFill > 0) then
            local tColour = oComponent.isEnabled() and oComponent.Colour or {
                R = 61,
                G = 67,
                B = 73
            };
            oDC:GradientFillLinear(_wx.wxRect(nFillX, nFillY, nFillWidth, nFillHeight),
                _wx.wxColour(tColour.R, tColour.G, tColour.B),
                _wx.wxColour(math.floor(tColour.R / 3), math.floor(tColour.G / 3),
                    math.floor(tColour.B / 3)), bVertical and _wx.wxEAST or _wx.wxSOUTH);
        end
        local sText = oComponent.Text:gsub("%%v", tostring(oComponent.Value)):gsub("%%m",
            tostring(oComponent.Max));
        oDC:SetFont(oComponent.Skin.Font);
        local nTextW, nTextH = oDC:GetTextExtent(sText);
        oDC:SetClippingRegion(4, 4, math.max(1, nWidth - 8), math.max(1, nHeight - 8));
        oComponent.Skin.text(oDC, sText, (nWidth - nTextW) / 2, (nHeight - nTextH) / 2, oComponent.isEnabled());
        oDC:DestroyClippingRegion();
    end;
    oComponent.setValue(tOptions.Value);
    return oComponent;
end

return Progress;
