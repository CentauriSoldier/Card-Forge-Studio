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
    Forge.DrawText(sNameStyle, nWidth / 2, (nHeight / 2) * 0.215, tRow.Name, true, true);
    --center the card type in the narrow bar above the lower panel
    local nTypeY = (sType == "Bun" or sType == "Nice" or sType == "Panic") and 0.64444444 or 0.64000000;
    Forge.DrawText("TYPE", nWidth / 2, nHeight * nTypeY, sType:upper(), true, true);

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
