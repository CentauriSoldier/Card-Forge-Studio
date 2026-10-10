--[[!
@fqxn CFS.Windows.Options
@desc Application and Forge preferences and staged game/card-set metadata editing.
!]]

-- Categorized application options and guide controls.
local wx = require("wx");
local GridStyle = require("Windows.GridStyle");
local WindowState = require("Windows.WindowState");
local Options = {};

--[[!
@fqxn CFS.Windows.Options.Private.center
@desc Centers on a shown parent or within the primary display when the parent is unavailable for centering.
@param any dDialog Dialog.
@param any dParent Parent.
@vis private
!]]
local function center(dDialog, dParent)
    if (dParent:IsShown() and not dParent:IsIconized()) then dDialog:CentreOnParent();
    else
        local oDisplay = wx.wxDisplay(0); local oScreen = oDisplay:GetClientArea(); local oSize = dDialog:GetSize();
        dDialog:Move(oScreen:GetX() + math.floor((oScreen:GetWidth() - oSize:GetWidth()) / 2), oScreen:GetY() + math.floor((oScreen:GetHeight() - oSize:GetHeight()) / 2));
        oDisplay:delete();
    end
end

-- Edit only known metadata keys and retain unrelated sections and values.
--[[!
@fqxn CFS.Windows.Options.Private.metadata
@desc Updates requested SETTINGS keys while preserving other INI text and its newline style.
@param any sText Text.
@param any tValues Values.
@vis private
!]]
local function metadata(sText, tValues)
    local sNewline = sText:find("\r\n", 1, true) and "\r\n" or "\n";
    local tLines, tSeen, bSettings, bFound = {}, {}, false, false;
    --[[!
    @fqxn CFS.Windows.Options.Private.missing
    @desc Appends requested metadata keys not already written in the SETTINGS section.
    @vis private
    !]]
    local function missing()
        for _, tValue in ipairs(tValues) do
            if (not tSeen[tValue[1]]) then tLines[#tLines + 1] = tValue[1].."="..tValue[2]; tSeen[tValue[1]] = true; end
        end
    end
    local sSource = sText:gsub("\r\n", "\n");
    if (sSource:sub(-1) ~= "\n") then sSource = sSource.."\n"; end
    for sLine in sSource:gmatch("(.-)\n") do
        local sSection = sLine:match("^%s*%[([^%]]+)%]%s*$");
        if (sSection) then
            if (bSettings) then missing(); end
            bSettings = sSection:upper() == "SETTINGS"; bFound = bFound or bSettings;
        end
        if (bSettings) then
            local sKey = sLine:match("^%s*([^=;#]+)%s*=");
            if (sKey) then
                sKey = sKey:match("^%s*(.-)%s*$");
                for _, tValue in ipairs(tValues) do
                    if (sKey:lower() == tValue[1]:lower()) then
                        if (sLine:match("=%s*(.-)%s*$") ~= tValue[2]) then sLine = sLine:match("^(%s*)")..sKey.."="..tValue[2]; end
                        tSeen[tValue[1]] = true;
                    end
                end
            end
        end
        tLines[#tLines + 1] = sLine;
    end
    if (not bFound) then tLines[#tLines + 1] = "[SETTINGS]"; end
    missing();
    return table.concat(tLines, sNewline)..(sText:sub(-1) == "\n" and sNewline or "");
end

--[[!
@fqxn CFS.Windows.Options.create
@pulsarlua function Options.create
@desc Creates application, Forge, game, and card-set options with staged metadata changes and protected Apply handling.
@param any dParent Parent window.
@param any tContext Context.
!]]
function Options.create(dParent, tContext)
    tContext = tContext or {};
    local dDialog = wx.wxDialog(dParent, wx.wxID_ANY, "Options", wx.wxDefaultPosition, wx.wxSize(880, 640),
        wx.wxDEFAULT_DIALOG_STYLE + wx.wxRESIZE_BORDER);
    dDialog:SetMinSize(wx.wxSize(720, 520));
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oBody = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local tNames = {"General", "Windows", "Forge", "Grids", "Game", "Card Set"};
    local oCategories = wx.wxListBox(dDialog, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tNames);
    local nWidth = 110;
    for _, sName in ipairs(tNames) do local nText = oCategories:GetTextExtent(sName); nWidth = math.max(nWidth, nText + 32); end
    oCategories:SetMinSize(wx.wxSize(nWidth, -1));
    oBody:Add(oCategories, 0, wx.wxEXPAND + wx.wxALL, 12);
    oBody:Add(wx.wxStaticLine(dDialog, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxLI_VERTICAL), 0, wx.wxEXPAND + wx.wxTOP + wx.wxBOTTOM, 12);
    local dContent = wx.wxPanel(dDialog, wx.wxID_ANY);
    local oContent = wx.wxBoxSizer(wx.wxVERTICAL); dContent:SetSizer(oContent);
    oBody:Add(dContent, 1, wx.wxEXPAND + wx.wxALL, 12);
    local tPages, tControls = {}, {};
    --[[!
    @fqxn CFS.Windows.Options.Private.page
    @desc Creates an options page with a title and description.
    @param any sTitle Title.
    @param any sDescription Description.
    @vis private
    !]]
    local function page(sTitle, sDescription)
        local dPage = wx.wxPanel(dContent, wx.wxID_ANY);
        local oPage = wx.wxBoxSizer(wx.wxVERTICAL);
        local oTitle = wx.wxStaticText(dPage, wx.wxID_ANY, sTitle);
        local oFont = oTitle:GetFont(); oFont:SetWeight(wx.wxFONTWEIGHT_BOLD); oFont:SetPointSize(14); oTitle:SetFont(oFont);
        oPage:Add(oTitle, 0, wx.wxBOTTOM, 12);
        local oDescription = wx.wxStaticText(dPage, wx.wxID_ANY, sDescription); oDescription:Wrap(490);
        oPage:Add(oDescription, 0, wx.wxBOTTOM, 20);
        dPage:SetSizer(oPage); oContent:Add(dPage, 1, wx.wxEXPAND); tPages[#tPages + 1] = dPage;
        return dPage, oPage;
    end
    --[[!
    @fqxn CFS.Windows.Options.Private.check
    @desc Creates a checkbox initialized from the current option value.
    @param any dPage Page.
    @param any oPage Page.
    @param any sLabel Label.
    @param any bValue Value.
    @vis private
    !]]
    local function check(dPage, oPage, sLabel, bValue)
        local oControl = wx.wxCheckBox(dPage, wx.wxID_ANY, sLabel); oControl:SetValue(not not bValue);
        oPage:Add(oControl, 0, wx.wxBOTTOM, 14); return oControl;
    end
    --[[!
    @fqxn CFS.Windows.Options.Private.field
    @desc Creates a labeled text field initialized from the current option value.
    @param any dPage Page.
    @param any oPage Page.
    @param any sLabel Label.
    @param any sValue Value.
    @vis private
    !]]
    local function field(dPage, oPage, sLabel, sValue)
        oPage:Add(wx.wxStaticText(dPage, wx.wxID_ANY, sLabel), 0, wx.wxBOTTOM, 6);
        local oControl = wx.wxTextCtrl(dPage, wx.wxID_ANY, tostring(sValue or ""));
        oPage:Add(oControl, 0, wx.wxEXPAND + wx.wxBOTTOM, 14); return oControl;
    end
    local dPage, oPage = page("General", "Choose how external data changes are handled.");
    tControls.csv = check(dPage, oPage, "Automatically reload external CSV changes",
        INIFile.GetValue(FS.AppCFG, "Settings", "ExternalCSVChanges") == "automatic");
    local oWarning = wx.wxStaticText(dPage, wx.wxID_ANY, "Automatic reload replaces unsaved Base Data edits. Turn it off to ask before reloading.");
    oWarning:Wrap(490); oPage:Add(oWarning, 0, wx.wxBOTTOM, 12);
    dPage, oPage = page("Windows", "Control how visible application windows come forward.");
    tControls.raise = check(dPage, oPage, "Bring other visible app windows forward when selecting an app window", WindowState.getRaiseTogether());
    dPage, oPage = page("Forge", "Preview colors and guide controls. These colors do not change exported cards.");
    local oForgeBook = wx.wxNotebook(dPage, wx.wxID_ANY);
    local dBackground = wx.wxPanel(oForgeBook, wx.wxID_ANY);
    local oBackground = wx.wxBoxSizer(wx.wxVERTICAL);
    local dGuides = wx.wxScrolledWindow(oForgeBook, wx.wxID_ANY);
    local oGuides = wx.wxBoxSizer(wx.wxVERTICAL);
    local tForgeColors = {
        {key = "backgroundColor", setting = "ForgeBackgroundColor", label = "Surrounding Background", default = "#232323"},
        {key = "canvasColor", setting = "ForgeCanvasColor", label = "Card Canvas", default = "#FFFFFF"},
    };
    local tLines = {
        {key = "horizontalColor", setting = "HorizontalGuideColor", label = "Horizontal guide", default = "#00DCFF"},
        {key = "verticalColor", setting = "VerticalGuideColor", label = "Vertical guide", default = "#00DCFF"},
        {key = "horizontalCenterColor", setting = "HorizontalCenterColor", label = "Horizontal centerline", default = "#FFC800"},
        {key = "verticalCenterColor", setting = "VerticalCenterColor", label = "Vertical centerline", default = "#FFC800"},
    };
    for _, tLine in ipairs(tLines) do
        tForgeColors[#tForgeColors + 1] = tLine;
    end

    for nIndex, tColor in ipairs(tForgeColors) do
        local dTarget = nIndex <= 2 and dBackground or dGuides;
        local oTarget = nIndex <= 2 and oBackground or oGuides;
        local sSaved = INIFile.GetValue(FS.AppCFG, "Settings", tColor.setting);
        local sColor = sSaved:match("^#%x%x%x%x%x%x$") and sSaved or tColor.default;
        local oRow = wx.wxBoxSizer(wx.wxHORIZONTAL);
        local oPicker = wx.wxColourPickerCtrl(dTarget, wx.wxID_ANY, wx.wxColour(sColor));

        tControls[tColor.key] = oPicker;
        oRow:Add(wx.wxStaticText(dTarget, wx.wxID_ANY, tColor.label), 1, wx.wxALIGN_CENTER_VERTICAL + wx.wxRIGHT, 16);
        oRow:Add(oPicker, 0);
        oTarget:Add(oRow, 0, wx.wxEXPAND + wx.wxALL, 12);
    end
    local sHelp = "Guides mark a position on the card; centerlines mark its midpoint.\nThe Utility Overlay option shows or hides all lines.\n\nCtrl + Left click: place the horizontal guide.\nCtrl + Right click: place the vertical guide.\nCtrl + Middle click: place both guides.\nAdd Shift to these shortcuts to remove the matching guides.\n\nLeft click: copy x, y from the top-left corner.\nRight click (with or without Ctrl): copy negative x, y from the bottom-right corner.\nCtrl + Left click also copies the horizontal position from the top and bottom.\nCtrl + Middle click also copies x, y from the top-left corner.";
    local oHelp = wx.wxStaticText(dGuides, wx.wxID_ANY, sHelp);

    oHelp:Wrap(450);
    oGuides:Add(oHelp, 0, wx.wxEXPAND + wx.wxALL, 12);
    dBackground:SetSizer(oBackground);
    dGuides:SetSizer(oGuides);
    dGuides:SetScrollRate(0, 10);
    oForgeBook:AddPage(dBackground, "Background");
    oForgeBook:AddPage(dGuides, "Guides");
    local dPreview = wx.wxPanel(oForgeBook, wx.wxID_ANY);
    local oPreview = wx.wxBoxSizer(wx.wxVERTICAL);

    dPreview:SetSizer(oPreview);
    for _, tLine in ipairs({{"overlay", "Utility Overlay"}, {"horizontalCenter", "Horizontal Centerline"}, {"verticalCenter", "Vertical Centerline"}}) do
        tControls[tLine[1]] = check(dPreview, oPreview, tLine[2], tContext.state and tContext.state[tLine[1]]);
    end
    if (not tContext.state or not tContext.cardSet) then dPreview:Enable(false); end
    oForgeBook:AddPage(dPreview, "Preview");
    oPage:Add(oForgeBook, 1, wx.wxEXPAND);

    dPage, oPage = page("Grids", "Shared alternating row and index colors for Base Data and Final Data.");
    local tGridColors = GridStyle.get();
    tControls.gridColors = {};

    for _, tDefinition in ipairs(GridStyle.definitions) do
        local oRow    = wx.wxBoxSizer(wx.wxHORIZONTAL);
        local oPicker = wx.wxColourPickerCtrl(dPage, wx.wxID_ANY, wx.wxColour(tGridColors[tDefinition.key]));

        tControls.gridColors[tDefinition.key] = oPicker;
        oRow:Add(wx.wxStaticText(dPage, wx.wxID_ANY, tDefinition.label), 1, wx.wxALIGN_CENTER_VERTICAL + wx.wxRIGHT, 16);
        oRow:Add(oPicker, 0, wx.wxALIGN_CENTER_VERTICAL);
        oPage:Add(oRow, 0, wx.wxEXPAND + wx.wxBOTTOM, 14);
    end

    -- Fixed sample data makes color comparisons consistent across openings.
    local tSamples = {
        {"Ember Fox", "Creature", "3"},
        {"Moonlit Grove", "Location", "5"},
        {"Copper Compass", "Item", "2"},
        {"Winter Spark", "Spell", "4"},
    };
    local oGridPreview = wx.wxGrid(dPage, wx.wxID_ANY);

    oGridPreview:CreateGrid(4, 3);
    oGridPreview:EnableEditing(false);
    oGridPreview:SetRowLabelSize(42);
    oGridPreview:SetColLabelSize(26);
    oGridPreview:SetColLabelValue(0, "Name");
    oGridPreview:SetColLabelValue(1, "Type");
    oGridPreview:SetColLabelValue(2, "Cost");

    for nRow, tValues in ipairs(tSamples) do
        oGridPreview:SetRowLabelValue(nRow - 1, tostring(nRow));

        for nColumn, sValue in ipairs(tValues) do
            oGridPreview:SetCellValue(nRow - 1, nColumn - 1, sValue);
        end
    end

    oGridPreview:AutoSizeColumns(false);

    -- Fit the four sample rows exactly instead of exposing the unused grid canvas.
    local nPreviewWidth  = oGridPreview:GetRowLabelSize() + 4;
    local nPreviewHeight = oGridPreview:GetColLabelSize() + 4;

    for nColumn = 0, 2 do
        nPreviewWidth = nPreviewWidth + oGridPreview:GetColSize(nColumn);
    end

    for nRow = 0, 3 do
        nPreviewHeight = nPreviewHeight + oGridPreview:GetRowSize(nRow);
    end

    oGridPreview:SetMinSize(wx.wxSize(nPreviewWidth, nPreviewHeight));
    oGridPreview:SetMaxSize(wx.wxSize(nPreviewWidth, nPreviewHeight));
    oPage:Add(wx.wxStaticText(dPage, wx.wxID_ANY, "Live Preview — changes are saved only with Apply or OK."), 0, wx.wxTOP + wx.wxBOTTOM, 8);
    oPage:Add(oGridPreview, 0, wx.wxALIGN_LEFT);
    tControls.gridPreview = oGridPreview;

    --[[!
    @fqxn CFS.Windows.Options.Private.previewGridColors
    @desc Repaints fixed sample rows from unsaved picker values without modifying preferences or data windows.
    @vis private
    !]]
    local function previewGridColors()
        local tColors = {};

        for _, tDefinition in ipairs(GridStyle.definitions) do
            tColors[tDefinition.key] = tControls.gridColors[tDefinition.key]:GetColour();
        end

        oGridPreview:BeginBatch();
        oGridPreview:SetLabelBackgroundColour(tColors.index);
        oGridPreview:SetLabelTextColour(tColors.indexText);

        for nRow = 0, 3 do
            local bPrimary = nRow % 2 == 0;

            for nColumn = 0, 2 do
                oGridPreview:SetCellBackgroundColour(nRow, nColumn, bPrimary and tColors.primary or tColors.secondary);
                oGridPreview:SetCellTextColour(nRow, nColumn, bPrimary and tColors.primaryText or tColors.secondaryText);
            end
        end

        oGridPreview:EndBatch();
        oGridPreview:ForceRefresh();
    end

    for _, tDefinition in ipairs(GridStyle.definitions) do
        tControls.gridColors[tDefinition.key]:Connect(wx.wxEVT_COMMAND_COLOURPICKER_CHANGED, previewGridColors);
    end

    previewGridColors();

    local tFiles = {};
    --[[!
    @fqxn CFS.Windows.Options.Private.info
    @desc Creates game or card-set metadata controls backed by a staged source model.
    @param any sTitle Title.
    @param any pInfo Info.
    @param any bCardSet Card set.
    @vis private
    !]]
    local function info(sTitle, pInfo, bCardSet)
        local dInfo, oInfo = page(sTitle, bCardSet and "Card-set name and render dimensions. Saving updates the live renderer through file monitoring."
            or "The name of the loaded game. Other game configuration is available in Game > Edit Source.");
        if (not pInfo or pInfo == "" or not wx.wxFileExists(pInfo)) then
            oInfo:Add(wx.wxStaticText(dInfo, wx.wxID_ANY, "Load a "..(bCardSet and "card set" or "game").." to edit these settings."), 0);
            return;
        end
        tFiles[#tFiles + 1] = {name = sTitle, path = pInfo, kind = "ini"};
        local tInfo = {index = #tFiles};
        tInfo.name = field(dInfo, oInfo, "Name", INIFile.GetValue(pInfo, "SETTINGS", "Name"));
        if (bCardSet) then
            tInfo.width = field(dInfo, oInfo, "Card width (pixels)", INIFile.GetValue(pInfo, "SETTINGS", "CardWidth"));
            tInfo.height = field(dInfo, oInfo, "Card height (pixels)", INIFile.GetValue(pInfo, "SETTINGS", "CardHeight"));
        end
        tControls[bCardSet and "card" or "game"] = tInfo;
    end
    info("Game", tContext.game and FS.Game.Info, false);
    info("Card Set", tContext.cardSet and FS.CardSet.Info, true);
    local tModel = require("Windows.Editors.Common").model(tFiles);
    --[[!
    @fqxn CFS.Windows.Options.Private.select
    @desc Shows the selected options page and updates the category selector.
    @param any nIndex Index.
    @vis private
    !]]
    local function select(nIndex)
        for nPage, dCurrent in ipairs(tPages) do dCurrent:Show(nPage == nIndex); end
        oCategories:SetSelection(nIndex - 1);
        dContent:Layout();
        tPages[nIndex]:Layout();
        tPages[nIndex]:Refresh(true);

        if (tNames[nIndex] == "Grids") then
            -- Native picker child buttons may otherwise remain unpainted until hover.
            for _, tDefinition in ipairs(GridStyle.definitions) do
                local oPicker = tControls.gridColors[tDefinition.key]:GetPickerCtrl();

                oPicker:Refresh(true);
                oPicker:Update();
            end

            previewGridColors();
        end
    end
    oCategories:Connect(wx.wxEVT_COMMAND_LISTBOX_SELECTED, function() select(oCategories:GetSelection() + 1); end);
    local nInitial = 1;

    for nIndex, sName in ipairs(tNames) do
        if (sName == tContext.category) then nInitial = nIndex; end
    end

    select(nInitial);
    oLayout:Add(oBody, 1, wx.wxEXPAND);
    local oStatus = wx.wxStaticText(dDialog, wx.wxID_ANY, ""); oStatus:Hide(); oStatus:SetForegroundColour(wx.wxColour(170, 25, 25));
    oLayout:Add(oStatus, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 12);
    local oButtons = wx.wxBoxSizer(wx.wxHORIZONTAL); oButtons:AddStretchSpacer();
    for _, tButton in ipairs({{wx.wxID_OK, "OK"}, {wx.wxID_APPLY, "Apply"}, {wx.wxID_CANCEL, "Cancel"}}) do
        local oButton = wx.wxButton(dDialog, tButton[1], tButton[2]); oButtons:Add(oButton, 0, wx.wxALL, 6);
    end
    oLayout:Add(oButtons, 0, wx.wxEXPAND + wx.wxALL, 6);
    dDialog:SetSizer(oLayout); dDialog:Layout(); center(dDialog, dParent);
    --[[!
    @fqxn CFS.Windows.Options.Private.onShow
    @desc Refreshes the selected page and native picker buttons when the Options dialog first becomes visible.
    @param any oEvent Native show event.
    @vis private
    !]]
    dDialog:Connect(wx.wxEVT_SHOW, function(oEvent)
        if (oEvent:IsShown()) then
            select(oCategories:GetSelection() + 1);
        end

        oEvent:Skip();
    end);
    --[[!
    @fqxn CFS.Windows.Options.Private.apply
    @desc Validates metadata, stages matching documentation renames, persists settings, and notifies the caller of accepted changes.
    @vis private
    !]]
    local function apply()
        for _, sKey in ipairs({"game", "card"}) do
            local tInfo = tControls[sKey];
            if (tInfo) then
                local sName = tInfo.name:GetValue():match("^%s*(.-)%s*$");
                assert(sName ~= "" and not sName:find("[\r\n]"), "Enter a nonempty, single-line "..sKey.." name.");
                local tValues = {{"Name", sName}};
                if (sKey == "card") then
                    for _, tDimension in ipairs({{"CardWidth", tInfo.width}, {"CardHeight", tInfo.height}}) do
                        local nValue = tonumber(tDimension[2]:GetValue());
                        assert(nValue and nValue > 0 and nValue < math.huge and nValue == math.floor(nValue), "Card dimensions must be positive whole numbers.");
                        tValues[#tValues + 1] = {tDimension[1], tostring(nValue)};
                    end
                end
                tModel.files[tInfo.index].text = metadata(tModel.files[tInfo.index].original, tValues);
            end
        end
        -- Stage namespace changes alongside names so rollback covers both metadata and scripts.
        if (tContext.game and type(tContext.game) ~= "boolean") then
            local tGameInfo = tControls.game;
            local tSetInfo  = tControls.card;
            local sOldGame = INIFile.GetValue(tModel.files[tGameInfo.index].path, "SETTINGS", "Name");
            local sOldSet = tSetInfo and INIFile.GetValue(tModel.files[tSetInfo.index].path, "SETTINGS", "Name");

            require("Documentation").Stage(tModel, tContext.game.GetUUID(), sOldGame,
                tGameInfo.name:GetValue():match("^%s*(.-)%s*$"), tSetInfo and FS.CardSet.Info,
                sOldSet, tSetInfo and tSetInfo.name:GetValue():match("^%s*(.-)%s*$"));
        end

        tModel.save();
        local bAutomatic = tControls.csv:GetValue();
        INIFile.SetValue(FS.AppCFG, "Settings", "ExternalCSVChanges", bAutomatic and "automatic" or "prompt");
        WindowState.setRaiseTogether(tControls.raise:GetValue());
        if (tContext.state and tContext.cardSet) then
            for sKey, sSetting in pairs({overlay = "UtilityOverlay", horizontalCenter = "HorizontalCenterline", verticalCenter = "VerticalCenterline"}) do
                local bValue = tControls[sKey]:GetValue();
                INIFile.SetValue(FS.AppCFG, "Settings", sSetting, bValue and "1" or "0"); tContext.state[sKey] = bValue;
            end
        end
        for _, tColor in ipairs(tForgeColors) do
            local sColor = tControls[tColor.key]:GetColour():GetAsString(wx.wxC2S_HTML_SYNTAX);

            INIFile.SetValue(FS.AppCFG, "Settings", tColor.setting, sColor);
            if (tContext.state) then tContext.state[tColor.key] = sColor; end
        end

        local tGridColors = {};

        for _, tDefinition in ipairs(GridStyle.definitions) do
            tGridColors[tDefinition.key] = tControls.gridColors[tDefinition.key]:GetColour():GetAsString(wx.wxC2S_HTML_SYNTAX);
        end

        GridStyle.save(tGridColors);

        if (tContext.changed) then tContext.changed(bAutomatic, tControls.game and tControls.game.name:GetValue():match("^%s*(.-)%s*$")); end
        require("Log").Note("Options saved.");
        oStatus:Hide(); dDialog:Layout();
        return true;
    end
    --[[!
    @fqxn CFS.Windows.Options.Private.protectedApply
    @desc Applies changes and displays failures without closing; closes only after successful application when requested.
    @param any bClose Close.
    @vis private
    !]]
    local function protectedApply(bClose)
        local bOK, sError = pcall(apply);
        if (bOK) then
            if (bClose) then dDialog:EndModal(wx.wxID_OK); end
        else
            oStatus:SetLabel(tostring(sError)); oStatus:Wrap(640); oStatus:Show(); dDialog:Layout();
            require("Errors").report(sError);
        end
    end
    dDialog:Connect(wx.wxID_APPLY, wx.wxEVT_COMMAND_BUTTON_CLICKED, function() protectedApply(false); end);
    dDialog:Connect(wx.wxID_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, function() protectedApply(true); end);
    return {dialog = dDialog, categories = oCategories, pages = tPages, controls = tControls, model = tModel, apply = apply, select = select, previewGridColors = previewGridColors};
end

--[[!
@fqxn CFS.Windows.Options.show
@pulsarlua function Options.show
@desc Runs the main Options dialog and destroys it after closing.
@param any dParent Parent window.
@param any tContext Context.
!]]
function Options.show(dParent, tContext)
    local tWindow = Options.create(dParent, tContext);
    tWindow.dialog:ShowModal(); tWindow.dialog:Destroy();
end

return Options;
