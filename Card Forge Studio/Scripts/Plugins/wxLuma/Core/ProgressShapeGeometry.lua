local _Options = require("wxLuma.Core.ControlOptions");
local _finite = require("wxLuma.Core.ControlNumeric").finite;
local Geometry = {};
local _Opposite = {left = "right", right = "left", top = "bottom", bottom = "top"};

--[[!
@fqxn wxLuma.ProgressShapeGeometry.cross
@desc Returns the signed turn of three normalized vertices.
!]]
local function cross(a, b, c) return (b.X - a.X) * (c.Y - a.Y) - (b.Y - a.Y) * (c.X - a.X); end

--[[!
@fqxn wxLuma.ProgressShapeGeometry.polygon
@desc Copies a dense simple polygon with 3..64 normalized vertices. Rejects zero
    area, repeated edges and self-intersection before allocating native resources.
!]]
function Geometry.polygon(tSource)
    _Options.array(tSource);
    assert(#tSource >= 3 and #tSource <= 64, "Polygon requires 3..64 vertices.");
    local tPoints, nArea = {}, 0;
    for nIndex, tPoint in ipairs(tSource) do
        assert(type(tPoint) == "table" and _finite(tPoint.X) and _finite(tPoint.Y)
            and tPoint.X >= 0 and tPoint.X <= 1 and tPoint.Y >= 0 and tPoint.Y <= 1,
            "Polygon vertices require finite normalized X/Y in 0..1.");
        tPoints[nIndex] = {X = tPoint.X, Y = tPoint.Y};
    end
    for nIndex, a in ipairs(tPoints) do
        local b = tPoints[nIndex % #tPoints + 1];
        local c = tPoints[(nIndex + 1) % #tPoints + 1];
        assert((a.X - b.X)^2 + (a.Y - b.Y)^2 > 1e-18, "Polygon has a zero-length edge.");
        assert(math.abs(cross(a, b, c)) > 1e-12 or (a.X - b.X) * (c.X - b.X) + (a.Y - b.Y) * (c.Y - b.Y) <= 0,
            "Polygon has overlapping adjacent edges.");
        nArea = nArea + a.X * b.Y - b.X * a.Y;
    end
    assert(math.abs(nArea) > 1e-12, "Polygon must have nonzero area.");

    --[[!
    @fqxn wxLuma.ProgressShapeGeometry.polygon.onSegment
    @desc Includes collinear touching when checking nonadjacent edges.
    !]]
    local function fOn(a, b, c)
        return math.abs(cross(a, b, c)) < 1e-12 and c.X >= math.min(a.X, b.X) - 1e-12
            and c.X <= math.max(a.X, b.X) + 1e-12 and c.Y >= math.min(a.Y, b.Y) - 1e-12
            and c.Y <= math.max(a.Y, b.Y) + 1e-12;
    end
    for i, a in ipairs(tPoints) do
        local b = tPoints[i % #tPoints + 1];
        for j = i + 1, #tPoints do
            if (j ~= i + 1 and not (i == 1 and j == #tPoints)) then
                local c, d = tPoints[j], tPoints[j % #tPoints + 1];
                local nA, nB, nC, nD = cross(a, b, c), cross(a, b, d), cross(c, d, a), cross(c, d, b);
                assert(not (nA * nB < 0 and nC * nD < 0 or fOn(a, b, c) or fOn(a, b, d)
                    or fOn(c, d, a) or fOn(c, d, b)), "Polygon must not self-intersect or touch itself.");
            end
        end
    end
    return tPoints;
end

--[[!
@fqxn wxLuma.ProgressShapeGeometry.prepare
@desc Prepares polygon boundaries and normalized fill coordinates at raster size.
    Linear values measure projected distance, radial values measure radius, and
    angular values measure sweep; percentages are not pixel-area percentages.
!]]
function Geometry.prepare(tVertices, nWidth, nHeight, nScale, nMode, tSettings)
    local tPoints = {};
    local nInset = math.min(2 * nScale, math.max(0, math.min(nWidth, nHeight) / 4));
    local nMinX, nMinY, nMaxX, nMaxY = math.huge, math.huge, -math.huge, -math.huge;
    for nIndex, tPoint in ipairs(tVertices) do
        local nX, nY = nInset + tPoint.X * (nWidth - 2 * nInset), nInset + tPoint.Y * (nHeight - 2 * nInset);
        tPoints[nIndex] = {X = nX, Y = nY};
        nMinX, nMinY, nMaxX, nMaxY = math.min(nMinX, nX), math.min(nMinY, nY), math.max(nMaxX, nX), math.max(nMaxY, nY);
    end
    local nCX, nCY, nRadius = (nMinX + nMaxX) / 2, (nMinY + nMaxY) / 2, 0;
    for _, tPoint in ipairs(tPoints) do nRadius = math.max(nRadius, math.sqrt((tPoint.X - nCX)^2 + (tPoint.Y - nCY)^2)); end
    local nOuter = nRadius * (tSettings.OuterRadius or 100) / 100;
    local nInner = tSettings.InnerRadius and nRadius * tSettings.InnerRadius / 100
        or nMode == 2 and tSettings.Thickness and math.max(0, nOuter - tSettings.Thickness * nScale) or 0;
    local tResult = {Points = tPoints, Width = nWidth, Height = nHeight, Inner = nInner, Outer = nOuter};

    --[[!
    @fqxn wxLuma.ProgressShapeGeometry.prepare.linear
    @desc Projects a pixel center along a cardinal fill path inside the actual vertex bounds.
    !]]
    local function fLinear(sOrigin, nX, nY)
        if (sOrigin == "left") then return (nX - nMinX) / (nMaxX - nMinX);
        elseif (sOrigin == "right") then return (nMaxX - nX) / (nMaxX - nMinX);
        elseif (sOrigin == "top") then return (nY - nMinY) / (nMaxY - nMinY); end
        return (nMaxY - nY) / (nMaxY - nMinY);
    end

    --[[!
    @fqxn wxLuma.ProgressShapeGeometry.prepare.coordinates
    @desc Returns fill/reserve distances, or nil outside the polygon/radial band.
    !]]
    function tResult.coordinates(nX, nY, tRowEdges)
        local bInside = false;
        if (tRowEdges) then
            -- Cached scanline crossings preserve the same left-inclusive,
            -- right-exclusive containment rule without walking every polygon edge.
            for i = 1, #tRowEdges, 2 do
                if (nX >= tRowEdges[i] and nX < tRowEdges[i + 1]) then bInside = true; break; end
            end
        else
            local b = tPoints[#tPoints];
            for _, a in ipairs(tPoints) do
                if ((a.Y > nY) ~= (b.Y > nY) and nX < (b.X - a.X) * (nY - a.Y) / (b.Y - a.Y) + a.X) then bInside = not bInside; end
                b = a;
            end
        end
        if (not bInside) then return nil; end
        if (nMode == 0) then return fLinear(tSettings.Origin, nX, nY), fLinear(tSettings.ReserveOrigin, nX, nY); end
        local nDX, nDY = nX - nCX, nY - nCY;
        local nDistance = math.sqrt(nDX * nDX + nDY * nDY);
        if (nDistance < nInner or nDistance >= nOuter or nOuter <= nInner) then return nil; end
        if (nMode == 1) then
            local nRadial = (nDistance - nInner) / (nOuter - nInner);
            return tSettings.Direction == "outward" and nRadial or 1 - nRadial,
                tSettings.ReserveDirection == "outward" and nRadial or 1 - nRadial;
        end
        local nAngle = (math.deg(math.atan(nDY, nDX)) + 90) % 360;
        return ((nAngle - tSettings.StartAngle) * (tSettings.Direction == "CW" and 1 or -1)) % 360 / 360,
            ((nAngle - tSettings.ReserveStartAngle) * (tSettings.ReserveDirection == "CW" and 1 or -1)) % 360 / 360;
    end

    local tRows = {};
    for nY = 0, nHeight - 1 do
        local tEdges, b = {}, tPoints[#tPoints];
        for _, a in ipairs(tPoints) do
            if ((a.Y > nY + 0.5) ~= (b.Y > nY + 0.5)) then
                tEdges[#tEdges + 1] = a.X + (b.X - a.X) * (nY + 0.5 - a.Y) / (b.Y - a.Y);
            end
            b = a;
        end
        table.sort(tEdges); tRows[nY + 1] = tEdges;
    end

    --[[!
    @fqxn wxLuma.ProgressShapeGeometry.prepare.threshold
    @desc Advances through usable path intervals after excluding independently
        placed reserve. Perpendicular linear cuts use the surviving polygon's projection.
    !]]
    function tResult.threshold(nReserve, nCurrent)
        local tIntervals = {};
        if (nMode == 2) then
            local nStart = ((tSettings.ReserveStartAngle - tSettings.StartAngle) * (tSettings.Direction == "CW" and 1 or -1)) % 360 / 360;
            local bSame = tSettings.Direction == tSettings.ReserveDirection;
            local nLow, nHigh = bSame and nStart or nStart - nReserve, bSame and nStart + nReserve or nStart;
            for nTurn = -1, 1 do
                local nA, nB = math.max(0, nLow + nTurn), math.min(1, nHigh + nTurn);
                if (nB > nA) then tIntervals[#tIntervals + 1] = {nA, nB}; end
            end
        elseif (nMode == 1 or tSettings.Origin == tSettings.ReserveOrigin or _Opposite[tSettings.Origin] == tSettings.ReserveOrigin) then
            local bSame = nMode == 1 and tSettings.Direction == tSettings.ReserveDirection
                or nMode == 0 and tSettings.Origin == tSettings.ReserveOrigin;
            tIntervals[1] = bSame and {0, nReserve} or {1 - nReserve, 1};
        elseif (nReserve > 0) then
            local nLow, nHigh = math.huge, -math.huge;
            local b = tPoints[#tPoints];
            for _, a in ipairs(tPoints) do
                local nA, nB = fLinear(tSettings.ReserveOrigin, a.X, a.Y), fLinear(tSettings.ReserveOrigin, b.X, b.Y);
                if (nA >= nReserve) then local nU = fLinear(tSettings.Origin, a.X, a.Y); nLow, nHigh = math.min(nLow, nU), math.max(nHigh, nU); end
                if ((nA < nReserve) ~= (nB < nReserve)) then
                    local nT = (nReserve - nA) / (nB - nA);
                    local nU = fLinear(tSettings.Origin, a.X + (b.X - a.X) * nT, a.Y + (b.Y - a.Y) * nT);
                    nLow, nHigh = math.min(nLow, nU), math.max(nHigh, nU);
                end
                b = a;
            end
            if (nLow <= nHigh) then return nLow + nCurrent * (nHigh - nLow); end
            return 0;
        end
        table.sort(tIntervals, function(a, b) return a[1] < b[1]; end);
        local nUsable = 1;
        for _, tInterval in ipairs(tIntervals) do nUsable = nUsable - (tInterval[2] - tInterval[1]); end
        local nRemaining, nCursor = nCurrent * math.max(0, nUsable), 0;
        for _, tInterval in ipairs(tIntervals) do
            local nGap = tInterval[1] - nCursor;
            if (nRemaining <= nGap) then break; end
            nRemaining = nRemaining - nGap; nCursor = tInterval[2];
        end
        return math.min(1, nCursor + nRemaining);
    end

    --[[!
    @fqxn wxLuma.ProgressShapeGeometry.prepare.paint
    @desc Splits scanlines at polygon, ring, fill and reserve boundaries. Samples
        one midpoint per constant span; work scales with edges and scanlines.
    !]]
    function tResult.paint(oDC, nReserve, nCurrent, tBrushes)
        local nThreshold = tResult.threshold(nReserve, nCurrent);
        local tRadii, tSlopes, tVertical = {}, {}, {};
        --[[!
        @fqxn wxLuma.ProgressShapeGeometry.prepare.paint.boundary
        @desc Prepares radial distances, ray slopes and vertical cuts once per
            value update, rather than recalculating trigonometry on every row.
        !]]
        local function fBoundary(sPolicy, nFraction, nAngle)
            if (nMode == 2) then
                local nRadians = math.rad(nAngle + (sPolicy == "CW" and 1 or -1) * nFraction * 360);
                local nCos = math.cos(nRadians);
                if (math.abs(nCos) > 1e-10) then tSlopes[#tSlopes + 1] = math.sin(nRadians) / nCos; end
            elseif (nMode == 1) then
                tRadii[#tRadii + 1] = sPolicy == "outward" and nInner + (nOuter - nInner) * nFraction or nOuter - (nOuter - nInner) * nFraction;
            elseif (sPolicy == "left" or sPolicy == "right") then
                tVertical[#tVertical + 1] = nMinX + (nMaxX - nMinX) * (sPolicy == "left" and nFraction or 1 - nFraction);
            end
        end
        if (nMode ~= 0) then
            tRadii = {nInner, nOuter};
            fBoundary(tSettings.Direction, 0, tSettings.StartAngle); fBoundary(tSettings.Direction, nThreshold, tSettings.StartAngle);
            fBoundary(tSettings.ReserveDirection, 0, tSettings.ReserveStartAngle); fBoundary(tSettings.ReserveDirection, nReserve, tSettings.ReserveStartAngle);
        else fBoundary(tSettings.Origin, nThreshold); fBoundary(tSettings.ReserveOrigin, nReserve); end
        local tBreaks;
        --[[!
        @fqxn wxLuma.ProgressShapeGeometry.prepare.paint.add
        @desc Converts an analytic crossing to a clamped pixel-center boundary.
        !]]
        local function fAdd(nX)
            local nPosition = nX - 0.5;
            tBreaks[#tBreaks + 1] = math.max(0, math.min(nWidth, math.ceil(nPosition)));
            -- Isolate a pixel exactly on an analytic edge. Its classification
            -- must not depend on a moving fill cut changing the span midpoint.
            local nNearest = math.floor(nPosition + 0.5);
            if (math.abs(nPosition - nNearest) < 1e-10) then
                tBreaks[#tBreaks + 1] = math.max(0, math.min(nWidth, nNearest));
                tBreaks[#tBreaks + 1] = math.max(0, math.min(nWidth, nNearest + 1));
            end
        end
        for nY = 0, nHeight - 1 do
            local nSampleY = nY + 0.5;
            local tRowEdges = tRows[nY + 1];
            tBreaks = {0, nWidth};
            for _, nX in ipairs(tRowEdges) do fAdd(nX); end
            local nDY = nSampleY - nCY;
            for _, nRadiusAt in ipairs(tRadii) do
                if (math.abs(nDY) < nRadiusAt) then
                    local nDX = math.sqrt(nRadiusAt^2 - nDY^2); fAdd(nCX - nDX); fAdd(nCX + nDX);
                end
            end
            for _, nSlope in ipairs(tSlopes) do fAdd(nCX - nDY * nSlope); end
            for _, nX in ipairs(tVertical) do fAdd(nX); end
            table.sort(tBreaks);
            for nIndex = 1, #tBreaks - 1 do
                local nA, nB = tBreaks[nIndex], tBreaks[nIndex + 1];
                if (nB > nA) then
                    local nU, nV = tResult.coordinates((nA + nB) / 2, nSampleY, tRowEdges);
                    if (nU) then
                        local sPart = (nReserve >= 1 or nV < nReserve) and "Reserve"
                            or nCurrent > 0 and (nCurrent >= 1 or nU < nThreshold) and "Fill" or "Track";
                        oDC:SetBrush(tBrushes[sPart]); oDC:DrawRectangle(nA, nY, nB - nA, 1);
                    end
                end
            end
        end
    end
    --[[!
    @fqxn wxLuma.ProgressShapeGeometry.prepare.reservePlan
    @desc Prepares immutable track/reserve spans and usable row intervals once
        per reserved amount. Value-only updates reuse this plan and its base image.
    !]]
    function tResult.reservePlan(nReserve)
        local tPlan = {Reserved = nReserve, Base = {}, Rows = {}};
        local sPart;
        local oCollector = {};
        function oCollector:SetBrush(sNext) sPart = sNext; end
        function oCollector:DrawRectangle(x, y, width, height)
            tPlan.Base[#tPlan.Base + 1] = {x, y, width, height, sPart};
            if (sPart == "Track") then
                local tRow = tPlan.Rows[y] or {}; tPlan.Rows[y] = tRow;
                tRow[#tRow + 1], tRow[#tRow + 2] = x, x + width;
            end
        end
        tResult.paint(oCollector, nReserve, 0, {Track = "Track", Fill = "Fill", Reserve = "Reserve"});
        return tPlan;
    end

    --[[!
    @fqxn wxLuma.ProgressShapeGeometry.prepare.paintBase
    @desc Paints a prepared track/reserve layer without rebuilding its geometry.
    !]]
    function tResult.paintBase(oDC, tPlan, tBrushes)
        local sPrevious;
        for _, tSpan in ipairs(tPlan.Base) do
            if (sPrevious ~= tSpan[5]) then sPrevious = tSpan[5]; oDC:SetBrush(tBrushes[sPrevious]); end
            oDC:DrawRectangle(tSpan[1], tSpan[2], tSpan[3], tSpan[4]);
        end
    end

    --[[!
    @fqxn wxLuma.ProgressShapeGeometry.prepare.paintFill
    @desc Paints only changed current inside prevalidated usable spans. Reserved
        pixels cannot be touched. Fixed polygon, band and reserve boundaries are
        reused, leaving only the moving fill boundary to calculate per update.
    !]]
    function tResult.paintFill(oDC, tPlan, nCurrent, oBrush)
        if (nCurrent <= 0) then return; end
        local nThreshold = tResult.threshold(tPlan.Reserved, nCurrent);
        local nCutRadius, tSlopes, nVertical = nil, {};
        if (nMode == 0) then
            if (tSettings.Origin == "left" or tSettings.Origin == "right") then
                nVertical = nMinX + (nMaxX - nMinX) * (tSettings.Origin == "left" and nThreshold or 1 - nThreshold);
            end
        elseif (nMode == 1) then
            nCutRadius = tSettings.Direction == "outward" and nInner + (nOuter - nInner) * nThreshold or nOuter - (nOuter - nInner) * nThreshold;
        else
            for _, nFraction in ipairs({0, nThreshold}) do
                local nAngle = math.rad(tSettings.StartAngle + (tSettings.Direction == "CW" and 1 or -1) * nFraction * 360);
                local nCos = math.cos(nAngle);
                if (math.abs(nCos) > 1e-10) then tSlopes[#tSlopes + 1] = math.sin(nAngle) / nCos; end
            end
        end
        oDC:SetBrush(oBrush);
        for nY, tRow in pairs(tPlan.Rows) do
            local nSampleY, nDY = nY + 0.5, nY + 0.5 - nCY;
            local tCuts = {};
            -- Use the same boundary-pixel isolation as the full reference painter.
            local function fCut(nX)
                local nPosition = nX - 0.5;
                tCuts[#tCuts + 1] = math.ceil(nPosition);
                local nNearest = math.floor(nPosition + 0.5);
                if (math.abs(nPosition - nNearest) < 1e-10) then tCuts[#tCuts + 1], tCuts[#tCuts + 2] = nNearest, nNearest + 1; end
            end
            if (nVertical) then fCut(nVertical); end
            if (nCutRadius and math.abs(nDY) < nCutRadius) then
                local nDX = math.sqrt(nCutRadius^2 - nDY^2);
                fCut(nCX - nDX); fCut(nCX + nDX);
            end
            for _, nSlope in ipairs(tSlopes) do fCut(nCX - nDY * nSlope); end
            for i = 1, #tRow, 2 do
                local nA, nB = tRow[i], tRow[i + 1];
                local tBreaks = {nA, nB};
                for _, nCut in ipairs(tCuts) do if (nCut > nA and nCut < nB) then tBreaks[#tBreaks + 1] = nCut; end end
                table.sort(tBreaks);
                for j = 1, #tBreaks - 1 do
                    local x, high = tBreaks[j], tBreaks[j + 1];
                    if (high > x) then
                        local nX, nU = (x + high) / 2;
                        if (nMode == 0) then nU = fLinear(tSettings.Origin, nX, nSampleY);
                        elseif (nMode == 1) then
                            nU = (math.sqrt((nX - nCX)^2 + nDY^2) - nInner) / (nOuter - nInner);
                            if (tSettings.Direction == "inward") then nU = 1 - nU; end
                        else
                            local nAngle = (math.deg(math.atan(nDY, nX - nCX)) + 90) % 360;
                            nU = ((nAngle - tSettings.StartAngle) * (tSettings.Direction == "CW" and 1 or -1)) % 360 / 360;
                        end
                        if (nCurrent >= 1 or nU < nThreshold) then oDC:DrawRectangle(x, nY, high - x, 1); end
                    end
                end
            end
        end
    end
    return tResult;
end

return Geometry;
