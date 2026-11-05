local _wx = require("wx");
local MenuRenderer = {};

--[[!
@fqxn wxLuma.UI.MenuRenderer.region
@desc Builds a native scanline region for exact circle/ellipse, diamond or square
    host geometry. Owned by the caller; used for drawing, hit tests and popup shape.
!]]
function MenuRenderer.region(sShape, nX, nY, nWidth, nHeight)
    local oRegion = _wx.wxRegion();

    if (sShape == "circle") then
        local nDiameter = math.min(nWidth, nHeight);
        nX, nY = nX + math.floor((nWidth - nDiameter) / 2), nY + math.floor((nHeight - nDiameter) / 2);
        nWidth, nHeight = nDiameter, nDiameter;
    end

    if (sShape == "square" or sShape == "rectangle") then
        oRegion:Union(nX, nY, nWidth, nHeight);
        return oRegion;
    end

    for nRow = 0, nHeight - 1 do
        local nYFraction = math.abs((nRow + 0.5) / nHeight * 2 - 1);
        local nHalf = sShape == "diamond" and (1 - nYFraction) or math.sqrt(math.max(0, 1 - nYFraction^2));
        local nLeft = math.floor(nWidth / 2 * (1 - nHalf));
        local nRight = math.ceil(nWidth / 2 * (1 + nHalf));

        if (nRight > nLeft) then
            oRegion:Union(nX + nLeft, nY + nRow, nRight - nLeft, 1);
        end
    end

    return oRegion;
end

--[[!
@fqxn wxLuma.UI.MenuRenderer.hit
@desc Tests the host shape, not an image allowed to overlap it. Rectangle rows
    use their complete row area. Images never steal neighboring menu hit targets.
!]]
function MenuRenderer.hit(tEntry, nX, nY, bRadial)
    local tItem = tEntry.Item;
    local nWidth  = bRadial and tItem.Width or tEntry.Width;
    local nHeight = tItem.Height;
    local nCenterX = tEntry.X + tEntry.Width / 2;
    local nCenterY = tEntry.Y + tEntry.Height / 2;
    local nDX = math.abs((nX - nCenterX) / (nWidth / 2));
    local nDY = math.abs((nY - nCenterY) / (nHeight / 2));

    if (not bRadial or tItem.Shape == "square") then
        return nDX <= 1 and nDY <= 1;
    elseif (tItem.Shape == "diamond") then
        return nDX + nDY <= 1;
    end

    local nRadius = math.min(nWidth, nHeight) / 2;
    return (nX - nCenterX)^2 + (nY - nCenterY)^2 <= nRadius^2;
end

