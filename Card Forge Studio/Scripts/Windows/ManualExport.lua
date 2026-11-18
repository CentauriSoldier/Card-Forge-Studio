--[[!
@fqxn CFS.Windows.ManualExport
@desc Game-bound native Web/PDF export window. Native controls own settings, actions and progress; a bounded native canvas displays Lua page plans. Lua reads saved files, paginates and writes PDF without a browser.
!]]

local wx			= require("wx");
local Export		= require("Manual.Export");
local JSON			= require("Manual.Lib.dkjson");
local WindowState	= require("Windows.WindowState");
local ManualExport	= {};

WindowState.register("ManualExport", {savePosition = true, saveSize = true, saveVisible = false});

--[[!
@fqxn CFS.Windows.ManualExport.Private.Functions.fileURL
@desc Converts an application-owned filename to its browser URL.
@param string pFile Native filename.
@return string sURL File URL.
@vis private
!]]
local function fileURL(pFile)
	local oFile	= wx.wxFileName(pFile);
	local sURL	= wx.wxFileSystem.FileNameToURL(oFile);
	oFile:delete();
	return sURL;
end

--[[!
@fqxn CFS.Windows.ManualExport.Functions.create
@desc Creates the shared native export window for one active game. Uses the existing settings file, supplier catalog, staged output replacement and WindowState service.
@param wxFrame dParent Studio owner.
@param string pManual Active game's manual folder.
@param table tOptions gameName, gameRoot, exports, onOpenOptions, hasDrafts and onClose.
@return table tWindow Window, controls and show/close operations.
!]]
function ManualExport.create(dParent, pManual, tOptions)
	local tContext				= {gameName = tOptions.gameName, gameRoot = tOptions.gameRoot, manualRoot = pManual, exportRoot = tOptions.exports};
	local tSettings, sOriginal	= Export.settings(tContext);
	local tProfiles				= Export.presets();
	local dFrame				= wx.wxFrame(dParent, wx.wxID_ANY, "Manual Export - "..tOptions.gameName, wx.wxDefaultPosition, wx.wxSize(1200, 850));
	local oLayout				= wx.wxBoxSizer(wx.wxVERTICAL);
	local oBook					= wx.wxNotebook(dFrame, wx.wxID_ANY);
	local dWeb					= wx.wxPanel(oBook, wx.wxID_ANY);
	local dPDF					= wx.wxPanel(oBook, wx.wxID_ANY);
	local oWeb					= wx.wxBoxSizer(wx.wxVERTICAL);
	local oPDF					= wx.wxBoxSizer(wx.wxVERTICAL);
	local oBody					= wx.wxBoxSizer(wx.wxHORIZONTAL);
	local dSettings				= wx.wxScrolledWindow(dPDF, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(320, -1));
	local oSettings				= wx.wxBoxSizer(wx.wxVERTICAL);
	local oFields				= wx.wxFlexGridSizer(0, 2, 8, 10);
	local tControls				= {};
	local tActions				= {};
	local tNames				= {"Custom"};
	local tFields				= {{"width", "Trim width (in)"}, {"height", "Trim height (in)"}, {"bleed", "Bleed, each edge (in)"}, {"marginTop", "Top margin (in)"}, {"marginBottom", "Bottom margin (in)"}, {"marginInside", "Inside margin (in)"}, {"marginOutside", "Outside margin (in)"}, {"dpi", "Image resolution (DPI)"}};
	local oPreset;
	local oNotes;
	local oSettingsStatus;
	local oCanvas;
	local oPageLabel;
	local oPageProgress;
	local nPreviewPage = 1;
	local fPreviewPage;
	local oStatus;
	local oHistory;
	local nStarted;
	local sStageMessage;
	local bConfirmingClose = false;
	local nProgressValue = 0;
	local tStageStarts;
	local tStageHistory;
	local tRunProgress;
	local oProgress;
	local oState;
	local oSaveTimer		= wx.wxTimer(dFrame, wx.wxNewId());
	local oProgressTimer	= wx.wxTimer(dFrame, wx.wxNewId());
	local tPreview;
	local bPreviewReady		= false;
	local nSettingsRevision	= 0;
	local nPreviewRevision	= 0;
	local bBusy				= false;
	local bDirty			= false;
	local bDisplaying		= false;
	local bClosed			= false;
	local bClosePending		= false;
	local bShutdown			= false;
	local tWindow			= {};
	local fDisplay;
	local fSave;
	local fRun;
	local fEnable;
	local fView;
	dFrame:SetMinSize(wx.wxSize(900, 650));
	dSettings:SetScrollRate(0, 12);
	dSettings:SetMinSize(wx.wxSize(310, -1));
	oFields:AddGrowableCol(1, 1);

	for _, tProfile in ipairs(tProfiles) do tNames[#tNames + 1] = tProfile.name; end
	oSettings:Add(wx.wxStaticText(dSettings, wx.wxID_ANY, "Book preset"), 0, wx.wxBOTTOM, 6);
	oPreset = wx.wxChoice(dSettings, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, tNames);
	oSettings:Add(oPreset, 0, wx.wxEXPAND + wx.wxBOTTOM, 12);
	for _, tField in ipairs(tFields) do
		oFields:Add(wx.wxStaticText(dSettings, wx.wxID_ANY, tField[2]), 0, wx.wxALIGN_CENTER_VERTICAL);
		local oControl = wx.wxTextCtrl(dSettings, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(85, -1));
		tControls[tField[1]] = oControl;
		oFields:Add(oControl, 1, wx.wxEXPAND);
	end
	oSettings:Add(oFields, 0, wx.wxEXPAND + wx.wxBOTTOM, 12);
	oNotes = wx.wxStaticText(dSettings, wx.wxID_ANY, "");
	oNotes:Wrap(285); oSettings:Add(oNotes, 0, wx.wxEXPAND + wx.wxBOTTOM, 12);
	oSettingsStatus = wx.wxStaticText(dSettings, wx.wxID_ANY, "Saved");
	oSettingsStatus:Wrap(285); oSettings:Add(oSettingsStatus, 0, wx.wxEXPAND + wx.wxBOTTOM, 12);
	dSettings:SetSizer(oSettings);
	oBody:Add(dSettings, 0, wx.wxEXPAND + wx.wxALL, 12);
	local dPreview	= wx.wxPanel(dPDF, wx.wxID_ANY);
	local oPreview	= wx.wxBoxSizer(wx.wxVERTICAL);
	oPreview:Add(wx.wxStaticText(dPreview, wx.wxID_ANY, "PDF page preview"), 0, wx.wxBOTTOM, 6);
    local oPageRow = wx.wxBoxSizer(wx.wxHORIZONTAL);
    local oPreviousPage = wx.wxButton(dPreview, wx.wxID_ANY, "Previous page");
    local oNextPage = wx.wxButton(dPreview, wx.wxID_ANY, "Next page");
    oPageLabel = wx.wxStaticText(dPreview, wx.wxID_ANY, "Refresh preview to prepare pages.");
    oPageRow:Add(oPreviousPage, 0, wx.wxRIGHT, 6);
    oPageRow:Add(oNextPage, 0, wx.wxRIGHT, 12);
    oPageRow:Add(oPageLabel, 1, wx.wxALIGN_CENTER_VERTICAL);
    oPreview:Add(oPageRow, 0, wx.wxEXPAND + wx.wxBOTTOM, 8);
    oCanvas = wx.wxPanel(dPreview, wx.wxID_ANY);
    oCanvas:SetBackgroundStyle(wx.wxBG_STYLE_PAINT);
    oPreview:Add(oCanvas, 1, wx.wxEXPAND);
    dPreview:SetSizer(oPreview);
    fPreviewPage = function(nPage)
        local nTotal = tPreview and tPreview.layout and tPreview.layout.pageCount or 0;

        nPreviewPage = math.max(1, math.min(nPage, math.max(1, nTotal)));
        oPageLabel:SetLabel(nTotal > 0 and "Page "..nPreviewPage.." of "..nTotal or "Refresh preview to prepare pages.");
        oPreviousPage:Enable(nTotal > 0 and nPreviewPage > 1 and not bBusy);
        oNextPage:Enable(nTotal > 0 and nPreviewPage < nTotal and not bBusy);
        oCanvas:Refresh(false);
    end;
    oPreviousPage:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() fPreviewPage(nPreviewPage - 1); end);
    oNextPage:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() fPreviewPage(nPreviewPage + 1); end);
    oCanvas:Connect(wx.wxEVT_SIZE, function(jEvent) oCanvas:Refresh(false); jEvent:Skip(); end);
    oCanvas:Connect(wx.wxEVT_PAINT, function()
        local oDC = wx.wxAutoBufferedPaintDC(oCanvas);
        local oBrush = wx.wxBrush(wx.wxColour(218, 222, 227));
        local bOK, sError;

        oDC:SetBackground(oBrush); oDC:Clear(); oBrush:delete();
        if (tPreview and tPreview.layout) then
            bOK, sError = pcall(Export.drawPage, tPreview.layout, nPreviewPage, oDC, oCanvas:GetClientSizeWH());
            if (not bOK) then
                oStatus:SetLabel("PDF preview failed: "..tostring(sError));
                if (CFS and CFS.Log) then pcall(CFS.Log.Error, tostring(sError)); end
            end
        end
        oDC:delete();
    end);
    tControls.preview, tControls.previousPage, tControls.nextPage, tControls.pageLabel = oCanvas, oPreviousPage, oNextPage, oPageLabel;
	oBody:Add(dPreview, 1, wx.wxEXPAND + wx.wxTOP + wx.wxRIGHT + wx.wxBOTTOM, 12);
	oPDF:Add(oBody, 1, wx.wxEXPAND);
	local oWebDescription	= wx.wxStaticText(dWeb, wx.wxID_ANY, "Build a standalone manual website from the saved Markdown, styles, images, document order and glossary.");
	local oWebReminder		= wx.wxStaticText(dWeb, wx.wxID_ANY, "Save any manual-editor changes before exporting. Export reads files directly from disk.");
	oWebDescription:Wrap(650); oWebReminder:Wrap(650);
	oWeb:Add(oWebDescription, 0, wx.wxALL, 16);
	oWeb:Add(oWebReminder, 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 16);
	oWeb:Add(wx.wxStaticText(dWeb, wx.wxID_ANY, "Output"), 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 6);
	oWeb:Add(wx.wxTextCtrl(dWeb, wx.wxID_ANY, tContext.exportRoot.."/Manual/Web/index.html", wx.wxDefaultPosition, wx.wxDefaultSize, wx.wxTE_READONLY), 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 16);
	oWeb:AddStretchSpacer();

	--[[!
	@fqxn CFS.Windows.ManualExport.Private.Functions.fView
	@desc Opens only this game's published output in its default browser/viewer.
	@vis private
	!]]
	fView = function(sKind)
		local pFile = tContext.exportRoot.."/Manual/"..(sKind == "web" and "Web/index.html" or "PDF/Manual.pdf");
		assert(wx.wxFileExists(pFile), "No "..sKind:upper().." export has been saved yet.");
		assert(wx.wxLaunchDefaultBrowser(fileURL(pFile)), "Could not open the saved export.");
	end;

	--[[!
	@fqxn CFS.Windows.ManualExport.Private.Functions.fProtect
	@desc Reports native action errors in the window and existing application log.
	@vis private
	!]]
	local function fProtect(fAction)
		return function()
			local bOK, sError = pcall(fAction);
			if (not bOK and not bClosed) then tContext.onProgress("failed", tostring(sError)); tContext.logParent = nil; end
		end;
	end

	--[[!
	@fqxn CFS.Windows.ManualExport.Private.Functions.fButton
	@desc Creates one native export action outside the browser preview.
	@vis private
	!]]
	local function fButton(dPanel, oRow, sLabel, fAction)
		local oButton = wx.wxButton(dPanel, wx.wxID_ANY, sLabel);
		oRow:Add(oButton, 0, wx.wxRIGHT, 8);
		oButton:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, fProtect(fAction));
		tActions[#tActions + 1] = oButton;
		return oButton;
	end
	local oWebActions	= wx.wxBoxSizer(wx.wxHORIZONTAL);
	local oPDFActionRow	= wx.wxBoxSizer(wx.wxHORIZONTAL);
	local oJobTimer = wx.wxTimer(dFrame, wx.wxNewId());
	local hJob;
	local function fResumeJob()
		if (bConfirmingClose) then oJobTimer:StartOnce(10); return; end
		local bOK, sError = coroutine.resume(hJob);
		if (coroutine.status(hJob) == "dead") then hJob = nil;
		else oJobTimer:StartOnce(1); end
		assert(bOK, sError);
	end
	dFrame:Connect(oJobTimer:GetId(), wx.wxEVT_TIMER, fProtect(fResumeJob));
	local function fStartExport(sKind, bPreview)
		if (hJob or bBusy) then return; end
		local nDeadline;
		local function fPause()
			if (not nDeadline or os.clock() >= nDeadline) then
				coroutine.yield();
				nDeadline = os.clock() + 0.025;
			end
		end
		hJob = coroutine.create(function() fRun(sKind, bPreview, fPause); end);
		fResumeJob();
	end
	tControls.exportWeb = fButton(dWeb, oWebActions, "Export Web", function() fStartExport("web", false); end);
	tControls.viewWeb = fButton(dWeb, oWebActions, "View Export", function() fView("web"); end);
	tControls.refreshPreview = fButton(dPDF, oPDFActionRow, "Refresh Preview", function() fStartExport("pdf", true); end);
	tControls.exportPDF = fButton(dPDF, oPDFActionRow, "Export PDF", function() fStartExport("pdf", false); end);
	tControls.viewPDF = fButton(dPDF, oPDFActionRow, "View Export", function() fView("pdf"); end);
	oWeb:Add(oWebActions, 0, wx.wxALL, 16); oPDF:Add(oPDFActionRow, 0, wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 12);
	dWeb:SetSizer(oWeb); dPDF:SetSizer(oPDF);
	oBook:AddPage(dWeb, "Web"); oBook:AddPage(dPDF, "PDF");
	oLayout:Add(oBook, 1, wx.wxEXPAND + wx.wxALL, 10);
	oProgress = wx.wxGauge(dFrame, wx.wxID_ANY, 100);
    oLayout:Add(oProgress, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT, 12); oProgress:Hide();
    oPageProgress = wx.wxGauge(dFrame, wx.wxID_ANY, 1);
    oLayout:Add(oPageProgress, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxTOP, 6);
    oPageProgress:Hide();
    tControls.pageProgress = oPageProgress;
	oStatus = wx.wxStaticText(dFrame, wx.wxID_ANY, "Ready. Exports use saved files on disk.");
	oLayout:Add(oStatus, 0, wx.wxEXPAND + wx.wxALL, 12);
	oHistory = wx.wxTextCtrl(dFrame, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxSize(-1, 110), wx.wxTE_MULTILINE + wx.wxTE_READONLY + wx.wxTE_DONTWRAP);
	oLayout:Add(oHistory, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 12);
	tControls.history, tControls.progress, tControls.status = oHistory, oProgress, oStatus;
	-- Stage boundaries are estimates; only a reported stage may advance the bar.
    local tStageProgress = {preparing = 0, fonts = 5, building = 20, assets = 70, paginating = 20, rendering = 70, writing = 95, publishing = 99, done = 100};
	local function fReport(sStage, sMessage, nPage)
		if (bClosed) then return; end
		local nElapsed = nStarted and os.time() - nStarted or 0;
		if (tStageStarts and tStageStarts[sStage] == nil and tStageProgress[sStage]) then tStageStarts[sStage] = nElapsed; end
		local nNext = (tRunProgress or tStageProgress)[sStage];
		if (nNext and nNext > nProgressValue) then nProgressValue = nNext; oProgress:SetValue(nNext); end
        if ((sStage == "rendering" or sStage == "writing") and nPage) then
            local nTotal = tonumber(sMessage:match("of (%d+)$"));

            if (nTotal) then
                oPageProgress:SetRange(nTotal); oPageProgress:SetValue(nPage);
                if (not oPageProgress:IsShown()) then oPageProgress:Show(); dFrame:Layout(); end
            end
        end
        sStageMessage = sMessage;
		oStatus:SetLabel(sMessage.." ("..nElapsed.."s elapsed)");
        local sLevel = sStage == "failed" and (tContext.cancelled and "WARNING" or "ERROR") or (sStage == "cancelling" or sStage == "warning") and "WARNING" or "NOTE";
        oHistory:AppendText("["..sLevel.." / "..nElapsed.."s] "..sMessage.."\n");
        if (CFS and CFS.Log) then
            local fLog = sLevel == "ERROR" and CFS.Log.Error or sLevel == "WARNING" and CFS.Log.Warning or CFS.Log.Note;
            local bLogged, sError = pcall(fLog, "Manual export: "..sMessage, tContext.logParent);

            if (not bLogged) then oHistory:AppendText("[ERROR] Could not write application log: "..tostring(sError).."\n"); end
            if (tContext.logParent and (sStage == "done" or sStage == "failed")) then
                local sStatus = sStage == "done" and "Completed" or tContext.cancelled and "Cancelled" or "Failed";
                local sSummary = tContext.logTitle..": "..sStatus.." ("..nElapsed.."s elapsed)";
                if (tContext.logParent.message ~= sSummary) then
                    local bUpdated, vEntry = pcall(CFS.Log.Update, tContext.logParent, sSummary, sLevel);
                    if (bUpdated) then tContext.logParent = vEntry;
                    else oHistory:AppendText("[ERROR] Could not update export log status: "..tostring(vEntry).."\n"); end
                end
            end
        end
	end
	tContext.onProgress = fReport;
	local oBottom = wx.wxBoxSizer(wx.wxHORIZONTAL);
	tControls.options = fButton(dFrame, oBottom, "Options", function() tOptions.onOpenOptions(); end);
	oBottom:AddStretchSpacer();
	local oClose = wx.wxButton(dFrame, wx.wxID_CLOSE, "Close");
	oBottom:Add(oClose, 0); oLayout:Add(oBottom, 0, wx.wxEXPAND + wx.wxLEFT + wx.wxRIGHT + wx.wxBOTTOM, 12);
	dFrame:SetSizer(oLayout);
	oState = WindowState.bind(dFrame, "ManualExport");

	--[[!
	@fqxn CFS.Windows.ManualExport.Private.Functions.fDisplay
	@desc Populates native settings without marking programmatic changes as drafts.
	@vis private
	!]]
	fDisplay = function()
		bDisplaying = true;
		local nSelection = 0;
		for nIndex, tProfile in ipairs(tProfiles) do if (tSettings.pdf.preset == tProfile.id) then nSelection = nIndex; end end
		oPreset:SetSelection(nSelection);
		for _, tField in ipairs(tFields) do tControls[tField[1]]:ChangeValue(tostring(tSettings.pdf[tField[1]])); end
		local tProfile = tProfiles[nSelection];
		oNotes:SetLabel(tProfile and (tProfile.minPages.."–"..tProfile.maxPages.." pages, in multiples of "..tProfile.pageMultiple..". Upload: "..tProfile.uploadPixels.." pixels. "..tProfile.notes) or "Custom dimensions. Margins are measured inward from trim edges and mirror on even pages. Bleed is added outside each edge. DPI is retained for future raster output.");
		oNotes:Wrap(285); dSettings:FitInside();
		bDisplaying = false;
	end;

	--[[!
	@fqxn CFS.Windows.ManualExport.Private.Functions.fSave
	@desc Captures and validates fields before conflict-aware autosave. Invalid drafts remain visible and protected on close.
	@vis private
	!]]
	fSave = function()
		oSaveTimer:Stop();
		if (not bDirty) then return; end
		local tDraft = assert(JSON.decode(JSON.encode(tSettings)));
		for _, tField in ipairs(tFields) do tDraft.pdf[tField[1]] = tonumber(tControls[tField[1]]:GetValue()); end
		local tProfile = tProfiles[oPreset:GetSelection()];
		tDraft.pdf.preset = tProfile and tProfile.id or "custom";
		Export.validate(tDraft);
		sOriginal = Export.save(tContext, tDraft, sOriginal);
		tSettings, bDirty = tDraft, false;
		oSettingsStatus:SetLabel("Saved");
	end;

	--[[!
	@fqxn CFS.Windows.ManualExport.Private.Functions.fChanged
	@desc Coalesces native field edits and invalidates the displayed preview.
	@vis private
	!]]
	local function fChanged()
		if (bDisplaying or bClosed) then return; end
		bDirty, bPreviewReady = true, false;
		nSettingsRevision = nSettingsRevision + 1;
		oSettingsStatus:SetLabel("Unsaved changes"); oSaveTimer:StartOnce(350);
		if (tPreview) then oStatus:SetLabel("Settings changed. Refresh the PDF preview before relying on it."); end
	end
	for _, tField in ipairs(tFields) do tControls[tField[1]]:Connect(wx.wxEVT_COMMAND_TEXT_UPDATED, fChanged); end
	oPreset:Connect(wx.wxEVT_COMMAND_CHOICE_SELECTED, function()
		local tProfile = tProfiles[oPreset:GetSelection()];
		if (tProfile) then
			for sKey, vValue in pairs(tProfile.values) do tSettings.pdf[sKey] = vValue; end
			tSettings.pdf.preset = tProfile.id; fDisplay();
		else
			oNotes:SetLabel("Custom dimensions. Margins are measured inward from trim edges and mirror on even pages. Bleed is added outside each edge. DPI is retained for future raster output.");
			oNotes:Wrap(285); dSettings:FitInside();
		end
		fChanged();
	end);
	dFrame:Connect(oSaveTimer:GetId(), wx.wxEVT_TIMER, function()
		local bSaved, sError = pcall(fSave);
		if (not bSaved) then oSettingsStatus:SetLabel("Not saved: "..tostring(sError)); oSettingsStatus:Wrap(285); dSettings:FitInside(); end
	end);

	--[[!
	@fqxn CFS.Windows.ManualExport.Private.Functions.fEnable
	@desc Prevents overlapping jobs while keeping preview and native events responsive.
	@vis private
	!]]
	fEnable = function()
		for _, oButton in ipairs(tActions) do oButton:Enable(not bBusy); end
		for _, tField in ipairs(tFields) do tControls[tField[1]]:Enable(not bBusy); end
		oPreset:Enable(not bBusy);
		tControls.viewWeb:Enable(not bBusy and wx.wxFileExists(tContext.exportRoot.."/Manual/Web/index.html"));
		tControls.viewPDF:Enable(not bBusy and wx.wxFileExists(tContext.exportRoot.."/Manual/PDF/Manual.pdf"));
	end;

	--[[!
	@fqxn CFS.Windows.ManualExport.Private.Functions.fRun
	@desc Runs disk-based generation from native actions. The busy guard covers event yielding during PDF printing; close/shutdown cancels only this job.
	@vis private
	!]]
	fRun = function(sKind, bPreview, fPause)
		if (bBusy) then return; end
		assert(not tOptions.hasDrafts or not tOptions.hasDrafts(), "Save manual-editor changes before exporting or refreshing the preview.");
		fSave();
        tContext.logParent = nil;
        tContext.logTitle = "Manual "..(bPreview and "preview" or "export").." ("..sKind:upper()..")";
        if (CFS and CFS.Log) then
            local bLogged, vEntry = pcall(CFS.Log.Note, tContext.logTitle..": Started");
            if (bLogged) then tContext.logParent = vEntry; end
        end
		bBusy, tContext.cancelled = true, false;
		nStarted, nProgressValue = os.time(), 0;
		tStageStarts, tRunProgress = {}, {};
		for sStage, nValue in pairs(tStageProgress) do
			tRunProgress[sStage] = tStageHistory and tStageHistory[sStage] or nValue;
		end
		oHistory:Clear(); oProgress:SetValue(0); oPageProgress:SetValue(0); oPageProgress:Hide();
		fEnable(); oProgress:Show(); dFrame:Layout(); oProgressTimer:Start(1000);
		fReport("preparing", bPreview and "Preparing PDF preview from saved files." or "Reading saved manual files for "..sKind:upper().." export.");
		local bOK, vResult = pcall(Export.run, tContext, sKind, tSettings, bPreview, fPause);
		bBusy = false;
		if (bClosed) then tContext.logParent = nil; return; end
		oProgressTimer:Stop(); fEnable(); dFrame:Layout();
		if (bOK) then
            if (sKind == "pdf") then
                if (tPreview) then Export.discard(tContext, tPreview); end
                tPreview = vResult;
                bPreviewReady = not bDirty;
                nPreviewRevision = nSettingsRevision;
                fPreviewPage(1);
            end
            fReport("done", vResult.message);
				if (sKind == "pdf" and os.time() > nStarted) then
					tStageHistory = {};
					for sStage, nElapsed in pairs(tStageStarts) do
						tStageHistory[sStage] = sStage == "done" and 100 or math.min(99, math.floor(nElapsed / (os.time() - nStarted) * 100));
					end
                end
        else fReport("failed", (tContext.cancelled and "Export cancelled: " or "Export failed: ")..tostring(vResult)); end
		if (bClosePending) then dFrame:Close(); if (bShutdown) then dParent:Close(); end end
		if (not bOK and not tContext.cancelled) then error(vResult, 0); end
        tContext.logParent = nil;
		return vResult;
	end;
	dFrame:Connect(oProgressTimer:GetId(), wx.wxEVT_TIMER, function()
		if (bBusy and not bClosed and sStageMessage) then
			oStatus:SetLabel(sStageMessage.." ("..(os.time() - nStarted).."s elapsed)");
		end
	end);
	oClose:Connect(wx.wxEVT_COMMAND_BUTTON_CLICKED, function() dFrame:Close(); end);
	dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, function(oEvent)
		if (bBusy and oEvent:CanVeto()) then
			if (bClosePending or bConfirmingClose) then oEvent:Veto(); return; end
			bConfirmingClose = true;
			local nAnswer = wx.wxMessageBox("Cancel the current manual export and close this window? The previous published output will be preserved.", "Manual Export", wx.wxYES_NO + wx.wxNO_DEFAULT + wx.wxICON_WARNING, dFrame);
			bConfirmingClose = false;
			if (nAnswer ~= wx.wxYES) then oEvent:Veto(); return; end
			bClosePending, tContext.cancelled = true, true;
			fReport("cancelling", "Cancelling the Lua export. Previous output is preserved.");
			oEvent:Veto(); return;
		end
		if (bDirty and oEvent:CanVeto() and wx.wxMessageBox("Discard unsaved export settings?", "Manual Export", wx.wxYES_NO + wx.wxNO_DEFAULT + wx.wxICON_WARNING, dFrame) ~= wx.wxYES) then oEvent:Veto(); return; end
		if (not bClosed) then
			bClosed, tContext.cancelled = true, true;
            oSaveTimer:Stop(); oProgressTimer:Stop(); oJobTimer:Stop();
            if (tPreview) then
                local bRemoved, sError = pcall(Export.discard, tContext, tPreview);

                if (not bRemoved and CFS and CFS.Log) then pcall(CFS.Log.Error, tostring(sError)); end
                tPreview = nil;
            end
			oState.close(); if (tOptions.onClose) then tOptions.onClose(); end
		end
		oEvent:Skip();
	end);

	--[[!
	@fqxn CFS.Windows.ManualExport.Window.show
	@desc Raises the shared window, optionally selecting Web or PDF.
	@param string|nil sKind Optional initial tab.
	@return boolean bShown Whether the window remains open.
	!]]
	function tWindow.show(sKind)
		if (bClosed) then return false; end
		if (sKind) then oBook:SetSelection(sKind == "pdf" and 1 or 0); end
		dFrame:Show(true); dFrame:Raise(); return true;
	end

	--[[!
	@fqxn CFS.Windows.ManualExport.Window.close
	@desc Honors pending settings and job cancellation before closing or switching games.
	@param boolean|nil bForShutdown Whether to retry Studio shutdown after cancellation.
	@return boolean bClosed Whether close was accepted.
	!]]
	function tWindow.close(bForShutdown)
		local bAccepted;
		if (bClosed) then return true; end
		bShutdown = bForShutdown == true;
		bAccepted = dFrame:Close();
		if (not bAccepted and not bClosePending) then bShutdown = false; end
		return bAccepted;
	end
	tWindow.frame, tWindow.preview, tWindow.book, tWindow.controls = dFrame, oCanvas, oBook, tControls;
	tWindow.run, tWindow.save, tWindow.context = fRun, fSave, tContext;
	fDisplay(); fEnable(); fPreviewPage(1);
	return tWindow;
end

return ManualExport;
