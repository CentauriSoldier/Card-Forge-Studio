local _wx = require("wx");
local _Catalog = require("wxLuma.Core.SystemArtworkCatalog");
local SystemArtwork = {};
-- Explicit family/part roles take precedence over generic material fallbacks.
-- A family name such as Property Grid must never act as a Grid-line part.
local _tFamilyRoles = {
    ["Property Grid"] = {
        Surface = "Editor", Category = "Background", Row = "Editor", Separator = "Border",
        Editor = "Editor", ["Editor Fill"] = "Editor", ["Editor Editor"] = "Editor",
        ["Editor Surface"] = "Editor", Text = "Text", ["Editor Text"] = "Text",
    },
    ["Collapsible Panel"] = {Surface = "Editor", Header = "Background", Text = "Text"},
};

--[[!
@fqxn wxLuma.UI.SystemArtwork.hasWord
@desc Matches a complete semantic part word. Background and Closed must never
    be mistaken for the Back and Close glyphs.
!]]
local function hasWord(sName, sWord)
    return sName:find("%f[%w]"..sWord.."%f[%W]") ~= nil;
end

--[[!
@fqxn wxLuma.UI.SystemArtwork.describe
@desc Resolves a semantic material and its natural layout bounds. The catalog is
    plain metadata; System never decodes artwork files. Unknown custom prefixes
    can use the same semantic part suffixes with explicit drawing dimensions.
!]]
function SystemArtwork.describe(sName)
    local sPart = sName:gsub(" Normal$", ""):gsub(" Hover$", ""):gsub(" Pressed$", ""):gsub(" Disabled$", "");
    local tSize = _Catalog[sPart] or {24, 24};
    for sFamily, tRoles in pairs(_tFamilyRoles) do
        if (sPart:sub(1, #sFamily + 1) == sFamily.." ") then
            local sMaterial = sPart:sub(#sFamily + 2);
            local sExplicit = tRoles[sMaterial];
            if (sExplicit) then
                if (sMaterial == "Header" and (hasWord(sName, "Hover") or hasWord(sName, "Pressed"))) then sExplicit = "Hover"; end
                return sExplicit, tSize[1], tSize[2];
            end
        end
    end
    local sRole = "Background";
    if (sName:find("Text Selection", 1, true)) then sRole = "Selection";
    elseif (sPart:match(" Text$") or sName:find("Severity", 1, true) or sName:find("Seam", 1, true)) then sRole = "Text";
    elseif (sName:find("Row Selected", 1, true) or sName:find("Entry Selected", 1, true)) then sRole = "Selection";
    elseif (sName:find("Series ", 1, true) or sName:find("Fill", 1, true)
        or sName:find("Chart Bar ", 1, true) or sName:find("Chart Swatch ", 1, true)) then sRole = "Fill";
    elseif (sName:find("Reserve", 1, true)) then sRole = "Reserve";
    elseif (sName:find("Blade Alternate", 1, true) or sName:find("Check Light", 1, true)) then sRole = "Hover";
    elseif (sName:find("Editor", 1, true) or sName:find("Track", 1, true) or sName:find("Plot", 1, true)
        or sName:find("Page", 1, true) or sName:find("Content", 1, true)) then sRole = "Editor";
    elseif (sPart:match(" Axis$") or sPart:match(" Grid$") or sName:find("Separator", 1, true)
        or sName:find("Check Dark", 1, true)) then sRole = "Border";
    elseif (sName:find("Hover", 1, true) or sName:find("Selected", 1, true) or sName:find(" On", 1, true)) then sRole = "Hover";
    end
    return sRole, tSize[1], tSize[2];
end

--[[!
@fqxn wxLuma.UI.SystemArtwork.draw
@desc Draws semantic control parts from system resources and vector glyphs.
    Native renderer operations are used when a native host is supplied. Unique
    shapes remain custom; no raster skin is needed for either path.
    System switches use rectangular track and thumb geometry drawn by the DC.
!]]
function SystemArtwork.draw(oTheme, oWindow, oDC, sName, nX, nY, nWidth, nHeight, bMaterial)
    if (nWidth < 1 or nHeight < 1) then return; end
    local sRole = SystemArtwork.describe(sName);
    local bEnabled = not sName:find("Disabled", 1, true);
    local nFlags = not bEnabled and _wx.wxCONTROL_DISABLED or sName:find("Pressed", 1, true) and _wx.wxCONTROL_PRESSED
        or sName:find("Hover", 1, true) and _wx.wxCONTROL_CURRENT or 0;
    local bCheck = sName:find("Checkbox", 1, true) or sName:find(" Check On", 1, true) or sName:find(" Check Off", 1, true);
    if (oWindow and bCheck) then
        if (sName:find(" On", 1, true)) then nFlags = nFlags + _wx.wxCONTROL_CHECKED; end
        _wx.wxRendererNative.Get():DrawCheckBox(oWindow, oDC, _wx.wxRect(nX, nY, nWidth, nHeight), nFlags);
        return;
    end
    local oPen = _wx.wxPen(oTheme.color("Border", bEnabled), 1, _wx.wxPENSTYLE_SOLID);
    local oInk = _wx.wxPen(oTheme.color(hasWord(sName, "Selected") and "SelectionText" or "Text", bEnabled), math.max(1, math.floor(math.min(nWidth, nHeight) / 14)), _wx.wxPENSTYLE_SOLID);
    local oBrush = _wx.wxBrush(oTheme.color(sRole, bEnabled));
    oDC:SetPen(oPen); oDC:SetBrush(oBrush);
    local nCX, nCY = nX + nWidth / 2, nY + nHeight / 2;
    local nRadius = math.max(1, math.min(nWidth, nHeight) / 2 - 2);
    local bGlyph = sName:find("Arrow", 1, true) or sName:find("Spinner", 1, true)
        or sName:find("Breadcrumb Separator", 1, true)
        or hasWord(sName, "Up") or hasWord(sName, "Down")
        or hasWord(sName, "Back") or hasWord(sName, "Next") or sName:find("Branch", 1, true)
        or sName:find(" Closed", 1, true) or sName:find(" Open", 1, true) or sName:find("Clear", 1, true)
        or hasWord(sName, "Close") or sName:find("Magnifier", 1, true) or sName:find("Needle", 1, true)
        or sName:find("Icon", 1, true) or sName:find("Browse", 1, true) or sName:find(" File", 1, true)
        or sName:find(" Folder", 1, true) or sName:find("Grip", 1, true) or sName:find(" Action", 1, true) and sName:find("Dockable", 1, true);

    -- Materials have no border: geometry and clipping are owned by the widget.
    if (sName:find("Focus", 1, true)) then
        -- Focus changes input ownership, not decorative geometry.
    elseif (bCheck or sName:match("^Radio ")) then
        if (sName:match("^Radio ")) then oDC:DrawCircle(nCX, nCY, nRadius);
        else oDC:DrawRectangle(nX + 2, nY + 2, math.max(1, nWidth - 4), math.max(1, nHeight - 4)); end
        if (sName:find(" On", 1, true)) then
            oDC:SetPen(oInk);
            if (sName:match("^Radio ")) then
                local oDot = _wx.wxBrush(oTheme.color("Text", bEnabled)); oDC:SetBrush(oDot);
                oDC:DrawCircle(nCX, nCY, math.max(1, nRadius / 2)); oDot:delete();
            else
                oDC:DrawLine(nX + nWidth * 0.2, nCY, nX + nWidth * 0.43, nY + nHeight * 0.75);
                oDC:DrawLine(nX + nWidth * 0.43, nY + nHeight * 0.75, nX + nWidth * 0.8, nY + nHeight * 0.25);
            end
        end
    elseif (sName:match("^Slider ")) then
        -- wxLua exposes no native slider renderer. Compact system-palette
        -- track/thumb geometry is supplied by Slider, independently of PNGs.
        if (hasWord(sName, "Track")) then
            oDC:SetPen(_wx.wxTRANSPARENT_PEN);
            local oTrack = _wx.wxBrush(oTheme.color("Border", bEnabled));
            oDC:SetBrush(oTrack); oDC:DrawRoundedRectangle(nX, nY, nWidth, nHeight, 2); oTrack:delete();
        else
            local oThumb = _wx.wxBrush(oTheme.color("Fill", bEnabled));
            oDC:SetBrush(oThumb); oDC:DrawRoundedRectangle(nX, nY, nWidth, nHeight, 2); oThumb:delete();
        end
    elseif (sName:find("Knob Face", 1, true) or sName:find("LED Bezel", 1, true)) then
        oDC:DrawCircle(nCX, nCY, nRadius);
    elseif (sName:find("LED Lens", 1, true) or sName:find("LED Glow", 1, true) or sName:find("LED Glass", 1, true)
        or sName:find("Chart Marker", 1, true)) then
        local oLight = _wx.wxBrush(bMaterial and _wx.wxWHITE or oTheme.color("Fill", bEnabled));
        oDC:SetBrush(oLight); oDC:SetPen(_wx.wxTRANSPARENT_PEN);
        if (not sName:find("Glass", 1, true)) then oDC:DrawCircle(nCX, nCY, nRadius); end
        oLight:delete();
    elseif (sName:match("^Switch [HV]")) then
        local bVertical = sName:find("Vertical", 1, true);
        local bOn = sName:find(" On", 1, true) ~= nil;
        if (sName:find("Reversed", 1, true)) then bOn = not bOn; end
        -- Keep the recessed rectangular track distinct from the parent surface.
        -- Straight DC edges need no graphics context or curve antialiasing.
        local oTrack = _wx.wxBrush(oTheme.color("Border", bEnabled));
        oDC:SetBrush(oTrack);
        oDC:DrawRectangle(nX + 1, nY + 1, nWidth - 2, nHeight - 2);
        local oThumb = _wx.wxBrush(oTheme.color(bOn and "Fill" or "Editor", bEnabled));
        -- Preserve the original thumb center and extent with a square outline.
        local nThumbHalf = math.min(nWidth, nHeight) * 0.35;
        local nThumbX = bVertical and nCX or nX + nWidth * (bOn and 0.75 or 0.25);
        local nThumbY = bVertical and nY + nHeight * (bOn and 0.25 or 0.75) or nCY;
        oDC:SetBrush(oThumb);
        oDC:DrawRectangle(nThumbX - nThumbHalf, nThumbY - nThumbHalf, nThumbHalf * 2, nThumbHalf * 2);
        oTrack:delete(); oThumb:delete();
    elseif (bGlyph) then
        oDC:SetPen(oInk); oDC:SetBrush(_wx.wxTRANSPARENT_BRUSH);
        local nDX, nDY = math.max(2, nWidth / 4), math.max(2, nHeight / 4);
        if (sName:find("Needle", 1, true)) then
            oDC:DrawLine(nCX, nCY, nX + nWidth - 3, nCY);
        elseif (sName:find("Clear", 1, true) or hasWord(sName, "Close")) then
            oDC:DrawLine(nCX - nDX, nCY - nDY, nCX + nDX, nCY + nDY);
            oDC:DrawLine(nCX + nDX, nCY - nDY, nCX - nDX, nCY + nDY);
        elseif (sName:find("Magnifier", 1, true)) then
            oDC:DrawCircle(nCX - 2, nCY - 2, math.min(nDX, nDY));
            oDC:DrawLine(nCX + nDX / 2, nCY + nDY / 2, nX + nWidth - 2, nY + nHeight - 2);
        elseif (sName:find("Log Viewer Icon", 1, true)) then
            -- Decorative document icons inherit the foreground, so a light
            -- skin bitmap is never carried over onto the System background.
            oDC:DrawRectangle(nX + nWidth * 0.2, nY + nHeight * 0.1, nWidth * 0.6, nHeight * 0.8);
            for nLine = 1, 3 do
                oDC:DrawLine(nX + nWidth * 0.32, nY + nHeight * (0.25 + nLine * 0.14),
                    nX + nWidth * 0.68, nY + nHeight * (0.25 + nLine * 0.14));
            end
        elseif (sName:find("DateTimePicker Icon", 1, true)) then
            -- A calendar page uses system foreground ink, including disabled state.
            oDC:DrawRectangle(nX + 3, nY + 4, nWidth - 6, nHeight - 7);
            oDC:DrawLine(nX + 3, nY + 8, nX + nWidth - 3, nY + 8);
            for nColumn = 1, 2 do
                local nAt = nX + 3 + (nWidth - 6) * nColumn / 3;
                oDC:DrawLine(nAt, nY + 8, nAt, nY + nHeight - 3);
            end
            oDC:DrawLine(nX + 3, nY + 12, nX + nWidth - 3, nY + 12);
            oDC:DrawLine(nX + 6, nY + 2, nX + 6, nY + 6);
            oDC:DrawLine(nX + nWidth - 6, nY + 2, nX + nWidth - 6, nY + 6);
        elseif (sName:find("Icon", 1, true) or sName:find("Browse", 1, true) or sName:find("Grip", 1, true)) then
            local sText = sName:find("error", 1, true) and "x" or sName:find("warning", 1, true) and "!"
                or sName:find("success", 1, true) and "+" or sName:find("Browse", 1, true) and "..." or "i";
            oTheme.text(oDC, sText, nX + 3, nY + 1, bEnabled);
        elseif (sName:find(" File", 1, true) or sName:find(" Folder", 1, true) or sName:find("Dockable", 1, true)) then
            oDC:DrawRectangle(nCX - nDX, nCY - nDY, nDX * 2, nDY * 2);
            oDC:DrawLine(nCX - nDX, nCY, nCX + nDX, nCY);
        else
            local bLeft = hasWord(sName, "Back") or hasWord(sName, "Left");
            local bRight = sName:find("Next", 1, true) or sName:find("Closed", 1, true)
                or sName:find(" Right", 1, true) or sName:find("Breadcrumb Separator", 1, true);
            local bUp = sName:find(" Up", 1, true);
            oTheme.arrowGlyph(oWindow, oDC, bLeft and "Left" or bRight and "Right" or bUp and "Up" or "Down",
                nX, nY, nWidth, nHeight, bEnabled and "Normal" or "Disabled");
        end
    elseif (sRole == "Fill" or sRole == "Reserve" or sRole == "Text" or sRole == "Border"
        or sName:find("Surface", 1, true) or sName:find("Background", 1, true)
        or sName:find("Track", 1, true) or sName:find("Plot", 1, true) or sName:find("Page", 1, true)
        or sName:find("Content", 1, true) or sName:find("Blade", 1, true) or sName:find("Row", 1, true)
        or sName:find("Entry", 1, true)) then
        if (bMaterial and (sName:find("Chart Bar", 1, true) or sName:find("Chart Swatch", 1, true))) then oDC:SetBrush(_wx.wxWHITE_BRUSH); end
        oDC:SetPen(_wx.wxTRANSPARENT_PEN); oDC:DrawRectangle(nX, nY, nWidth, nHeight);
    else
        oDC:DrawRectangle(nX, nY, nWidth, nHeight);
    end
    oPen:delete(); oInk:delete(); oBrush:delete();
end

return SystemArtwork;
