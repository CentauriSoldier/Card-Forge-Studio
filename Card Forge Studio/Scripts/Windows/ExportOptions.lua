--[[!
@fqxn CFS.Windows.ExportOptions
@desc Per-card-set PNG export settings and output dimension preview.
!]]

-- Per-card-set export options. Each supported format has its own tab.
local wx = require("wx");
local ExporterPNG = require("Exporter").get("PNG");
local ExportOptions = {};
--[[!
@fqxn CFS.Windows.ExportOptions.create
@pulsarlua function ExportOptions.create
@desc Creates per-card-set PNG options for scale, sides, back mode, and shared-back row.
@param any dParent Parent window.
@param any pInfo Info.
@param any tNames Names.
@param any nWidth Width.
@param any nHeight Height.
!]]
function ExportOptions.create(dParent, pInfo, tNames, nWidth, nHeight)
    local tModel = ExporterPNG.model(pInfo);
    local tSettings = tModel.options;
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, "Export Options", wx.wxDefaultPosition, wx.wxSize(520, 330), wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oBook = wx.wxNotebook(dDialog, wx.wxID_ANY);
    local dPNG = wx.wxPanel(oBook, wx.wxID_ANY); local oPNG = wx.wxBoxSizer(wx.wxVERTICAL);
    --[[!
    @fqxn CFS.Windows.ExportOptions.Private.choice
    @desc Adds a labeled choice control to the PNG options page.
    @vis private
    @param any sLabel Label.
    @param any tChoices Choices.
    !]]
    local function choice(sLabel, tChoices)
        oPNG:Add(wx.wxStaticText(dPNG, wx.wxID_ANY, sLabel), 0, wx.wxLEFT + wx.wxRIGHT + wx.wxTOP, 12);
        local oChoice = wx.wxChoice(dPNG, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tChoices);
        oPNG:Add(oChoice, 0, wx.wxEXPAND + wx.wxALL, 12); return oChoice;
    end
    oPNG:Add(wx.wxStaticText(dPNG, wx.wxID_ANY, "Output size (%) — 100% is the card's native size"), 0, wx.wxLEFT + wx.wxRIGHT + wx.wxTOP, 12);
    local oScale = wx.wxSpinCtrl(dPNG, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(110, -1), wx.wxSP_ARROW_KEYS, 1, 1000, tSettings.scale);
    local oScaleRow = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oDefault = wx.wxButton(dPNG, wx.wxID_ANY, "Default", wx.wxDefaultPosition, wx.wxSize(-1, oScale:GetBestSize():GetHeight()));
    oScaleRow:Add(oScale, 0, wx.wxEXPAND); oScaleRow:Add(oDefault, 0, wx.wxEXPAND + wx.wxLEFT, 8);
    oPNG:Add(oScaleRow, 0, wx.wxALL, 12);
    local oDimensions = wx.wxStaticText(dPNG, wx.wxID_ANY, ""); oPNG:Add(oDimensions, 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 12);
    --[[!
    @fqxn CFS.Windows.ExportOptions.Private.showDimensions
    @desc Displays scaled dimensions or the output-pixel limit when the requested size is invalid.
    @vis private
    !]]
    local function showDimensions()
        if (not nWidth or not nHeight) then oDimensions:SetLabel("Maximum: 64 million output pixels."); return; end
        local bOK, nOutputWidth, nOutputHeight = pcall(ExporterPNG.dimensions, nWidth, nHeight, oScale:GetValue());
        oDimensions:SetLabel(bOK and (nOutputWidth.." × "..nOutputHeight.." pixels") or "Too large: maximum 64 million output pixels.");
        dPNG:Layout();
    end
    oScale:Connect(wx.wxEVT_COMMAND_SPINCTRL_UPDATED, showDimensions); oScale:Connect(wx.wxEVT_COMMAND_TEXT_UPDATED, showDimensions); showDimensions();
    oDefault:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() oScale:SetValue(100); showDimensions(); end);
    local oSides = choice("Export sides", {"Fronts only", "Fronts and backs", "Backs only"});
    local tSides = {"fronts", "both", "backs"};
    for nIndex, sSide in ipairs(tSides) do if (tSettings.sides == sSide) then oSides:SetSelection(nIndex - 1); end end
    local oBacks = choice("Back images", {"One shared back", "One back per card"}); oBacks:SetSelection(tSettings.backs == "shared" and 0 or 1);
    local tRows = {"First exported card"};
    for nRow, sName in ipairs(tNames) do tRows[#tRows + 1] = "Row "..nRow.." - "..sName; end
    local oRow = choice("Card used for the shared back", tRows); oRow:SetSelection(tSettings.backRow <= #tNames and tSettings.backRow or 0);
    --[[!
    @fqxn CFS.Windows.ExportOptions.Private.update
    @desc Enables back-image controls only when the selected sides require them.
    @vis private
    !]]
    local function update() local bBacks = oSides:GetSelection() ~= 0; oBacks:Enable(bBacks); oRow:Enable(bBacks and oBacks:GetSelection() == 0); end
    oSides:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, update); oBacks:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, update); update();
    dPNG:SetSizer(oPNG); oBook:AddPage(dPNG, "PNG"); oLayout:Add(oBook, 1, wx.wxEXPAND + wx.wxALL, 10);
    local oStatus = wx.wxStaticText(dDialog, wx.wxID_ANY, ""); oStatus:SetForegroundColour(wx.wxColour("#B03030")); oStatus:Hide(); oLayout:Add(oStatus, 0, wx.wxEXPAND + wx.wxALL, 10);
    oLayout:Add(dDialog:CreateButtonSizer(wx.wxOK + wx.wxCANCEL), 0, wx.wxEXPAND + wx.wxALL, 8);
    dDialog:SetSizerAndFit(oLayout); dDialog:SetMinSize(dDialog:GetSize()); dDialog:CentreOnParent();
    --[[!
    @fqxn CFS.Windows.ExportOptions.Private.save
    @desc Validates output dimensions and persists selected PNG options through the exporter model.
    @vis private
    !]]
    local function save()
        if (nWidth and nHeight) then ExporterPNG.dimensions(nWidth, nHeight, oScale:GetValue()); end
        tModel.saveOptions({scale = oScale:GetValue(), type = "PNG", sides = tSides[oSides:GetSelection() + 1], backs = oBacks:GetSelection() == 0 and "shared" or "individual", backRow = oRow:GetSelection()});
    end
    dDialog:Connect(wx.wxID_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        local bOK, sError = pcall(save);
        if (bOK) then dDialog:EndModal(wx.wxID_OK);
        else oStatus:SetLabel(tostring(sError)); oStatus:Wrap(470); oStatus:Show(); dDialog:Layout(); require("Errors").report(sError); end
    end);
    return {default = oDefault, scale = oScale, dimensions = oDimensions, dialog = dDialog, book = oBook, sides = oSides, backs = oBacks, row = oRow, save = save, model = tModel};
end
--[[!
@fqxn CFS.Windows.ExportOptions.show
@pulsarlua function ExportOptions.show
@desc Runs and destroys the options dialog, returning whether the user accepted it.
@param any dParent Parent window.
@param any pInfo Info.
@param any tNames Names.
@param any nWidth Width.
@param any nHeight Height.
!]]
function ExportOptions.show(dParent, pInfo, tNames, nWidth, nHeight)
    local tWindow = ExportOptions.create(dParent, pInfo, tNames, nWidth, nHeight); local nResult = tWindow.dialog:ShowModal(); tWindow.dialog:Destroy(); return nResult == wx.wxID_OK;
end
return ExportOptions;
