-- Native message-card window; the Log service owns messages and disk operations.
local wx = require("wx");
local Log = require("Log");
local Window = {};
local WindowState = require("Windows.WindowState");
local _tWindowState = {
    savePosition = true,
    saveSize     = true,
    saveVisible  = true,
};
WindowState.register("Log", _tWindowState);

local _dFrame, _oCards, _oWindowState;
local _tLevelColours = {DEBUG = "#576575", NOTE = "#285a86", WARNING = "#805300", ERROR = "#a02525"};

local function escapeHTML(sText)
    return sText:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("\r\n", "\n"):gsub("\n", "<br>");
end

local function refreshCards()
    if (not _oCards) then
        return;
    end

    local _tEntries = Log.GetEntries();

    local tHTML = {'<html><body bgcolor="#eef0f3"><font face="Segoe UI,Arial" color="#20252b">'};

    if (#_tEntries == 0) then
        tHTML[#tHTML + 1] = '<p>No log messages.</p>';
    end

    for nIndex = #_tEntries, 1, -1 do
        local tEntry = _tEntries[nIndex];
        local sBackground = nIndex % 2 == 1 and "#ffffff" or "#f7f8fa";
        local sLevelColour = _tLevelColours[tEntry.level];
        tHTML[#tHTML + 1] = '<table width="100%" cellspacing="0" cellpadding="12" bgcolor="'..sBackground..'"><tr><td>';
        tHTML[#tHTML + 1] = '<font color="'..sLevelColour..'"><b>'..tEntry.level..'</b></font> &nbsp; <font color="#626a73">'..tEntry.timestamp..'</font><br><br>';
        tHTML[#tHTML + 1] = escapeHTML(tEntry.message)..'</td></tr></table><br>';
    end

    tHTML[#tHTML + 1] = '</font></body></html>';
    _oCards:SetPage(table.concat(tHTML));
    _dFrame:SetStatusText(tostring(#_tEntries).." messages");
end

local function ensureWindow()
    if (_dFrame) then
        return;
    end

    _dFrame = wx.wxFrame(wx.NULL, wx.wxID_ANY, "Card Forge Studio - Log", wx.wxDefaultPosition, wx.wxSize(720, 560));
    _oWindowState = WindowState.bind(_dFrame, "Log");
    _dFrame:SetMinSize(wx.wxSize(420, 280));
    local dPanel = wx.wxPanel(_dFrame, wx.wxID_ANY);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oButtons = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oClear = wx.wxButton(dPanel, wx.wxID_ANY, "Clear Window");
    local oClearLog = wx.wxButton(dPanel, wx.wxID_ANY, "Clear Log");
    oClearLog:SetToolTip("Clears the log and the window.");
    _oCards = wx.wxHtmlWindow(dPanel, wx.wxID_ANY);
    oButtons:Add(oClear, 0, wx.wxALL, 8);
    oButtons:Add(oClearLog, 0, wx.wxTOP + wx.wxRIGHT + wx.wxBOTTOM, 8);
    oLayout:Add(oButtons, 0, wx.wxEXPAND);
    oLayout:Add(_oCards, 1, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 8);
    dPanel:SetSizer(oLayout);
    _dFrame:CreateStatusBar();
    oClear:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        Log.ClearWindow();
    end);
    oClearLog:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        local bOK, sError = pcall(Log.ClearLog);

        if (not bOK) then
            require("Errors").report(sError);
        end
    end);
    _dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        if (oEvent:CanVeto()) then
            _dFrame:Hide();
            oEvent:Veto();
        else
            _oWindowState.close();
            _dFrame:Destroy();
            _dFrame, _oCards = nil, nil;
        end
    end);
    refreshCards();
end

function Window.Show()
    ensureWindow();
    _dFrame:Show(true);
    _dFrame:Raise();
end

function Window.IsShown()
    return _dFrame ~= nil and _dFrame:IsShown();
end

function Window.Close()
    if (_dFrame) then
        _oWindowState.close();
        _dFrame:Destroy();
        _dFrame, _oCards = nil, nil;
    end
end

Log.subscribe(refreshCards);

return Window;
