--[[!
@fqxn CFS.Windows.ManualGuide
@desc Modeless, offline Manual Editor Guide. Uses the existing WebView and window-state services; no active game or authoring bridge is required.
!]]
local wx = require("wx");
local WindowState = require("Windows.WindowState");
local ManualGuide = {};
WindowState.register("ManualGuide", {savePosition = true, saveSize = true, saveVisible = false});

--[[!
@fqxn CFS.Windows.ManualGuide.Functions.create
@desc Opens the bundled guide in a dedicated window. The caller may raise the existing window or clear its reference with onClose.
@param any dParent Parent frame.
@param table tOptions Optional onClose callback.
@return table tWindow Frame, show and close functions.
!]]
function ManualGuide.create(dParent, tOptions)
    tOptions = tOptions or {};
    local WebView = assert(wxwebview, "The Manual Editor Guide requires the wxLua WebView binding.");
    local pPage = APP_PATH.."/Docs/Manual Editor Guide/index.html";
    assert(wx.wxFileExists(pPage), "Manual Editor Guide is unavailable: "..pPage);
    local oFile = wx.wxFileName(pPage);
    local sURL = wx.wxFileSystem.FileNameToURL(oFile); oFile:delete();
    local dFrame = wx.wxFrame(dParent, wx.wxID_ANY, "Manual Editor Guide - Card Forge Studio", wx.wxDefaultPosition, wx.wxSize(1180, 820));
    dFrame:SetMinSize(wx.wxSize(720, 500));
    local bOK, oBrowser = pcall(WebView.wxWebView.New, dFrame, wx.wxID_ANY, "about:blank", wx.wxDefaultPosition, wx.wxDefaultSize, "wxWebViewEdge");
    if (not bOK or not oBrowser) then dFrame:Destroy(); error("Cannot create the guide browser: "..tostring(oBrowser), 2); end
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL); oLayout:Add(oBrowser, 1, wx.wxEXPAND); dFrame:SetSizer(oLayout);
    local oState = WindowState.bind(dFrame, "ManualGuide");
    local bClosed = false;
    oBrowser:Connect(WebView.wxEVT_WEBVIEW_NAVIGATING, function(oEvent)
        local sTarget = oEvent:GetURL();
        if (sTarget == "about:blank" or sTarget:match("^[^?#]*") == sURL) then oEvent:Skip(); else oEvent:Veto(); end
    end);
    dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        if (not bClosed) then
            bClosed = true; oBrowser:Stop(); oState.close();
            if (tOptions.onClose) then tOptions.onClose(); end
        end
        oEvent:Skip();
    end);
    oBrowser:LoadURL(sURL); dFrame:Show(true); dFrame:Layout();
    return {frame = dFrame,
        show = function() if (not bClosed) then dFrame:Show(true); dFrame:Raise(); end end,
        close = function() if (bClosed) then return true; end return dFrame:Close(); end};
end
return ManualGuide;
