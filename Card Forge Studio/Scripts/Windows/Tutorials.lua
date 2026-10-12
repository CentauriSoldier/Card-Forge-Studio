local wx          = require("wx");
local WebView     = assert(wxwebview, "Tutorials requires the wxLua WebView binding.");
local WindowState = require("Windows.WindowState");
local Tutorials   = {};

WindowState.register("Tutorials", {savePosition = true, saveSize = true, saveVisible = false,});

--[[!
@fqxn CFS.Windows.Tutorials
@desc A native tutorial reader with Basic and Advanced topic lists sharing the left sidebar, numbered steps across the top, and the selected instruction below. Readers can select any step without completing earlier steps. Lessons are loaded from the top-level Tutorial module and its ordered topic files. Outdated browser lessons are not loaded.
!]]

--[[!
@fqxn CFS.Windows.Tutorials.Private.Functions.escapeHTML
@desc Escapes topic and step titles for the browser instruction viewer.
@param string sText Title text.
@return string sHTML Escaped title.
@vis private
!]]
local function escapeHTML(sText)
    return sText:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;");
end

--[[!
@fqxn CFS.Windows.Tutorials.Functions.create
@pulsarlua function Tutorials.create
@desc Creates a modeless tutorial window. Optional topics contain a title and ordered steps, each with a title and HTML instruction body. Empty content leaves the instruction area blank. No game is required or changed.
@param any dParent Parent window.
@param table tOptions Optional topics and onClose callback.
@return table tWindow Window controls and navigation functions.
!]]
function Tutorials.create(dParent, tOptions)
    tOptions = tOptions or {};
    local tTopics = tOptions.topics or require("Tutorial").Load();
    for _, tTopic in ipairs(tTopics) do
        assert(type(tTopic.title) == "string" and type(tTopic.steps) == "table", "Tutorial topics require a title and steps.");
        for _, tStep in ipairs(tTopic.steps) do assert(type(tStep.title) == "string" and type(tStep.html) == "string", "Tutorial steps require a title and HTML content."); end
    end
    local dFrame = wx.wxFrame(dParent, wx.wxID_ANY, "Tutorials - Card Forge Studio", wx.wxDefaultPosition, wx.wxSize(1000, 720));
    dFrame:SetMinSize(wx.wxSize(680, 480));
    local oState = WindowState.bind(dFrame, "Tutorials");
    local dPanel = wx.wxPanel(dFrame, wx.wxID_ANY);
    dPanel:SetBackgroundColour(wx.wxColour("#eef0f3"));
    local oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
    local oBody = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local dTopics = wx.wxPanel(dPanel, wx.wxID_ANY);
    local oTopics = wx.wxBoxSizer(wx.wxVERTICAL);
    local tBasicTitles, tAdvancedTitles, tBasicIndices, tAdvancedIndices = {}, {}, {}, {};
    for nIndex, tTopic in ipairs(tTopics) do
        local bAdvanced = tTopic.category == "Advanced";
        local tTitles = bAdvanced and tAdvancedTitles or tBasicTitles;
        local tIndices = bAdvanced and tAdvancedIndices or tBasicIndices;
        tTitles[#tTitles + 1] = tTopic.title; tIndices[#tIndices + 1] = nIndex;
    end
    local oBasicBox = wx.wxStaticBoxSizer(wx.wxVERTICAL, dTopics, "Basic topics");
    local oAdvancedBox = wx.wxStaticBoxSizer(wx.wxVERTICAL, dTopics, "Advanced topics");
    local oList = wx.wxListBox(dTopics, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(210, -1), tBasicTitles);
    local oAdvancedList = wx.wxListBox(dTopics, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(210, -1), tAdvancedTitles);
    oBasicBox:Add(oList, 1, wx.wxEXPAND + wx.wxALL, 8);
    oAdvancedBox:Add(oAdvancedList, 1, wx.wxEXPAND + wx.wxALL, 8);
    oTopics:Add(oBasicBox, 1, wx.wxEXPAND + wx.wxBOTTOM, 8);
    oTopics:Add(oAdvancedBox, 1, wx.wxEXPAND); dTopics:SetSizer(oTopics);
    oBody:Add(dTopics, 0, wx.wxEXPAND + wx.wxRIGHT, 12);
    local dReader = wx.wxPanel(dPanel, wx.wxID_ANY);
    local oReader = wx.wxBoxSizer(wx.wxVERTICAL);
    local dSteps = wx.wxScrolledWindow(dReader, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(-1, 64));
    dSteps:SetScrollRate(12, 0);
    local oSteps = wx.wxBoxSizer(wx.wxHORIZONTAL); dSteps:SetSizer(oSteps);
    oReader:Add(dSteps, 0, wx.wxEXPAND + wx.wxBOTTOM, 10);
    local oContent = assert(WebView.wxWebView.New(dReader, wx.wxID_ANY), "Cannot create the tutorial browser.");
    oReader:Add(oContent, 1, wx.wxEXPAND);
    local oNavigation = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oPrevious = wx.wxButton(dReader, wx.wxID_ANY, "Previous");
    local oNext = wx.wxButton(dReader, wx.wxID_ANY, "Next");
    local oPosition = wx.wxStaticText(dReader, wx.wxID_ANY, "");
    oNavigation:Add(oPrevious, 0); oNavigation:Add(oNext, 0, wx.wxLEFT, 8); oNavigation:Add(oPosition, 1, wx.wxALIGN_CENTER_VERTICAL + wx.wxLEFT, 12);
    oReader:Add(oNavigation, 0, wx.wxEXPAND + wx.wxTOP, 12); dReader:SetSizer(oReader);
    oBody:Add(dReader, 1, wx.wxEXPAND); oLayout:Add(oBody, 1, wx.wxEXPAND + wx.wxALL, 12);
    dPanel:SetSizer(oLayout);
    local nTopic, nStep, bClosed = nil, nil, false;
    local tButtons = {};
    local oTemporary = wx.wxFile();
    local pTemporary = wx.wxFileName.CreateTempFileName("cfs-tutorial-", oTemporary);
    oTemporary:Close(); oTemporary:delete();
    local pPage = pTemporary..".html";
    assert(wx.wxRenameFile(pTemporary, pPage), "Cannot create the tutorial HTML file.");
    local oPage = wx.wxFileName(pPage);
    local sPageURL = wx.wxFileSystem.FileNameToURL(oPage); oPage:delete();
    local nPage = 0;
    --[[!
    @fqxn CFS.Windows.Tutorials.Private.Functions.showPage
    @desc Displays a styled local HTML page so existing tutorial image URLs remain available to the browser.
    @param string sTitle Step or topic title.
    @param string sHTML Instruction body.
    @vis private
    !]]
    local function showPage(sTitle, sHTML)
        local sDocument = [[<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><style>
            * {box-sizing:border-box} body {margin:0;background:#f5f7fb;color:#20252b;font:18px/1.65 "Segoe UI",Arial,sans-serif}
            main {max-width:960px;margin:0 auto;padding:28px 32px} h1,h2,h3 {line-height:1.25;color:#29385a}
            h2 {font-size:28px;margin:0 0 24px} p,ul,ol {margin:0 0 18px} li {margin-bottom:8px}
            pre {overflow:auto;padding:18px;background:#edf0f6;border:1px solid #d8dfec;border-radius:10px;white-space:pre-wrap;overflow-wrap:anywhere}
            code,pre {font-family:Consolas,monospace;font-size:16px} code {background:#edf0f6;padding:2px 5px;border-radius:4px} pre code {padding:0}
            img {max-width:100%;height:auto;object-fit:contain;border-radius:8px} table {border-collapse:collapse;max-width:100%}
            th,td {padding:10px;border:1px solid #d8dfec;text-align:left} blockquote {margin:18px 0;padding:12px 18px;border-left:4px solid #647ab6;background:#edf0f6}
            a {color:#3659a3} @media(max-width:600px) {main {padding:20px} h2 {font-size:24px}}
        </style></head><body><main>]];
        if (sTitle ~= "") then sDocument = sDocument.."<h2>"..escapeHTML(sTitle).."</h2>"; end
        sDocument = sDocument..sHTML.."</main></body></html>";
        local hPage = assert(io.open(pPage, "wb"), "Cannot open the tutorial HTML file.");
        assert(hPage:write(sDocument)); assert(hPage:close());
        nPage = nPage + 1; oContent:LoadURL(sPageURL.."?step="..nPage);
    end
    --[[!
    @fqxn CFS.Windows.Tutorials.Private.Functions.selectStep
    @desc Displays any selected step and updates numbered navigation without enforcing completion order.
    @param number nIndex One-based step index.
    @vis private
    !]]
    local function selectStep(nIndex)
        local tTopic = assert(tTopics[nTopic], "Choose a tutorial topic first.");
        local tStep = assert(tTopic.steps[nIndex], "Unknown tutorial step.");
        nStep = nIndex;
        for nButton, oButton in ipairs(tButtons) do oButton:SetValue(nButton == nStep); end
        showPage(tStep.title, tStep.html);
        oPosition:SetLabel("Step "..nStep.." of "..#tTopic.steps);
        oPrevious:Enable(nStep > 1); oNext:Enable(nStep < #tTopic.steps);
    end
    --[[!
    @fqxn CFS.Windows.Tutorials.Private.Functions.selectTopic
    @desc Rebuilds the top step strip for a topic and displays its first step, or an empty-topic notice.
    @param number nIndex One-based topic index.
    @vis private
    !]]
    local function selectTopic(nIndex)
        local tTopic = assert(tTopics[nIndex], "Unknown tutorial topic.");
        nTopic, nStep = nIndex, nil;
        oList:SetSelection(wx.wxNOT_FOUND); oAdvancedList:SetSelection(wx.wxNOT_FOUND);
        for nRow, nTopicIndex in ipairs(tBasicIndices) do if (nTopicIndex == nIndex) then oList:SetSelection(nRow - 1); end end
        for nRow, nTopicIndex in ipairs(tAdvancedIndices) do if (nTopicIndex == nIndex) then oAdvancedList:SetSelection(nRow - 1); end end
        oSteps:Clear(true); tButtons = {};
        for nIndex, tStep in ipairs(tTopic.steps) do
            local nTarget = nIndex;
            local oButton = wx.wxToggleButton(dSteps, wx.wxID_ANY, tostring(nIndex)..". "..tStep.title);
            oButton:SetToolTip(tStep.title);
            oButton:Connect(wx.wxEVT_COMMAND_TOGGLEBUTTON_CLICKED, function() selectStep(nTarget); end);
            oSteps:Add(oButton, 0, wx.wxALL, 6); tButtons[#tButtons + 1] = oButton;
        end
        dSteps:FitInside(); dSteps:Layout(); dSteps:Scroll(0, 0);
        if (#tTopic.steps > 0) then selectStep(1);
        else
            showPage(tTopic.title, "<p>No steps are available for this topic yet.</p>");
            oPosition:SetLabel(""); oPrevious:Disable(); oNext:Disable();
        end
    end
    oList:Connect(wx.wxEVT_COMMAND_LISTBOX_SELECTED, function() local nIndex = tBasicIndices[oList:GetSelection() + 1]; if (nIndex) then selectTopic(nIndex); end end);
    oAdvancedList:Connect(wx.wxEVT_COMMAND_LISTBOX_SELECTED, function() local nIndex = tAdvancedIndices[oAdvancedList:GetSelection() + 1]; if (nIndex) then selectTopic(nIndex); end end);
    oPrevious:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() if (nStep and nStep > 1) then selectStep(nStep - 1); end end);
    oNext:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() if (nStep and nStep < #tTopics[nTopic].steps) then selectStep(nStep + 1); end end);
    if (#tTopics > 0) then selectTopic(1);
    else
        showPage("", "");
        dSteps:Hide();
        oPrevious:Disable(); oNext:Disable();
    end
    --[[!
    @fqxn CFS.Windows.Tutorials.Private.Functions.onClose
    @desc Saves window state and clears the caller's open-window reference on closure.
    @param any oEvent Native close event.
    @vis private
    !]]
    dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
        bClosed = true; oState.close();
        oContent:Stop(); wx.wxRemoveFile(pPage);
        if (tOptions.onClose) then tOptions.onClose(); end
        oEvent:Skip();
    end);
    dFrame:CentreOnParent(); dFrame:Show(true); dPanel:Layout();
    return {frame = dFrame, topics = oList, advancedTopics = oAdvancedList, steps = dSteps, content = oContent, previous = oPrevious, next = oNext,
        selectTopic = selectTopic, selectStep = selectStep,
        --[[!
        @fqxn CFS.Windows.Tutorials.Private.Functions.show
        @desc Shows and raises the existing tutorials window.
        @vis private
        !]]
        show = function() dFrame:Show(true); dFrame:Raise(); end,
        --[[!
        @fqxn CFS.Windows.Tutorials.Private.Functions.close
        @desc Closes the tutorial reader without changing any project.
        @vis private
        !]]
        close = function() if (bClosed) then return true; end return dFrame:Close(); end};
end

return Tutorials;
