local _wx     = require("wx");
local _finite = require("wxLuma.Core.ControlNumeric").finite;
local ControlProgressReserve = {};

ControlProgressReserve.Events = {
    "reservedChanged", "reserveOriginChanged", "reserveDirectionChanged",
    "reserveStartAngleChanged", "radiiChanged"
};

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.validate
@desc Validates optional reserve and radius settings before creating native resources.
@param table tOptions Progress creation options.
@param string sKind Progress, GlobeProgress, RadialProgress, CircularProgress or IrisProgress.
!]]
function ControlProgressReserve.validate(tOptions, sKind)
    local nReserved = tOptions.Reserved or 0;
    assert(_finite(nReserved) and nReserved >= 0 and nReserved <= tOptions.Max - tOptions.Min,
        "Reserved must be finite and within the progress range.");
    local sOrigin = tOptions.ReserveOrigin;
    assert(sOrigin == nil or ((sKind == "Progress" or sKind == "GlobeProgress")
        and (sOrigin == "left" or sOrigin == "right" or sOrigin == "top" or sOrigin == "bottom")),
        "ReserveOrigin requires a linear progress control and a valid edge.");
    local sDirection = tOptions.ReserveDirection;
    assert(sDirection == nil or (sKind == "CircularProgress" and (sDirection == "CW" or sDirection == "CCW"))
        or ((sKind == "RadialProgress" or sKind == "IrisProgress") and (sDirection == "inward" or sDirection == "outward")),
        "Invalid reserve direction for this progress control.");
    assert(tOptions.ReserveStartAngle == nil or (sKind == "CircularProgress"
        and _finite(tOptions.ReserveStartAngle)), "ReserveStartAngle requires circular progress and finite degrees.");
    local nInner = tOptions.InnerRadius;
    local nOuter = tOptions.OuterRadius;
    assert((nInner == nil and nOuter == nil) or sKind == "CircularProgress" or sKind == "RadialProgress",
        "Radius settings require circular or radial progress.");
    nInner, nOuter = nInner or 0, nOuter or 100;
    assert(_finite(nInner) and _finite(nOuter) and nInner >= 0 and nInner < nOuter and nOuter <= 100,
        "Radii must satisfy 0 <= inner < outer <= 100.");
end

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.attach
@desc Composes general resource reservations independently of any resource model.
    Stored values are bounded by usable capacity, including at creation. Raising
    reserve trims current to the new effective maximum; lowering it never restores
    a previously trimmed value. Nil geometry follows the full end of the fill.
    Renderers may install a private Changed callback on the returned policy;
    effective setters invoke it before refresh and optional public notifications.
