-- Welcome page artwork from the original AutoPlay page.
-- Development controls and WindowWizard experiments are intentionally omitted.
local wx = require("wx");
local Welcome = {};

function Welcome.create(pApplication)
    local sVersion = INIFile.GetValue(FS.AppCFG, "Settings", "Version");
    local oVersionFont = wx.wxFont(18, wx.wxFONTFAMILY_DEFAULT, wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_NORMAL, false, "CRYSTAL");
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

    local function draw(oCanvas)
        local oSize = oCanvas:GetClientSize();
        local nScale = math.min(oSize:GetWidth() / 1400, oSize:GetHeight() / 1200);
        local nLeft = (oSize:GetWidth() - 1400 * nScale) / 2;
        local nTop = (oSize:GetHeight() - 1200 * nScale) / 2;
        local oDC = wx.wxPaintDC(oCanvas);
        oDC:SetBackground(wx.wxBrush(wx.wxColour(0, 0, 0)));
        oDC:Clear();

        for _, tLayer in ipairs(tLayers) do
            local nWidth = math.max(1, math.floor(tLayer.width * nScale));
            local nHeight = math.max(1, math.floor(tLayer.height * nScale));
            local oBitmap = wx.wxBitmap(tLayer.image:Scale(nWidth, nHeight, wx.wxIMAGE_QUALITY_HIGH));
            oDC:DrawBitmap(oBitmap, math.floor(nLeft + tLayer.x * nScale), math.floor(nTop + tLayer.y * nScale), true);
            oBitmap:delete();
        end

        oDC:SetFont(oVersionFont);
        oDC:SetBrush(wx.wxBrush(wx.wxColour(45, 45, 45)));
        oDC:SetPen(wx.wxPen(wx.wxColour(75, 75, 75), 1, wx.wxPENSTYLE_SOLID));

        for nIndex = 1, 2 do
            oDC:DrawRoundedRectangle(math.max(0, oSize:GetWidth() - 20 - (3 - nIndex) * 76), math.max(0, oSize:GetHeight() - 84), 64, 64, 12);
        end

        oDC:SetTextForeground(wx.wxColour(255, 255, 255));
        oDC:DrawText(sVersion, 8, 8);

        oDC:delete();
    end

    local function addLinks(dCanvas, fProtect)
        local tButtons = {};
        local tLinks = {
            {image = "patreon", url = APP_PATREON, label = "Patreon"},
            {image = "github", url = APP_GITHUB, label = "GitHub"},
        };

        for _, tLink in ipairs(tLinks) do
            local pImage = pApplication.."Images/Buttons/"..tLink.image;
            local oNormal = wx.wxImage(pImage..".png", wx.wxBITMAP_TYPE_ANY);
            local oHover = wx.wxImage(pImage.." hover.png", wx.wxBITMAP_TYPE_ANY);
            assert(oNormal:IsOk() and oHover:IsOk(), "Cannot load Welcome link images.");
            local oButton = wx.wxBitmapButton(dCanvas, wx.wxID_ANY,
                wx.wxBitmap(oNormal:Scale(48, 48, wx.wxIMAGE_QUALITY_HIGH)), wx.wxDefaultPosition, wx.wxSize(48, 48), wx.wxBORDER_NONE);
            oButton:SetBitmapCurrent(wx.wxBitmap(oHover:Scale(48, 48, wx.wxIMAGE_QUALITY_HIGH)));
            oButton:SetBackgroundColour(wx.wxColour(45, 45, 45));
            oButton:SetToolTip(tLink.label);
            local sURL = tLink.url;
            oButton:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, fProtect(function()
                assert(wx.wxLaunchDefaultBrowser(sURL), "Could not open the browser.");
            end));
            tButtons[#tButtons + 1] = oButton;
        end

        local function layout()
            local oSize = dCanvas:GetClientSize();

            for nIndex, oButton in ipairs(tButtons) do
                oButton:Move(math.max(0, oSize:GetWidth() - 12 - (#tButtons - nIndex + 1) * 76), math.max(0, oSize:GetHeight() - 76));
            end
        end

        dCanvas:Connect(wx.wxEVT_SIZE, function(oEvent)
            layout();
            oEvent:Skip();
        end);
        layout();

        return {
            ShowItems = function(_, bShow)
                for _, oButton in ipairs(tButtons) do
                    oButton:Show(bShow);
                end

                layout();
            end,
        };
    end

    return {draw = draw, addLinks = addLinks};
end

return Welcome;
