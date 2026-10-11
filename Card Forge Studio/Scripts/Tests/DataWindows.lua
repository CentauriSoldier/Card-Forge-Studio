--[[!
@fqxn CFS.Modules.Tests.DataWindows
@desc
<section aria-label="DataWindows · Development overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">DataWindows · Development</h2><p style="font-size:1.15rem;margin:0">This file is a development check, not a user-facing feature.</p></div>
<h3>How it fits into your work</h3><p>It exercises application behavior during development rather than providing a game drawing or processing API.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Main">Main</a></h3><p style="margin:0">The main Studio window connects your project, preview, and editing tools.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataSession">Shared Data Session</a></h3><p style="margin:0">The shared session keeps both grids looking at the same underlying cards.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Tests should use synthetic fixtures in temporary storage and never publish personal paths or private game data.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
@vis private
!]]

-- Standalone interaction test. These rows are fixtures, not game data.
-- No game files or CSV files are written by this test.
local _pTests = assert(debug.getinfo(1, "S").source:match("^@(.+[/\\])"));
local _pScripts = _pTests.."../";
package.path = _pScripts.."?.lua;"..package.path;
package.cpath = _pScripts.."../Bin/?.dll;"..package.cpath;

local wx = require("wx");
local Base64 = require("Plugins.LuaEx.lib.base64");
local _tSession;
local _tBaseRows = {
    {Name = "Alpha", Power = "10", Code = Base64.enc("return function()\n    return 10;\nend")},
    {Name = "Beta", Power = "2", Code = ""},
    {Name = "Gamma", Power = "30", Code = ""},
};

local function processRow(tBaseRow)
    return {Name = tBaseRow.Name, Power = tostring((tonumber(tBaseRow.Power) or 0) * 2),
        Code = tBaseRow.Code ~= "" and "Code stored" or ""};
end

local _tFinalRows = {};

for nRow, tRow in ipairs(_tBaseRows) do
    _tFinalRows[nRow] = processRow(tRow);
end

_tSession = require("Windows.DataSession").create({
    onEdit = function(nRow, sHeader, sValue)
        local tRow = {};

        for sColumn, sText in pairs(_tSession.base[nRow]) do
            tRow[sColumn] = sText;
        end

        tRow[sHeader] = sValue;

        return processRow(tRow);
    end,
    onReprocess = function(nRow)
        _tSession.final[nRow] = processRow(_tSession.base[nRow]);
        _tSession.refresh();
    end,
});
_tSession.setData({"Name", "Power", "Code"}, _tBaseRows, _tFinalRows, {Code = true});

local _dBase = require("Windows.BaseData").create(_tSession);
local _dFinal = require("Windows.FinalData").create(_tSession);
local _dTest = wx.wxFrame(wx.NULL, wx.wxID_ANY, "Data Window Test",
    wx.wxDefaultPosition, wx.wxSize(620, 220));
local _dPanel = wx.wxPanel(_dTest, wx.wxID_ANY);
local _oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
local _oText = wx.wxStaticText(_dPanel, wx.wxID_ANY,
    "Test rows only. Final Power is twice Base Power.\n\n"..
    "Try search, Contains filters, Base/Final values, sorting, and selection in either grid.\n"..
    "Edit Base Power. Double-click a Base Code cell to open the modal Lua editor.\n"..
    "Save is disabled because this test does not write CSV files.\n\n"..
    "Close this test window to close both grids.");
_oLayout:Add(_oText, 1, wx.wxEXPAND + wx.wxALL, 12);
_dPanel:SetSizer(_oLayout);
_dBase.frame:SetTitle("Base Data - Test Rows");
_dFinal.frame:SetTitle("Final Data - Test Rows");
_dBase.frame:Move(30, 50);
_dFinal.frame:Move(960, 50);
_dTest:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
    _dBase.close();
    _dFinal.close();
    oEvent:Skip();
end);
_dBase.show();
_dFinal.show();
_dTest:Show(true);
wx.wxGetApp():MainLoop();
os.exit(0);
