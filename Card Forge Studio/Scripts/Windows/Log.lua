--[[!
@fqxn CFS.Windows.Log
@desc
<section aria-label="Windows.Log overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">Windows.Log</h2><p style="font-size:1.15rem;margin:0">The log window displays recorded messages as readable cards.</p></div>
<h3>How it fits into your work</h3><p>Inspect messages, copy a single entry, or copy the whole log for diagnosis.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.Log">Log</a></h3><p style="margin:0">Logging records Studio activity and preserves useful context when something goes wrong.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Errors">Errors</a></h3><p style="margin:0">Error reporting gives services a shared way to record failures without opening modal windows.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">The window is the presentation layer. The logging service owns recorded messages and disk output.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

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

--[[!
@fqxn CFS.Windows.Log.Private.Functions.copyText
@desc Copies plain text to the native clipboard and reports failure without leaving the clipboard open.
@param string sText Text to copy.
!]]
local function copyText(sText)
    local oClipboard = wx.wxClipboard.Get();
    if (not oClipboard:Open()) then
        require("Errors").report("Clipboard is unavailable.");

        return;
    end

    local bOK, vResult = pcall(function()
        return oClipboard:SetData(wx.wxTextDataObject(sText));
    end);
    oClipboard:Close();

    if (not bOK or not vResult) then
        require("Errors").report(bOK and "Could not copy log text." or vResult);
    end
end


--[[!
@fqxn CFS.Windows.Log.Private.Functions.entryText
@desc Formats a log entry as plain text, retaining its level, timestamp and multiline message.
@param table tEntry Log entry.
@return string Copyable entry text.
!]]
local function entryText(tEntry)
    return "["..tEntry.level.." > "..tEntry.timestamp.."]\r\n"..tEntry.message;
end


--[[!
@fqxn CFS.Windows.Log.Private.Functions.escapeHTML
@desc Escapes log text for HTML cards and converts line breaks to HTML breaks.
@param any sText Text.
@vis private
!]]
local function escapeHTML(sText)
    return sText:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("\r\n", "\n"):gsub("\n", "<br>");
end

--[[!
@fqxn CFS.Windows.Log.Private.Functions.refreshCards
@desc Rebuilds the log-card HTML from current in-memory entries.
@vis private
!]]
local function refreshCards()
    if (not _oCards) then
        return;
    end

    local _tEntries = Log.GetEntries();

    local tHTML = {'<html><body bgcolor="#eef0f3"><font face="Segoe UI,Arial" color="#20252b">'};

    if (#_tEntries == 0) then
        tHTML[#tHTML + 1] = '<p>No log messages.</p>';
    end

    for nIndex = 1, #_tEntries do
        local tEntry = _tEntries[nIndex];
        local sBackground = nIndex % 2 == 1 and "#ffffff" or "#f7f8fa";
        local sLevelColour = _tLevelColours[tEntry.level];
        tHTML[#tHTML + 1] = '<table width="100%" cellspacing="0" cellpadding="12" bgcolor="'..sBackground..'"><tr><td>';
        tHTML[#tHTML + 1] = '<font color="'..sLevelColour..'"><b>'..tEntry.level..'</b></font> &nbsp; <font color="#626a73">'..tEntry.timestamp..'</font><br><br>';
        tHTML[#tHTML + 1] = escapeHTML(tEntry.message)..'</td><td width="65" valign="top" align="right"><table cellpadding="5" bgcolor="#e1e7ee"><tr><td><a href="copy:'..nIndex..'">Copy</a></td></tr></table></td></tr></table><br>';
    end

    tHTML[#tHTML + 1] = '</font></body></html>';
    _oCards:SetPage(table.concat(tHTML));
    _oCards:Scroll(0, _oCards:GetScrollRange(wx.wxVERTICAL));
    _dFrame:SetStatusText(tostring(#_tEntries).." messages");
end

--[[!
@fqxn CFS.Windows.Log.Private.Functions.ensureWindow
@desc Creates the native log frame and controls once and binds persistent window state.
@vis private
!]]
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
    local oCopyAll = wx.wxButton(dPanel, wx.wxID_ANY, "Copy All");
    local oClear = wx.wxButton(dPanel, wx.wxID_ANY, "Clear Window");
    local oClearLog = wx.wxButton(dPanel, wx.wxID_ANY, "Clear Log");
    oClearLog:SetToolTip("Clears the log and the window.");
    _oCards = wx.wxHtmlWindow(dPanel, wx.wxID_ANY);
    oButtons:Add(oCopyAll, 0, wx.wxALL, 8);
    oButtons:Add(oClear, 0, wx.wxTOP + wx.wxRIGHT + wx.wxBOTTOM, 8);
    oButtons:Add(oClearLog, 0, wx.wxTOP + wx.wxRIGHT + wx.wxBOTTOM, 8);
    oLayout:Add(oButtons, 0, wx.wxEXPAND);
    oLayout:Add(_oCards, 1, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 8);
    dPanel:SetSizer(oLayout);
    _dFrame:CreateStatusBar();
    oCopyAll:SetToolTip("Copies every displayed log entry to the clipboard.");
    oCopyAll:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        local tRecords = {};

        for _, tEntry in ipairs(Log.GetEntries()) do
            tRecords[#tRecords + 1] = entryText(tEntry);
        end

        if (#tRecords == 0) then return; end

        copyText(table.concat(tRecords, "\r\n\r\n"));
    end);
    _oCards:Connect(wx.wxEVT_HTML_LINK_CLICKED, function(oEvent)
        local nIndex = tonumber(oEvent:GetLinkInfo():GetHref():match("^copy:(%d+)$"));
        local tEntry = nIndex and Log.GetEntries()[nIndex];

        if (tEntry) then
            copyText(entryText(tEntry));
        end
    end);
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

--[[!
@fqxn CFS.Windows.Log.Functions.Show
@pulsarlua function Window.Show
@desc Creates the log window if needed, then shows and raises it.
!]]
function Window.Show()
    ensureWindow();
    _dFrame:Show(true);
    _dFrame:Raise();
end

--[[!
@fqxn CFS.Windows.Log.Functions.IsShown
@pulsarlua function Window.IsShown
@desc Reports whether the log frame exists and is visible.
!]]
function Window.IsShown()
    return _dFrame ~= nil and _dFrame:IsShown();
end

--[[!
@fqxn CFS.Windows.Log.Functions.Close
@pulsarlua function Window.Close
@desc Saves window state, destroys the log frame, and clears its native references.
!]]
function Window.Close()
    if (_dFrame) then
        _oWindowState.close();
        _dFrame:Destroy();
        _dFrame, _oCards = nil, nil;
    end
end

Log.subscribe(refreshCards);

return Window;