@param table oComponent Public progress object.
@param table tOptions Validated creation settings.
@param table tEvents Component event dispatcher.
@param string sKind Public progress kind.
@ret table tPolicy Private geometry and rendering settings.
!]]
function ControlProgressReserve.attach(oComponent, tOptions, tEvents, sKind)
    local tPolicy = {
        Reserved = tOptions.Reserved or 0,
        ReserveOrigin = tOptions.ReserveOrigin,
        ReserveDirection = tOptions.ReserveDirection,
        ReserveStartAngle = tOptions.ReserveStartAngle and tOptions.ReserveStartAngle % 360,
        InnerRadius = tOptions.InnerRadius,
        OuterRadius = tOptions.OuterRadius
    };

    if (tPolicy.InnerRadius ~= nil or tPolicy.OuterRadius ~= nil) then
        tPolicy.InnerRadius = tPolicy.InnerRadius or 0;
        tPolicy.OuterRadius = tPolicy.OuterRadius or 100;
    end

    -- Some factories initialize current before composing reserve; the linear
    -- factory initializes it later through its capacity-aware setValue method.
    if (oComponent.Value ~= nil) then
        oComponent.Value = math.max(oComponent.Min, math.min(oComponent.Max - tPolicy.Reserved, oComponent.Value));
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.getReserved
    @desc Returns capacity excluded from normal progress, in value units.
    @ret number nReserved Reserved amount; zero by default.
    !]]
    function oComponent.getReserved()
        return tPolicy.Reserved;
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.getMax
    @desc Returns the total configured maximum before reserved capacity is deducted.
    @ret number nMaximum Total maximum, independent of reserve.
    !]]
    function oComponent.getMax()
        return oComponent.Max;
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.getEffectiveMax
    @desc Returns Max minus reserved capacity, including a nonzero Min offset.
    @ret number nMaximum Value considered full.
    !]]
    function oComponent.getEffectiveMax()
        return oComponent.Max - tPolicy.Reserved;
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.isFull
    @desc Tests current against usable capacity. An entirely reserved range has
        no usable capacity and is full at Min. No value is modified.
    @ret boolean bFull Whether current reaches the effective maximum.
    !]]
    function oComponent.isFull()
        return oComponent.Value >= oComponent.getEffectiveMax();
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.setReserved
    @desc Changes excluded capacity and clamps current to the effective maximum.
        Both fields and dependent rendering commit before callbacks. Repeated
        values do not repaint or notify; invalid values preserve the previous state.
    @param number nValue Capacity in [0, Max - Min].
    @param boolean|nil bNotify Emit OnChange/valueChanged if current was trimmed,
        then reservedChanged with old/new amounts and effective maximum.
    @ret table oComponent This component.
    !]]
    function oComponent.setReserved(nValue, bNotify)
        assert(_finite(nValue) and nValue >= 0 and nValue <= oComponent.Max - oComponent.Min,
            "Reserved must be finite and within the progress range.");

        if (not oComponent.Disposed and tPolicy.Reserved ~= nValue) then
            local nOld = tPolicy.Reserved;
            local nOldValue = oComponent.Value;
            tPolicy.Reserved = nValue;
            local nCurrent = math.max(oComponent.Min, math.min(oComponent.getEffectiveMax(), nOldValue));
            oComponent.Value = nCurrent;

            if (tPolicy.Changed) then
                tPolicy.Changed();
            end

            oComponent.refresh();

            if (bNotify) then
                if (nOldValue ~= nCurrent) then
                    if (oComponent.OnChange) then
                        oComponent.OnChange(nCurrent, oComponent);
                    end

                    tEvents.emit("valueChanged", {Value = nCurrent, OldValue = nOldValue});
                end

                tEvents.emit("reservedChanged", {Reserved = nValue, OldReserved = nOld,
                    EffectiveMax = oComponent.getEffectiveMax()});
            end
        end

        return oComponent;
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.geometryAccessors
    @desc Installs matching get/set methods for each applicable reserve geometry
        property. Getters return nil for automatic placement; setters accept nil
        to restore it. Optional notifications contain the old and new settings.
    !]]
    local function fGeometryAccessors(sName, sEvent, fValidate)
        oComponent["get"..sName] = function()
            return tPolicy[sName];
        end;
        oComponent["set"..sName] = function(vValue, bNotify)
            assert(vValue == nil or fValidate(vValue), "Invalid "..sName..".");

            if (sName == "ReserveStartAngle" and vValue ~= nil) then
                vValue = vValue % 360;
            end

            if (not oComponent.Disposed and tPolicy[sName] ~= vValue) then
                local vOld = tPolicy[sName];
                tPolicy[sName] = vValue;

                if (tPolicy.Changed) then
                    tPolicy.Changed();
                end

                oComponent.refresh();

                if (bNotify) then
                    tEvents.emit(sEvent, {[sName] = vValue, ["Old"..sName] = vOld});
                end
            end

            return oComponent;
        end;
    end

    if (sKind == "Progress" or sKind == "GlobeProgress") then
        fGeometryAccessors("ReserveOrigin", "reserveOriginChanged", function(sValue)
            return sValue == "left" or sValue == "right" or sValue == "top" or sValue == "bottom";
        end);
    else
        fGeometryAccessors("ReserveDirection", "reserveDirectionChanged", function(sValue)
            return sKind == "CircularProgress" and (sValue == "CW" or sValue == "CCW")
                or (sKind == "RadialProgress" or sKind == "IrisProgress") and (sValue == "inward" or sValue == "outward");
        end);
    end

    if (sKind == "CircularProgress") then
        fGeometryAccessors("ReserveStartAngle", "reserveStartAngleChanged", _finite);
    end

    if (sKind == "CircularProgress" or sKind == "RadialProgress") then
        --[[!
        @fqxn wxLuma.UI.ControlProgressReserve.getRadii
        @desc Returns explicit inner/outer percentages. Nil inner on a circular
            control denotes its legacy pixel Thickness; radial defaults to zero.
        @ret number|nil nInner Inner percentage or legacy thickness mode.
        @ret number nOuter Outer percentage, default 100.
        !]]
        function oComponent.getRadii()
            local nInner = tPolicy.InnerRadius;

            if (nInner == nil and sKind == "RadialProgress") then
                nInner = 0;
            end

            return nInner, tPolicy.OuterRadius or 100;
        end

        --[[!
        @fqxn wxLuma.UI.ControlProgressReserve.setRadii
        @desc Atomically sets a radial band in percentages of the available radius.
            Inner zero enables a solid pie; nil/nil restores original geometry.
        @param number|nil nInner Inner percentage; defaults to zero when outer supplied.
        @param number|nil nOuter Outer percentage; defaults to 100 when inner supplied.
        @param boolean|nil bNotify Emit radiiChanged after an effective change.
        @ret table oComponent This component.
        !]]
        function oComponent.setRadii(nInner, nOuter, bNotify)
            if (nInner ~= nil or nOuter ~= nil) then
                nInner, nOuter = nInner or 0, nOuter or 100;
                assert(_finite(nInner) and _finite(nOuter) and nInner >= 0
                    and nInner < nOuter and nOuter <= 100, "Invalid radius percentages.");
            end

            if (not oComponent.Disposed and (nInner ~= tPolicy.InnerRadius or nOuter ~= tPolicy.OuterRadius)) then
                local nOldInner, nOldOuter = tPolicy.InnerRadius, tPolicy.OuterRadius;
                tPolicy.InnerRadius, tPolicy.OuterRadius = nInner, nOuter;

                if (tPolicy.Changed) then
                    tPolicy.Changed();
                end

                oComponent.refresh();

                if (bNotify) then
                    tEvents.emit("radiiChanged", {InnerRadius = nInner, OuterRadius = nOuter,
                        OldInnerRadius = nOldInner, OldOuterRadius = nOldOuter});
                end
            end

            return oComponent;
        end
    end

    return tPolicy;
