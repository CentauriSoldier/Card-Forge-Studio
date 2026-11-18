-- Manual appearance controls edit only the active game's manual settings.
local wx = require("wx");
local Appearance = require("Manual.Appearance");
local ManualAppearance = {};
function ManualAppearance.create(dPage, oPage, pManual)
    local tDraft, sOriginal = Appearance.load(pManual);
    local tLabels = {};
    for _, tTarget in ipairs(Appearance.targets) do tLabels[#tLabels + 1] = tTarget.label; end
    oPage:Add(wx.wxStaticText(dPage, wx.wxID_ANY, "Game manual appearance (saved in Manual/Config/Appearance.lua)"), 0, wx.wxTOP + wx.wxBOTTOM, 12);
    local oTarget = wx.wxChoice(dPage, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tLabels);
    oTarget:SetSelection(0); oPage:Add(oTarget, 0, wx.wxEXPAND + wx.wxBOTTOM, 8);
    local oHelp = wx.wxStaticText(dPage, wx.wxID_ANY, "Blank values inherit the existing design. Sizes accept CSS units (px, rem, %, etc.). Artwork paths are relative to the manual, e.g. Images/Appearance/Defaults/Panel.svg. Named text styles reference your game styles.");
    oHelp:Wrap(590); oPage:Add(oHelp, 0, wx.wxEXPAND + wx.wxBOTTOM, 8);
    local oGrid = wx.wxGrid(dPage, wx.wxID_ANY);
    oGrid:CreateGrid(#Appearance.fields, 2); oGrid:SetRowLabelSize(0);
    oGrid:SetColLabelValue(0, "Property"); oGrid:SetColLabelValue(1, "Override (blank inherits)");
    oGrid:SetColSize(0, 225); oGrid:SetColSize(1, 345);
    oPage:Add(oGrid, 1, wx.wxEXPAND + wx.wxBOTTOM, 8);
    local tStyles = Appearance.styleNames(pManual);
    table.insert(tStyles, 1, "Inherit text style");
    local oStyle = wx.wxChoice(dPage, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tStyles);
    oStyle:SetSelection(0); oPage:Add(oStyle, 0, wx.wxEXPAND + wx.wxBOTTOM, 8);
    oStyle:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, function()
        oGrid:SetCellValue(0, 1, oStyle:GetSelection() == 0 and "" or oStyle:GetStringSelection());
    end);
    local nTarget = 1;
    local function commit()
        if (oGrid:IsCellEditControlEnabled()) then oGrid:SaveEditControlValue(); oGrid:DisableCellEditControl(); end
        local tValues = {};
        for nRow, tField in ipairs(Appearance.fields) do
            local sValue = oGrid:GetCellValue(nRow - 1, 1):match('^%s*(.-)%s*$');
            if (sValue ~= '') then tValues[tField.key] = sValue; end
        end
        tDraft.Properties[Appearance.targets[nTarget].key] = next(tValues) and tValues or nil;
    end
    local function display()
        local tValues = tDraft.Properties[Appearance.targets[nTarget].key] or {};
        oStyle:SetSelection(0);
        if (tValues.textStyle) then oStyle:SetStringSelection(tValues.textStyle); end
        for nRow, tField in ipairs(Appearance.fields) do
            oGrid:SetCellValue(nRow - 1, 0, tField.label); oGrid:SetReadOnly(nRow - 1, 0, true);
            oGrid:SetCellValue(nRow - 1, 1, tValues[tField.key] or '');
        end
    end
    oTarget:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, function() commit(); nTarget = oTarget:GetSelection() + 1; display(); end);
    display();
    return {
        validate = function()
            commit(); Appearance.validate(tDraft);
            -- Resolve styles and artwork before any options are written.
            Appearance.css(pManual, '.manual-appearance', '../content-images/', tDraft);
        end,
        save = function()
            Appearance.save(pManual, tDraft, sOriginal);
            local Documents = require('Manual.Documents');
            sOriginal = Documents.read(pManual..'/Config/Appearance.lua');
        end,
    };
end
return ManualAppearance;
