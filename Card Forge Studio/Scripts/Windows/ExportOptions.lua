--[[!
@fqxn CFS.Windows.ExportOptions
@desc
<section aria-label="ExportOptions overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">ExportOptions</h2><p style="font-size:1.15rem;margin:0">Export Options configures images, versioned atlases, finalized data, themed HTML galleries, and ZIP packages for the active card set.</p></div>
<h3>How it fits into your work</h3><p>Choose faces and percentage sizing, inspect expected output dimensions, and retain choices for the set.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Exporter.Exporters.ExporterPNG">PNG Export</a></h3><p style="margin:0">PNG export turns your finished card artwork into individual image files.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.DataGrid">Data Grid</a></h3><p style="margin:0">The common grid supplies table controls for both data windows.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Classes.CardSet">Card Set</a></h3><p style="margin:0">A card set brings together one collection of cards, its dimensions, and the files that describe how those cards look and behave.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">These settings remain per card set rather than being moved into global grid preferences.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- Per-card-set export options. Each supported format has its own tab.
local wx = require("wx");
local ExporterPNG = require("Exporter").get("PNG");
local ExportOptions = {};
--[[!
@fqxn CFS.Windows.ExportOptions.Functions.create
@pulsarlua function ExportOptions.create
@desc Creates per-card-set format options. PNG and Atlas retain image controls; data, gallery, and ZIP settings use their dedicated controls. Accepted changes are validated before saving; Cancel leaves metadata unchanged.
@param any dParent Parent window.
@param any pInfo Info.
@param any tNames Names.
@param any nWidth Width.
@param any nHeight Height.
@param string|nil sType PNG, Atlas, CSV, JSON, Lua, HTML, or Zip; defaults to PNG.
!]]
function ExportOptions.create(dParent, pInfo, tNames, nWidth, nHeight, sType)
    sType = sType or "PNG";
    if (sType ~= "PNG" and sType ~= "Atlas") then return require("Exporters.Options").create(dParent, pInfo, tNames, nWidth, nHeight, sType); end
    local service = require("Exporter").get(sType);
    local tModel = service.model(pInfo);
    local tSettings = tModel.options;
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, "Export Options", wx.wxDefaultPosition, wx.wxSize(520, 330), wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oBook = wx.wxNotebook(dDialog, wx.wxID_ANY);
    local dPNG = wx.wxPanel(oBook, wx.wxID_ANY); local oPNG = wx.wxBoxSizer(wx.wxVERTICAL);
    --[[!
    @fqxn CFS.Windows.ExportOptions.Private.Functions.choice
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
    local oTarget, oPageWidth, oPageHeight, oPadding;
    if (sType == "Atlas") then
        oTarget = choice("Target and format version", {"Generic — CFS Atlas format 1", "LÖVE — 11.5"});
        oTarget:SetSelection(tSettings.target == "Love_11_5" and 1 or 0);
        local oSizes = wx.wxFlexGridSizer(2, 3, 6, 12);
        for _, sLabel in ipairs({"Page width (px)", "Page height (px)", "Padding per edge (px)"}) do oSizes:Add(wx.wxStaticText(dPNG, wx.wxID_ANY, sLabel), 0); end
        oPageWidth = wx.wxSpinCtrl(dPNG, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(110, -1), wx.wxSP_ARROW_KEYS, 64, 8192, tSettings.pageWidth);
        oPageHeight = wx.wxSpinCtrl(dPNG, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(110, -1), wx.wxSP_ARROW_KEYS, 64, 8192, tSettings.pageHeight);
        oPadding = wx.wxSpinCtrl(dPNG, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(110, -1), wx.wxSP_ARROW_KEYS, 1, 32, tSettings.padding);
        for _, oControl in ipairs({oPageWidth, oPageHeight, oPadding}) do oSizes:Add(oControl, 0); end
        oPNG:Add(oSizes, 0, wx.wxALL, 12);
        oPNG:Add(wx.wxStaticText(dPNG, wx.wxID_ANY, "Full cards; no rotation or trimming. One-pixel duplicated edge border."), 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 12);
    end
    oPNG:Add(wx.wxStaticText(dPNG, wx.wxID_ANY, "Output size (%) — 100% is the card's native size"), 0, wx.wxLEFT + wx.wxRIGHT + wx.wxTOP, 12);
    local oScale = wx.wxSpinCtrl(dPNG, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(110, -1), wx.wxSP_ARROW_KEYS, 1, 1000, tSettings.scale);
    local oScaleRow = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oDefault = wx.wxButton(dPNG, wx.wxID_ANY, "Default", wx.wxDefaultPosition, wx.wxSize(-1, oScale:GetBestSize():GetHeight()));
    oScaleRow:Add(oScale, 0, wx.wxEXPAND); oScaleRow:Add(oDefault, 0, wx.wxEXPAND + wx.wxLEFT, 8);
    oPNG:Add(oScaleRow, 0, wx.wxALL, 12);
    local oDimensions = wx.wxStaticText(dPNG, wx.wxID_ANY, ""); oPNG:Add(oDimensions, 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 12);
    --[[!
    @fqxn CFS.Windows.ExportOptions.Private.Functions.showDimensions
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
    @fqxn CFS.Windows.ExportOptions.Private.Functions.update
    @desc Enables back-image controls only when the selected sides require them.
    @vis private
    !]]
    local function update() local bBacks = oSides:GetSelection() ~= 0; oBacks:Enable(bBacks); oRow:Enable(bBacks and oBacks:GetSelection() == 0); end
    oSides:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, update); oBacks:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, update); update();
    dPNG:SetSizer(oPNG); oBook:AddPage(dPNG, sType); oLayout:Add(oBook, 1, wx.wxEXPAND + wx.wxALL, 10);
    local oStatus = wx.wxStaticText(dDialog, wx.wxID_ANY, ""); oStatus:SetForegroundColour(wx.wxColour("#B03030")); oStatus:Hide(); oLayout:Add(oStatus, 0, wx.wxEXPAND + wx.wxALL, 10);
    oLayout:Add(dDialog:CreateButtonSizer(wx.wxOK + wx.wxCANCEL), 0, wx.wxEXPAND + wx.wxALL, 8);
    dDialog:SetSizerAndFit(oLayout); dDialog:SetMinSize(dDialog:GetSize()); dDialog:CentreOnParent();
    --[[!
    @fqxn CFS.Windows.ExportOptions.Private.Functions.save
    @desc Validates output dimensions, atlas fit, and target settings before persisting the selected format through its transactional model.
    @vis private
    !]]
    local function save()
        if (nWidth and nHeight) then ExporterPNG.dimensions(nWidth, nHeight, oScale:GetValue()); end
        local tNew = {scale = oScale:GetValue(), type = sType, sides = tSides[oSides:GetSelection() + 1], backs = oBacks:GetSelection() == 0 and "shared" or "individual", backRow = oRow:GetSelection()};
        if (sType == "Atlas") then
            tNew.target = oTarget:GetSelection() == 0 and "Generic_1" or "Love_11_5";
            tNew.pageWidth, tNew.pageHeight, tNew.padding = oPageWidth:GetValue(), oPageHeight:GetValue(), oPadding:GetValue();
            tNew.selected = tSettings.selected;
            if (nWidth and nHeight and #tNames > 0) then service.plan({1}, tNew, tNames, #tNames, nWidth, nHeight); end
        end
        tModel.saveOptions(tNew);
    end
    dDialog:Connect(wx.wxID_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        local bOK, sError = pcall(save);
        if (bOK) then dDialog:EndModal(wx.wxID_OK);
        else oStatus:SetLabel(tostring(sError)); oStatus:Wrap(470); oStatus:Show(); dDialog:Layout(); require("Errors").report(sError); end
    end);
    return {target = oTarget, pageWidth = oPageWidth, pageHeight = oPageHeight, padding = oPadding, default = oDefault, scale = oScale, dimensions = oDimensions, dialog = dDialog, book = oBook, sides = oSides, backs = oBacks, row = oRow, save = save, model = tModel};
end
--[[!
@fqxn CFS.Windows.ExportOptions.Functions.show
@pulsarlua function ExportOptions.show
@desc Runs and destroys the options dialog, returning whether the user accepted it.
@param any dParent Parent window.
@param any pInfo Info.
@param any tNames Names.
@param any nWidth Width.
@param any nHeight Height.
@param string|nil sType PNG, Atlas, CSV, JSON, Lua, HTML, or Zip; defaults to PNG.
!]]
function ExportOptions.show(dParent, pInfo, tNames, nWidth, nHeight, sType)
    local tWindow = ExportOptions.create(dParent, pInfo, tNames, nWidth, nHeight, sType); local nResult = tWindow.dialog:ShowModal(); tWindow.dialog:Destroy(); return nResult == wx.wxID_OK;
end
return ExportOptions;
