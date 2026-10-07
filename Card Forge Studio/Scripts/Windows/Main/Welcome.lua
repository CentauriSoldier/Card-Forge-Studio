-- Welcome page artwork from the original AutoPlay page.
-- Development controls and WindowWizard experiments are intentionally omitted.
local wx = require("wx");
local Welcome = {};

function Welcome.create(pApplication)
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

        oDC:delete();
    end

    local function addLinks(oParent, oLayout, fProtect)
        local oLinks = wx.wxBoxSizer(wx.wxHORIZONTAL);
        local tLinks = {
            {image = "patreon", url = APP_PATREON, label = "Patreon"},
            {image = "github", url = APP_GITHUB, label = "GitHub"},
        };

        oLinks:AddStretchSpacer(1);

        for _, tLink in ipairs(tLinks) do
            local pImage = pApplication.."Images/Buttons/"..tLink.image;
            local oNormal = wx.wxImage(pImage..".png", wx.wxBITMAP_TYPE_ANY);
            local oHover = wx.wxImage(pImage.." hover.png", wx.wxBITMAP_TYPE_ANY);
            assert(oNormal:IsOk() and oHover:IsOk(), "Cannot load Welcome link images.");
            local oButton = wx.wxBitmapButton(oParent, wx.wxID_ANY,
                wx.wxBitmap(oNormal:Scale(48, 48, wx.wxIMAGE_QUALITY_HIGH)));
            oButton:SetBitmapCurrent(wx.wxBitmap(oHover:Scale(48, 48, wx.wxIMAGE_QUALITY_HIGH)));
            oButton:SetToolTip(tLink.label);
            local sURL = tLink.url;
            oButton:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, fProtect(function()
                assert(wx.wxLaunchDefaultBrowser(sURL), "Could not open the browser.");
            end));
            oLinks:Add(oButton, 0, wx.wxALL, 4);
        end

        oLayout:Add(oLinks, 0, wx.wxEXPAND);

        return oLinks;
    end

    return {draw = draw, addLinks = addLinks};
end

return Welcome;