end

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.drawMask
@desc Draws disjoint current/track/reserve spans using analytic intersections.
    Only shape boundaries are evaluated: work scales with scanlines rather than
    raster area. Brushes remain aligned to the complete control. Fill coordinates
    measure usable path length, preserving linear/angular/radial semantics.
@param wxDC oDC Borrowed destination, already cleared.
@param number nWidth Raster width.
@param number nHeight Raster height.
@param function fCoordinates Returns normal/reserve coordinates, or nil outside shape.
@param number nReserve Reserved capacity fraction.
@param number nCurrent Current fraction of usable capacity.
@param table tBrushes Borrowed Track, Fill and Reserve brushes.
@param table tGeometry Shape, origins, directions, angles and radius boundaries.
!]]
function ControlProgressReserve.drawMask(oDC, nWidth, nHeight, fCoordinates, nReserve, nCurrent, tBrushes, tGeometry)
    local tIntervals = {};
    local bCircular = tGeometry.Kind == "circular";
    local bRadial = tGeometry.Kind == "radial";
    local tOpposite = {left = "right", right = "left", top = "bottom", bottom = "top"};
    nCurrent = math.max(0, math.min(1, nCurrent));

    -- Express a reserve on the normal path. Wrapped angular intervals split at
    -- zero; aligned linear/radial paths have only one excluded interval.
    if (bCircular) then
        local nSign = tGeometry.Direction == "CW" and 1 or -1;
        local nStart = ((tGeometry.ReserveStartAngle - tGeometry.StartAngle) * nSign) % 360 / 360;
        local bSame = tGeometry.Direction == tGeometry.ReserveDirection;
        local nLow = bSame and nStart or nStart - nReserve;
        local nHigh = bSame and nStart + nReserve or nStart;

        for nTurn = -1, 1 do
            local nA, nB = math.max(0, nLow + nTurn), math.min(1, nHigh + nTurn);

            if (nB > nA) then
                tIntervals[#tIntervals + 1] = {nA, nB};
            end
        end
    elseif (bRadial or tGeometry.Origin == tGeometry.ReserveOrigin) then
        local bSame = not bRadial or tGeometry.Direction == tGeometry.ReserveDirection;
        tIntervals[1] = bSame and {0, nReserve} or {1 - nReserve, 1};
    elseif (tOpposite[tGeometry.Origin] == tGeometry.ReserveOrigin) then
        tIntervals[1] = {1 - nReserve, 1};
    end

    table.sort(tIntervals, function(tLeft, tRight)
        return tLeft[1] < tRight[1];
    end);
    local nUsable = 1;

    for _, tInterval in ipairs(tIntervals) do
        nUsable = nUsable - (tInterval[2] - tInterval[1]);
    end

    local nRemaining = nCurrent * math.max(0, nUsable);
    local nCursor, nThreshold = 0, 0;

    for _, tInterval in ipairs(tIntervals) do
        local nGap = tInterval[1] - nCursor;

        if (nRemaining <= nGap) then
            break;
        end

        nRemaining = nRemaining - nGap;
        nCursor = tInterval[2];
    end

    nThreshold = math.min(1, nCursor + nRemaining);

    -- A perpendicular cut through a globe can remove both ends of its normal
    -- path. Its remaining chord determines the usable coordinate range.
    if (tGeometry.Kind == "globe" and #tIntervals == 0 and nReserve > 0.5) then
        local nExtent = math.sqrt(math.max(0, 1 - (2 * nReserve - 1)^2));
        nThreshold = (1 - nExtent) / 2 + nCurrent * nExtent;
    end

    local nCenter = tGeometry.Center;
    local nRadius = tGeometry.Radius;
    local nInner = tGeometry.Inner or 0;
    local tAngles = {};
    local tCircles = {};
    local tVertical = {};

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.drawMask.boundary
    @desc Adds intersections for one linear, angular or radial boundary.
    !]]
    local function fBoundary(sPolicy, nFraction, nAngle)
        if (bCircular) then
            tAngles[#tAngles + 1] = nAngle + (sPolicy == "CW" and 1 or -1) * nFraction * 360;
        elseif (bRadial) then
            tCircles[#tCircles + 1] = sPolicy == "outward"
                and nInner + (nRadius - nInner) * nFraction
                or nRadius - (nRadius - nInner) * nFraction;
        elseif (sPolicy == "left" or sPolicy == "right") then
            local nLength = tGeometry.Kind == "bar" and nWidth or 2 * nRadius;
            local nStart = tGeometry.Kind == "bar" and 0 or nCenter - nRadius;
            tVertical[#tVertical + 1] = nStart + nLength * (sPolicy == "left" and nFraction or 1 - nFraction);
        end
    end

    if (bCircular or bRadial) then
        fBoundary(tGeometry.Direction, 0, tGeometry.StartAngle);
        fBoundary(tGeometry.Direction, nThreshold, tGeometry.StartAngle);
        fBoundary(tGeometry.ReserveDirection, 0, tGeometry.ReserveStartAngle);
        fBoundary(tGeometry.ReserveDirection, nReserve, tGeometry.ReserveStartAngle);
    else
        fBoundary(tGeometry.Origin, nThreshold);
        fBoundary(tGeometry.ReserveOrigin, nReserve);
    end

    if (tGeometry.Kind ~= "bar") then
        tCircles[#tCircles + 1] = nRadius;

        if (nInner > 0) then
            tCircles[#tCircles + 1] = nInner;
        end
    end

    for nY = 0, nHeight - 1 do
        local tBreaks = {0, nWidth};
        local nDY = nCenter and nY + 0.5 - nCenter or 0;

        --[[!
        @fqxn wxLuma.UI.ControlProgressReserve.drawMask.addIntersection
        @desc Converts a geometric boundary into the first pixel center beyond it.
        !]]
        local function fAdd(nX)
            tBreaks[#tBreaks + 1] = math.max(0, math.min(nWidth, math.ceil(nX - 0.5)));
        end

        for _, nX in ipairs(tVertical) do
            fAdd(nX);
        end

        for _, nCircle in ipairs(tCircles) do
            if (math.abs(nDY) < nCircle) then
                local nDX = math.sqrt(nCircle * nCircle - nDY * nDY);
                fAdd(nCenter - nDX);
                fAdd(nCenter + nDX);
            end
        end

        for _, nAngle in ipairs(tAngles) do
            local nRadians = math.rad(nAngle);
            local nCos = math.cos(nRadians);

            if (math.abs(nCos) > 0.000000001) then
                fAdd(nCenter - nDY * math.sin(nRadians) / nCos);
            end
        end

        table.sort(tBreaks);

        for nIndex = 1, #tBreaks - 1 do
            local nStart, nEnd = tBreaks[nIndex], tBreaks[nIndex + 1];

            if (nEnd > nStart) then
                local nFill, nReserved = fCoordinates((nStart + nEnd - 1) / 2, nY);

                if (nFill) then
                    local sState = (nReserve >= 1 or nReserved < nReserve) and "Reserve"
                        or (nCurrent > 0 and (nCurrent >= 1 or nFill < nThreshold) and "Fill" or "Track");
                    oDC:SetBrush(tBrushes[sState]);
                    oDC:DrawRectangle(nStart, nY, nEnd - nStart, 1);
                end
            end
        end
    end
end

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.nativeDisc
@desc Builds reusable monochrome clipping masks with native circles and rectangles.
    Boolean bitmap operations intersect reserve with the radial band and subtract
    it from usable capacity. Each colour layer owns its transferred native mask.
    This avoids region overloads absent from the packaged wxLua binding.
@param table tPlan Independent disc plan, populated with owned masked layers.
!]]
local function nativeDisc(tPlan)
    local nSize = tPlan.Size;
    local tGeometry = tPlan.Geometry;
    local nCenter, nRadius = tGeometry.Center, tGeometry.Radius;
    local nInner = tGeometry.Inner or 0;
    local nReserve = tPlan.Reserved;
    local oBlack = _wx.wxBrush(_wx.wxColour(0, 0, 0));
    local oWhite = _wx.wxBrush(_wx.wxColour(255, 255, 255));
    local oShape = _wx.wxBitmap(nSize, nSize, 1);
    local oReserved = _wx.wxBitmap(nSize, nSize, 1);
    local oUsable = _wx.wxBitmap(nSize, nSize, 1);
    local oShapeDC, oReserveDC, oUsableDC = _wx.wxMemoryDC(), _wx.wxMemoryDC(), _wx.wxMemoryDC();
    oShapeDC:SelectObject(oShape);
    oReserveDC:SelectObject(oReserved);
    oUsableDC:SelectObject(oUsable);

    for _, oDC in ipairs({oShapeDC, oReserveDC, oUsableDC}) do
        oDC:SetBackground(oBlack);
        oDC:Clear();
        oDC:SetPen(_wx.wxTRANSPARENT_PEN);
        oDC:SetBrush(oWhite);
    end

    oShapeDC:DrawCircle(nCenter, nCenter, math.floor(nRadius));

    if (nInner > 0) then
        oShapeDC:SetBrush(oBlack);
        oShapeDC:DrawCircle(nCenter, nCenter, math.floor(nInner));
    end

    if (nReserve >= 1) then
        oReserveDC:DrawRectangle(0, 0, nSize, nSize);
    elseif (nReserve > 0 and tGeometry.Kind == "radial") then
        local bOutward = tGeometry.ReserveDirection == "outward";
        local nBoundary = bOutward and nInner + (nRadius - nInner) * nReserve
            or nRadius - (nRadius - nInner) * nReserve;

        if (not bOutward) then
            oReserveDC:DrawRectangle(0, 0, nSize, nSize);
            oReserveDC:SetBrush(oBlack);
        end

        oReserveDC:DrawCircle(nCenter, nCenter, math.floor(nBoundary + 0.5));
    elseif (nReserve > 0) then
        local sOrigin = tGeometry.ReserveOrigin;
        local bReverse = sOrigin == "right" or sOrigin == "bottom";
        local nCut = math.ceil(nCenter - nRadius + 2 * nRadius * (bReverse and 1 - nReserve or nReserve) - 0.5);

        if (sOrigin == "left") then
            oReserveDC:DrawRectangle(0, 0, nCut, nSize);
        elseif (sOrigin == "right") then
            oReserveDC:DrawRectangle(nCut, 0, nSize - nCut, nSize);
        elseif (sOrigin == "top") then
            oReserveDC:DrawRectangle(0, 0, nSize, nCut);
        else
            oReserveDC:DrawRectangle(0, nCut, nSize, nSize - nCut);
        end
    end

    -- Keep every mask inside the same circle/band. Inverting only the reserved
    -- pixels preserves transparent inner holes and the outside background.
    oReserveDC:Blit(0, 0, nSize, nSize, oShapeDC, 0, 0, _wx.wxAND);
    oUsableDC:Blit(0, 0, nSize, nSize, oShapeDC, 0, 0, _wx.wxCOPY);
    oUsableDC:Blit(0, 0, nSize, nSize, oReserveDC, 0, 0, _wx.wxAND_INVERT);

    for _, oDC in ipairs({oShapeDC, oReserveDC, oUsableDC}) do
        oDC:SelectObject(_wx.wxNullBitmap);
        oDC:delete();
    end

    tPlan.FillBitmap = _wx.wxBitmap(nSize, nSize);
    tPlan.ReserveBitmap = _wx.wxBitmap(nSize, nSize);
    tPlan.FillBitmap:SetMask(_wx.wxMask(oUsable));
    tPlan.ReserveBitmap:SetMask(_wx.wxMask(oReserved));
    oShape:delete();
    oReserved:delete();
    oUsable:delete();
    oBlack:delete();
    oWhite:delete();
end

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.prepareDisc
@desc Prepares native clipping masks for globe/radial reserves. Analytic spans
    remain available when explicitly requested or for an unsupported shape.
@param number nSize Supersampled square size.
@param number nReserve Reserved fraction of the complete range.
@param table tGeometry Disc geometry and independent reserve policy.
@param function fCoordinates Reference normal/reserve coordinate evaluator.
@param string|nil sRenderer auto/native/strips; auto uses supported native shapes.
@ret table tPlan Owned masks or fixed spans and the independent geometry.
!]]
function ControlProgressReserve.prepareDisc(nSize, nReserve, tGeometry, fCoordinates, sRenderer)
    local tPlan = {Size = nSize, Reserved = nReserve, Geometry = tGeometry, Rows = {}, Base = {}};
    local bSupported = tGeometry.Kind == "globe" or tGeometry.Kind == "radial";
    tPlan.Renderer = sRenderer ~= "strips" and bSupported and "native" or "strips";

    if (tPlan.Renderer == "native") then
        nativeDisc(tPlan);
        return tPlan;
    end

    local sState;
    local tCollector = {};

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.prepareDisc.collector.SetBrush
    @desc Records a symbolic brush selected by the reference rasterizer.
    !]]
    function tCollector:SetBrush(sBrush)
        sState = sBrush;
    end

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.prepareDisc.collector.DrawRectangle
    @desc Retains exact base spans and the usable intervals available to fill.
    !]]
    function tCollector:DrawRectangle(nX, nY, nWidth, nHeight)
        tPlan.Base[#tPlan.Base + 1] = {nX, nY, nWidth, nHeight, sState};

        if (sState == "Track") then
            local tRow = tPlan.Rows[nY];

            if (not tRow) then
                tRow = {};
                tPlan.Rows[nY] = tRow;
            end

            tRow[#tRow + 1] = {nX, nX + nWidth};
        end
    end

    ControlProgressReserve.drawMask(tCollector, nSize, nSize, fCoordinates, nReserve, 0,
        {Track = "Track", Fill = "Fill", Reserve = "Reserve"}, tGeometry);
    return tPlan;
end

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.releaseDisc
@desc Releases plan-owned native layers and masks after replacement or disposal.
    Strip plans have no native resources. Repeated calls are harmless.
@param table|nil tPlan Previous plan, if any.
!]]
function ControlProgressReserve.releaseDisc(tPlan)
    if (tPlan) then
        for _, sName in ipairs({"FillBitmap", "ReserveBitmap"}) do
            if (tPlan[sName]) then
                tPlan[sName]:delete();
                tPlan[sName] = nil;
            end
        end
    end
