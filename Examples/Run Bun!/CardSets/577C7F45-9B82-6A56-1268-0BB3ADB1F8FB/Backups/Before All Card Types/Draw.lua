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
end
