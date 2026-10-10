--[[!
@fqxn CFS.Modules.Tests.DataWindows
@desc Development test harness; not a public application API.
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
