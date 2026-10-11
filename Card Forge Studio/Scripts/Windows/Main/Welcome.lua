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

-- Welcome page artwork from the original AutoPlay page.
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
    local oVersionFont = wx.wxFont(10, wx.wxFONTFAMILY_ROMAN, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, false, "Times New Roman");
    assert(oVersionFont:IsOk(), "Cannot create the Welcome version font.");
    local oQuiet = wx.wxLogNull();
    local tLayers = {
        {file = "BG Welcome.png", x = -202, y = 0, width = 1804, height = 1200},
        {file = "Card Forge.png", x = 371, y = 333, width = 658, height = 160},
        {file = "Studio.png", x = 501, y = 492, width = 399, height = 138},
    };

    for _, tLayer in ipairs(tLayers) do
        tLayer.image = wx.wxImage(pApplication.."Images/"..tLayer.file, wx.wxBITMAP_TYPE_ANY);
        assert(tLayer.image:IsOk(), "Cannot load Welcome image: "..tLayer.file);
    end

    oQuiet:delete();

    --[[!
    @fqxn CFS.Windows.Main.Welcome.Private.Functions.draw
    @desc Paints welcome artwork scaled to the canvas dimensions.
    @param any oCanvas Canvas.
    @vis private
    !]]
    local function draw(oCanvas)
        local oSize = oCanvas:GetClientSize();
        local nScale = math.min(oSize:GetWidth() / 1400, oSize:GetHeight() / 1200);
        local nLeft = (oSize:GetWidth() - 1400 * nScale) / 2;
        local nTop = (oSize:GetHeight() - 1200 * nScale) / 2;
        local oDC = wx.wxPaintDC(oCanvas);
        oDC:SetBackground(wx.wxBrush(wx.wxColour(0, 0, 0)));
        oDC:Clear();

        for nIndex, tLayer in ipairs(tLayers) do
            local nLayerScale = nIndex == 1 and math.max(oSize:GetWidth() / tLayer.width, oSize:GetHeight() / tLayer.height) or nScale;
            local nLayerLeft = nIndex == 1 and (oSize:GetWidth() - tLayer.width * nLayerScale) / 2 or nLeft + tLayer.x * nScale;
            local nLayerTop = nIndex == 1 and (oSize:GetHeight() - tLayer.height * nLayerScale) / 2 or nTop + tLayer.y * nScale;
            local nWidth = math.max(1, math.ceil(tLayer.width * nLayerScale));
            local nHeight = math.max(1, math.ceil(tLayer.height * nLayerScale));
            local oBitmap = wx.wxBitmap(tLayer.image:Scale(nWidth, nHeight, wx.wxIMAGE_QUALITY_HIGH));
            oDC:DrawBitmap(oBitmap, math.floor(nLayerLeft), math.floor(nLayerTop), true);
            oBitmap:delete();
        end

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
        local tButtons = {};
        local tLinks = {
            {image = "patreon", url = APP_PATREON, label = "Help support the project"},
            {image = "github", url = APP_GITHUB, label = "View source code and download releases on GitHub"},
            {image = "website", url = "https://cardforge.studio", label = "Visit cardforge.studio"},
        };

        for _, tLink in ipairs(tLinks) do
            local pImage = pApplication.."Images/Buttons/"..tLink.image;
            local oNormal = wx.wxImage(pImage..".png", wx.wxBITMAP_TYPE_ANY);
            local oHover = wx.wxImage(pImage.." hover.png", wx.wxBITMAP_TYPE_ANY);
            assert(oNormal:IsOk() and oHover:IsOk(), "Cannot load Welcome link images.");
            local oButton = wx.wxBitmapButton(dCanvas, wx.wxID_ANY,
                wx.wxBitmap(oNormal:Scale(96, 96, wx.wxIMAGE_QUALITY_HIGH)), wx.wxDefaultPosition, wx.wxSize(96, 96), wx.wxBORDER_NONE);
            oButton:SetBitmapCurrent(wx.wxBitmap(oHover:Scale(96, 96, wx.wxIMAGE_QUALITY_HIGH)));
            oButton:SetBackgroundColour(wx.wxColour(45, 45, 45));
            oButton:SetToolTip(tLink.label);
            local sURL = tLink.url;
            oButton:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, fProtect(function()
                assert(wx.wxLaunchDefaultBrowser(sURL), "Could not open the browser.");
            end));
            tButtons[#tButtons + 1] = {button = oButton, normal = oNormal:Scale(96, 96, wx.wxIMAGE_QUALITY_HIGH), hover = oHover:Scale(96, 96, wx.wxIMAGE_QUALITY_HIGH)};
        end

        --[[!
        @fqxn CFS.Windows.Main.Welcome.Private.Functions.layout
        @desc Positions welcome link buttons after a canvas resize.
        @vis private
        !]]
        local function layout()
            local oSize = dCanvas:GetClientSize();

            local nScale = math.max(oSize:GetWidth() / tLayers[1].width, oSize:GetHeight() / tLayers[1].height);
            local nWidth = math.max(1, math.ceil(tLayers[1].width * nScale));
            local nHeight = math.max(1, math.ceil(tLayers[1].height * nScale));
            local nLeft = math.floor((oSize:GetWidth() - tLayers[1].width * nScale) / 2);
            local nTop = math.floor((oSize:GetHeight() - tLayers[1].height * nScale) / 2);
            local oBackground = wx.wxBitmap(tLayers[1].image:Scale(nWidth, nHeight, wx.wxIMAGE_QUALITY_HIGH));
            for nIndex, tButton in ipairs(tButtons) do
                local nX = math.max(0, oSize:GetWidth() - 12 - (#tButtons - nIndex + 1) * 108);
                local nY = 12;
                tButton.button:Move(nX, nY);
                for _, sState in ipairs({"normal", "hover"}) do
                    local oBitmap = wx.wxBitmap(96, 96);
                    local oDC = wx.wxMemoryDC(); oDC:SelectObject(oBitmap);
                    oDC:SetBackground(wx.wxBrush(wx.wxColour(0, 0, 0))); oDC:Clear();
                    oDC:DrawBitmap(oBackground, nLeft - nX, nTop - nY, false);
                    local oBadge = wx.wxBitmap(tButton[sState]); oDC:DrawBitmap(oBadge, 0, 0, true);
                    oDC:SelectObject(wx.wxNullBitmap); oDC:delete(); oBadge:delete();
                    if (sState == "normal") then tButton.button:SetBitmap(oBitmap); else tButton.button:SetBitmapCurrent(oBitmap); end
                    oBitmap:delete();
                end
            end
            oBackground:delete();
        end

        dCanvas:Connect(wx.wxEVT_SIZE, function(oEvent)
            layout();
            oEvent:Skip();
        end);
        layout();

        return {
            --[[!
            @fqxn CFS.Windows.Main.Welcome.Private.Functions.ShowItems
            @desc Shows or hides welcome link controls and recomputes their positions.
            @param any _ _.
            @param any bShow Show.
            @vis private
            !]]
            ShowItems = function(_, bShow)
                for _, tButton in ipairs(tButtons) do
                    tButton.button:Show(bShow);
                end

                layout();
            end,
        };
    end

    return {draw = draw, addLinks = addLinks};
end

return Welcome;
