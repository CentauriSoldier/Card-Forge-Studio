local wx       = require("wx");
local Exporter = require("Exporter");
local PNG      = require("Exporters.ExporterPNG");
local Themes   = require("Exporters.HTML.Themes");
local ipairs   = ipairs;
local pairs    = pairs;
local pcall    = pcall;
local table    = table;
local tostring = tostring;
local Options  = {};

--[[!
@fqxn CFS.Modules.Exporter.Support.Options
@desc Native format-specific options for CSV, JSON, Lua, HTML, and ZIP. The grid supplies export scope; this dialog saves only the active format's per-card-set choices. Cancel discards drafts.
@vis private
!]]

--[[!
@fqxn CFS.Modules.Exporter.Support.Options.Functions.create
@desc Builds a compact options dialog with data, gallery, or package controls appropriate to the selected format. Image choices retain the same meaning as PNG export.
@param any dParent Parent window.
@param string pInfo Card-set metadata.
@param table tNames Source-row names.
@param number nWidth Native width.
@param number nHeight Native height.
@param string sType Selected format.
@return table tWindow Controls, model, save operation, and native dialog.
@vis private
!]]
function Options.create(dParent, pInfo, tNames, nWidth, nHeight, sType)
    local service = Exporter.get(sType); local tModel = service.model(pInfo); local tSettings = tModel.options;
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, sType == "Zip" and "ZIP Export Options" or sType.." Export Options", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local sExplanation = "Exports finalized text values in original column order. Choose All, Visible, or Selected in the data grid.";
    if (sType == "HTML") then sExplanation = "An offline gallery with search, filters, enlarged viewing, and front/back switching. Keep its output files together."; end
    if (sType == "Zip") then sExplanation = "Packages only generated card output. A gallery always includes its artwork. No source scripts or original game files are copied."; end
    local oExplanation = wx.wxStaticText(dDialog, wx.wxID_ANY, sExplanation); oExplanation:Wrap(500); oLayout:Add(oExplanation, 0, wx.wxEXPAND + wx.wxALL, 14);
    local oFields = wx.wxFlexGridSizer(0, 2, 10, 14); oFields:AddGrowableCol(1);
    local tWindow = {dialog = dDialog, model = tModel};
    --[[!
    @fqxn CFS.Modules.Exporter.Support.Options.Private.Functions.field
    @desc Adds an aligned label and control.
    @vis private
    !]]
    local function field(sLabel, oControl)
        oFields:Add(wx.wxStaticText(dDialog, wx.wxID_ANY, sLabel), 0, wx.wxALIGN_CENTER_VERTICAL);
        oFields:Add(oControl, 1, wx.wxEXPAND); return oControl;
    end
    --[[!
    @fqxn CFS.Modules.Exporter.Support.Options.Private.Functions.choice
    @desc Creates a native labeled choice.
    @vis private
    !]]
    local function choice(sLabel, tChoices)
        return field(sLabel, wx.wxChoice(dDialog, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(300, -1), tChoices));
    end
    --[[!
    @fqxn CFS.Modules.Exporter.Support.Options.Private.Functions.checkbox
    @desc Creates a draft boolean setting.
    @vis private
    !]]
    local function checkbox(sLabel, bValue)
        local oControl = wx.wxCheckBox(dDialog, wx.wxID_ANY, sLabel); oControl:SetValue(bValue); oLayout:Add(oControl, 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 14); return oControl;
    end
    if (sType == "CSV") then
        tWindow.headers = checkbox("Include column headers", tSettings.headers);
        tWindow.bom = checkbox("UTF-8 BOM for spreadsheet encoding detection", tSettings.bom);
    end
    if (sType == "Zip") then
        tWindow.images = checkbox("PNG artwork", tSettings.images);
        tWindow.data = checkbox("Finalized data: CSV, JSON, and Lua", tSettings.data);
        tWindow.gallery = checkbox("Themed interactive HTML gallery (includes artwork)", tSettings.gallery);
    end
    local tThemeKeys = {};
    if (sType == "HTML" or sType == "Zip") then
        tThemeKeys[1] = "midnight_blue";
        local tOther = {}; for sKey in pairs(Themes) do if(sKey ~= "midnight_blue") then tOther[#tOther + 1] = sKey; end; end
        table.sort(tOther, function(a,b) return Themes[a].name < Themes[b].name; end);
        for _, sKey in ipairs(tOther) do tThemeKeys[#tThemeKeys + 1] = sKey; end
        local tLabels = {}; for _, sKey in ipairs(tThemeKeys) do tLabels[#tLabels + 1] = Themes[sKey].name; end
        tWindow.theme = choice("Gallery theme", tLabels);
        for nIndex, sKey in ipairs(tThemeKeys) do if(sKey == tSettings.theme) then tWindow.theme:SetSelection(nIndex - 1); end; end
        tWindow.title = field("Gallery title", wx.wxTextCtrl(dDialog, wx.wxID_ANY, tSettings.title)); tWindow.title:SetMaxLength(160);
        tWindow.scale = field("Artwork size (%)", wx.wxSpinCtrl(dDialog, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(120, -1), wx.wxSP_ARROW_KEYS, 1, 1000, tSettings.scale));
        tWindow.dimensions = field("Output dimensions", wx.wxStaticText(dDialog, wx.wxID_ANY, ""));
        tWindow.sides = choice("Export sides", {"Fronts only", "Fronts and backs", "Backs only"});
        local tSides = {"fronts", "both", "backs"};
        for nIndex, sSide in ipairs(tSides) do if(tSettings.sides == sSide) then tWindow.sides:SetSelection(nIndex - 1); end; end
        tWindow.backs = choice("Back images", {"One shared back", "One back per card"}); tWindow.backs:SetSelection(tSettings.backs == "shared" and 0 or 1);
        local tRows = {"First exported card"}; for nRow, sName in ipairs(tNames) do tRows[#tRows + 1] = "Row "..nRow.." - "..sName; end
        tWindow.row = choice("Shared-back card", tRows); tWindow.row:SetSelection(tSettings.backRow <= #tNames and tSettings.backRow or 0);
        --[[!
        @fqxn CFS.Modules.Exporter.Support.Options.Private.Functions.update
        @desc Refreshes enabled image/gallery controls and scaled dimensions.
        @vis private
        !]]
        local function update()
            local bImages = sType == "HTML" or tWindow.images:GetValue() or tWindow.gallery:GetValue();
            local bGallery = sType == "HTML" or tWindow.gallery:GetValue();
            tWindow.scale:Enable(bImages); tWindow.sides:Enable(bImages); tWindow.theme:Enable(bGallery); tWindow.title:Enable(bGallery);
            local bBacks = bImages and tWindow.sides:GetSelection() ~= 0;
            tWindow.backs:Enable(bBacks); tWindow.row:Enable(bBacks and tWindow.backs:GetSelection() == 0);
            local bOK, nOutputWidth, nOutputHeight = pcall(PNG.dimensions, nWidth, nHeight, tWindow.scale:GetValue());
            tWindow.dimensions:SetLabel(not bImages and "Artwork not included" or bOK and (nOutputWidth.." × "..nOutputHeight.." pixels") or "Invalid or oversized output dimensions");
            dDialog:Layout();
        end
        for _, oControl in ipairs({tWindow.sides, tWindow.backs}) do oControl:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, update); end
        tWindow.scale:Connect(wx.wxEVT_COMMAND_SPINCTRL_UPDATED, update); tWindow.scale:Connect(wx.wxEVT_COMMAND_TEXT_UPDATED, update);
        if (sType == "Zip") then tWindow.images:Connect(wx.wxEVT_COMMAND_CHECKBOX_CLICKED, update); tWindow.gallery:Connect(wx.wxEVT_COMMAND_CHECKBOX_CLICKED, update); end
        tWindow.update = update; update();
    end
    oLayout:Add(oFields, 1, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 14);
    local oStatus = wx.wxStaticText(dDialog, wx.wxID_ANY, ""); oStatus:SetForegroundColour(wx.wxColour("#B03030")); oStatus:Hide(); oLayout:Add(oStatus, 0, wx.wxEXPAND + wx.wxALL, 14);
    oLayout:Add(dDialog:CreateButtonSizer(wx.wxOK + wx.wxCANCEL), 0, wx.wxEXPAND + wx.wxALL, 10);
    dDialog:SetSizerAndFit(oLayout); dDialog:SetMinSize(dDialog:GetSize()); dDialog:CentreOnParent();
    --[[!
    @fqxn CFS.Modules.Exporter.Support.Options.Private.Functions.save
    @desc Collects draft controls, validates artwork and package choices, and saves through the transactional model.
    @vis private
    !]]
    function tWindow.save()
        local tNew = {}; for sKey, vValue in pairs(tSettings) do tNew[sKey] = vValue; end
        if (sType == "CSV") then tNew.headers, tNew.bom = tWindow.headers:GetValue(), tWindow.bom:GetValue(); end
        if (sType == "Zip") then tNew.images, tNew.data, tNew.gallery = tWindow.images:GetValue(), tWindow.data:GetValue(), tWindow.gallery:GetValue(); end
        if (sType == "HTML" or sType == "Zip") then
            tNew.theme, tNew.title, tNew.scale = tThemeKeys[tWindow.theme:GetSelection() + 1], tWindow.title:GetValue(), tWindow.scale:GetValue();
            tNew.sides = ({"fronts", "both", "backs"})[tWindow.sides:GetSelection() + 1]; tNew.backs = tWindow.backs:GetSelection() == 0 and "shared" or "individual"; tNew.backRow = tWindow.row:GetSelection();
            if (sType == "HTML" or tNew.images or tNew.gallery) then
                PNG.dimensions(nWidth, nHeight, tNew.scale);
                if (#tNames > 0) then PNG.plan({1}, tNew, tNames, #tNames); end
            end
        end
        tModel.saveOptions(tNew);
    end
    dDialog:Connect(wx.wxID_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        local bOK, sError = pcall(tWindow.save);
        if (bOK) then dDialog:EndModal(wx.wxID_OK);
        else oStatus:SetLabel(tostring(sError)); oStatus:Wrap(500); oStatus:Show(); dDialog:Layout(); require("Errors").report(sError); end
    end);
    return tWindow;
end
return Options;