--[[!
@fqxn wxLuma.UI.MenuRenderer.create
@desc Owns bounded decoded-image and rendered-item caches. Every shape and image
    clip is supersampled before alpha-aware scaling; the supplied skin is borrowed.
!]]
function MenuRenderer.create(oSkin, sArtwork, bRadial, fImageError)
    local tRenderer = {};
    local tImages, tImageOrder, tCache, tOrder = {}, {}, {}, {};
    local nScale = 3;
    local oFont = _wx.wxFont(oSkin.Font);
    oFont:SetPointSize(math.max(1, oSkin.Font:GetPointSize() * nScale));

    local function fImage(pPath)
        if (tImages[pPath] == false) then
            return nil;
        end

        if (tImages[pPath]) then
            return tImages[pPath];
        end

        local hFile = io.open(pPath, "rb");
        local oImage;

        if (hFile) then
            hFile:close();
            oImage = _wx.wxImage(pPath, _wx.wxBITMAP_TYPE_ANY);
        end

        if (not oImage or not oImage:IsOk()) then
            if (oImage) then
                oImage:delete();
            end

            tImages[pPath] = false;

            if (fImageError) then
                fImageError(pPath);
            end
        else
            tImages[pPath] = oImage;
        end

        tImageOrder[#tImageOrder + 1] = pPath;

        if (#tImageOrder > 32) then
            local pOld = table.remove(tImageOrder, 1);

            if (tImages[pOld]) then
                tImages[pOld]:delete();
            end

            tImages[pOld] = nil;
        end

        return tImages[pPath] or nil;
    end

    -- Keep colour artwork separate from its one-bit geometry mask. Converting
    -- that mask to alpha before scaling smooths edges without reserving an image
    -- colour as transparent (magenta and black remain valid artwork colours).
    local function fBuild(tEntry, sState)
        local tItem = tEntry.Item;
        local nWidth, nHeight = tEntry.Width * nScale, tEntry.Height * nScale;
        local nHostWidth = (bRadial and tItem.Width or tEntry.Width) * nScale;
        local nHostHeight = tItem.Height * nScale;
        local nHostX = math.floor((nWidth - nHostWidth) / 2);
        local nHostY = math.floor((nHeight - nHostHeight) / 2);
        local sShape = bRadial and tItem.Shape or "rectangle";
        local sFamily = bRadial and (sShape:sub(1, 1):upper()..sShape:sub(2)) or "Row";
        local oMaterial = oSkin.getBitmap((tItem.Artwork or sArtwork).." "..sFamily.." "..sState,
            nHostWidth, nHostHeight);
        local oBitmap = _wx.wxBitmap(nWidth, nHeight);
        local oMemory = _wx.wxMemoryDC();
        local oBackgroundBrush = _wx.wxBrush(_wx.wxColour(24, 29, 36));
        oMemory:SelectObject(oBitmap);
        oMemory:SetBackground(oBackgroundBrush);
        oMemory:Clear();
        local oArtBrush = _wx.wxBrush(oMaterial);
        oMemory:SetBrush(oArtBrush);
        oMemory:SetPen(_wx.wxTRANSPARENT_PEN);

        if (sShape == "circle") then
            oMemory:DrawCircle(nHostX + math.floor(nHostWidth / 2), nHostY + math.floor(nHostHeight / 2),
                math.floor(math.min(nHostWidth, nHostHeight) / 2));
        elseif (sShape == "diamond") then
            local tPoints = {
                _wx.wxPoint(nHostX + math.floor(nHostWidth / 2), nHostY),
                _wx.wxPoint(nHostX + nHostWidth, nHostY + math.floor(nHostHeight / 2)),
                _wx.wxPoint(nHostX + math.floor(nHostWidth / 2), nHostY + nHostHeight),
                _wx.wxPoint(nHostX, nHostY + math.floor(nHostHeight / 2))
            };
            oMemory:DrawPolygon(tPoints);

            for _, oPoint in ipairs(tPoints) do
                oPoint:delete();
            end
        else
            oMemory:DrawRectangle(nHostX, nHostY, nHostWidth, nHostHeight);
        end

        oArtBrush:delete();

        if (tItem.Image) then
            local oImage = fImage(tItem.Image);

            if (oImage) then
                local nImageWidth = (bRadial and tItem.ImageWidth or math.min(tItem.ImageWidth, tEntry.Height - 8)) * nScale;
                local nImageHeight = (bRadial and tItem.ImageHeight or math.min(tItem.ImageHeight, tEntry.Height - 8)) * nScale;
                local nImageX = bRadial and math.floor((nWidth - nImageWidth) / 2) or 4 * nScale;
                local nImageY = math.floor((nHeight - nImageHeight) / 2);
                local oScaled = oImage:Scale(nImageWidth, nImageHeight, _wx.wxIMAGE_QUALITY_HIGH);
                local oImageBitmap = _wx.wxBitmap(oScaled);

                oMemory:DrawBitmap(oImageBitmap, nImageX, nImageY, true);
                oImageBitmap:delete();
                oScaled:delete();

            end
        end

        local nTextBoxWidth = nHostWidth - 8 * nScale;
        local nTextBoxHeight = nHostHeight - 4 * nScale;
        local nTextBoxX = nHostX + math.floor((nHostWidth - nTextBoxWidth) / 2);
        local nTextBoxY = nHostY + math.floor((nHostHeight - nTextBoxHeight) / 2);
        local oTextClip = _wx.wxDCClipper(oMemory,
            _wx.wxRect(nTextBoxX, nTextBoxY, math.max(1, nTextBoxWidth), math.max(1, nTextBoxHeight)));
        oMemory:SetFont(oFont);
        oMemory:SetBackgroundMode(_wx.wxTRANSPARENT);
        oMemory:SetTextForeground(sState == "Disabled" and _wx.wxColour(114, 126, 139)
            or _wx.wxColour(225, 233, 242));
        local sText = tItem.Text;
        local nTextWidth, nTextHeight = oMemory:GetTextExtent(sText);
        local nTextX = bRadial and math.floor((nWidth - nTextWidth) / 2)
            or (tItem.Image and math.min(tItem.ImageWidth, tEntry.Height - 8) + 12 or 10) * nScale;
        local nTextY = bRadial and tItem.Image and nHostY + math.floor(nHostHeight * 0.6 - nTextHeight / 2)
            or math.floor((nHeight - nTextHeight) / 2);
        if (tItem.Image and sText ~= "") then
            oMemory:SetTextForeground(_wx.wxColour(8, 12, 18));
            oMemory:DrawText(sText, nTextX + nScale, nTextY + nScale);
            oMemory:SetTextForeground(sState == "Disabled" and _wx.wxColour(114, 126, 139)
                or _wx.wxColour(225, 233, 242));
        end

        oMemory:DrawText(sText, nTextX, nTextY);

        if (tItem.Items and not bRadial) then
            oMemory:DrawText(">", nWidth - 16 * nScale, math.floor((nHeight - nTextHeight) / 2));
        end

        oTextClip:delete();
        -- A separate monochrome bitmap describes exact host coverage. This clips
        -- artwork and captions without optional wxDC region-clipping bindings.
        local oMaskBitmap = _wx.wxBitmap(nWidth, nHeight, 1);
        local oMaskDC = _wx.wxMemoryDC();
        local oBlack = _wx.wxBrush(_wx.wxColour(0, 0, 0));
        local oWhite = _wx.wxBrush(_wx.wxColour(255, 255, 255));
        oMaskDC:SelectObject(oMaskBitmap);
        oMaskDC:SetBackground(oBlack);
        oMaskDC:Clear();
        oMaskDC:SetPen(_wx.wxTRANSPARENT_PEN);
        oMaskDC:SetBrush(oWhite);

        for nRow = 0, nHeight - 1 do
            local nLeft, nRight = nHostX, nHostX + nHostWidth;
            local nRelativeY = nRow - nHostY;

            if (nRelativeY < 0 or nRelativeY >= nHostHeight) then
                nLeft, nRight = nWidth, nWidth;
            elseif (sShape == "circle") then
                local nDiameter = math.min(nHostWidth, nHostHeight);
                local nOffsetY = math.floor((nHostHeight - nDiameter) / 2);
                local nDY = math.abs((nRelativeY - nOffsetY + 0.5) / nDiameter * 2 - 1);
                local nHalf = math.sqrt(math.max(0, 1 - nDY^2));
                local nOffsetX = math.floor((nHostWidth - nDiameter) / 2);
                nLeft = nHostX + nOffsetX + math.floor(nDiameter / 2 * (1 - nHalf));
                nRight = nHostX + nOffsetX + math.ceil(nDiameter / 2 * (1 + nHalf));
            elseif (sShape == "diamond") then
                local nHalf = math.max(0, 1 - math.abs((nRelativeY + 0.5) / nHostHeight * 2 - 1));
                nLeft = nHostX + math.floor(nHostWidth / 2 * (1 - nHalf));
                nRight = nHostX + math.ceil(nHostWidth / 2 * (1 + nHalf));
            end

            if (nRight > nLeft) then
                oMaskDC:DrawRectangle(nLeft, nRow, nRight - nLeft, 1);
            end
        end

        oMaskDC:SelectObject(_wx.wxNullBitmap);
        oMaskDC:delete();
        oBlack:delete();
        oWhite:delete();
        oMemory:SelectObject(_wx.wxNullBitmap);
        oMemory:delete();
        oBitmap:SetMask(_wx.wxMask(oMaskBitmap));
        oMaskBitmap:delete();
        oBackgroundBrush:delete();
        local oImage = oBitmap:ConvertToImage();
        oImage:InitAlpha();
        oImage:SetMask(false);
        local oScaled = oImage:Scale(tEntry.Width, tEntry.Height, _wx.wxIMAGE_QUALITY_HIGH);
        local oResult = _wx.wxBitmap(oScaled);
        oScaled:delete();
        oImage:delete();
        oBitmap:delete();
        return oResult;
    end

    --[[!
    @fqxn wxLuma.UI.MenuRenderer.draw
    @desc Alpha-draws one cached menu item in its measured footprint.
    !]]
    function tRenderer.draw(oDC, tEntry, sState)
        local sKey = table.concat({tEntry.Item.Id, sState, tEntry.Width, tEntry.Height}, ":");

        if (not tCache[sKey]) then
            tCache[sKey] = fBuild(tEntry, sState);
            tOrder[#tOrder + 1] = sKey;

        end

        if (bRadial and tEntry.Item.Image and not tEntry.Item.ClipImage) then
            local sImageKey = sKey..":image";
            local oImage = fImage(tEntry.Item.Image);

            if (oImage and not tCache[sImageKey]) then
                local oScaled = oImage:Scale(tEntry.Item.ImageWidth, tEntry.Item.ImageHeight, _wx.wxIMAGE_QUALITY_HIGH);
                tCache[sImageKey] = _wx.wxBitmap(oScaled);
                oScaled:delete();
                tOrder[#tOrder + 1] = sImageKey;
            end

            if (tCache[sImageKey]) then
                oDC:DrawBitmap(tCache[sImageKey], tEntry.X + math.floor((tEntry.Width - tEntry.Item.ImageWidth) / 2),
                    tEntry.Y + math.floor((tEntry.Height - tEntry.Item.ImageHeight) / 2), true);
            end
        end

        oDC:DrawBitmap(tCache[sKey], tEntry.X, tEntry.Y, true);

        while (#tOrder > 96) do
            local sOld = table.remove(tOrder, 1);
            tCache[sOld]:delete();
            tCache[sOld] = nil;
        end
    end

    --[[!
    @fqxn wxLuma.UI.MenuRenderer.clear
    @desc Invalidates item artwork after descriptor changes; decoded sources remain.
    !]]
    function tRenderer.clear()
        for _, oBitmap in pairs(tCache) do
            oBitmap:delete();
        end

        tCache, tOrder = {}, {};
    end

    --[[!
    @fqxn wxLuma.UI.MenuRenderer.destroy
    @desc Releases all owned native images, item bitmaps and the scaled font once.
    !]]
    function tRenderer.destroy()
        tRenderer.clear();

        for _, oImage in pairs(tImages) do
            if (oImage) then
                oImage:delete();
            end
        end

        tImages, tImageOrder = {}, {};
        oFont:delete();
    end

    return tRenderer;
end

return MenuRenderer;