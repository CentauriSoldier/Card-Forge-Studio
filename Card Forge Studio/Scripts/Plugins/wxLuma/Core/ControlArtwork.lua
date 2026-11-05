local _wx = require("wx");
local ControlArtwork = {};

--[[!
@fqxn wxLuma.UI.ControlArtwork.create
@desc Creates private drawing helpers. Every decorative color comes from Skin;
    image paths own decoded/scaled resources while Skin retains its own bitmaps.
@param table oSkin Shared skin.
@param string sPrefix Artwork family prefix.
@ret table tArt Private draw/text/image/destroy helpers.
!]]
function ControlArtwork.create(oSkin, sPrefix)
    local tColors, tImages, tScaled = {}, {}, {};
    local tArt = {};

    --[[!
    @fqxn wxLuma.UI.ControlArtwork.color
    @desc Samples a skin material as a native color; callers borrow the result.
    @param string sPart Palette part such as Text Normal or Surface Normal.
    @ret wxColour oColor Borrowed palette entry.
    !]]
    function tArt.color(sPart)
        if (not tColors[sPart]) then
            local oImage = oSkin.getBitmap(sPrefix.." "..sPart):ConvertToImage();
            tColors[sPart] = _wx.wxColour(oImage:GetRed(0, 0), oImage:GetGreen(0, 0), oImage:GetBlue(0, 0));
            oImage:delete();
        end
        return tColors[sPart];
    end

    --[[!
    @fqxn wxLuma.UI.ControlArtwork.part
    @desc Draws one skinned part at explicit bounds without adding fixed colors.
    !]]
    function tArt.part(oDC, sPart, nX, nY, nWidth, nHeight)
        if (nWidth > 0 and nHeight > 0) then
            oSkin.draw(oDC, sPrefix.." "..sPart, nX, nY, nWidth, nHeight);
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlArtwork.text
    @desc Draws text using the skin font and sampled enabled/disabled text material.
    !]]
    function tArt.text(oDC, sText, nX, nY, bEnabled)
        oDC:SetFont(oSkin.Font);
        oDC:SetTextForeground(tArt.color(bEnabled == false and "Text Disabled" or "Text Normal"));
        oDC:SetBackgroundMode(_wx.wxTRANSPARENT);
        local _, nLineHeight = oDC:GetTextExtent("Ag");
        for sLine in (sText.."\n"):gmatch("(.-)\n") do
            oDC:DrawText(sLine, math.floor(nX), math.floor(nY));
            nY = nY + nLineHeight;
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlArtwork.prepare
    @desc Loads an optional image path before live data mutation. Failure raises
        an error; already loaded images remain owned until destroy.
    !]]
    function tArt.prepare(pPath)
        if (pPath and not tImages[pPath]) then
            assert(type(pPath) == "string", "Image must be a file path.");
            local hFile = assert(io.open(pPath, "rb"), "Cannot open image: "..pPath);
            hFile:close();
            local oImage = _wx.wxImage(pPath, _wx.wxBITMAP_TYPE_ANY);
            if (not oImage:IsOk()) then
                oImage:delete();
                error("Cannot decode image: "..pPath);
            end
            tImages[pPath] = oImage;
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlArtwork.image
    @desc Contains an owned image in a square, caching the most recent size per path.
    !]]
    function tArt.image(oDC, pPath, nX, nY, nSize)
        if (not pPath or nSize < 1) then
            return;
        end
        tArt.prepare(pPath);
        local tEntry = tScaled[pPath];
        if (not tEntry or tEntry.Size ~= nSize) then
            if (tEntry) then
                tEntry.Bitmap:delete();
            end
            local oImage = tImages[pPath];
            local nScale = nSize / math.max(oImage:GetWidth(), oImage:GetHeight());
            local nWidth = math.max(1, math.floor(oImage:GetWidth() * nScale));
            local nHeight = math.max(1, math.floor(oImage:GetHeight() * nScale));
            local oScaled = oImage:Scale(nWidth, nHeight, _wx.wxIMAGE_QUALITY_HIGH);
            tEntry = {Size = nSize, Width = nWidth, Height = nHeight, Bitmap = _wx.wxBitmap(oScaled)};
            tScaled[pPath] = tEntry;
            oScaled:delete();
        end
        oDC:DrawBitmap(tEntry.Bitmap, math.floor(nX + (nSize - tEntry.Width) / 2),
            math.floor(nY + (nSize - tEntry.Height) / 2), true);
    end

    --[[!
    @fqxn wxLuma.UI.ControlArtwork.retain
    @desc Releases decoded/scaled images no longer referenced by current item data.
    @param table tItems Current descriptor array with optional Image paths.
    !]]
    function tArt.retain(tItems)
        local tKeep = {};
        for _, tItem in ipairs(tItems) do
            if (tItem.Image) then
                tKeep[tItem.Image] = true;
            end
        end
        for pPath, oImage in pairs(tImages) do
            if (not tKeep[pPath]) then
                oImage:delete();
                tImages[pPath] = nil;
                if (tScaled[pPath]) then
                    tScaled[pPath].Bitmap:delete();
                    tScaled[pPath] = nil;
                end
            end
        end
    end

    --[[!
    @fqxn wxLuma.UI.ControlArtwork.destroy
    @desc Releases only privately owned palette and image resources; safe to repeat.
    !]]
    function tArt.destroy()
        for _, oColor in pairs(tColors) do
            oColor:delete();
        end
        for _, oImage in pairs(tImages) do
            oImage:delete();
        end
        for _, tEntry in pairs(tScaled) do
            tEntry.Bitmap:delete();
        end
        tColors, tImages, tScaled = {}, {}, {};
    end
    return tArt;
end

return ControlArtwork;
