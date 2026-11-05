local MenuLayout = {};

--[[!
@fqxn wxLuma.UI.MenuLayout.footprint
@desc Measures the host plus explicitly unclipped image extents. These conservative
    rectangular footprints guarantee spacing even for mixed shapes and item sizes.
@param table tItem Normalized item descriptor.
@ret number nWidth Required width.
@ret number nHeight Required height.
!]]
function MenuLayout.footprint(tItem)
    return math.max(tItem.Width, tItem.Image and not tItem.ClipImage and tItem.ImageWidth or 0),
        math.max(tItem.Height, tItem.Image and not tItem.ClipImage and tItem.ImageHeight or 0);
end

-- Build evenly spaced centers; native coordinates are rounded before collision
-- checks so the final painted items retain the requested minimum gap.
local function radialEntries(tItems, tOptions, nRadius)
    local tEntries = {};
    local nMinX, nMinY, nMaxX, nMaxY = math.huge, math.huge, -math.huge, -math.huge;
    local nSign = tOptions.Direction == "CW" and 1 or -1;

    for nIndex, tItem in ipairs(tItems) do
        local nAngle = (tOptions.StartAngle + nSign * 360 * (nIndex - 1) / #tItems) * math.pi / 180;
        local nWidth, nHeight = MenuLayout.footprint(tItem);
        local nX = math.floor(math.sin(nAngle) * nRadius - nWidth / 2 + 0.5);
        local nY = math.floor(-math.cos(nAngle) * nRadius - nHeight / 2 + 0.5);
        tEntries[nIndex] = {Item = tItem, X = nX, Y = nY, Width = nWidth, Height = nHeight};
        nMinX, nMinY = math.min(nMinX, nX), math.min(nMinY, nY);
        nMaxX, nMaxY = math.max(nMaxX, nX + nWidth), math.max(nMaxY, nY + nHeight);
    end

    return tEntries, nMinX, nMinY, nMaxX, nMaxY;
end

local function separated(tEntries, nSpacing)
    for nIndex, tLeft in ipairs(tEntries) do
        for nOther = nIndex + 1, #tEntries do
            local tRight = tEntries[nOther];
            local nDX = math.max(tLeft.X - tRight.X - tRight.Width, tRight.X - tLeft.X - tLeft.Width);
            local nDY = math.max(tLeft.Y - tRight.Y - tRight.Height, tRight.Y - tLeft.Y - tLeft.Height);

            if ((nDX < 0 and nDY < 0)
                or math.max(0, nDX)^2 + math.max(0, nDY)^2 < nSpacing^2) then
                return false;
            end
        end
    end

    return true;
end

--[[!
@fqxn wxLuma.UI.MenuLayout.radial
@desc Finds a fitting ring within the radius range. Radius measures item centers;
    containment considers full footprints. No item is resized to make it fit.
@param table tItems Ordered page entries, including any Back/More controls.
@param table tOptions Direction, StartAngle, Spacing, MinRadius and MaxRadius.
@param number nAvailableWidth Containment width.
@param number nAvailableHeight Containment height.
@ret table|nil tLayout Entries, Width/Height, AnchorX/Y and Radius; nil when impossible.
!]]
function MenuLayout.radial(tItems, tOptions, nAvailableWidth, nAvailableHeight)
    if (#tItems == 0) then
        return nil;
    end

    local nLow, nHigh = tOptions.MinRadius, tOptions.MaxRadius;
    local tAtMax = radialEntries(tItems, tOptions, nHigh);

    if (not separated(tAtMax, tOptions.Spacing)) then
        return nil;
    end

    -- Search a continuous radius, then inspect nearby pixel positions. The final
    -- collision test uses the actual rounded layout, including non-adjacent pairs.
    for nPass = 1, 24 do
        local nMiddle = (nLow + nHigh) / 2;
        local tMiddle = radialEntries(tItems, tOptions, nMiddle);

        if (separated(tMiddle, tOptions.Spacing)) then
            nHigh = nMiddle;
        else
            nLow = nMiddle;
        end
    end

    for nPass = 0, 4 do
        local nRadius = math.min(tOptions.MaxRadius, nHigh + nPass * 0.5);
        local tEntries, nMinX, nMinY, nMaxX, nMaxY = radialEntries(tItems, tOptions, nRadius);
        local nWidth, nHeight = nMaxX - nMinX + 8, nMaxY - nMinY + 8;

        if (separated(tEntries, tOptions.Spacing) and nWidth <= nAvailableWidth and nHeight <= nAvailableHeight) then
            for _, tEntry in ipairs(tEntries) do
                tEntry.X, tEntry.Y = tEntry.X - nMinX + 4, tEntry.Y - nMinY + 4;
            end

            return {Entries = tEntries, Width = nWidth, Height = nHeight,
                AnchorX = 4 - nMinX, AnchorY = 4 - nMinY, Radius = nRadius};
        end
    end
end

--[[!
@fqxn wxLuma.UI.MenuLayout.context
@desc Stacks measured rows without resizing them. Excess rows are paginated by
    the menu engine, which reserves Back/More before committing a page.
!]]
function MenuLayout.context(tItems, tOptions, nAvailableWidth, nAvailableHeight)
    local nWidth, nHeight = tOptions.Width, 8;
    local nSpacing = math.ceil(tOptions.Spacing);

    for _, tItem in ipairs(tItems) do
        nWidth = math.max(nWidth, tItem.Width + 8);
        nHeight = nHeight + tItem.Height + nSpacing;
    end

    nHeight = nHeight - (#tItems > 0 and nSpacing or 0);

    if (#tItems == 0 or nWidth > nAvailableWidth or nHeight > nAvailableHeight) then
        return nil;
    end

    local tEntries = {};
    local nY = 4;

    for nIndex, tItem in ipairs(tItems) do
        tEntries[nIndex] = {Item = tItem, X = 4, Y = nY, Width = nWidth - 8, Height = tItem.Height};
        nY = nY + tItem.Height + nSpacing;
    end

    return {Entries = tEntries, Width = nWidth, Height = nHeight, AnchorX = 0, AnchorY = 0, Radius = 0};
end

--[[!
@fqxn wxLuma.UI.MenuLayout.capacityBound
@desc Bounds a candidate page using the smallest footprint's inscribed circle.
    This avoids repeatedly constructing huge impossible rings for large item sets.
!]]
function MenuLayout.capacityBound(tItems, tOptions, bRadial, nAvailableHeight)
    local nSmallest = math.min(tOptions.ItemWidth, tOptions.ItemHeight);

    for _, tItem in ipairs(tItems) do
        local nWidth, nHeight = MenuLayout.footprint(tItem);
        nSmallest = math.min(nSmallest, bRadial and math.min(nWidth, nHeight) or nHeight);
    end

    if (not bRadial) then
        return math.max(1, math.floor(nAvailableHeight / math.max(1, nSmallest + tOptions.Spacing)));
    end

    local nDistance = nSmallest + tOptions.Spacing;

    if (tOptions.MaxRadius <= 0 or nDistance > 2 * tOptions.MaxRadius) then
        return 1;
    end

    return math.max(2, math.floor(math.pi / math.asin(math.min(1, nDistance / (2 * tOptions.MaxRadius)))));
end

return MenuLayout;