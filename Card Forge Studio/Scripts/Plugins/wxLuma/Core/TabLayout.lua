local TabLayout = {};

--[[!
@fqxn wxLuma.UI.TabLayout.compute
@desc Computes measured-width wrapped or scrolling headers on any edge. If a
    wrapped strip would consume the page, it falls back to scrolling. Clipped
    entries retain full drawing bounds and separate visible hit-test bounds.
@param table tWidths Natural tab widths in display order.
@param number nWidth Client width.
@param number nHeight Client height.
@param string sMode wrap or scroll.
@param string sPosition top, bottom, left or right.
@param number nOffset Requested scroll pixels.
@param number|nil nEnsure Selected index to reveal, or nil to preserve manual scroll.
@ret table tPlan Entries, Page, Viewport, optional Back/Forward, Mode, Offset, Maximum.
!]]
function TabLayout.compute(tWidths, nWidth, nHeight, sMode, sPosition, nOffset, nEnsure)
    local bVertical = sPosition == "left" or sPosition == "right";
    local nAvailableW, nAvailableH = math.max(1, nWidth - 8), math.max(1, nHeight - 8);
    local tPlan = {Entries = {}, Mode = sMode, Offset = 0, Maximum = 0, Vertical = bVertical};
    local nColumn = 1;
    for _, nSize in ipairs(tWidths) do
        nColumn = math.max(nColumn, math.min(nSize, nAvailableW));
    end
    local tRaw = {};
    local nHeaderWidth, nHeaderHeight;
    if (#tWidths == 0) then
        nHeaderWidth, nHeaderHeight = 0, 0;
    elseif (sMode == "wrap") then
        if (bVertical) then
            local nRows = math.max(1, math.floor(nAvailableH / 36));
            local nColumns = math.ceil(#tWidths / nRows);
            nHeaderWidth, nHeaderHeight = nColumns * nColumn, nAvailableH;
            for nIndex in ipairs(tWidths) do
                tRaw[nIndex] = {X = math.floor((nIndex - 1) / nRows) * nColumn,
                    Y = ((nIndex - 1) % nRows) * 36, Width = nColumn, Height = 36};
            end
            if (nHeaderWidth > nAvailableW - 64) then
                tPlan.Mode = "scroll";
            end
        else
            local nX, nY = 0, 0;
            for nIndex, nSize in ipairs(tWidths) do
                nSize = math.min(nSize, nAvailableW);
                if (nX > 0 and nX + nSize > nAvailableW) then
                    nX, nY = 0, nY + 36;
                end
                tRaw[nIndex] = {X = nX, Y = nY, Width = nSize, Height = 36};
                nX = nX + nSize;
            end
            nHeaderWidth, nHeaderHeight = nAvailableW, nY + 36;
            if (nHeaderHeight > nAvailableH - 40) then
                tPlan.Mode = "scroll";
            end
        end
    end
    local nExtent = 0;
    if (#tWidths > 0 and tPlan.Mode == "scroll") then
        tRaw = {};
        for nIndex, nSize in ipairs(tWidths) do
            tRaw[nIndex] = {X = bVertical and 0 or nExtent, Y = bVertical and nExtent or 0,
                Width = bVertical and nColumn or nSize, Height = 36};
            nExtent = nExtent + (bVertical and 36 or nSize);
        end
        nHeaderWidth = bVertical and math.min(nColumn, math.max(1, nAvailableW - 1)) or nAvailableW;
        nHeaderHeight = bVertical and nAvailableH or math.min(36, nAvailableH);
    end
    nHeaderWidth, nHeaderHeight = nHeaderWidth or 0, nHeaderHeight or 0;
    local nHeaderX = sPosition == "right" and nWidth - 4 - nHeaderWidth or 4;
    local nHeaderY = sPosition == "bottom" and nHeight - 4 - nHeaderHeight or 4;
    local tView = {X = nHeaderX, Y = nHeaderY, Width = nHeaderWidth, Height = nHeaderHeight};
    tPlan.Page = {X = 4, Y = 4, Width = nAvailableW, Height = nAvailableH};
    if (#tWidths > 0) then
        if (bVertical) then
            tPlan.Page.X = sPosition == "left" and 4 + nHeaderWidth or 4;
            tPlan.Page.Width = math.max(1, nAvailableW - nHeaderWidth);
        else
            tPlan.Page.Y = sPosition == "top" and 4 + nHeaderHeight or 4;
            tPlan.Page.Height = math.max(1, nAvailableH - nHeaderHeight);
        end
    end
    if (tPlan.Mode == "scroll" and nExtent > (bVertical and tView.Height or tView.Width)) then
        local nButton = math.min(28, math.floor((bVertical and tView.Height or tView.Width) / 3));
        tPlan.Back = {X = tView.X, Y = tView.Y,
            Width = bVertical and tView.Width or nButton, Height = bVertical and nButton or tView.Height};
        tPlan.Forward = {X = bVertical and tView.X or tView.X + tView.Width - nButton,
            Y = bVertical and tView.Y + tView.Height - nButton or tView.Y,
            Width = tPlan.Back.Width, Height = tPlan.Back.Height};
        if (bVertical) then
            tView.Y, tView.Height = tView.Y + nButton, math.max(1, tView.Height - nButton * 2);
        else
            tView.X, tView.Width = tView.X + nButton, math.max(1, tView.Width - nButton * 2);
        end
        tPlan.Maximum = math.max(0, nExtent - (bVertical and tView.Height or tView.Width));
        nOffset = math.max(0, math.min(tPlan.Maximum, nOffset));
        if (nEnsure and tRaw[nEnsure]) then
            local tTarget = tRaw[nEnsure];
            local nStart = bVertical and tTarget.Y or tTarget.X;
            local nSize = bVertical and tTarget.Height or tTarget.Width;
            local nVisible = bVertical and tView.Height or tView.Width;
            if (nStart < nOffset) then
                nOffset = nStart;
            elseif (nStart + nSize > nOffset + nVisible) then
                nOffset = nStart + math.min(nSize, nVisible) - nVisible;
            end
        end
        tPlan.Offset = math.max(0, math.min(tPlan.Maximum, nOffset));
    end
    tPlan.Viewport = tView;
    for nIndex, tRect in ipairs(tRaw) do
        local nX = tView.X + tRect.X - (not bVertical and tPlan.Offset or 0);
        local nY = tView.Y + tRect.Y - (bVertical and tPlan.Offset or 0);
        local nLeft, nTop = math.max(nX, tView.X), math.max(nY, tView.Y);
        local nRight = math.min(nX + tRect.Width, tView.X + tView.Width);
        local nBottom = math.min(nY + tRect.Height, tView.Y + tView.Height);
        if (nRight > nLeft and nBottom > nTop) then
            tPlan.Entries[#tPlan.Entries + 1] = {Index = nIndex, X = nLeft, Y = nTop,
                Width = nRight - nLeft, Height = nBottom - nTop,
                DrawX = nX, DrawY = nY, DrawWidth = tRect.Width, DrawHeight = tRect.Height};
        end
    end
    return tPlan;
end

return TabLayout;
