local _wx = require("wx");
local _Theme = require("wxLuma.Core.ControlTheme");
local _Border = require("wxLuma.Core.ControlBorder");
local _Surface = require("wxLuma.Core.ControlSurface");
local _Events = require("wxLuma.Core.ControlEvents");
local _Reserve = require("wxLuma.Core.ControlProgressReserve");
local _Outline = require("wxLuma.Core.ControlProgressOutline");
local _Geometry = require("wxLuma.Core.ProgressShapeGeometry");
local _finite = require("wxLuma.Core.ControlNumeric").finite;
local ShapeProgress = {};
local _Opposite = {left = "right", right = "left", top = "bottom", bottom = "top"};

--[[!
@fqxn wxLuma.UI.ShapeProgress.create
@desc Creates polygon progress, or rectangular radial/angular progress, using
    analytic scanline clipping. Concave simple polygons are supported. Fill and
    reserve retain independent paths; no graphics context or image fallback is used.
@param wxWindow oParent Native parent.
@param table tOptions Progress options; Polygon is a dense normalized {X,Y} array.
    Supersampling is 2 or 4, default 2. ReserveRenderer is auto or strips; native
    disc-only reservation is explicitly unsupported for these silhouettes.
@param number nShape RECTANGLE (0) or POLYGON (2).
@param number nMode LINEAR (0), RADIAL (1), ANGULAR (2).
@ret table oComponent A standard progress surface with existing reserve/state/events APIs.
!]]
function ShapeProgress.create(oParent, tOptions, nShape, nMode)
    tOptions = _Border.withDefault(_Theme.options(tOptions, oParent), _wx.wxBORDER_NONE);
    _Outline.create(tOptions);
    local bOutline = tOptions.Outline ~= false;
    local nOutlineWidth = tOptions.OutlineWidth or 2;
    local tOutlineRGB = tOptions.OutlineColour and {R = tOptions.OutlineColour.R, G = tOptions.OutlineColour.G, B = tOptions.OutlineColour.B};
    assert(_finite(tOptions.Min) and _finite(tOptions.Max) and tOptions.Max > tOptions.Min
        and _finite(tOptions.Max - tOptions.Min) and _finite(tOptions.Value), "Invalid shape progress range/value.");
    local tVertices = nShape == 2 and _Geometry.polygon(tOptions.Polygon)
        or {{X = 0, Y = 0}, {X = 1, Y = 0}, {X = 1, Y = 1}, {X = 0, Y = 1}};
    local sReserveKind = nMode == 0 and "Progress" or nMode == 1 and "RadialProgress" or "CircularProgress";
    _Reserve.validate(tOptions, sReserveKind);
    local sAppearance = tOptions.Appearance == nil and (tOptions.Colour and "colour" or "skin") or tOptions.Appearance;
    assert(sAppearance == "colour" or sAppearance == "skin", "Invalid shape progress Appearance.");
    local sArtwork = tOptions.Artwork or (nMode == 0 and "Progress" or nMode == 1 and "Radial Progress" or "Circular Progress");
    assert(type(sArtwork) == "string" and sArtwork:find("%S"), "Invalid shape progress Artwork.");
    local sText = tOptions.Text or "%v / %m";
    assert(type(sText) == "string", "Shape progress Text must be a string.");
    local nScale = tOptions.Supersampling == nil and 2 or tOptions.Supersampling;
    assert(nScale == 2 or nScale == 4, "Supersampling must be 2 or 4.");
    local sRenderer = tOptions.ReserveRenderer == nil and "auto" or tOptions.ReserveRenderer;
    assert(sRenderer == "auto" or sRenderer == "strips", "Polygon/rectangular radial progress requires ReserveRenderer auto or strips.");
    local nThickness = tOptions.Thickness;
    assert(nThickness == nil or nMode == 2 and _finite(nThickness) and nThickness > 0, "Thickness requires angular progress and positive pixels.");
    local tColour = tOptions.Colour or {R = 77, G = 120, B = 169};
    local tRGB = {};
    for _, sChannel in ipairs({"R", "G", "B"}) do
        assert(_finite(tColour[sChannel]) and tColour[sChannel] >= 0 and tColour[sChannel] <= 255, "Invalid shape progress Colour.");
        tRGB[sChannel] = tColour[sChannel];
    end
    local sOrientation = tOptions.Orientation or ((tOptions.Origin == "top" or tOptions.Origin == "bottom") and "vertical" or "horizontal");
    local sOrigin = tOptions.Origin or (sOrientation == "vertical" and "bottom" or "left");
    assert(nMode ~= 0 or (sOrientation == "vertical" or sOrientation == "horizontal") and _Opposite[sOrigin]
        and ((sOrientation == "vertical") == (sOrigin == "top" or sOrigin == "bottom")), "Invalid shape progress orientation/origin.");
    local sDirection = tOptions.Direction or (nMode == 1 and "outward" or "CW");
    assert(nMode == 0 or nMode == 1 and (sDirection == "outward" or sDirection == "inward")
        or nMode == 2 and (sDirection == "CW" or sDirection == "CCW"), "Invalid shape progress Direction.");
    local nStartAngle = tOptions.StartAngle == nil and 0 or tOptions.StartAngle;
    assert(_finite(nStartAngle), "StartAngle must be finite."); nStartAngle = nStartAngle % 360;
    local sKind = (nShape == 2 and "Polygon" or "Rectangle")..(nMode == 0 and "Linear" or nMode == 1 and "Radial" or "Angular").."Progress";
    local oComponent = _Surface.create(oParent, tOptions, sKind);
    oComponent.Min, oComponent.Max, oComponent.Value = tOptions.Min, tOptions.Max, tOptions.Value;
    oComponent.Text, oComponent.Colour = sText, tRGB;
    local tNames = {"appearanceChanged", "supersamplingChanged", "reserveRendererChanged", "polygonChanged"};
    for _, sName in ipairs(_Reserve.Events) do tNames[#tNames + 1] = sName; end
    for _, sName in ipairs(nMode == 0 and {"originChanged", "orientationChanged"} or {"directionChanged", "startAngleChanged"}) do tNames[#tNames + 1] = sName; end
    local tEvents = _Events.attach(oComponent, nil, tNames);
    local tReserve = _Reserve.attach(oComponent, tOptions, tEvents, sReserveKind);
    local oRaster, sRasterKey;
    local tCachedGeometry, sGeometryKey;
    local tReservePlan, sBaseKey;
    local oWorkBitmap, oBaseBitmap, nBufferWidth, nBufferHeight;
    local nRevision = 0;

    --[[!
    @fqxn wxLuma.UI.ShapeProgress.invalidate
    @desc Invalidates the single raster without touching value, reserve or native ownership.
    !]]
    local function fInvalidate() nRevision = nRevision + 1; oComponent.refresh(); end
    tReserve.Changed = fInvalidate;

    --[[!
    @fqxn wxLuma.UI.ShapeProgress.setValue
    @desc Clamps to usable capacity before changed-only callback/event notification.
    !]]
    function oComponent.setValue(nValue, bNotify)
        assert(_finite(nValue), "Shape progress value must be finite.");
        if (oComponent.Disposed) then return oComponent; end
        nValue = math.max(oComponent.Min, math.min(oComponent.getEffectiveMax(), nValue));
        local nOld = oComponent.Value;
        if (nOld ~= nValue) then
            oComponent.Value = nValue; oComponent.refresh();
            if (bNotify) then
                if (oComponent.OnChange) then oComponent.OnChange(nValue, oComponent); end
                tEvents.emit("valueChanged", {Value = nValue, OldValue = nOld});
            end
        end
        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ShapeProgress.setting
    @desc Installs validated scalar geometry/rendering settings with changed-only events.
        Getters read current closure state; setters commit before notifying.
    !]]
    local function fSetting(sName, fGet, fStore, fValidate, sEvent, fNormalize)
        oComponent["get"..sName] = fGet;
        oComponent["set"..sName] = function(vValue, bNotify)
            assert(fValidate(vValue), "Invalid shape progress "..sName..".");
            if (fNormalize) then vValue = fNormalize(vValue); end
            local vOld = fGet();
            if (not oComponent.Disposed and vOld ~= vValue) then
                fStore(vValue); fInvalidate();
                if (bNotify) then tEvents.emit(sEvent, {[sName] = fGet(), ["Old"..sName] = vOld}); end
            end
            return oComponent;
        end;
    end
    fSetting("Appearance", function() return sAppearance; end, function(v) sAppearance = v; end,
        function(v) return v == "skin" or v == "colour"; end, "appearanceChanged");
    fSetting("Supersampling", function() return nScale; end, function(v) nScale = v; end,
        function(v) return v == 2 or v == 4; end, "supersamplingChanged");
    fSetting("ReserveRenderer", function() return sRenderer; end, function(v) sRenderer = v; end,
        function(v) return v == "auto" or v == "strips"; end, "reserveRendererChanged");
    if (nMode == 0) then
        --[[!
        @fqxn wxLuma.UI.ShapeProgress.setOrigin
        @desc Changes the active edge and coupled orientation before notifying either event.
        !]]
        function oComponent.setOrigin(sNext, bNotify)
            assert(_Opposite[sNext], "Invalid shape progress Origin.");
            if (oComponent.Disposed or sNext == sOrigin) then return oComponent; end
            local sOld, sOldOrientation = sOrigin, sOrientation;
            sOrigin = sNext; sOrientation = (sNext == "left" or sNext == "right") and "horizontal" or "vertical";
            fInvalidate();
            if (bNotify) then
                if (sOldOrientation ~= sOrientation) then tEvents.emit("orientationChanged", {Orientation = sOrientation, OldOrientation = sOldOrientation}); end
                tEvents.emit("originChanged", {Origin = sNext, OldOrigin = sOld});
            end
            return oComponent;
        end
        --[[!
        @fqxn wxLuma.UI.ShapeProgress.getOrigin
        @desc Returns the current linear starting edge.
        !]]
        function oComponent.getOrigin() return sOrigin; end
        --[[!
        @fqxn wxLuma.UI.ShapeProgress.getOrientation
        @desc Returns the axis coupled to the current starting edge.
        !]]
        function oComponent.getOrientation() return sOrientation; end
        --[[!
        @fqxn wxLuma.UI.ShapeProgress.setOrientation
        @desc Changes axis while retaining the forward/reverse edge policy.
        !]]
        function oComponent.setOrientation(sNext, bNotify)
            assert(sNext == "horizontal" or sNext == "vertical", "Invalid shape progress Orientation.");
            local bReverse = sOrigin == "right" or sOrigin == "top";
            return oComponent.setOrigin(sNext == "vertical" and (bReverse and "top" or "bottom") or (bReverse and "right" or "left"), bNotify);
        end
    else
        fSetting("Direction", function() return sDirection; end, function(v) sDirection = v; end,
            function(v) return nMode == 1 and (v == "outward" or v == "inward") or nMode == 2 and (v == "CW" or v == "CCW"); end, "directionChanged");
        if (nMode == 2) then
            fSetting("StartAngle", function() return nStartAngle; end, function(v) nStartAngle = v; end, _finite,
                "startAngleChanged", function(v) return v % 360; end);
        end
    end
    if (nShape == 2) then
        --[[!
        @fqxn wxLuma.UI.ShapeProgress.getPolygon
        @desc Returns detached normalized vertices; callers cannot mutate the live silhouette.
        !]]
        function oComponent.getPolygon()
            local tCopy = {}; for i, p in ipairs(tVertices) do tCopy[i] = {X = p.X, Y = p.Y}; end; return tCopy;
        end
        --[[!
        @fqxn wxLuma.UI.ShapeProgress.setPolygon
        @desc Validates the complete replacement before changing geometry or cached rendering.
        !]]
        function oComponent.setPolygon(tNext, bNotify)
            local tCopy = _Geometry.polygon(tNext);
            if (oComponent.Disposed) then return oComponent; end
            local bSame = #tCopy == #tVertices;
            for i, p in ipairs(tCopy) do if (not tVertices[i] or p.X ~= tVertices[i].X or p.Y ~= tVertices[i].Y) then bSame = false; break; end end
            if (not bSame) then
                tVertices = tCopy; fInvalidate();
                if (bNotify) then tEvents.emit("polygonChanged", {Polygon = oComponent.getPolygon()}); end
            end
            return oComponent;
        end
    end

    --[[!
    @fqxn wxLuma.UI.ShapeProgress.draw
    @desc Builds one supersampled raster per effective state and reuses it until
        geometry, size, appearance, capacity or value changes. Skin materials stay
        anchored to the full raster; a borrowed output DC is never deleted.
    !]]
    oComponent.draw = function(oDC, nWidth, nHeight)
        if (oComponent.Disposed or nWidth < 1 or nHeight < 1) then return; end
        nWidth, nHeight = math.floor(nWidth), math.floor(nHeight);
        local bEnabled = oComponent.isEnabled();
        local sKey = table.concat({nWidth, nHeight, nRevision, oComponent.Value, tReserve.Reserved,
            tostring(bEnabled), oComponent.Colour.R, oComponent.Colour.G, oComponent.Colour.B}, ":");
        if (sRasterKey ~= sKey) then
            local nW, nH = nWidth * nScale, nHeight * nScale;
            local tSettings = {Origin = sOrigin, ReserveOrigin = tReserve.ReserveOrigin or _Opposite[sOrigin],
                Direction = sDirection, ReserveDirection = tReserve.ReserveDirection or (nMode == 1 and (sDirection == "outward" and "inward" or "outward") or (sDirection == "CW" and "CCW" or "CW")),
                StartAngle = nStartAngle, ReserveStartAngle = tReserve.ReserveStartAngle or nStartAngle,
                InnerRadius = tReserve.InnerRadius, OuterRadius = tReserve.OuterRadius, Thickness = nThickness};
            local sNextGeometryKey = table.concat({nW, nH, nScale, nRevision}, ":");
            if (sGeometryKey ~= sNextGeometryKey) then
                tCachedGeometry = _Geometry.prepare(tVertices, nW, nH, nScale, nMode, tSettings);
                sGeometryKey = sNextGeometryKey;
            end
            local tGeometry = tCachedGeometry;
            if (nBufferWidth ~= nW or nBufferHeight ~= nH) then
                if (oWorkBitmap) then oWorkBitmap:delete(); oBaseBitmap:delete(); end
                oWorkBitmap, oBaseBitmap = _wx.wxBitmap(nW, nH), _wx.wxBitmap(nW, nH);
                nBufferWidth, nBufferHeight, sBaseKey = nW, nH, nil;
            end
            local oMemory = _wx.wxMemoryDC(); oMemory:SelectObject(oWorkBitmap);
            oMemory:SetPen(_wx.wxTRANSPARENT_PEN);
            local tBrushes, tColors = {}, {};
            for _, sPart in ipairs({"Track", "Fill", "Reserve"}) do
                if (sPart ~= "Reserve" or tReserve.Reserved > 0) then
                    if (sAppearance == "skin") then
                        tBrushes[sPart] = _wx.wxBrush(oComponent.Skin.getBitmap(sArtwork.." "..sPart..(bEnabled and " Normal" or " Disabled"), nW, nH));
                    else
                        local oColor;
                        if (sPart == "Fill" and bEnabled) then oColor = _wx.wxColour(oComponent.Colour.R, oComponent.Colour.G, oComponent.Colour.B);
                        else oColor = _Theme.colour(oComponent.Skin, not bEnabled and "DisabledText" or sPart == "Track" and "Track" or "Reserve", 80, 90, 100); end
                        tColors[#tColors + 1] = oColor; tBrushes[sPart] = _wx.wxBrush(oColor);
                    end
                end
            end
            local nTotal = oComponent.Max - oComponent.Min;
            local nUsable = oComponent.getEffectiveMax() - oComponent.Min;
            local sNextBaseKey = table.concat({sNextGeometryKey, tostring(bEnabled), oComponent.Colour.R, oComponent.Colour.G, oComponent.Colour.B}, ":");
            if (sBaseKey ~= sNextBaseKey) then
                tReservePlan = tGeometry.reservePlan(tReserve.Reserved / nTotal);
                local oBaseDC = _wx.wxMemoryDC(); oBaseDC:SelectObject(oBaseBitmap);
                local oBackground = oComponent.Control:GetParent():GetBackgroundColour();
                local oBackgroundBrush = _wx.wxBrush(oBackground);
                oBaseDC:SetBackground(oBackgroundBrush); oBaseDC:Clear(); oBaseDC:SetPen(_wx.wxTRANSPARENT_PEN);
                tGeometry.paintBase(oBaseDC, tReservePlan, tBrushes);
                oBaseDC:SelectObject(_wx.wxNullBitmap); oBaseDC:delete(); oBackgroundBrush:delete(); oBackground:delete();
                sBaseKey = sNextBaseKey;
            end
            oMemory:DrawBitmap(oBaseBitmap, 0, 0, false);
            tGeometry.paintFill(oMemory, tReservePlan, nUsable > 0 and (oComponent.Value - oComponent.Min) / nUsable or 0, tBrushes.Fill);
            if (bOutline) then
                local oColor = tOutlineRGB and _wx.wxColour(tOutlineRGB.R, tOutlineRGB.G, tOutlineRGB.B)
                    or _Theme.colour(oComponent.Skin, bEnabled and "Border" or "DisabledText", 100, 110, 120);
                local oPen = _wx.wxPen(oColor, math.max(1, math.floor(nOutlineWidth * nScale)), _wx.wxPENSTYLE_SOLID);
                local tNative = {}; for i, p in ipairs(tGeometry.Points) do tNative[i] = _wx.wxPoint(math.floor(p.X), math.floor(p.Y)); end
                oMemory:SetPen(oPen); oMemory:SetBrush(_wx.wxTRANSPARENT_BRUSH); oMemory:DrawPolygon(tNative);
                for _, oPoint in ipairs(tNative) do oPoint:delete(); end
                oPen:delete(); oColor:delete();
            end
            oMemory:SelectObject(_wx.wxNullBitmap); oMemory:delete();
            for _, oBrush in pairs(tBrushes) do oBrush:delete(); end
            for _, oColor in ipairs(tColors) do oColor:delete(); end
            local oImage = oWorkBitmap:ConvertToImage(); local oScaled = oImage:Scale(nWidth, nHeight, _wx.wxIMAGE_QUALITY_HIGH);
            local oNext = _wx.wxBitmap(oScaled); oScaled:delete(); oImage:delete();
            if (oRaster) then oRaster:delete(); end
            oRaster, sRasterKey = oNext, sKey;
        end
        oDC:DrawBitmap(oRaster, 0, 0, false);
        local sDisplay = oComponent.Text:gsub("%%v", tostring(oComponent.Value)):gsub("%%m", tostring(oComponent.Max));
        oDC:SetFont(oComponent.Skin.Font); local nW, nH = oDC:GetTextExtent(sDisplay);
        local oClip = _wx.wxDCClipper(oDC, _wx.wxRect(0, 0, nWidth, nHeight));
        oComponent.Skin.text(oDC, sDisplay, (nWidth - nW) / 2, (nHeight - nH) / 2, bEnabled); oClip:delete();
    end;
    oComponent.onThemeChanged = fInvalidate;
    oComponent.onDestroy = function()
        if (oRaster) then oRaster:delete(); oRaster = nil; end
        if (oWorkBitmap) then oWorkBitmap:delete(); oBaseBitmap:delete(); oWorkBitmap, oBaseBitmap = nil, nil; end
        tCachedGeometry, tReservePlan = nil, nil;
    end;
    oComponent.setValue(tOptions.Value);
    _Theme.finish(oComponent, tOptions);
    return oComponent;
end

return ShapeProgress;
