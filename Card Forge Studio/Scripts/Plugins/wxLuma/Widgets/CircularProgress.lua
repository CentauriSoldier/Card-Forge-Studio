local _Reserve = require("wxLuma.Core.ControlProgressReserve");
local _wx             = require("wx");
local _ControlSurface = require("wxLuma.Core.ControlSurface");
local _ControlEvents  = require("wxLuma.Core.ControlEvents");
local _finite         = require("wxLuma.Core.ControlNumeric").finite;
local CircularProgress = {};

--[[!
@fqxn wxLuma.UI.CircularProgress.create
@desc Creates a determinate ring with a configurable starting angle. Direction may change
    without changing progress. The parent owns the native control; no timer runs.
@param wxWindow oParent The native parent.
@param table tOptions Skin, Min, Max, Value; optional Direction (CW or CCW, default
    CW), Thickness (positive pixels, default 12), Text (%v/current, %m/max), Colour
    ({R,G,B}), Appearance (skin/colour), Artwork (material prefix, default
    Circular Progress), StartAngle (degrees, default 0 at twelve o'clock), Enabled,
    OnChange and standard containment options. Angles increase clockwise:
    90 right, 180 bottom, 270 left; fill Direction remains independent.
    Appearance defaults to colour when Colour is supplied, otherwise skin.
    Reserved defaults to zero; ReserveDirection and ReserveStartAngle optionally
    place it independently. InnerRadius/OuterRadius select percentage-based bands;
    inner zero allows a solid pie instead of the default pixel-thickness ring.
@ret table oComponent An independent public object with shared surface/events API.
!]]
function CircularProgress.create(oParent, tOptions)
    assert(_finite(tOptions.Min) and _finite(tOptions.Max)
        and tOptions.Max > tOptions.Min, "Invalid circular progress range.");
    assert(_finite(tOptions.Value), "Circular progress value must be finite.");
    local sDirection = tOptions.Direction or "CW";
    local nStartAngle = tOptions.StartAngle;

    if (nStartAngle == nil) then
        nStartAngle = 0;
    end

    assert(_finite(nStartAngle), "StartAngle must be finite degrees.");
    nStartAngle = nStartAngle % 360;
    local nThickness = tOptions.Thickness or 12;
    local sText      = tOptions.Text or "%v / %m";
    local tColour    = tOptions.Colour or {R = 88, G = 120, B = 148};
    local sAppearance = tOptions.Appearance or (tOptions.Colour and "colour" or "skin");
    local sArtwork = tOptions.Artwork or "Circular Progress";
    assert(sAppearance == "skin" or sAppearance == "colour", "Appearance must be skin or colour.");
    assert(type(sArtwork) == "string" and sArtwork:find("%S"), "Artwork must be a material prefix.");
    assert(sDirection == "CW" or sDirection == "CCW", "Direction must be CW or CCW.");
    assert(_finite(nThickness) and nThickness > 0, "Thickness must be positive and finite.");
    assert(type(sText) == "string", "Circular progress Text must be a string.");

    for _, sChannel in ipairs({"R", "G", "B"}) do
        assert(_finite(tColour[sChannel]) and tColour[sChannel] >= 0
            and tColour[sChannel] <= 255, "Colour channels must be between 0 and 255.");
    end

    _Reserve.validate(tOptions, "CircularProgress");
    local oComponent = _ControlSurface.create(oParent, tOptions, "CircularProgress");
    local tExtraEvents = {"directionChanged", "appearanceChanged", "startAngleChanged"};

    for _, sEvent in ipairs(_Reserve.Events) do
        tExtraEvents[#tExtraEvents + 1] = sEvent;
    end

    local tEvents = _ControlEvents.attach(oComponent, nil, tExtraEvents);
    local oBackground = _wx.wxBrush(_wx.wxColour(24, 29, 36));
    local oRaster;
    local sCachedRaster;
    oComponent.Min   = tOptions.Min;
    oComponent.Max   = tOptions.Max;
    oComponent.Value = math.max(tOptions.Min, math.min(tOptions.Max, tOptions.Value));
    local tReserve = _Reserve.attach(oComponent, tOptions, tEvents, "CircularProgress");

    --[[!
    @fqxn wxLuma.UI.CircularProgress.getAppearance
    @desc Returns skin for bitmap materials or colour for the solid colour ring.
    @ret string sAppearance Current appearance.
    !]]
    function oComponent.getAppearance()
        return sAppearance;
    end

    --[[!
    @fqxn wxLuma.UI.CircularProgress.setAppearance
    @desc Switches skin/material and colour rendering without changing progress,
        direction or geometry. Changed appearance repaints; repeated mode is silent.
    @param string sMode skin or colour.
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

    -- Rebuild a square ring at four times the display resolution, then downsample
    -- once. This smooths both circular edges and the moving sector boundary using
    -- core wxDC/wxImage facilities, without an optional graphics-context backend.
    local function fRaster(nDiameter, nFraction, bEnabled)
        local sKey = table.concat({nDiameter, nFraction, sDirection, nStartAngle,
            bEnabled and "enabled" or "disabled", sAppearance, tReserve.Reserved,
            tReserve.ReserveDirection or "auto", tReserve.ReserveStartAngle or "auto",
            tReserve.InnerRadius or "legacy", tReserve.OuterRadius or 100}, ":");

        if (sCachedRaster == sKey) then
            return;
        end

        local nScale = 4;
        local nSize = nDiameter * nScale;
        local nCenter = math.floor(nDiameter / 2) * nScale;
        local nRadius = (math.floor(nDiameter / 2) - 2) * nScale;
        local nInner = tReserve.InnerRadius and nRadius * tReserve.InnerRadius / 100
            or (tReserve.OuterRadius and 0 or math.max(0, math.floor(nRadius / nScale - nThickness) * nScale));
        nRadius = nRadius * (tReserve.OuterRadius or 100) / 100;
        local oBitmap = _wx.wxBitmap(nSize, nSize);
        local oMemory = _wx.wxMemoryDC();
        local oTrack, oFill, oReserved;

        if (sAppearance == "skin") then
            local sState = bEnabled and "Normal" or "Disabled";
            -- Bitmap brushes borrow skin-owned material images only during this
            -- build. Geometry masks those square materials into the ring shape.
            oTrack = _wx.wxBrush(oComponent.Skin.getBitmap(sArtwork.." Track "..sState, nSize, nSize));
            oFill = _wx.wxBrush(oComponent.Skin.getBitmap(sArtwork.." Fill "..sState, nSize, nSize));
        else
            oTrack = _wx.wxBrush(_wx.wxColour(43, 50, 59));
            oFill = _wx.wxBrush(bEnabled and _wx.wxColour(tColour.R, tColour.G, tColour.B)
                or _wx.wxColour(61, 67, 73));
        end

        if (tReserve.Reserved > 0) then
            local sState = bEnabled and "Normal" or "Disabled";
            oReserved = sAppearance == "skin"
                and _wx.wxBrush(oComponent.Skin.getBitmap(sArtwork.." Reserve "..sState, nSize, nSize))
                or _wx.wxBrush(bEnabled and _wx.wxColour(142, 99, 164) or _wx.wxColour(72, 65, 78));
        end

        oMemory:SelectObject(oBitmap);
        oMemory:SetBackground(oBackground);
        oMemory:Clear();
        oMemory:SetPen(_wx.wxTRANSPARENT_PEN);
        oMemory:SetBrush(oTrack);
        oMemory:DrawCircle(nCenter, nCenter, nRadius);
        oMemory:SetBrush(oFill);

        if (tReserve.Reserved > 0) then
            oMemory:Clear();
            local nReserved = tReserve.Reserved / (oComponent.Max - oComponent.Min);
            local nReserveAngle = tReserve.ReserveStartAngle or nStartAngle;
            local sReserveDirection = tReserve.ReserveDirection or (sDirection == "CW" and "CCW" or "CW");

            --[[!
            @fqxn wxLuma.UI.CircularProgress.raster.coordinates
            @desc Masks the radial band and measures independent angular paths.
                The current path skips reserve even when the sectors intersect.
            !]]
            local function fCoordinates(nX, nY)
                local nDX, nDY = nX + 0.5 - nCenter, nY + 0.5 - nCenter;
                local nDistance = math.sqrt(nDX * nDX + nDY * nDY);

                if (nDistance < nInner or nDistance >= nRadius) then
                    return nil;
                end

                local nAngle = (math.deg(math.atan(nDY, nDX)) + 90) % 360;
                local nFill = (sDirection == "CW" and (nAngle - nStartAngle) or (nStartAngle - nAngle)) % 360 / 360;
                local nReserve = (sReserveDirection == "CW" and (nAngle - nReserveAngle)
                    or (nReserveAngle - nAngle)) % 360 / 360;
                return nFill, nReserve;
            end

            _Reserve.drawMask(oMemory, nSize, nSize, fCoordinates, nReserved,
                nReserved < 1 and nFraction / (1 - nReserved) or 0,
                {Track = oTrack, Fill = oFill, Reserve = oReserved},
                {Kind = "circular", Center = nCenter, Radius = nRadius, Inner = nInner,
                    Direction = sDirection, StartAngle = nStartAngle,
                    ReserveDirection = sReserveDirection, ReserveStartAngle = nReserveAngle});
        elseif (nFraction >= 1) then
            oMemory:DrawCircle(nCenter, nCenter, nRadius);
        elseif (nFraction > 0) then
            local tPoints = {_wx.wxPoint(nCenter, nCenter)};
            local nSegments = math.max(1, math.ceil(360 * nFraction));
            local nSign = sDirection == "CW" and 1 or -1;

            -- Screen Y increases downward: positive angles sweep clockwise.
            for nIndex = 0, nSegments do
                local nAngle = (nStartAngle - 90) * math.pi / 180
                    + nSign * math.pi * 2 * nFraction * nIndex / nSegments;
                tPoints[#tPoints + 1] = _wx.wxPoint(
                    math.floor(nCenter + math.cos(nAngle) * nRadius + 0.5),
                    math.floor(nCenter + math.sin(nAngle) * nRadius + 0.5));
            end

            oMemory:DrawPolygon(tPoints);

            for _, oPoint in ipairs(tPoints) do
                oPoint:delete();
            end
        end

        if (nInner > 0) then
            oMemory:SetBrush(oBackground);
            oMemory:DrawCircle(nCenter, nCenter, nInner);
        end

        oMemory:SelectObject(_wx.wxNullBitmap);
        oMemory:delete();
        oTrack:delete();
        oFill:delete();

        if (oReserved) then
            oReserved:delete();
        end
        local oImage = oBitmap:ConvertToImage();
        local oScaled = oImage:Scale(nDiameter, nDiameter, _wx.wxIMAGE_QUALITY_HIGH);
        local oNewRaster = _wx.wxBitmap(oScaled);
        oScaled:delete();
        oImage:delete();
        oBitmap:delete();

        if (oRaster) then
            oRaster:delete();
        end

        oRaster = oNewRaster;
        sCachedRaster = sKey;
    end

    --[[!
    @fqxn wxLuma.UI.CircularProgress.setValue
    @desc Clamps finite progress to Min and the reserve-adjusted effective maximum. Effective changes redraw;
        notifications are opt-in and unchanged values remain silent.
    @param number nValue The requested progress.
    @param boolean|nil bNotify Emit OnChange(value, component) and valueChanged.
    @ret table oComponent This component.
    !]]
    function oComponent.setValue(nValue, bNotify)
        assert(_finite(nValue), "Circular progress value must be finite.");
        nValue = math.max(oComponent.Min, math.min(oComponent.getEffectiveMax(), nValue));

        if (not oComponent.Disposed and nValue ~= oComponent.Value) then
            local nOldValue = oComponent.Value;
            oComponent.Value = nValue;
            oComponent.refresh();

            if (bNotify) then
                if (oComponent.OnChange) then
                    oComponent.OnChange(nValue, oComponent);
                end

                tEvents.emit("valueChanged", {Value = nValue, OldValue = nOldValue});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.CircularProgress.getStartAngle
    @desc Returns normalized clock-face degrees in [0, 360): 0 top, 90 right,
        180 bottom, 270 left. This coordinate system is independent of CW/CCW.
    @ret number nAngle Current starting angle.
    !]]
    function oComponent.getStartAngle()
        return nStartAngle;
    end

    --[[!
    @fqxn wxLuma.UI.CircularProgress.setStartAngle
    @desc Moves the start at runtime without changing progress or fill direction.
        Finite degrees wrap modulo 360; equivalent angles do not repaint or notify.
    @param number nAngle Clock-face degrees; negative and fractional values allowed.
    @param boolean|nil bNotify Emit startAngleChanged on an effective change.
    @ret table oComponent This component.
    !]]
    function oComponent.setStartAngle(nAngle, bNotify)
        assert(_finite(nAngle), "StartAngle must be finite degrees.");
        nAngle = nAngle % 360;

        if (not oComponent.Disposed and nStartAngle ~= nAngle) then
            local nOldAngle = nStartAngle;
            nStartAngle = nAngle;
            oComponent.refresh();

            if (bNotify) then
                tEvents.emit("startAngleChanged", {StartAngle = nAngle, OldStartAngle = nOldAngle});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.CircularProgress.getDirection
    @desc Returns the current fill direction, CW or CCW.
    @ret string sDirection The current direction.
    !]]
    function oComponent.getDirection()
        return sDirection;
    end

    --[[!
    @fqxn wxLuma.UI.CircularProgress.setDirection
    @desc Changes fill direction at runtime, preserving progress and geometry.
    @param string sNewDirection CW or CCW, sweeping from the current StartAngle.
    @param boolean|nil bNotify Emit directionChanged on an effective change.
    @ret table oComponent This component.
    !]]
    function oComponent.setDirection(sNewDirection, bNotify)
        assert(sNewDirection == "CW" or sNewDirection == "CCW", "Direction must be CW or CCW.");

        if (not oComponent.Disposed and sNewDirection ~= sDirection) then
            local sOldDirection = sDirection;
            sDirection = sNewDirection;
            oComponent.refresh();

            if (bNotify) then
                tEvents.emit("directionChanged", {Direction = sDirection, OldDirection = sOldDirection});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.CircularProgress.draw
    @desc Draws the cached antialiased ring centered in a borrowed DC. Text uses
        the shared skin font and stays clipped inside the circular hole.
    @param wxDC oDC Borrowed destination.
    @param number nWidth Available width.
    @param number nHeight Available height.
    !]]
    function oComponent.draw(oDC, nWidth, nHeight)
        if (oComponent.Disposed) then
            return;
        end

        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, math.max(1, nWidth), math.max(1, nHeight)));
        oDC:SetBackground(oBackground);
        oDC:Clear();
        local nDiameter = math.floor(math.min(nWidth, nHeight));
        local nRadius = math.floor(nDiameter / 2) - 2;
        local nOffsetX = math.floor((nWidth - nDiameter) / 2);
        local nOffsetY = math.floor((nHeight - nDiameter) / 2);
        local nX = nOffsetX + math.floor(nDiameter / 2);
        local nY = nOffsetY + math.floor(nDiameter / 2);
        local nFraction = (oComponent.Value - oComponent.Min) / (oComponent.Max - oComponent.Min);

        if (nRadius > 0) then
            fRaster(nDiameter, nFraction, oComponent.isEnabled());
            oDC:DrawBitmap(oRaster, nOffsetX, nOffsetY, false);
            local nInner = tReserve.InnerRadius and nRadius * tReserve.InnerRadius / 100
                or (tReserve.OuterRadius and 0 or math.max(0, math.floor(nRadius - nThickness)));

            if (nInner > 0) then
                local nTextHalf = math.floor(nInner / math.sqrt(2));
                local oTextClip = _wx.wxDCClipper(oDC,
                    _wx.wxRect(nX - nTextHalf, nY - nTextHalf, math.max(1, nTextHalf * 2), math.max(1, nTextHalf * 2)));
                local sDisplay = sText:gsub("%%v", tostring(oComponent.Value)):gsub("%%m", tostring(oComponent.Max));
                oDC:SetFont(oComponent.Skin.Font);
                local nTextWidth, nTextHeight = oDC:GetTextExtent(sDisplay);
                oComponent.Skin.text(oDC, sDisplay, nX - nTextWidth / 2,
                    nY - nTextHeight / 2, oComponent.isEnabled());
                oTextClip:delete();
            end
        end

        oClip:delete();
    end

    -- Cached raster and background belong to this component; skin materials are
    -- borrowed. Dispose the skin only after all controls using it are destroyed.
    oComponent.onDestroy = function()
        if (oRaster) then
            oRaster:delete();
            oRaster = nil;
        end

        oBackground:delete();
    end;
    return oComponent;
end

return CircularProgress;
