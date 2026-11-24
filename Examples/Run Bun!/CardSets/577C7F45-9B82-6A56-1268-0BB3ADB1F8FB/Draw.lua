--[[!
@fqxn Run Bun!.Alpha.Draw
@desc Draws this card face. Add drawing calls inside the returned function.
]]
return function(sObject, D, hDC)
    local tRow          = _tRow;
    local nWidth        = _nCardWidth;
    local nHeight       = _nCardHeight;

    --artwork bounds scaled to the current card dimensions
    local tArtBounds = {
        Bun     = {X = nWidth * 0.05333333, Y = nHeight * 0.16355556, Width = nWidth * 0.89333333, Height = nHeight * 0.43822222},
        Dog     = {X = nWidth * 0.06181818, Y = nHeight * 0.17066667, Width = nWidth * 0.86787879, Height = nHeight * 0.43111111},
        Chase   = {X = nWidth * 0.05575758, Y = nHeight * 0.16888889, Width = nWidth * 0.88727273, Height = nHeight * 0.43022222},
        Lure    = {X = nWidth * 0.05696970, Y = nHeight * 0.17244444, Width = nWidth * 0.88484848, Height = nHeight * 0.42755556},
        Nice    = {X = nWidth * 0.05212121, Y = nHeight * 0.16266667, Width = nWidth * 0.89212121, Height = nHeight * 0.43911111},
        Nasty   = {X = nWidth * 0.05818182, Y = nHeight * 0.16888889, Width = nWidth * 0.88363636, Height = nHeight * 0.42577778},
        Panic   = {X = nWidth * 0.06303030, Y = nHeight * 0.16888889, Width = nWidth * 0.86909091, Height = nHeight * 0.42755556},
        Startle = {X = nWidth * 0.06787879, Y = nHeight * 0.17955556, Width = nWidth * 0.86545455, Height = nHeight * 0.41600000},
        Sniff   = {X = nWidth * 0.08000000, Y = nHeight * 0.18133333, Width = nWidth * 0.84242424, Height = nHeight * 0.40711111},
        Prep    = {X = nWidth * 0.08848485, Y = nHeight * 0.18400000, Width = nWidth * 0.82424242, Height = nHeight * 0.37866667},
    };

    --type positions scaled to the current card dimensions; Bun and Dog X mark the right edge
    local tTypePositions = {
        Bun     = {X = nWidth * 0.90000000, Y = nHeight * 0.64444444},
        Dog     = {X = nWidth * 0.90000000, Y = nHeight * 0.64000000},
        Chase   = {X = nWidth / 2, Y = nHeight * 0.64000000},
        Lure    = {X = nWidth / 2, Y = nHeight * 0.64000000},
        Nice    = {X = nWidth / 2, Y = nHeight * 0.64444444},
        Nasty   = {X = nWidth / 2, Y = nHeight * 0.64000000},
        Panic   = {X = nWidth / 2, Y = nHeight * 0.64444444},
        Startle = {X = nWidth / 2, Y = nHeight * 0.64000000},
        Sniff   = {X = nWidth / 2, Y = nHeight * 0.64000000},
        Prep    = {X = nWidth / 2, Y = nHeight * 0.59200000},
    };

    local sType         = tRow.Type;
    local sNameStyle    = sType.."Name";
    local pImages       = _pCardSet.."/Images";
    local pComponents   = pImages.."/Components";
    local pFrame        = pComponents.."/Frame "..sType..".png";
    local pArt          = pImages..'/'..sType..'/'.._tRow.Name..".png";

    local tBounds       = tArtBounds[sType];

    --draw the art
    Forge.DrawImageCropped(pArt, tBounds.X + tBounds.Width / 2, tBounds.Y + tBounds.Height / 2,
        tBounds.Width, tBounds.Height);

    --draw the frame
    Forge.DrawImage(pFrame, 0, 0, nWidth, nHeight);

    --select the inherited Bun name color by sex
    if (sType == "Bun" and (tRow.Sex == "M" or tRow.Sex == "F")) then
        sNameStyle = "BUNNAME_"..tRow.Sex;
    end

    --draw the card name
    Forge.DrawText(sNameStyle, nWidth / 2, (nHeight / 2) * 0.215, tRow.Name:gsub("-[qQ]", '?'), true, true);
    --draw Bun and Dog tags on the left and their card type on the right
    local tTypePosition = tTypePositions[sType];
    if (sType == "Bun" or sType == "Dog") then
        local sTypeText      = sType:upper();
        local nTypeWidth, nTypeHeight, nTypeMinX = STYLE["TYPE"].Prep(D, sTypeText);
        Forge.DrawText("TYPE", tTypePosition.X - nTypeWidth - nTypeMinX, tTypePosition.Y, sTypeText, false, true);

        STYLE["INFORMATION"].Prep(D, tRow.Tags or "");
        local nTagX         = nWidth * 0.10000000;
        local sSeparator    = "";
        for sTag in (tRow.Tags or ""):gmatch("[^,]+") do
            sTag = sTag:match("^%s*(.-)%s*$");
            local nTagY = tTypePosition.Y - D.GetTextHeight(sSeparator..sTag) / 2;
            if (sSeparator ~= "") then
                Forge.DrawText("INFORMATION", nTagX, nTagY, sSeparator, false, false);
                nTagX = nTagX + D.GetTextWidth(sSeparator);
            end
            D.DrawText(nTagX, nTagY, sTag, CFG.Tag[sType][sTag].Color);
            nTagX = nTagX + D.GetTextWidth(sTag);
            sSeparator = ", ";
        end
    else
        Forge.DrawText("TYPE", tTypePosition.X, tTypePosition.Y, sType:upper(), true, true);
    end

    --wrap each flavor paragraph inside the lower panel, preserving explicit line breaks
    local sFlavor = tRow.Flavor or "";
    if (sFlavor ~= "") then
        local tModes = {"Wrap"};
        for sBreak in sFlavor:gsub("\r\n", "\n"):gsub("\r", "\n"):gmatch("\n") do
            tModes[#tModes + 1] = "Wrap";
        end
        Forge.DrawStyledTextFit("FLAVOR", nWidth * 0.10000000, nHeight * 0.85000000,
            sFlavor, nWidth * 0.80000000, tModes);
    end
end
