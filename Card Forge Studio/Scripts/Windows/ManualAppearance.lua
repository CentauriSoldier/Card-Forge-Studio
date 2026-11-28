--[[!
@fqxn CFS.Windows.ManualAppearance
@desc Modeless visual manual designer. Draft settings use the existing renderer; only Save writes game appearance.
!]]
local wx = require("wx");
local Appearance = require("Manual.Appearance");
local Documents = require("Manual.Documents");
local WindowState = require("Windows.WindowState");
local ManualAppearance = {};
WindowState.register("ManualAppearance", {savePosition = true, saveSize = true, saveVisible = false});

local function fileURL(pFile)
    local oFile = wx.wxFileName(pFile);
    local sURL = wx.wxFileSystem.FileNameToURL(oFile);
    oFile:delete(); return sURL;
end

--[[!
@fqxn CFS.Windows.ManualAppearance.Functions.create
@desc Opens visual controls, optional exact values and a live sample. Clearing an override inherits the base theme. Nil preview settings restore the saved theme.
@param any dParent Owning manual-editor frame.
@param string pManual Game manual folder.
@param table tOptions gameName, onPreview, onClose and optional show=false for deferred presentation.
@return table tWindow Lifecycle and draft-state operations.
!]]
function ManualAppearance.create(dParent, pManual, tOptions)
    tOptions = tOptions or {};
    local tDraft, sOriginal = Appearance.load(pManual);
    local WebView = assert(wxwebview, "Manual Appearance requires the wxLua WebView binding.");
    local dFrame = wx.wxFrame(dParent, wx.wxID_ANY, "Manual Appearance - "..(tOptions.gameName or "Game"), wx.wxDefaultPosition, wx.wxSize(1240, 840));
    dFrame:SetMinSize(wx.wxSize(940, 620));
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oBody = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local dControls = wx.wxPanel(dFrame, wx.wxID_ANY);
    local oControls = wx.wxBoxSizer(wx.wxVERTICAL);
    local oTheme = wx.wxChoice(dControls, wx.wxID_ANY);
    oTheme:Append("Whole manual");
    for _, tVariant in ipairs(tDraft.Variants or {}) do oTheme:Append(tVariant.Name); end
    oTheme:SetSelection(0);
    oControls:Add(wx.wxStaticText(dControls, wx.wxID_ANY, "Theme"), 0, wx.wxBOTTOM, 4);
    oControls:Add(oTheme, 0, wx.wxEXPAND + wx.wxBOTTOM, 6);
    local oThemeRow = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oAddTheme = wx.wxButton(dControls, wx.wxID_ANY, "Add section theme…");
    local oAssignTheme = wx.wxButton(dControls, wx.wxID_ANY, "Choose sections…");
    oThemeRow:Add(oAddTheme, 1, wx.wxRIGHT, 6); oThemeRow:Add(oAssignTheme, 1);
    oControls:Add(oThemeRow, 0, wx.wxEXPAND + wx.wxBOTTOM, 6);
    local tContexts = {};
    for _, tContext in ipairs(Appearance.contexts) do tContexts[#tContexts + 1] = tContext.label; end
    local oContext = wx.wxChoice(dControls, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tContexts);
    oContext:SetSelection(0);
    oControls:Add(wx.wxStaticText(dControls, wx.wxID_ANY, "Size / output"), 0, wx.wxBOTTOM, 4);
    oControls:Add(oContext, 0, wx.wxEXPAND + wx.wxBOTTOM, 8);
    local tLabels = {};
    for _, tTarget in ipairs(Appearance.targets) do tLabels[#tLabels + 1] = tTarget.label; end
    oControls:Add(wx.wxStaticText(dControls, wx.wxID_ANY, "Choose a part of the manual"), 0, wx.wxBOTTOM, 6);
    local oSearch = wx.wxTextCtrl(dControls, wx.wxID_ANY, "");
    oSearch:SetHint("Find a part: heading, glossary, border…");
    oControls:Add(oSearch, 0, wx.wxEXPAND + wx.wxBOTTOM, 6);
    local tTargetIndices = {};
    for nIndex in ipairs(Appearance.targets) do tTargetIndices[nIndex] = nIndex; end
    local oTarget = wx.wxChoice(dControls, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tLabels);
    oTarget:SetSelection(0); oControls:Add(oTarget, 0, wx.wxEXPAND + wx.wxBOTTOM, 8);
    local oReset = wx.wxButton(dControls, wx.wxID_ANY, "Restore this section's defaults");
    oControls:Add(oReset, 0, wx.wxEXPAND + wx.wxBOTTOM, 8);
    local oHelp = wx.wxStaticText(dControls, wx.wxID_ANY, "Choose an element below. Inherit uses its defaults. Size-specific and section-theme changes override the whole manual. Save keeps changes; Cancel discards the draft.");
    oHelp:Wrap(360); oControls:Add(oHelp, 0, wx.wxEXPAND + wx.wxBOTTOM, 8);
    local oBook = wx.wxNotebook(dControls, wx.wxID_ANY);
    local dVisual = wx.wxScrolledWindow(oBook, wx.wxID_ANY);
    local dArt = wx.wxScrolledWindow(oBook, wx.wxID_ANY);
    local dBox = wx.wxScrolledWindow(oBook, wx.wxID_ANY);
    local dLayout = wx.wxScrolledWindow(oBook, wx.wxID_ANY);
    local oBox = wx.wxBoxSizer(wx.wxVERTICAL);
    local oPosition = wx.wxBoxSizer(wx.wxVERTICAL);
    dBox:SetScrollRate(0, 12); dLayout:SetScrollRate(0, 12);
    local dAdvanced = wx.wxPanel(oBook, wx.wxID_ANY);
    local oVisual = wx.wxBoxSizer(wx.wxVERTICAL);
    local oArt = wx.wxBoxSizer(wx.wxVERTICAL);
    local oAdvanced = wx.wxBoxSizer(wx.wxVERTICAL);
    dVisual:SetScrollRate(0, 12); dArt:SetScrollRate(0, 12);
    oBook:AddPage(dVisual, "Text", true); oBook:AddPage(dBox, "Box", false); oBook:AddPage(dLayout, "Layout", false); oBook:AddPage(dArt, "Artwork", false); oBook:AddPage(dAdvanced, "Advanced", false);
    oControls:Add(oBook, 1, wx.wxEXPAND); dControls:SetSizer(oControls);
    dControls:SetMinSize(wx.wxSize(420, -1)); oBody:Add(dControls, 0, wx.wxEXPAND + wx.wxALL, 12);
    local dPreview = wx.wxPanel(dFrame, wx.wxID_ANY);
    local oPreview = wx.wxBoxSizer(wx.wxVERTICAL);
    local oSampleLabel = wx.wxStaticText(dPreview, wx.wxID_ANY, "Live example");
    oPreview:Add(oSampleLabel, 0, wx.wxBOTTOM, 8);
    local bOK, oBrowser = pcall(WebView.wxWebView.New, dPreview, wx.wxID_ANY, "about:blank", wx.wxDefaultPosition, wx.wxDefaultSize, "wxWebViewEdge");
    if (not bOK or not oBrowser) then dFrame:Destroy(); error("Cannot create appearance preview: "..tostring(oBrowser), 2); end
    oPreview:Add(oBrowser, 1, wx.wxEXPAND); dPreview:SetSizer(oPreview); oBody:Add(dPreview, 1, wx.wxEXPAND + wx.wxALL, 12);
    oLayout:Add(oBody, 1, wx.wxEXPAND);
    local oBottom = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oStatus = wx.wxStaticText(dFrame, wx.wxID_ANY, "Saved appearance");
    local oSave = wx.wxButton(dFrame, wx.wxID_ANY, "Save");
    local oCancel = wx.wxButton(dFrame, wx.wxID_ANY, "Cancel");
    oBottom:Add(oStatus, 1, wx.wxALIGN_CENTER_VERTICAL + wx.wxRIGHT, 10);
    oBottom:Add(oSave, 0, wx.wxRIGHT, 8); oBottom:Add(oCancel, 0);
    oLayout:Add(oBottom, 0, wx.wxEXPAND + wx.wxALL, 12); dFrame:SetSizer(oLayout);
    local oGrid = wx.wxGrid(dAdvanced, wx.wxID_ANY);
    oGrid:CreateGrid(#Appearance.fields, 2); oGrid:SetRowLabelSize(0);
    oGrid:SetColLabelValue(0, "Property"); oGrid:SetColLabelValue(1, "Override");
    oGrid:SetColSize(0, 190); oGrid:SetColSize(1, 180);
    oAdvanced:Add(wx.wxStaticText(dAdvanced, wx.wxID_ANY, "Optional exact values. Blank inherits the base theme."), 0, wx.wxALL, 8);
    oAdvanced:Add(oGrid, 1, wx.wxEXPAND); dAdvanced:SetSizer(oAdvanced);
    local tBindings = {};
    local nTarget, nTheme, nContext = 1, 0, 1;
    local bDisplaying, bDirty, bClosed = false, false, false;
    local fDisplay, fPreview;
    local oTimer = wx.wxTimer(dFrame, wx.wxNewId());
    local oTemporary = wx.wxFile();
    local pTemporary = wx.wxFileName.CreateTempFileName(wx.wxFileName.GetTempDir().."/cfs-appearance-", oTemporary);
    if (oTemporary:IsOpened()) then oTemporary:Close(); end
    oTemporary:delete();
    local pPage = pTemporary..".html";
    if (pTemporary == "" or not wx.wxRenameFile(pTemporary, pPage, false)) then dFrame:Destroy(); error("Cannot create appearance sample page.", 2); end
    local sPageURL = fileURL(pPage);
    local sImages = fileURL(pManual):gsub("/$", "").."/Images/";
    local nRevision = 0;

    local function fTheme()
        return nTheme == 0 and tDraft or tDraft.Variants[nTheme];
    end
    local function fProperties()
        local tTheme = fTheme();
        local sKey = Appearance.contexts[nContext].key;
        tTheme[sKey] = tTheme[sKey] or {};
        return tTheme[sKey];
    end
    local function fValues()
        return fProperties()[Appearance.targets[nTarget].key] or {};
    end
    local function fChanged()
        bDirty = true; oStatus:SetLabel("Unsaved appearance changes"); oTimer:StartOnce(180);
    end
    local function fSet(sKey, sValue)
        if (bDisplaying) then return; end
        local tValues = fValues();
        tValues[sKey] = sValue ~= "" and sValue or nil;
        if (sKey == "borderStyle" and sValue == "none") then
            tValues.frameImage = "none";
            for _, sEdge in ipairs({"borderTop", "borderRight", "borderBottom", "borderLeft"}) do tValues[sEdge] = nil; end
        end
        fProperties()[Appearance.targets[nTarget].key] = next(tValues) and tValues or nil;
        fChanged(); fDisplay();
    end
    local function fRow(dPage, oSizer, sLabel)
        oSizer:Add(wx.wxStaticText(dPage, wx.wxID_ANY, sLabel), 0, wx.wxLEFT + wx.wxRIGHT + wx.wxTOP, 10);
        local oRow = wx.wxBoxSizer(wx.wxHORIZONTAL);
        oSizer:Add(oRow, 0, wx.wxEXPAND + wx.wxALL, 10); return oRow;
    end
    local function fPage(sKey)
        if (sKey:match("^border") or sKey:match("^frame") or sKey == "background" or sKey == "radius" or sKey == "shadow" or sKey == "clip" or sKey == "filter") then return dBox, oBox; end
        if (sKey == "color" or sKey:match("^font") or sKey:match("^text") or sKey == "lineHeight" or sKey == "letterSpacing" or sKey == "listStyleType") then return dVisual, oVisual; end
        return dLayout, oPosition;
    end
    local function fChoice(dPage, oSizer, sKey, sLabel, tChoices)
        if (dPage == dVisual) then dPage, oSizer = fPage(sKey); end
        local tNames = {"Inherit"};
        for _, tChoice in ipairs(tChoices) do tNames[#tNames + 1] = tChoice[1]; end
        local oRow = fRow(dPage, oSizer, sLabel);
        local oChoice = wx.wxChoice(dPage, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tNames);
        oRow:Add(oChoice, 1, wx.wxEXPAND);
        oChoice:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, function()
            local nSelected = oChoice:GetSelection();
            if (nSelected >= 0 and nSelected <= #tChoices) then fSet(sKey, nSelected == 0 and "" or tChoices[nSelected][2]); end
        end);
        tBindings[#tBindings + 1] = function(tValues)
            if (oChoice:GetCount() > #tNames) then oChoice:Delete(oChoice:GetCount() - 1); end
            local sValue, nSelected = tValues[sKey] or "", 0;
            for nIndex, tChoice in ipairs(tChoices) do if (tChoice[2] == sValue) then nSelected = nIndex; end end
            if (sValue ~= "" and nSelected == 0) then oChoice:Append("Custom: "..sValue); nSelected = #tNames; end
            oChoice:SetSelection(nSelected);
        end;
    end
    local function fColor(sKey, sLabel)
        local dPage, oSizer = fPage(sKey);
        local oRow = fRow(dPage, oSizer, sLabel);
        local oPick = wx.wxColourPickerCtrl(dPage, wx.wxID_ANY, wx.wxColour("#ffffff"));
        local oCurrent = wx.wxStaticText(dPage, wx.wxID_ANY, "Inherit");
        local oInherit = wx.wxButton(dPage, wx.wxID_ANY, "Inherit");
        oRow:Add(oPick, 0, wx.wxRIGHT, 8); oRow:Add(oCurrent, 1, wx.wxALIGN_CENTER_VERTICAL); oRow:Add(oInherit, 0);
        oPick:Connect(wx.wxEVT_COMMAND_COLOURPICKER_CHANGED, function()
            local oColor = oPick:GetColour();
            fSet(sKey, string.format("#%02x%02x%02x", oColor:Red(), oColor:Green(), oColor:Blue()));
        end);
        oInherit:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() fSet(sKey, ""); end);
        tBindings[#tBindings + 1] = function(tValues)
            local sValue = tValues[sKey];
            local bSimple = sValue and sValue:match("^#%x%x%x%x%x%x$");
            oPick:SetColour(wx.wxColour(bSimple and sValue or "#ffffff"));
            oCurrent:SetLabel(not sValue and "Inherit" or bSimple and sValue or "Custom (Advanced)");
        end;
    end
    local function fArtwork(sKey, sLabel)
        local oRow = fRow(dArt, oArt, sLabel);
        local oPick = wx.wxButton(dArt, wx.wxID_ANY, "Choose image…");
        local oDefault = wx.wxButton(dArt, wx.wxID_ANY, "Inherit");
        local oNone = wx.wxButton(dArt, wx.wxID_ANY, "None");
        oRow:Add(oPick, 1, wx.wxRIGHT, 6); oRow:Add(oDefault, 0, wx.wxRIGHT, 6); oRow:Add(oNone, 0);
        local oCurrent = wx.wxStaticText(dArt, wx.wxID_ANY, "Inherited artwork");
        oCurrent:Wrap(355); oArt:Add(oCurrent, 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 10);
        oPick:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
            local dDialog = wx.wxFileDialog(dFrame, "Choose artwork from this manual's Images folder", pManual.."/Images", "", "Images (*.png;*.jpg;*.jpeg;*.svg;*.webp)|*.png;*.jpg;*.jpeg;*.svg;*.webp", wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST);
            if (dDialog:ShowModal() == wx.wxID_OK) then
                local pImage = dDialog:GetPath():gsub("\\", "/");
                local pRoot = pManual:gsub("\\", "/"):gsub("/$", "").."/";
                if (pImage:sub(1, #pRoot + 7):lower() == (pRoot.."Images/"):lower()) then fSet(sKey, pImage:sub(#pRoot + 1));
                else wx.wxMessageBox("Place the artwork in this manual's Images folder first. This keeps the game portable.", "Manual Appearance", wx.wxOK + wx.wxICON_INFORMATION, dFrame); end
            end
            dDialog:Destroy();
        end);
        oDefault:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() fSet(sKey, ""); end);
        oNone:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() fSet(sKey, "none"); end);
        tBindings[#tBindings + 1] = function(tValues) oCurrent:SetLabel(tValues[sKey] or "Inherited artwork"); oCurrent:Wrap(355); end;
    end

    local function fValue(sKey, sLabel, sHint)
        local dPage, oSizer = fPage(sKey);
        local oRow = fRow(dPage, oSizer, sLabel);
        local oValue = wx.wxTextCtrl(dPage, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_PROCESS_ENTER);
        oValue:SetHint(sHint or "Blank = inherit");
        local oApply = wx.wxButton(dPage, wx.wxID_ANY, "Apply");
        local oInherit = wx.wxButton(dPage, wx.wxID_ANY, "Inherit");
        oRow:Add(oValue, 1, wx.wxRIGHT, 6); oRow:Add(oApply, 0, wx.wxRIGHT, 6); oRow:Add(oInherit, 0);
        local function fApply() fSet(sKey, oValue:GetValue():match("^%s*(.-)%s*$")); end
        oApply:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, fApply);
        oValue:Connect(wx.wxEVT_COMMAND_TEXT_ENTER, fApply);
        oValue:Connect(wx.wxEVT_KILL_FOCUS, function(oEvent)
            if (not bDisplaying and oValue:GetValue() ~= (fValues()[sKey] or "")) then fApply(); end
            oEvent:Skip();
        end);
        oInherit:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() fSet(sKey, ""); end);
        tBindings[#tBindings + 1] = function(tValues) oValue:ChangeValue(tValues[sKey] or ""); end;
    end
    local oGradient = fRow(dBox, oBox, "Two-color background gradient");
    local oStartColor = wx.wxColourPickerCtrl(dBox, wx.wxID_ANY, wx.wxColour("#fff5df"));
    local oEndColor = wx.wxColourPickerCtrl(dBox, wx.wxID_ANY, wx.wxColour("#e8c994"));
    local oDirection = wx.wxChoice(dBox, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, {"Down", "Right", "Diagonal"});
    oDirection:SetSelection(0);
    local oApplyGradient = wx.wxButton(dBox, wx.wxID_ANY, "Apply");
    oGradient:Add(oStartColor, 0, wx.wxRIGHT, 6); oGradient:Add(oEndColor, 0, wx.wxRIGHT, 6);
    oGradient:Add(oDirection, 1, wx.wxRIGHT, 6); oGradient:Add(oApplyGradient, 0);
    oApplyGradient:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        local function fHex(oPicker)
            local oColor = oPicker:GetColour();
            return string.format("#%02x%02x%02x", oColor:Red(), oColor:Green(), oColor:Blue());
        end
        local tAngles = {"180deg", "90deg", "135deg"};
        fSet("background", "linear-gradient("..tAngles[oDirection:GetSelection() + 1]..", "..fHex(oStartColor)..", "..fHex(oEndColor)..")");
    end);
    tBindings[#tBindings + 1] = function(tValues)
        local sAngle, sStart, sEnd = (tValues.background or ""):match("^linear%-gradient%((%d+deg),%s*(#%x+),%s*(#%x+)%)$");
        if (sStart and #sStart == 7 and #sEnd == 7) then
            oStartColor:SetColour(wx.wxColour(sStart)); oEndColor:SetColour(wx.wxColour(sEnd));
            oDirection:SetSelection(sAngle == "90deg" and 1 or sAngle == "135deg" and 2 or 0);
        end
    end;
    fColor("background", "Background color"); fColor("color", "Text color"); fColor("borderColor", "Border color");
    local tStyles = {};
    for _, sName in ipairs(Appearance.styleNames(pManual)) do tStyles[#tStyles + 1] = {sName, sName}; end
    fChoice(dVisual, oVisual, "textStyle", "Named text style", tStyles);
    fChoice(dVisual, oVisual, "fontSize", "Text size", {{"Small", "14px"}, {"Body", "18px"}, {"Subheading", "24px"}, {"Heading", "32px"}, {"Title", "48px"}});
    fChoice(dVisual, oVisual, "fontWeight", "Text weight", {{"Normal", "400"}, {"Medium", "500"}, {"Semibold", "600"}, {"Bold", "700"}});
    fChoice(dVisual, oVisual, "fontStyle", "Text slant", {{"Normal", "normal"}, {"Italic", "italic"}});
    fChoice(dVisual, oVisual, "lineHeight", "Line spacing", {{"Compact", "1.2"}, {"Comfortable", "1.5"}, {"Open", "1.8"}, {"Double", "2"}});
    fChoice(dVisual, oVisual, "textDecoration", "Text decoration", {{"None", "none"}, {"Underline", "underline"}, {"Strike through", "line-through"}});
    fChoice(dVisual, oVisual, "background", "Background fill", {{"Transparent", "transparent"}, {"White", "#ffffff"}, {"Cream", "#fff5df"}, {"Dark", "#18232b"}});
    fChoice(dVisual, oVisual, "textAlign", "Text alignment", {{"Left", "left"}, {"Center", "center"}, {"Right", "right"}});
    fChoice(dVisual, oVisual, "justifyContent", "Heading / item alignment", {{"Left", "flex-start"}, {"Center", "center"}, {"Right", "flex-end"}, {"Spread out", "space-between"}});
    fChoice(dVisual, oVisual, "borderStyle", "Border", {{"None", "none"}, {"Solid", "solid"}, {"Dashed", "dashed"}, {"Dotted", "dotted"}, {"Double", "double"}});
    fChoice(dVisual, oVisual, "borderWidth", "Border thickness", {{"None", "0px"}, {"Hairline", "1px"}, {"Thin", "2px"}, {"Medium", "4px"}, {"Wide frame", "32px"}, {"Large frame", "72px"}});
    fChoice(dVisual, oVisual, "radius", "Corners", {{"Square", "0px"}, {"Slightly rounded", "4px"}, {"Rounded", "8px"}, {"Soft", "16px"}, {"Large", "32px"}});
    local tSpacing = {{"None", "0px"}, {"Small", "4px"}, {"Medium", "8px"}, {"Comfortable", "16px"}, {"Generous", "24px"}, {"Large", "32px"}};
    fChoice(dVisual, oVisual, "padding", "Inner spacing", tSpacing);
    fChoice(dVisual, oVisual, "margin", "Outer spacing", tSpacing);
    fChoice(dVisual, oVisual, "display", "Visibility / layout", {{"Hidden", "none"}, {"Block", "block"}, {"Flexible row", "flex"}});
    fChoice(dVisual, oVisual, "shadow", "Shadow", {{"None", "none"}, {"Subtle", "0 2px 5px #0002"}, {"Raised", "0 5px 14px #0004"}});
    fChoice(dVisual, oVisual, "listStyleType", "List markers", {{"None", "none"}, {"Dots", "disc"}, {"Circles", "circle"}, {"Squares", "square"}, {"Numbers", "decimal"}, {"Letters", "lower-alpha"}, {"Roman numerals", "upper-roman"}});
    fChoice(dVisual, oVisual, "gridTemplateColumns", "Grid columns", {{"One", "1fr"}, {"Two", "repeat(2, minmax(0, 1fr))"}, {"Three", "repeat(3, minmax(0, 1fr))"}});
    fChoice(dVisual, oVisual, "columnCount", "Columns", {{"One", "1"}, {"Two", "2"}, {"Three", "3"}, {"Four", "4"}, {"Automatic", "auto"}});
    fChoice(dVisual, oVisual, "columnWidth", "Preferred column width", {{"Narrow", "12rem"}, {"Medium", "18rem"}, {"Wide", "24rem"}, {"Automatic", "auto"}});
    fChoice(dVisual, oVisual, "columnGap", "Column spacing", tSpacing);
    fChoice(dVisual, oVisual, "breakInside", "Split across columns / pages", {{"Keep together", "avoid"}, {"Allow splitting", "auto"}});
    fChoice(dVisual, oVisual, "fontFamily", "Typeface", {{"System", "system-ui, sans-serif"}, {"Georgia", "Georgia, serif"}, {"Monospace", "monospace"}, {"Stardos Stencil", '"Stardos Stencil", Georgia, serif'}});
    fChoice(dVisual, oVisual, "objectFit", "Picture fit", {{"Fit inside", "contain"}, {"Fill and crop", "cover"}, {"Stretch", "fill"}});
    fChoice(dVisual, oVisual, "position", "Positioning", {{"Normal flow", "static"}, {"Layer container", "relative"}, {"Overlay layer", "absolute"}});
    fChoice(dVisual, oVisual, "overflowWrap", "Long words", {{"Normal", "normal"}, {"Wrap when needed", "anywhere"}});
    fChoice(dVisual, oVisual, "columnSpan", "Span columns", {{"No", "none"}, {"All columns", "all"}});
    fChoice(dVisual, oVisual, "clip", "Cut corners", {{"None", "none"}});
    fChoice(dVisual, oVisual, "filter", "Artwork effects", {{"None", "none"}});
    fChoice(dVisual, oVisual, "alignItems", "Vertical item alignment", {{"Top", "flex-start"}, {"Center", "center"}, {"Bottom", "flex-end"}, {"Stretch", "stretch"}});
    fChoice(dVisual, oVisual, "textShadow", "Text shadow", {{"None", "none"}, {"Subtle", "0 1px 2px #0003"}, {"Light highlight", "0 1px 0 #fff8"}});
    fChoice(dVisual, oVisual, "whiteSpace", "Text wrapping", {{"Wrap normally", "normal"}, {"Keep on one line", "nowrap"}, {"Preserve lines and wrap", "pre-wrap"}});
    fChoice(dVisual, oVisual, "overflowX", "Wide content", {{"Scroll when needed", "auto"}, {"Show overflow", "visible"}, {"Clip overflow", "hidden"}});
    fChoice(dVisual, oVisual, "aspectRatio", "Picture proportions", {{"Automatic", "auto"}, {"Square", "1 / 1"}, {"Landscape", "16 / 9"}, {"Portrait", "2 / 3"}});
    fChoice(dVisual, oVisual, "marginTop", "Space above", tSpacing);
    fChoice(dVisual, oVisual, "marginBottom", "Space below", tSpacing);
    fChoice(dVisual, oVisual, "textUnderlineOffset", "Underline distance", {{"Close", "1px"}, {"Medium", "3px"}, {"Far", "5px"}});
    fChoice(dVisual, oVisual, "textDecorationThickness", "Underline thickness", {{"Fine", "1px"}, {"Medium", "2px"}, {"Heavy", "3px"}});
    for _, tEdge in ipairs({{"borderTop", "Top"}, {"borderRight", "Right"}, {"borderBottom", "Bottom"}, {"borderLeft", "Left"}}) do
        fChoice(dVisual, oVisual, tEdge[1], tEdge[2].." border", {{"None", "none"}, {"Thin", "1px solid"}, {"Medium", "2px solid"}, {"Heavy", "4px solid"}, {"Dotted", "1px dotted"}});
    end
    fChoice(dArt, oArt, "backgroundBlend", "Artwork blending", {{"Normal", "normal"}, {"Soft light", "soft-light"}, {"Multiply", "multiply"}, {"Screen", "screen"}});
    fChoice(dArt, oArt, "cornerSize", "Ornament size", {{"Small", "16px 16px"}, {"Medium", "24px 24px"}, {"Large", "48px 48px"}});
    fValue("fontSize", "Exact text size", "For example: 18px or 1.2rem");
    fValue("fontFamily", "Other installed typeface", "Typeface name");
    fValue("letterSpacing", "Letter spacing", "For example: 1px");
    fValue("width", "Width", "For example: 100%, 240px, auto");
    fValue("maxWidth", "Maximum width", "For example: 100% or 800px");
    fValue("height", "Height", "For example: auto or 200px");
    fValue("maxHeight", "Maximum height", "For example: none or 400px");
    fValue("minHeight", "Minimum height", "For example: 0 or 100px");
    fValue("padding", "Exact inner spacing", "One value, or top right bottom left");
    fValue("margin", "Exact outer spacing", "One value, or top right bottom left");
    fValue("gap", "Space between items", "For example: 8px");
    fValue("top", "Top position", "For example: auto, 0 or 10%");
    fValue("left", "Left position", "For example: auto, 0 or 3%");
    fValue("right", "Right position", "For example: auto or 3%");
    fValue("bottom", "Bottom position", "For example: auto or 3%");
    fValue("frameSlice", "Frame slice", "For example: 25%");
    fValue("frameWidth", "Frame artwork width", "For example: 32px");
    fValue("frameOutset", "Frame overhang", "For example: 0");
    fArtwork("sourceImage", "Content picture used by a cover layer");
    fArtwork("cornerTL", "Top-left ornament"); fArtwork("cornerTR", "Top-right ornament");
    fArtwork("cornerBL", "Bottom-left ornament"); fArtwork("cornerBR", "Bottom-right ornament");
    fArtwork("image", "Background artwork"); fArtwork("frameImage", "Frame artwork");
    fChoice(dArt, oArt, "imageSize", "Background fit", {{"Cover", "cover"}, {"Contain", "contain"}, {"Stretch", "100% 100%"}, {"Natural size", "auto"}});
    fChoice(dArt, oArt, "imageRepeat", "Background repeat", {{"No repeat", "no-repeat"}, {"Tile", "repeat"}});
    fChoice(dArt, oArt, "imagePosition", "Background position", {{"Center", "center"}, {"Top", "center top"}, {"Bottom", "center bottom"}});
    fChoice(dArt, oArt, "backgroundClip", "Background extends beneath", {{"Content only", "content-box"}, {"Content and padding", "padding-box"}, {"Frame and corners", "border-box"}});
    fChoice(dArt, oArt, "backgroundOrigin", "Position background inside", {{"Content", "content-box"}, {"Padding", "padding-box"}, {"Frame", "border-box"}});
    fChoice(dArt, oArt, "frameRepeat", "Frame edges", {{"Stretch", "stretch"}, {"Repeat", "repeat"}, {"Round", "round"}});
    dVisual:SetSizer(oVisual); dBox:SetSizer(oBox); dLayout:SetSizer(oPosition); dArt:SetSizer(oArt);

    fDisplay = function()
        bDisplaying = true;
        local tValues = fValues();
        for _, fBinding in ipairs(tBindings) do fBinding(tValues); end
        for nRow, tField in ipairs(Appearance.fields) do
            oGrid:SetCellValue(nRow - 1, 0, tField.label); oGrid:SetReadOnly(nRow - 1, 0, true);
            oGrid:SetCellValue(nRow - 1, 1, tValues[tField.key] or "");
        end
        oAssignTheme:Enable(nTheme > 0);
        oSampleLabel:SetLabel("Live example — "..Appearance.targets[nTarget].label.." / "..Appearance.contexts[nContext].label);
        dVisual:FitInside(); dBox:FitInside(); dLayout:FitInside(); dArt:FitInside(); bDisplaying = false;
    end;
    local function fCommitGrid()
        if (oGrid:IsCellEditControlEnabled()) then oGrid:SaveEditControlValue(); oGrid:DisableCellEditControl(); end
    end
    fPreview = function()
        if (bClosed) then return false; end
        local bRendered, sFailure = pcall(function()
            local tSample = {Version = tDraft.Version, BaseCSS = tDraft.BaseCSS, Properties = {}};
            for sKey, tValues in pairs(tDraft.Properties) do tSample.Properties[sKey] = {}; for sField, sValue in pairs(tValues) do tSample.Properties[sKey][sField] = sValue; end end
            local function fMerge(tProperties)
                for sKey, tValues in pairs(tProperties or {}) do
                    tSample.Properties[sKey] = tSample.Properties[sKey] or {};
                    for sField, sValue in pairs(tValues) do tSample.Properties[sKey][sField] = sValue; end
                end
            end
            if (nContext > 1) then fMerge(tDraft[Appearance.contexts[nContext].key]); end
            if (nTheme > 0) then fMerge(fTheme().Properties); if (nContext > 1) then fMerge(fTheme()[Appearance.contexts[nContext].key]); end end
            local sCSS, tWarnings = Appearance.css(pManual, ".manual-appearance", sImages, tSample);
            local nLevel = tonumber(Appearance.targets[nTarget].key:match("(%d)$")) or 1;
            local nHeading = nLevel == 2 and 1 or nLevel;
            local sExamples = '<p>A paragraph with <strong>bold text</strong>, <em>italic text</em>, <s>strikethrough</s>, a superscript<sup>2</sup>, and <code>inline code</code>.</p><p><a href="#example">An ordinary link</a> and a <a class="glossary-link" href="#glossary-example">glossary term</a>. Hover the links to see their hover styling.</p><ul><li>A bulleted item<ul><li>A nested item</li></ul></li><li>Another item</li></ul><ol><li>A numbered item</li><li>Another numbered item</li></ol><hr><blockquote>A quotation with its own backing and border.</blockquote><pre><code>Example code block\nsecond line</code></pre><table class="table"><thead><tr><th><strong>Table heading</strong></th><th>Value</th></tr></thead><tbody><tr><td>First row</td><td>12</td></tr><tr><td>Alternating row</td><td>24</td></tr></tbody></table><p><img class="source-figure" src="'..sImages..'Appearance/Defaults/Banner.svg" alt="Sample artwork"></p>';
            local sSection = '<section class="manual-section metal-panel manual-heading-level-'..nLevel..' section-level-'..(nLevel == 1 and 2 or nLevel)..'"><div class="section-heading"><span class="heading-anchor"></span><h'..nHeading..'>Heading '..nLevel..' example</h'..nHeading..'></div><div class="section-copy">'..sExamples..'</div></section>';
            sSection = sSection..'<section id="glossary"><div class="section-heading"><h2>Glossary example</h2></div><section id="glossary-example" class="manual-section manual-heading-level-3 section-level-3"><div class="section-heading"><span class="heading-anchor"></span><h3>Example term</h3></div><div class="section-copy"><p>A definition shows entry spacing and column layout.</p></div></section><section id="glossary-second" class="manual-section manual-heading-level-3 section-level-3"><div class="section-heading"><h3>Second term</h3></div><div class="section-copy"><p>A second definition demonstrates how entries flow.</p></div></section></section><aside class="glossary-popup" style="position:relative;inset:auto;margin:1rem 0"><strong>Definition popup</strong><div class="glossary-popup-content"><p>This example stays visible while you adjust its appearance.</p></div></aside>';
            for nExample = 1, 6 do
                if (nExample ~= nLevel) then
                    local nTag = nExample == 2 and 1 or nExample;
                    sSection = sSection..'<section class="manual-section manual-heading-level-'..nExample..' section-level-'..(nExample == 1 and 2 or nExample)..'"><div class="section-heading"><span class="heading-anchor"></span><h'..nTag..'>Heading '..nExample..' example</h'..nTag..'></div><div class="section-copy"><p>Body text for heading level '..nExample..'.</p></div></section>';
                end
            end
            local function fPicture(sTarget)
                local sPath = (tSample.Properties[sTarget] or {}).sourceImage;
                if (not sPath or sPath == "none" or not wx.wxFileExists(pManual.."/"..sPath)) then sPath = "Images/Appearance/Defaults/Banner.svg"; end
                return sImages..sPath:sub(8):gsub('([^%w%-%._~/])', function(sChar) return string.format('%%%02X', sChar:byte()); end);
            end
            sSection = sSection..'<p class="manual-cover"><img class="source-figure manual-cover-scene" src="'..fPicture("CoverScene")..'" alt="Cover scene"><img class="source-figure manual-cover-title" src="'..fPicture("CoverTitle")..'" alt="Cover title"></p><div class="quicksheet-card">Quick reference example</div><footer class="chapter-footer">Chapter footer <a href="#example">Next chapter</a></footer>';
            local sHTML = '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0}*{box-sizing:border-box}</style><style>'..sCSS..'</style></head><body class="manual-appearance"><main class="manual-shell"><header class="title-assembly"><span class="web-game-title">Your manual</span><span class="web-manual-subtitle">APPEARANCE EXAMPLE</span></header><nav class="navigation-assembly"><button class="navigation-toggle">Contents</button><div class="manual-view-buttons"><button class="btn">Chapter view</button><button class="btn active">Full manual</button></div><div class="toc"><div class="has-current"><div class="toc-group-header"><a href="#example">Chapter group</a></div></div><a href="#example">Contents item</a><a class="is-current" href="#example">Selected item</a></div><label class="toc-accordion-option">Contents option</label></nav><div class="chapter-strip">Chapter information</div>'..sSection..'</main></body></html>';
            local hFile = assert(io.open(pPage, "wb")); assert(hFile:write(sHTML)); assert(hFile:close());
            nRevision = nRevision + 1; oBrowser:LoadURL(sPageURL.."?revision="..nRevision);
            if (tOptions.onPreview) then tOptions.onPreview(tDraft); end
            return #tWarnings > 0 and table.concat(tWarnings, "\n") or nil;
        end);
        oStatus:SetLabel(bRendered and (sFailure and "Using default artwork — hover here for details" or bDirty and "Previewing unsaved changes" or "Saved appearance") or "Preview unchanged; hover here for error details.");
        oStatus:SetToolTip(sFailure and tostring(sFailure) or "");
        return bRendered;
    end;
    oGrid:Connect(wx.wxEVT_GRID_CELL_CHANGED, function(oEvent)
        if (not bDisplaying and oEvent:GetCol() == 1) then fSet(Appearance.fields[oEvent:GetRow() + 1].key, oGrid:GetCellValue(oEvent:GetRow(), 1):match("^%s*(.-)%s*$")); end
        oEvent:Skip();
    end);
    oTheme:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, function() fCommitGrid(); nTheme = oTheme:GetSelection(); fDisplay(); oTimer:StartOnce(1); end);
    oContext:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, function() fCommitGrid(); nContext = oContext:GetSelection() + 1; fDisplay(); oTimer:StartOnce(1); end);
    oAddTheme:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        local sName = wx.wxGetTextFromUser("Name this section theme", "Manual Appearance", "", dFrame):match("^%s*(.-)%s*$");
        if (sName == "") then return; end
        if (#sName > 80) then wx.wxMessageBox("Use a name of at most 80 characters.", "Manual Appearance", wx.wxOK, dFrame); return; end
        fCommitGrid(); tDraft.Variants = tDraft.Variants or {};
        tDraft.Variants[#tDraft.Variants + 1] = {Name = sName, Sections = {}, Properties = {}};
        oTheme:Append(sName); nTheme = #tDraft.Variants; oTheme:SetSelection(nTheme); fChanged(); fDisplay();
    end);
    oAssignTheme:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        if (nTheme == 0) then return; end
        local tIDs, tNames, tSeen = {}, {}, {};
        local sFile = wx.wxFindFirstFile(pManual.."/Content/*.md", wx.wxFILE);
        while (sFile ~= "") do
            local sSource = Documents.read(sFile);
            for sID in sSource:gmatch("<!%-%- section:%s*([%w_-]+)") do
                if (not tSeen[sID]) then tSeen[sID] = true; tIDs[#tIDs + 1] = sID; end
            end
            sFile = wx.wxFindNextFile();
        end
        for _, sID in ipairs(fTheme().Sections) do if (not tSeen[sID]) then tSeen[sID] = true; tIDs[#tIDs + 1] = sID; end end
        table.sort(tIDs);
        for _, sID in ipairs(tIDs) do tNames[#tNames + 1] = sID:gsub("-", " "); end
        local dDialog = wx.wxMultiChoiceDialog(dFrame, "Choose the sections that use this theme", "Section theme", tNames);
        local tSelected = {};
        for nIndex, sID in ipairs(tIDs) do for _, sExisting in ipairs(fTheme().Sections) do if (sID == sExisting) then tSelected[#tSelected + 1] = nIndex - 1; end end end
        dDialog:SetSelections(tSelected);
        if (dDialog:ShowModal() == wx.wxID_OK) then
            fTheme().Sections = {};
            local tSelections = dDialog:GetSelections();
            for nIndex = 0, tSelections:GetCount() - 1 do fTheme().Sections[#fTheme().Sections + 1] = tIDs[tSelections:Item(nIndex) + 1]; end
            fChanged();
        end
        dDialog:Destroy();
    end);
    oSearch:Connect(wx.wxEVT_COMMAND_TEXT_UPDATED, function()
        fCommitGrid();
        local sQuery = oSearch:GetValue():lower();
        oTarget:Clear(); tTargetIndices = {};
        for nIndex, tTarget in ipairs(Appearance.targets) do
            if (sQuery == "" or tTarget.label:lower():find(sQuery, 1, true) or tTarget.key:lower():find(sQuery, 1, true)) then
                tTargetIndices[#tTargetIndices + 1] = nIndex; oTarget:Append(tTarget.label);
                if (nIndex == nTarget) then oTarget:SetSelection(#tTargetIndices - 1); end
            end
        end
        if (oTarget:GetSelection() == wx.wxNOT_FOUND and #tTargetIndices > 0) then
            oTarget:SetSelection(0); nTarget = tTargetIndices[1]; fDisplay(); oTimer:StartOnce(1);
        end
    end);
    oTarget:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, function() fCommitGrid(); nTarget = tTargetIndices[oTarget:GetSelection() + 1]; fDisplay(); oTimer:StartOnce(1); end);
    oReset:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() fCommitGrid(); fProperties()[Appearance.targets[nTarget].key] = nil; fChanged(); fDisplay(); end);
    dFrame:Connect(oTimer:GetId(), wx.wxEVT_TIMER, fPreview);
    oSave:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function()
        fCommitGrid(); oTimer:Stop();
        if (not fPreview()) then return; end
        local bSaved, sFailure = pcall(function()
            Appearance.save(pManual, tDraft, sOriginal);
            sOriginal = Documents.read(pManual.."/Config/Appearance.lua");
        end);
        if (bSaved) then bDirty = false; oStatus:SetLabel("Appearance saved");
        else oStatus:SetLabel("Save failed; your draft is still open."); wx.wxMessageBox(tostring(sFailure), "Manual Appearance", wx.wxOK + wx.wxICON_ERROR, dFrame); end
    end);
    oBrowser:Connect(WebView.wxEVT_WEBVIEW_NAVIGATING, function(oEvent)
        local sURL = oEvent:GetURL();
        if (sURL == "about:blank" or sURL:match("^[^?#]*") == sPageURL) then oEvent:Skip(); else oEvent:Veto(); end
    end);
    local oState = WindowState.bind(dFrame, "ManualAppearance");
    local tWindow = {};
    dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        if (not bClosed) then
            fCommitGrid();
            if (bDirty and oEvent:CanVeto() and wx.wxMessageBox("Discard unsaved appearance changes?", "Manual Appearance", wx.wxYES_NO + wx.wxNO_DEFAULT + wx.wxICON_WARNING, dFrame) ~= wx.wxYES) then oEvent:Veto(); return; end
            if (tOptions.onPreview) then
                local bRestored, sFailure = pcall(tOptions.onPreview, nil);
                if (not bRestored and oEvent:CanVeto()) then wx.wxMessageBox(tostring(sFailure), "Cannot restore saved appearance", wx.wxOK + wx.wxICON_ERROR, dFrame); oEvent:Veto(); return; end
            end
            bClosed = true; oTimer:Stop(); oBrowser:Stop(); wx.wxRemoveFile(pPage); oState.close();
            if (tOptions.onClose) then tOptions.onClose(); end
        end
        oEvent:Skip();
    end);
    oCancel:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() dFrame:Close(); end);
    function tWindow.show() if (bClosed) then return false; end dFrame:Show(true); dFrame:Raise(); return true; end
    function tWindow.close(bForce) if (bClosed) then return true; end return dFrame:Close(bForce == true); end
    function tWindow.hasDrafts() return bDirty; end
    tWindow.frame = dFrame;
    fDisplay(); if (tOptions.show ~= false) then tWindow.show(); end oTimer:StartOnce(1);
    return tWindow;
end
return ManualAppearance;
