local assert    = assert;
local io        = io;
local wx        = require("wx");
local License   = {};

--[[!
@fqxn CFS.Windows.License
@desc Displays Studio’s root LICENSE text with an explanation of the separate terms that apply to third-party components. The text is read from disk whenever the page opens, so the page and packaged license remain connected.
!]]

--[[!
@fqxn CFS.Windows.License.Private.Functions.escapeHTML
@desc Escapes file text before placing it in the license viewer.
@param string sText License file contents.
@return string sHTML Escaped text.
@vis private
!]]
local function escapeHTML(sText)
    return sText:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;");
end


--[[!
@fqxn CFS.Windows.License.Functions.show
@pulsarlua function License.show
@desc Opens a resizable license viewer using the application-root LICENSE file. Third-party terms are explained above the displayed text. Missing or unreadable license files are reported to the caller.
@param any dParent Parent window.
!]]
function License.show(dParent)
    local hFile = assert(io.open(APP_PATH.."/LICENSE", "rb"), "Cannot open the application LICENSE file.");
    local sText = hFile:read("a");
    local bClosed = hFile:close();
    assert(sText and bClosed, "Cannot read the application LICENSE file.");

    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, "License", wx.wxDefaultPosition, wx.wxSize(780, 620), wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oPage = wx.wxHtmlWindow(dDialog, wx.wxID_ANY);
    local sHTML = '<html><body bgcolor="#eef0f3"><font face="Segoe UI,Arial" color="#20252b"><h1>Card Forge Studio License</h1>'..
        '<table width="100%" cellpadding="14" bgcolor="#ffffff"><tr><td><h3>Our code and third-party components</h3>'..
        '<p>Card Forge Studio uses the Unlicense for its own original work wherever applicable. The license below does not change the ownership or license terms of third-party software, fonts, artwork, or other components. Those items remain subject to their respective licenses and notices.</p>'..
        '<p>Bundled third-party notices are available under Docs/Licenses.</p></td></tr></table><br>'..
        '<table width="100%" cellpadding="14" bgcolor="#ffffff"><tr><td><h2>The Unlicense</h2><font face="Courier New">'..
        escapeHTML(sText):gsub("\r\n", "\n"):gsub("\n", "<br>")..'</font></td></tr></table></font></body></html>';
    oPage:SetPage(sHTML);
    oLayout:Add(oPage, 1, wx.wxEXPAND + wx.wxALL, 12);
    local oClose = wx.wxButton(dDialog, wx.wxID_OK, "Close");
    oLayout:Add(oClose, 0, wx.wxALIGN_RIGHT + wx.wxRIGHT + wx.wxBOTTOM, 12);
    dDialog:SetSizer(oLayout);
    dDialog:SetMinSize(wx.wxSize(460, 340));
    dDialog:CentreOnParent();
    dDialog:ShowModal();
    dDialog:Destroy();
end


return License;
