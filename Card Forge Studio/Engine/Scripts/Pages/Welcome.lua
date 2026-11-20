--[[!
@fqxn CardForgeEngine.Pages.Welcome
@desc Welcome content for the main window. This is a page panel, not another
    top-level window. wxLuma owns the image and descriptive text controls.
!]]
local wx = require("wx");
local GamesList = require("Scripts.Controls.GamesList");
local Welcome = {};

--[[!
@fqxn CardForgeEngine.Pages.Welcome.create
@desc Creates the welcome artwork and introduction, with a responsive layout.
    The parent owns native controls; dispose releases the borrowed-skin users
    before releasing this page's shared skin.
@param wxWindow oParent The main application frame.
@param string pRoot Installation root used to locate the welcome artwork.
@param table wxLuma Loaded framework with project-local artwork defaults.
@ret table Page Native Control and an idempotent dispose function.
!]]
function Welcome.create(oParent, pRoot, wxLuma)
    local oPanel = wx.wxPanel(oParent, wx.wxID_ANY);
    oPanel:SetBackgroundColour(wx.wxColour(24, 29, 36));
    local oSkin = wxLuma.Controls.loadSkin();
    local oArtwork = wxLuma.Controls.image(oPanel, {
        Skin = oSkin,
        Value = pRoot.."/Images/Card Forge Engine.png",
        ScaleMode = "contain",
    });
    local oTitle = wx.wxStaticText(oPanel, wx.wxID_ANY, "Card Forge Engine");
    local oTitleFont = wx.wxFont(26, wx.wxFONTFAMILY_SWISS,
        wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD);
    oTitle:SetFont(oTitleFont);
    oTitleFont:delete();
    oTitle:SetForegroundColour(wx.wxColour(232, 242, 252));
    local oGreeting = wxLuma.Controls.label(oPanel, {
        Skin = oSkin,
        Value = "Welcome aboard.",
        Padding = 0,
    });
    local oDescription = wxLuma.Controls.label(oPanel, {
        Skin = oSkin,
        Value = "Your cards. Your rules. Your universe.\n\nA home for the card games you imagine.",
        Padding = 0,
        Wrap = true,
    });
    local oGamesHeader = wx.wxStaticText(oPanel, wx.wxID_ANY, "Games");
    local oHeaderFont = wx.wxFont(18, wx.wxFONTFAMILY_SWISS,
        wx.wxFONTSTYLE_NORMAL, wx.wxFONTWEIGHT_BOLD);
    oGamesHeader:SetFont(oHeaderFont);
    oHeaderFont:delete();
    oGamesHeader:SetForegroundColour(wx.wxColour(105, 208, 250));
    local oGames = GamesList.create(oPanel, wxLuma, oSkin);
    local Page = {
        Control = oPanel,
        Artwork = oArtwork,
        Games = oGames,
        Disposed = false,
    };

    --[[!
    @fqxn CardForgeEngine.Pages.Welcome.layout
    @desc Retains the original artwork and introduction layout in the welcome area.
        Games occupies a separate full-height column at the far right.
    !]]
    local function fLayout()
        if (Page.Disposed) then return; end
        local nWidth, nHeight = oPanel:GetClientSizeWH();
        local nMargin = 32;
        local nGamesWidth = 320;
        local nColumnGap = 40;
        local nWelcomeWidth = math.max(1, nWidth - nGamesWidth - nColumnGap);
        local nTextX, nTextY, nTextWidth;

        -- Apply the original welcome geometry within its own area. The main
        -- window is wider to make room for Games without shifting this content.
        if (nWelcomeWidth >= 760) then
            local nArtWidth = math.floor(nWelcomeWidth * 0.43);
            oArtwork.layout(nMargin, nMargin, nArtWidth - nMargin, math.max(1, nHeight - 104));
            nTextX = nArtWidth + 32;
            nTextY = math.max(64, math.floor(nHeight * 0.29));
            nTextWidth = math.max(1, nWelcomeWidth - nTextX - nMargin);
        else
            local nArtHeight = math.max(100, math.floor(nHeight * 0.43));
            oArtwork.layout(nMargin, 20, math.max(1, nWelcomeWidth - nMargin * 2), nArtHeight);
            nTextX, nTextY = nMargin, nArtHeight + 44;
            nTextWidth = math.max(1, nWelcomeWidth - nMargin * 2);
        end
        oTitle:SetSize(nTextX, nTextY, nTextWidth, 52);
        oGreeting.layout(nTextX, nTextY + 68, nTextWidth, 28);
        oDescription.layout(nTextX, nTextY + 108, nTextWidth, 104);

        -- Games has its own column, rather than replacing the introduction.
        local nGamesX = nWelcomeWidth + nColumnGap;
        local nListWidth = math.max(1, nWidth - nGamesX - nMargin);
        oGamesHeader:SetSize(nGamesX, nMargin, nListWidth, 34);
        oGames.layout(nGamesX, nMargin + 48, nListWidth,
            math.max(80, nHeight - nMargin * 2 - 48));
    end

    --[[!
    @fqxn CardForgeEngine.Pages.Welcome.dispose
    @desc Releases wxLuma drawing resources once; the parent destroys native controls.
    !]]
    function Page.dispose()
        if (Page.Disposed) then return; end
        Page.Disposed = true;
        for _, oComponent in ipairs({oArtwork, oGreeting, oDescription, oGames}) do
            oComponent.destroy();
        end
        oSkin.destroy();
    end

    oPanel:Connect(wx.wxEVT_SIZE, function(oEvent)
        fLayout();
        oEvent:Skip();
    end);
    fLayout();
    return Page;
end

return Welcome;