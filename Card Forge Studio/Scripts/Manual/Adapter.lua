--[[!
@fqxn CFS.Manual.Adapter
@desc Hosts the original admin HTML/CSS/JavaScript in Studio's Edge WebView. Lua supplies active-game snapshots and whitelisted filesystem services. No PHP process or native imitation of the editor controls is used.
!]]

local wx = require("wx");
local JSON = require("Manual.Lib.dkjson");
local Services = require("Manual.Services");
local Bridge = require("Manual.Bridge");
local WindowState = require("Windows.WindowState");
local Adapter = {};
local _pWeb = _Scripts.."/Manual/Web";

WindowState.register("ManualEditor", {savePosition = true, saveSize = true, saveVisible = false});

--[[!
@fqxn CFS.Manual.Adapter.Private.Functions.fileURL
@desc Converts an owned filesystem path to a browser file URL using wxWidgets.
@param string pFile Native path.
@return string sURL File URL.
@vis private
!]]
local function fileURL(pFile)
	local oFile = wx.wxFileName(pFile);
	local sURL = wx.wxFileSystem.FileNameToURL(oFile);
	oFile:delete();
	return sURL;
end

--[[!
@fqxn CFS.Manual.Adapter.Functions.create
@desc Creates one game-bound web editor using the existing Studio menu contract. Keeps window state through WindowState; protects unsaved drafts on native close. Runtime HTML is temporary and removed on close. Shared web assets remain application-owned; all source files remain game-owned.
@param wxFrame dParent Studio owner.
@param string pManual Active game's Manual directory.
@param table tOptions gameName, gameRoot, exports and optional onClose callback.
@return table tWindow Frame, browser, bound paths and show/close operations.
!]]
function Adapter.create(dParent, pManual, tOptions)
	local WebView = assert(wxwebview, "Manual Editor requires the wxLua WebView binding.");
	local tContext = {gameName = tOptions.gameName, gameRoot = tOptions.gameRoot, manualRoot = pManual, exportRoot = tOptions.exports, manualURL = fileURL(pManual)};
	local tService = Services.create(tContext);
	local tBridge = Bridge.create(tService);
	local tWindow = {};
	local dFrame;
	local oBrowser;
	local oLayout;
	local oState;
	local oDispatchTimer;
	local oTemporary;
	local pPage;
	local pTemporary;
	local sPageURL;
	local sSelected = "intro.md";
	local nPageRevision = 0;
	local bClosed = false;
	local bDispatching = false;
	local bClosePending = false;
	local bShutdownPending = false;
	local tPending = {};
	local bOK;
	local sError;
	local fBuild;
	local fNavigate;
	local fDispatch;
	local fClose;
	local sReply = "";
	local nOptionsRevision = 0;
	local sOptionsScript = "";
	local function publishReply()
		local hReply = assert(io.open(pPage..".reply.tmp", "wb"));
		assert(hReply:write(sReply..sOptionsScript)); assert(hReply:close());
		assert(wx.wxRenameFile(pPage..".reply.tmp", pPage..".reply.js", true), "Cannot publish the editor reply.");
	end
	assert(wx.wxDirExists(pManual) and wx.wxDirExists(tOptions.exports), "Manual Editor game paths are unavailable.");

	--[[!
	@fqxn CFS.Manual.Adapter.Private.Functions.fBuild
	@desc Rebuilds only the owned runtime page from the unchanged admin template and current Lua snapshot. JSON escapes less-than characters so game text cannot close its bootstrap script element.
	@vis private
	!]]
	fBuild = function()
		local tSnapshot = tService.snapshot();
		local tTokens = {};
		local sTemplate;
		local hTemplate = assert(io.open(_pWeb.."/Editor.html", "rb"));
		local hPage;
		sTemplate = assert(hTemplate:read("a"));
		assert(hTemplate:close());
		tSnapshot.selected = sSelected;
		tSnapshot.context.bridgeReplyURL = fileURL(pPage..".reply.js");
		nPageRevision = nPageRevision + 1;
		tTokens.ASSET_BASE = fileURL(_pWeb.."/Editor.html");
		tTokens.ASSET_REVISION = pPage:match("[^/\\]+$"):gsub("[^A-Za-z0-9]", "").."-"..nPageRevision;
		tTokens.BOOTSTRAP = JSON.encode(tSnapshot):gsub("<", "\\u003c");
		for _, sKey in ipairs({"FILE", "VERSION", "CONTENT", "STYLE_TAGS", "FILE_OPTIONS", "ORDER_ROWS", "STYLE_OPTIONS", "GAME_CSS"}) do tTokens[sKey] = ""; end
		for _, sKey in ipairs({"ORDER_STATE", "GLOSSARY_STATE"}) do tTokens[sKey] = "{}"; end
		sTemplate = sTemplate:gsub("{{([A-Z_]+)}}", function(sKey) return assert(tTokens[sKey], "Unknown manual template token: "..sKey); end);
		hPage = assert(io.open(pPage, "wb"));
		assert(hPage:write(sTemplate));
		assert(hPage:close());
	end;

	dFrame = wx.wxFrame(dParent, wx.wxID_ANY, "Manual Editor - "..tOptions.gameName, wx.wxDefaultPosition, wx.wxSize(1400, 900));
	dFrame:SetMinSize(wx.wxSize(800, 560));
	bOK, oBrowser = pcall(WebView.wxWebView.New, dFrame, wx.wxID_ANY, "about:blank", wx.wxDefaultPosition, wx.wxDefaultSize, "wxWebViewEdge");
	if (not bOK or not oBrowser) then dFrame:Destroy(); error("Cannot create the Manual Editor Edge WebView: "..tostring(oBrowser), 2); end
	oTemporary = wx.wxFile();
	pTemporary = wx.wxFileName.CreateTempFileName(wx.wxFileName.GetTempDir().."/cfs-manual-", oTemporary);
	if (oTemporary:IsOpened()) then oTemporary:Close(); end
	oTemporary:delete();
	assert(pTemporary ~= "", "Cannot create the Manual Editor runtime page.");
	pPage = pTemporary..".html";
	if (not wx.wxRenameFile(pTemporary, pPage, false)) then wx.wxRemoveFile(pTemporary); dFrame:Destroy(); error("Cannot create the Manual Editor HTML file.", 2); end
	sPageURL = fileURL(pPage);
	bOK, sError = pcall(fBuild);
	if (not bOK) then wx.wxRemoveFile(pPage); dFrame:Destroy(); error(sError, 2); end
	oDispatchTimer = wx.wxTimer(dFrame, wx.wxNewId());

	--[[!
	@fqxn CFS.Manual.Adapter.Private.Functions.fDispatch
	@desc Processes queued browser requests on a native timer after the Edge event callback has returned. Edge forbids synchronous RunScript inside its callbacks. Replies are published to an owned script file instead of blocking on RunScript; the busy guard prevents nested export dispatch; native close waits until an in-flight dispatch completes.
	@vis private
	!]]
	fDispatch = function()
		local tRequest;
		local bProcessed;
		local sFailure;
		local fExecute;
		if (bClosed or bDispatching or #tPending == 0) then return; end
		tRequest = table.remove(tPending, 1);
		bDispatching = true;

		--[[!
		@fqxn CFS.Manual.Adapter.Private.Functions.fExecute
		@desc Handles one queued chapter navigation or bridge request outside the browser's event stack.
		@vis private
		!]]
		fExecute = function()
			local sScript;
			if (tRequest.export) then
				tOptions.onOpenExport();
			elseif (tRequest.appearance) then
                tOptions.onOpenOptions();
			elseif (tRequest.file) then
				sSelected = tRequest.file;
				fBuild();
				oBrowser:LoadURL(sPageURL);
			else
				sScript = tBridge.handle(tRequest.url);
				if (sScript and not bClosePending) then
					-- Publish outside browser callbacks. The page reads replies
					-- asynchronously; no native RunScript wait can hold dispatch.
					sReply = sScript;
					publishReply();
				end
			end
		end;
		bProcessed, sFailure = pcall(fExecute);
		if (not bProcessed and not bClosed) then wx.wxMessageBox(tostring(sFailure), "Manual Editor", wx.wxOK + wx.wxICON_ERROR, dFrame); end
		bDispatching = false;
		if (bClosePending and not bClosed) then
			dFrame:Close();
			if (bShutdownPending) then dParent:Close(); end
			return;
		end
		if (not bClosed and #tPending > 0) then oDispatchTimer:StartOnce(1); end
	end;
	dFrame:Connect(oDispatchTimer:GetId(), wx.wxEVT_TIMER, fDispatch);

	--[[!
	@fqxn CFS.Manual.Adapter.Private.Functions.fNavigate
	@desc Intercepts and queues bridge/chapter-open requests without running JavaScript or issuing another LoadURL inside the Edge callback. Only the owned runtime page may remain in the privileged editor view. Refresh rebuilds its snapshot before navigation proceeds.
	@param wxWebViewEvent oEvent Native navigation event.
	@vis private
	!]]
	fNavigate = function(oEvent)
		local sURL = oEvent:GetURL();
		local sBase = sURL:match("^[^?#]*");
		local sOpen = sURL:match("^cfsmanual://open%?file=([^&#]+)");
		local bLoaded;
		local sFailure;
		if (sURL == "about:blank" or sURL == "about:srcdoc") then oEvent:Skip(); return; end
		if (sBase == sPageURL) then
			bLoaded, sFailure = pcall(fBuild);
			if (not bLoaded) then oEvent:Veto(); wx.wxMessageBox(tostring(sFailure), "Manual Editor", wx.wxOK + wx.wxICON_ERROR, dFrame); return; end
			oEvent:Skip(); return;
		end
		oEvent:Veto();
		if (sURL == "cfsmanual://export") then
			tPending[#tPending + 1] = {export = true};
		elseif (sURL == "cfsmanual://appearance") then
            tPending[#tPending + 1] = {appearance = true};
		elseif (sOpen) then
			tPending[#tPending + 1] = {file = sOpen:gsub("%%(%x%x)", function(sHex) return string.char(tonumber(sHex, 16)); end)};
		elseif (sURL:match("^cfsmanual://bridge/")) then
			tPending[#tPending + 1] = {url = sURL};
		end
		if (not bDispatching and #tPending > 0) then oDispatchTimer:StartOnce(1); end
	end;
	oBrowser:Connect(WebView.wxEVT_WEBVIEW_NAVIGATING, fNavigate);
	--[[!
	@fqxn CFS.Manual.Adapter.Private.Functions.manualBridgeTitleChanged
	@desc Receives bounded request chunks through a document-title event from the owned page. Title changes never navigate or unload the document. Dispatch remains on the guarded timer, outside all WebView callbacks.
	@param wxWebViewEvent oEvent Title and current document URL.
	@vis private
	!]]
	oBrowser:Connect(WebView.wxEVT_WEBVIEW_TITLE_CHANGED, function(oEvent)
		local sMessage = oEvent:GetString();
		if (bClosed or oEvent:GetURL():match("^[^?#]*") ~= sPageURL or not sMessage:match("^cfsmanual://bridge/")) then return; end
		tPending[#tPending + 1] = {url = sMessage};
		if (not bDispatching) then oDispatchTimer:StartOnce(1); end
	end);
	oLayout = wx.wxBoxSizer(wx.wxVERTICAL);
	oLayout:Add(oBrowser, 1, wx.wxEXPAND);
	dFrame:SetSizer(oLayout);
	oState = WindowState.bind(dFrame, "ManualEditor");

	--[[!
	@fqxn CFS.Manual.Adapter.Private.Functions.fClose
	@desc Confirms discarding reported drafts and immediately hides a closing editor without disabling Studio. If a request is running, defers browser destruction until dispatch returns; otherwise clears transport buffers, removes owned temporary HTML and releases shared window state exactly once.
	@param wxCloseEvent oEvent Native close event.
	@vis private
	!]]
	fClose = function(oEvent)
		if (not bClosePending and bDispatching and oEvent:CanVeto() and wx.wxMessageBox("An export or another editor operation is still running. Close this window? The operation will continue in the background unless Studio is shutting down.", "Manual Editor", wx.wxYES_NO + wx.wxNO_DEFAULT + wx.wxICON_WARNING, dFrame) ~= wx.wxYES) then oEvent:Veto(); return; end
		if (not bClosePending and oEvent:CanVeto() and tService.dirty and wx.wxMessageBox("Discard unsaved manual-editor changes?", "Manual Editor", wx.wxYES_NO + wx.wxNO_DEFAULT + wx.wxICON_WARNING, dFrame) ~= wx.wxYES) then oEvent:Veto(); return; end
		if (bDispatching and oEvent:CanVeto()) then
			bClosePending = true;
			if (bShutdownPending) then tContext.cancelled = true; end
			dFrame:Hide();
			oEvent:Veto();
			return;
		end
		if (not bClosed) then
			bClosed = true;
			oDispatchTimer:Stop(); tPending = {};
			oBrowser:Stop(); tBridge.close(); wx.wxRemoveFile(pPage); wx.wxRemoveFile(pPage..".reply.js"); wx.wxRemoveFile(pPage..".reply.tmp"); oState.close();
			if (tOptions.onClose) then tOptions.onClose(); end
		end
		oEvent:Skip();
	end;
	dFrame:Connect(wx.wxEVT_CLOSE_WINDOW, fClose);
	tWindow.frame, tWindow.browser, tWindow.manualRoot, tWindow.exportRoot = dFrame, oBrowser, pManual, tOptions.exports;

	--[[!
	@fqxn CFS.Manual.Adapter.Window.applyOptions
	@desc Publishes saved display preferences to the current page without navigation.
	!]]
	function tWindow.applyOptions()
		if (bClosed) then return; end
		nOptionsRevision = nOptionsRevision + 1;
		local tSettings = {revision = nOptionsRevision,
			lineNumbers = INIFile.GetValue(FS.AppCFG, "ManualEditor", "LineNumbers") == "1",
            appearanceCSS = require("Manual.Appearance").css(pManual, ".manual-appearance", fileURL(pManual):gsub("/$", "").."/Images/")};
		sOptionsScript = "\ndocument.dispatchEvent(new CustomEvent('manual-editor-options', {detail:"..JSON.encode(tSettings).."}));";
		publishReply();
	end

	--[[!
	@fqxn CFS.Manual.Adapter.Window.show
	@desc Shows and raises this modeless game-bound editor without disabling other Studio windows. Preserves the existing nonblocking menu and shared WindowState contracts.
	@return boolean bShown Whether it remains open.
	!]]
	function tWindow.show()
		if (bClosed) then return false; end
		dFrame:Show(true);
		dFrame:Raise(); return true;
	end

	--[[!
	@fqxn CFS.Manual.Adapter.Window.close
	@desc Requests native close, preserving the shared menu's veto contract for unsaved drafts.
	@param boolean bShutdown Whether Studio shutdown should cancel a pending export and retry parent close after dispatch returns.
	@return boolean bClosed Native close result.
	!]]
	function tWindow.close(bShutdown)
		local bAccepted;
		if (bClosed) then return true; end
		bShutdownPending = bShutdown == true;
		bAccepted = dFrame:Close();
		if (not bAccepted and not bClosePending) then bShutdownPending = false; end
		return bAccepted;
	end

	--[[!
	@fqxn CFS.Manual.Adapter.Window.hasDrafts
	@desc Reads the editor's existing reported draft state for native export protection.
	@return boolean bDirty Whether authoring/settings drafts remain unsaved.
	!]]
	function tWindow.hasDrafts()
		return tService.dirty == true;
	end
	oBrowser:LoadURL(sPageURL);
	tWindow.show();
	return tWindow;
end

return Adapter;