end

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.paintDiscLayer
@desc Clears a masked layer with a stationary material. Masks affect compositing,
    not drawing into the layer, so every value begins with a clean track.
@param wxBitmap oBitmap Owned reusable masked layer.
@param wxBrush oBrush Borrowed full-disc material.
@ret wxMemoryDC oDC Selected temporary DC; caller must deselect and delete it.
!]]
local function paintDiscLayer(oBitmap, oBrush)
    local oDC = _wx.wxMemoryDC();
    oDC:SelectObject(oBitmap);
    oDC:SetBackground(oBrush);
    oDC:Clear();
    oDC:SetPen(_wx.wxTRANSPARENT_PEN);
    return oDC;
end

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.drawDiscBase
@desc Draws the fixed track/reserve layer after a plan or material change.
@param wxDC oDC Cleared destination with transparent pen.
@param table tPlan Prepared disc geometry.
@param table tBrushes Borrowed Track and Reserve materials.
!]]
function ControlProgressReserve.drawDiscBase(oDC, tPlan, tBrushes)
    if (tPlan.Renderer == "native") then
        local oTrackDC = paintDiscLayer(tPlan.FillBitmap, tBrushes.Track);
        oTrackDC:SelectObject(_wx.wxNullBitmap);
        oTrackDC:delete();
        oDC:DrawBitmap(tPlan.FillBitmap, 0, 0, true);
        local oReserveDC = paintDiscLayer(tPlan.ReserveBitmap, tBrushes.Reserve or tBrushes.Track);
        oReserveDC:SelectObject(_wx.wxNullBitmap);
        oReserveDC:delete();
        oDC:DrawBitmap(tPlan.ReserveBitmap, 0, 0, true);
        return;
    end

    local sPrevious;

    for _, tSpan in ipairs(tPlan.Base) do
        if (sPrevious ~= tSpan[5]) then
            sPrevious = tSpan[5];
            oDC:SetBrush(tBrushes[sPrevious]);
        end

        oDC:DrawRectangle(tSpan[1], tSpan[2], tSpan[3], tSpan[4]);
    end
