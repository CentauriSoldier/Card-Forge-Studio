--[[!
@fqxn CFS.Windows.Main.Welcome
@desc
<section aria-label="Main.Welcome overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Main.Welcome</h2><p style="font-size:1.15rem;margin:0">The welcome panel introduces Studio before a project is loaded.</p></div>
<h3>How it fits into your work</h3><p>It displays artwork, version information, and external project links inside the main window.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Main">Main</a></h3><p style="margin:0">The main Studio window connects your project, preview, and editing tools.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Constants">Constants</a></h3><p style="margin:0">Shared constants let Studio services agree on names, paths, and processing choices.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">The welcome display does not create or activate a game.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Welcome page artwork uses a separate card logo and sparse fabrication backdrop.
-- Development controls and WindowWizard experiments are intentionally omitted.
local wx = require("wx");
local Welcome = {};

--[[!
@fqxn CFS.Windows.Main.Welcome.Functions.create
@pulsarlua function Welcome.create
@desc Builds the welcome canvas and layout using the application version and bundled artwork.
@param any pApplication Application.
!]]
function Welcome.create(pApplication)
    local sVersion = INIFile.GetValue(FS.AppCFG, "Settings", "Version"):gsub("[Aa][Ll][Pp][Hh][Aa]", "Beta");
    if (not sVersion:lower():find("beta", 1, true)) then sVersion = "Beta "..sVersion; end
    local oVersionFont = wx.wxFont(10, wx.wxFONTFAMILY_SWISS, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL);
    assert(oVersionFont:IsOk(), "Cannot create the Welcome version font.");
    local oQuiet = wx.wxLogNull();
    local tLayers = {
        {file = "BG Welcome.png", x = 0, y = -5, width = 1644, height = 1096},
        {file = "Logo.png", x = -5, y = 200, width = 700, height = 700},
        {file = "Card Forge.png", x = 735, y = 290, width = 700, height = 233},
        {file = "Studio.png", x = 735, y = 490, width = 700, height = 233},
    };

    for _, tLayer in ipairs(tLayers) do
        tLayer.image = wx.wxImage(pApplication.."Images/"..tLayer.file, wx.wxBITMAP_TYPE_ANY);
        assert(tLayer.image:IsOk(), "Cannot load Welcome image: "..tLayer.file);
    end

    oQuiet:delete();
    local oBackgroundImage = tLayers[1].image;
    local nSampleX = oBackgroundImage:GetWidth() - 1;
    local oBackgroundColour = wx.wxColour(oBackgroundImage:GetRed(nSampleX, 0),
        oBackgroundImage:GetGreen(nSampleX, 0), oBackgroundImage:GetBlue(nSampleX, 0));

    --[[!
    @fqxn CFS.Windows.Main.Welcome.Private.Functions.drawRail
    @desc Connects the three differently shaped link modules to a shared machine rail.
    @vis private
    !]]
    local function drawRail(oDC, nWidth)
        local nLeft = math.max(8, nWidth - 336);
        oDC:SetPen(wx.wxPen(wx.wxColour(46, 64, 79), 8, wx.wxPENSTYLE_SOLID));
        oDC:DrawLine(nLeft, 62, nWidth - 22, 62);
        oDC:SetPen(wx.wxPen(wx.wxColour(100, 122, 139), 1, wx.wxPENSTYLE_SOLID));
        oDC:DrawLine(nLeft, 58, nWidth - 22, 58);
        oDC:SetPen(wx.wxPen(wx.wxColour(0, 153, 191), 2, wx.wxPENSTYLE_SOLID));
        oDC:DrawLine(nLeft, 64, nWidth - 22, 64);
    end

    --[[!
    @fqxn CFS.Windows.Main.Welcome.Private.Functions.draw
    @desc Paints welcome artwork scaled to the canvas dimensions.
    @param any oCanvas Canvas.
    @vis private
    !]]
    local function draw(oCanvas)
        local oSize = oCanvas:GetClientSize();
        local nScale = math.min(oSize:GetWidth() / 1536, oSize:GetHeight() / 1024);
        local nLeft = (oSize:GetWidth() - 1536 * nScale) / 2;
        local nTop = (oSize:GetHeight() - 1024 * nScale) / 2;
        local oDC = wx.wxPaintDC(oCanvas);
        oDC:SetBackground(wx.wxBrush(oBackgroundColour));
        oDC:Clear();

        -- The card sits behind the enlarged cutout machine so its arms and platform overlap it.
        for _, nLayer in ipairs({2, 1, 3, 4}) do
            local tLayer = tLayers[nLayer];
            local nLayerScale = nScale;
            local nLayerLeft = nLeft + tLayer.x * nScale;
            local nLayerTop = nTop + tLayer.y * nScale;
            local nWidth = math.max(1, math.ceil(tLayer.width * nLayerScale));
            local nHeight = math.max(1, math.ceil(tLayer.height * nLayerScale));
            local oBitmap = wx.wxBitmap(tLayer.image:Scale(nWidth, nHeight, wx.wxIMAGE_QUALITY_HIGH));
            oDC:DrawBitmap(oBitmap, math.floor(nLayerLeft), math.floor(nLayerTop), true);
            oBitmap:delete();
        end

        drawRail(oDC, oSize:GetWidth());

        -- The title is artwork; the supporting welcome copy remains native text.
        local oBodyFont = wx.wxFont(math.max(10, math.floor(16 * nScale)), wx.wxFONTFAMILY_SWISS,
            wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL);
        local nTextLeft = math.floor(nLeft + 735 * nScale);
        local nLineY = math.floor(nTop + 755 * nScale);
        oDC:SetFont(oBodyFont);
        local _, nLineHeight = oDC:GetTextExtent("Welcome aboard.");
        oDC:SetTextForeground(wx.wxColour(105, 208, 250));
        oDC:DrawText("Welcome aboard.", nTextLeft, nLineY);
        oDC:SetTextForeground(wx.wxColour(220, 231, 242));
        nLineY = nLineY + nLineHeight + math.max(14, math.floor(20 * nScale));
        for _, sLine in ipairs({"Design your cards.", "Build your sets.", "Bring your ideas to the table."}) do
            oDC:DrawText(sLine, nTextLeft, nLineY);
            nLineY = nLineY + nLineHeight + 8;
        end
        oBodyFont:delete();

        oDC:SetFont(oVersionFont);
        oDC:SetTextForeground(wx.wxColour(255, 255, 255));
        local nTextWidth, nTextHeight = oDC:GetTextExtent(sVersion);
        local nTextX = math.max(8, oSize:GetWidth() - nTextWidth - 12);
        local nTextY = math.max(8, oSize:GetHeight() - nTextHeight - 10);
        local oGraphics = assert(wx.wxGraphicsContext.Create(oDC), "Could not create Welcome version graphics context.");
        oGraphics:SetPen(wx.wxTRANSPARENT_PEN);
        oGraphics:SetBrush(wx.wxBrush(wx.wxColour(0, 0, 0, 160)));
        oGraphics:DrawRoundedRectangle(nTextX - 6, nTextY - 4, nTextWidth + 12, nTextHeight + 8, 4);
        oGraphics:delete();
        oDC:DrawText(sVersion, nTextX, nTextY);

        oDC:delete();
    end

    --[[!
    @fqxn CFS.Windows.Main.Welcome.Private.Functions.addLinks
    @desc Creates bundled artwork links and connects protected browser-launch actions.
    @param any dCanvas Canvas.
    @param any fProtect Protect.
    @vis private
    !]]
    local function addLinks(dCanvas, fProtect)
        local wxLuma = require("wxLuma.init")();
        local oSkin = wxLuma.Controls.loadSkin();
        local tButtons = {};
        local tLinks = {
            {image = "patreon", url = APP_PATREON, label = "Help support the project"},
            {image = "github", url = APP_GITHUB, label = "View source code and download releases on GitHub"},
            {image = "website", url = "https://cardforge.studio", label = "Visit cardforge.studio"},
        };
        local oClock = wx.wxStopWatch();
        local oBackground;
        local bVisible = true;
        local bDisposed = false;
        local bPlayed = false;
        local nClickUntil = 0;

        --[[!
        @fqxn CFS.Windows.Main.Welcome.Private.Functions.playButtonSound
        @desc Plays one asynchronous effect per interaction. Clicks take priority
            over hover sounds; visual state changes never replay audio.
        @vis private
        !]]
        local function playButtonSound(tButton, sState)
            if (not bVisible or bDisposed) then return; end
            local nNow = oClock:Time();
            if (sState == "hover") then
                if (nNow < nClickUntil or nNow - tButton.lastHover < 140) then return; end
                tButton.lastHover = nNow;
            else
                nClickUntil = nNow + 300;
            end
            bPlayed = true;
            return tButton.sounds[sState]:Play(wx.wxSOUND_ASYNC);
        end

        for _, tLink in ipairs(tLinks) do
            local pImage = pApplication.."Images/Buttons/"..tLink.image;
            local pSound = pApplication.."Audio/SFX/Buttons/"..tLink.image;
            local tButton = {normal = pImage..".png", hover = pImage.." hover.png",
                inside = false, lastHover = -1000, x = 0, y = 12, sounds = {}};
            for _, sState in ipairs({"hover", "click"}) do
                local oSound = wx.wxSound(pSound.." "..sState..".wav");
                assert(oSound:IsOk(), "Cannot load Welcome button sound: "..tLink.image.." "..sState);
                tButton.sounds[sState] = oSound;
            end
            local sURL = tLink.url;
            local oButton = wxLuma.Controls.imageButton(dCanvas, {
                Skin = oSkin,
                Image = tButton.normal,
                AlphaHit = false,
                Background = function(oDC)
                    oDC:SetBackground(wx.wxBrush(oBackgroundColour)); oDC:Clear();
                    if (oBackground) then oDC:DrawBitmap(oBackground, -tButton.x, -tButton.y, false); end
                end,
                OnClick = fProtect(function()
                    playButtonSound(tButton, "click");
                    assert(wx.wxLaunchDefaultBrowser(sURL), "Could not open the browser.");
                end),
            });
            tButton.button = oButton;
            oButton.Control:SetBackgroundColour(oBackgroundColour);
            oButton.Control:SetToolTip(tLink.label);
            oButton.Control:SetCursor(wx.wxCursor(wx.wxCURSOR_HAND));
            oButton.on("pointerEnter", fProtect(function()
                if (not bVisible or bDisposed or tButton.inside) then return; end
                tButton.inside = true;
                oButton.setImage(tButton.hover);
                playButtonSound(tButton, "hover");
            end));
            oButton.on("pointerLeave", fProtect(function()
                if (bDisposed) then return; end
                tButton.inside = false;
                oButton.setImage(tButton.normal);
            end));
            tButtons[#tButtons + 1] = tButton;
        end

        --[[!
        @fqxn CFS.Windows.Main.Welcome.Private.Functions.layout
        @desc Matches the background and shared rail, then positions wxLuma link modules.
            No animation timer or per-frame bitmap replacement is used.
        @vis private
        !]]
        local function layout()
            if (bDisposed) then return; end
            local oSize = dCanvas:GetClientSize();
            local nCanvasWidth = math.max(1, oSize:GetWidth());
            local nCanvasHeight = math.max(1, oSize:GetHeight());
            local nScale = math.min(nCanvasWidth / 1536, nCanvasHeight / 1024);
            local nWidth = math.max(1, math.ceil(tLayers[1].width * nScale));
            local nHeight = math.max(1, math.ceil(tLayers[1].height * nScale));
            local nLeft = math.floor((nCanvasWidth - 1536 * nScale) / 2 + tLayers[1].x * nScale);
            local nTop = math.floor((nCanvasHeight - 1024 * nScale) / 2 + tLayers[1].y * nScale);
            if (oBackground) then oBackground:delete(); end
            oBackground = wx.wxBitmap(nCanvasWidth, nCanvasHeight);
            local oDC = wx.wxMemoryDC(); oDC:SelectObject(oBackground);
            oDC:SetBackground(wx.wxBrush(oBackgroundColour)); oDC:Clear();
            local oImageScaled = tLayers[1].image:Scale(nWidth, nHeight, wx.wxIMAGE_QUALITY_HIGH);
            local oBackdrop = wx.wxBitmap(oImageScaled);
            oDC:DrawBitmap(oBackdrop, nLeft, nTop, true);
            drawRail(oDC, nCanvasWidth);
            oDC:SelectObject(wx.wxNullBitmap); oDC:delete(); oBackdrop:delete(); oImageScaled:delete();
            for nIndex, tButton in ipairs(tButtons) do
                tButton.x = math.max(0, nCanvasWidth - 12 - (#tButtons - nIndex + 1) * 108);
                tButton.button.layout(tButton.x, tButton.y, 96, 96);
                tButton.button.Control:Refresh(false);
            end
        end
        dCanvas:Connect(wx.wxEVT_SIZE, function(oEvent)
            layout(); oEvent:Skip();
        end);
        dCanvas:Connect(wx.wxEVT_DESTROY, function(oEvent)
            if (oEvent:GetEventObject() == dCanvas and not bDisposed) then
                bDisposed = true;
                if (bPlayed) then wx.wxSound.Stop(); end
                for _, tButton in ipairs(tButtons) do
                    tButton.button.destroy();
                    for _, oSound in pairs(tButton.sounds) do oSound:delete(); end
                end
                oSkin.destroy(); oClock:delete();
                if (oBackground) then oBackground:delete(); end
            end
            oEvent:Skip();
        end);
        layout();

        return {
            --[[!
            @fqxn CFS.Windows.Main.Welcome.Private.Functions.ShowItems
            @desc Shows or hides the static link modules and restores their idle artwork.
            @vis private
            !]]
            ShowItems = function(_, bShow)
                if (bDisposed) then return; end
                bVisible = bShow;
                if (not bShow and bPlayed) then wx.wxSound.Stop(); end
                for _, tButton in ipairs(tButtons) do
                    tButton.inside = false;
                    tButton.button.setImage(tButton.normal);
                    tButton.button.setEnabled(bShow);
                    tButton.button.Control:Show(bShow);
                end
                layout();
            end,
        };
    end

    return {draw = draw, addLinks = addLinks};
end

return Welcome;