end

--[[!
@fqxn wxLuma.UI.ControlProgressReserve.drawDiscFill
@desc Draws changing native circles/rings/levels through the cached usable mask.
    The optional strip fallback reuses fixed intersections and combines equal spans.
    The threshold follows the existing usable-path semantics, including reserves
    on the same edge and perpendicular cuts through a globe.
@param wxDC oDC Borrowed destination with the Fill brush and transparent pen.
@param table tPlan Prepared fixed geometry.
@param number nFraction Current fraction of the complete range, clamped to capacity.
@param table tBrushes Borrowed Track and Fill brushes for native layers.
!]]
function ControlProgressReserve.drawDiscFill(oDC, tPlan, nFraction, tBrushes)
    local nReserve = tPlan.Reserved;

    if (nFraction <= 0 or nReserve >= 1) then
        return;
    end

    local tGeometry = tPlan.Geometry;
    local bRadial = tGeometry.Kind == "radial";
    local nCurrent = math.min(1, nFraction / (1 - nReserve));
    local nThreshold = nFraction;
    local nCenter, nRadius = tGeometry.Center, tGeometry.Radius;
    local nInner = tGeometry.Inner or 0;

    if (bRadial and tGeometry.Direction == tGeometry.ReserveDirection
        or not bRadial and tGeometry.Origin == tGeometry.ReserveOrigin) then
        nThreshold = nFraction + nReserve;
    elseif (not bRadial) then
        local tOpposite = {left = "right", right = "left", top = "bottom", bottom = "top"};

        if (tOpposite[tGeometry.Origin] ~= tGeometry.ReserveOrigin) then
            local nExtent = nReserve > 0.5 and math.sqrt(math.max(0, 1 - (2 * nReserve - 1)^2)) or 1;
            nThreshold = (1 - nExtent) / 2 + nCurrent * nExtent;
        end
    end

    local bOutward = tGeometry.Direction == "outward";
    local nBoundary = bRadial and (bOutward and nInner + (nRadius - nInner) * nThreshold
        or nRadius - (nRadius - nInner) * nThreshold);

    if (tPlan.Renderer == "native") then
        local oFillDC = paintDiscLayer(tPlan.FillBitmap, tBrushes.Track);
        oFillDC:SetBrush(tBrushes.Fill);

        if (nCurrent >= 1) then
            oFillDC:DrawRectangle(0, 0, tPlan.Size, tPlan.Size);
        elseif (bRadial) then
            if (not bOutward) then
                oFillDC:DrawRectangle(0, 0, tPlan.Size, tPlan.Size);
                oFillDC:SetBrush(tBrushes.Track);
            end

            oFillDC:DrawCircle(nCenter, nCenter, math.max(0, math.floor(nBoundary + 0.5)));
        else
            local sOrigin = tGeometry.Origin;
            local bReverse = sOrigin == "right" or sOrigin == "bottom";
            local nCut = math.ceil(nCenter - nRadius + 2 * nRadius * (bReverse and 1 - nThreshold or nThreshold) - 0.5);

            if (sOrigin == "left") then
                oFillDC:DrawRectangle(0, 0, nCut, tPlan.Size);
            elseif (sOrigin == "right") then
                oFillDC:DrawRectangle(nCut, 0, tPlan.Size - nCut, tPlan.Size);
            elseif (sOrigin == "top") then
                oFillDC:DrawRectangle(0, 0, tPlan.Size, nCut);
            else
                oFillDC:DrawRectangle(0, nCut, tPlan.Size, tPlan.Size - nCut);
            end
        end

        oFillDC:SelectObject(_wx.wxNullBitmap);
        oFillDC:delete();
        oDC:DrawBitmap(tPlan.FillBitmap, 0, 0, true);
        return;
    end

    local tActive = {};

    --[[!
    @fqxn wxLuma.UI.ControlProgressReserve.drawDiscFill.span
    @desc Extends matching rectangles across consecutive rows, flushing changes.
        Span clipping never paints over reserve or outside the radial band.
    !]]
    local function fSpan(tNext, nStart, nEnd, nY)
        if (nEnd <= nStart) then
            return;
        end

        local sKey = nStart..":"..nEnd;
        local tRectangle = tActive[sKey];

        if (tRectangle) then
            tRectangle[4] = tRectangle[4] + 1;
            tActive[sKey] = nil;
        else
            tRectangle = {nStart, nY, nEnd - nStart, 1};
        end

        tNext[sKey] = tRectangle;
    end

    for nY = 0, tPlan.Size do
        local tNext = {};
        local tRow = tPlan.Rows[nY];
        local nLeft, nRight;
        local bInvert = false;

        if (tRow and nCurrent < 1) then
            if (bRadial) then
                local nDY = nY + 0.5 - nCenter;
                local nDX = math.abs(nDY) < nBoundary
                    and math.sqrt(nBoundary * nBoundary - nDY * nDY) or 0;
                nLeft = math.ceil(nCenter - nDX - 0.5);
                nRight = math.ceil(nCenter + nDX - 0.5);
                bInvert = not bOutward;
            else
                local sOrigin = tGeometry.Origin;
                local bReverse = sOrigin == "right" or sOrigin == "bottom";
                local nCut = nCenter - nRadius + 2 * nRadius * (bReverse and 1 - nThreshold or nThreshold);

                if (sOrigin == "left" or sOrigin == "right") then
                    nLeft, nRight = 0, math.ceil(nCut - 0.5);
                    bInvert = bReverse;
                else
                    local nCoordinate = bReverse and (nCenter + nRadius - nY - 0.5) / (2 * nRadius)
                        or (nY + 0.5 - nCenter + nRadius) / (2 * nRadius);
                    nLeft, nRight = 0, nCoordinate < nThreshold and tPlan.Size or 0;
                end
            end
        end

        for _, tSpan in ipairs(tRow or {}) do
            if (nCurrent >= 1) then
                fSpan(tNext, tSpan[1], tSpan[2], nY);
            elseif (bInvert) then
                fSpan(tNext, tSpan[1], math.min(tSpan[2], nLeft), nY);
                fSpan(tNext, math.max(tSpan[1], nRight), tSpan[2], nY);
            else
                fSpan(tNext, math.max(tSpan[1], nLeft), math.min(tSpan[2], nRight), nY);
            end
        end

        for _, tRectangle in pairs(tActive) do
            oDC:DrawRectangle(tRectangle[1], tRectangle[2], tRectangle[3], tRectangle[4]);
        end

        tActive = tNext;
    end
end

return ControlProgressReserve;
