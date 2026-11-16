--[[!
@fqxn CFS.Manual.Exporter
@desc Exports the shared manual renderer's HTML and game-owned assets. Each output is built in a unique sibling staging folder before replacing only Web or PDF under the bound game's Exports/Manual folder. PDF uses an installed Chromium-family browser in headless mode, without PHP or an installed-font collection.
!]]

local wx		= require("wx");
local Documents	= require("Manual.Documents");
local JSON		= require("Manual.Lib.dkjson");
local Exporter	= {};

--[[!
@fqxn CFS.Manual.Exporter.Private.Functions.fAbsolute
@desc Normalizes a native path without changing the current working directory.
@param string pPath Native path.
@return string pAbsolute Absolute path with forward separators.
@vis private
!]]
local function fAbsolute(pPath)
	local oPath	= wx.wxFileName(pPath);
	local sPath;
	assert(oPath:Normalize(wx.wxPATH_NORM_DOTS + wx.wxPATH_NORM_ABSOLUTE), "Cannot normalize the export path.");
	sPath = oPath:GetFullPath():gsub("\\", "/"):gsub("/+$", "");
	oPath:delete();
	return sPath;
end

--[[!
@fqxn CFS.Manual.Exporter.Private.Functions.fWrite
@desc Writes a newly staged file and verifies its handle is closed.
@param string pFile Owned staging filename.
@param string sText Complete bytes.
@vis private
!]]
local function fWrite(pFile, sText)
	local hFile = assert(io.open(pFile, "wb"));
	assert(hFile:write(sText));
	assert(hFile:close());
end

--[[!
@fqxn CFS.Manual.Exporter.Private.Functions.fCopy
@desc Copies an asset tree using native wxWidgets APIs. Directory enumeration does not follow links; symbolic-link entries are refused rather than traversed.
@param string pSource Existing asset folder.
@param string pTarget Owned new staging folder.
@vis private
!]]
local function fCopy(pSource, pTarget)
	local oDir;
	local bFound;
	local sName;
	local pFrom;
	assert(wx.wxDirExists(pSource), "Missing export asset folder: "..pSource);
	assert(wx.wxFileName.Mkdir(pTarget, 511, wx.wxPATH_MKDIR_FULL), "Cannot create staged asset folder.");
	oDir = wx.wxDir(pSource);
	assert(oDir:IsOpened(), "Cannot read export assets.");
	bFound, sName = oDir:GetFirst("", wx.wxDIR_FILES + wx.wxDIR_DIRS + wx.wxDIR_HIDDEN + wx.wxDIR_NO_FOLLOW);
	while (bFound) do
		pFrom = pSource.."/"..sName;
		-- wxFILE_EXISTS_SYMLINK is absent from this Lua binding; the documented
		-- wxWidgets value includes NO_FOLLOW and is used only for this test.
		assert(not wx.wxFileName.Exists(pFrom, 0x1004), "Linked export assets are not supported: "..pFrom);
		if (wx.wxDirExists(pFrom)) then fCopy(pFrom, pTarget.."/"..sName);
		else assert(wx.wxCopyFile(pFrom, pTarget.."/"..sName, false), "Cannot copy an export asset."); end
		bFound, sName = oDir:GetNext();
	end
	oDir:delete();
end

--[[!
@fqxn CFS.Manual.Exporter.Private.Functions.fRemove
@desc Deletes only an explicitly selected child of the normalized Exports/Manual root. Uses native recursive removal, never a shell or a browser-supplied path.
@param string pRoot Bound export root.
@param string pFolder Owned child folder.
@vis private
!]]
local function fRemove(pRoot, pFolder)
	local pChecked = fAbsolute(pFolder);
	pRoot = fAbsolute(pRoot);
	assert(pChecked:sub(1, #pRoot + 1) == pRoot.."/" and not pChecked:sub(#pRoot + 2):find("/", 1, true), "Refusing cleanup outside the manual export folder.");
	if (wx.wxDirExists(pChecked)) then
		-- wxPATH_RMDIR_RECURSIVE (0x0002) is not exported by this Lua binding.
		assert(wx.wxFileName.Rmdir(pChecked, 0x0002), "Cannot clean the owned export folder: "..pChecked);
	end
end

--[[!
@fqxn CFS.Manual.Exporter.Private.Functions.fBrowser
@desc Finds an installed headless-capable browser. An explicit executable override may be provided through CFS_MANUAL_PDF_BROWSER; no browser or font is downloaded or installed.
@return string pBrowser Existing executable.
@vis private
!]]
local function fBrowser()
	local tPaths	= {};
	local pOverride	= os.getenv("CFS_MANUAL_PDF_BROWSER");
	if (pOverride and pOverride ~= "") then assert(wx.wxFileExists(pOverride), "CFS_MANUAL_PDF_BROWSER does not name an existing executable."); return pOverride; end
	for _, sVariable in ipairs({"PROGRAMFILES", "PROGRAMFILES(X86)", "LOCALAPPDATA"}) do
		local pBase = os.getenv(sVariable);
		if (pBase) then
			tPaths[#tPaths + 1] = pBase.."/Microsoft/Edge/Application/msedge.exe";
			tPaths[#tPaths + 1] = pBase.."/Google/Chrome/Application/chrome.exe";
		end
	end
	for _, pPath in ipairs({"/usr/bin/chromium", "/usr/bin/chromium-browser", "/usr/bin/google-chrome", "/opt/google/chrome/chrome", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"}) do tPaths[#tPaths + 1] = pPath; end
	for _, pPath in ipairs(tPaths) do if (wx.wxFileExists(pPath)) then return pPath; end end
	error("PDF export needs installed Chrome, Chromium or Edge. Set CFS_MANUAL_PDF_BROWSER if it is installed in another location.", 2);
end

--[[!
@fqxn CFS.Manual.Exporter.Private.Functions.fQuote
@desc Quotes one argument for wxExecute's native command parser, without involving a command shell. Rejects embedded quotes/control characters rather than accepting ambiguous paths.
@param string sValue Native argument.
@return string sQuoted Quoted argument.
@vis private
!]]
local function fQuote(sValue)
	assert(not sValue:find('["%z\1-\31]'), "An export executable or path contains an unsupported quote/control character.");
	return '"'..sValue:gsub("\\", "/")..'"';
end

--[[!
@fqxn CFS.Manual.Exporter.Private.Functions.fPrintBrowser
@desc Starts an isolated headless browser, gives its print page the private loopback connection, and waits for that page to finish pagination, print and deliver the PDF. Uses no fixed print delay. The editor retains ownership of Studio window modality; exporting does not disable its browser. Only the owned browser process can be terminated on timeout.
@param string pBrowser Installed browser executable.
@param string pStage Owned export staging directory.
@param string sURL Staged print document URL.
@param table tContext Bound context carrying shutdown cancellation.
@vis private
!]]
local function fPrintBrowser(pBrowser, pStage, sURL, tContext)
	local pProfile	= pStage.."/browser-profile";
	local pPort		= pProfile.."/DevToolsActivePort";
	local nPID;
	local nStarted	= os.time();
	local bOK;
	local sFailure;
	local sDeliveredPDF;
	--[[!
	@fqxn CFS.Manual.Exporter.Private.Functions.fPrintWait
	@desc Processes pending native events while the guarded export dispatcher is busy, then pauses briefly. The editor browser remains enabled so it can process bridge responses.
	@vis private
	!]]
	local function fPrintWait()
		if (wx.wxGetApp()) then wx.wxYield(); end
		assert(not tContext.cancelled, "PDF export cancelled for Studio shutdown; the previous export was preserved.");
		wx.wxMilliSleep(25);
	end
	--[[!
	@fqxn CFS.Manual.Exporter.Private.Functions.fPrintJob
	@desc Connects only the owned print document to its isolated browser and waits for confirmed file delivery followed by browser shutdown.
	@vis private
	!]]
	local function fPrintJob()
		local sPort;
		local sPath;
		local tConnection;
		local oDirectory;
		local pDirectory;
		local sProblem;
		local bRead;
		local sRead;
		local sCommand = fQuote(pBrowser).." --headless --disable-background-timer-throttling --disable-renderer-backgrounding --disable-backgrounding-occluded-windows --enable-logging --log-level=0 --disable-gpu --no-first-run --no-default-browser-check --remote-debugging-port=0 --remote-allow-origins=file://,null "..fQuote("--log-file="..pStage.."/print-debug.log").." "..fQuote("--user-data-dir="..pProfile).." "..fQuote(sURL);
		nPID = wx.wxExecute(sCommand, wx.wxEXEC_ASYNC);
		assert(nPID > 0, "Cannot start the isolated PDF browser.");
		while (not sPort or not sPath) do
			assert(wx.wxProcess.Exists(nPID) and os.time() - nStarted < 20, "The PDF browser did not open its local print connection.");
			if (wx.wxFileExists(pPort)) then sPort, sPath = Documents.read(pPort):match("^(%d+)\r?\n(/devtools/browser/[A-Za-z0-9-]+)"); end
			if (sPort and sPath) then break; end
			fPrintWait();
		end
		assert(sPort and sPath, "Invalid local PDF connection information.");
		oDirectory = wx.wxFileName(pStage);
		pDirectory = oDirectory:GetFullPath(wx.wxPATH_NATIVE); oDirectory:delete();
		tConnection = {url = "ws://127.0.0.1:"..sPort..sPath, directory = pDirectory};
		fWrite(pStage.."/js/PrintConnection.tmp", "window.CFSPrintConnect("..JSON.encode(tConnection)..");");
		assert(wx.wxRenameFile(pStage.."/js/PrintConnection.tmp", pStage.."/js/PrintConnection.js", false), "Cannot deliver the local print connection.");
		-- Some browser launchers hand the job to a child process. Completion is
		-- the delivered file, not the lifetime of the initial launcher PID.
		while (not sDeliveredPDF and not sProblem) do
			if (os.time() - nStarted >= 180) then
				sRead = wx.wxFileExists(pStage.."/print-debug.log") and Documents.read(pStage.."/print-debug.log") or "";
				sProblem = "browser startup";
				for sStage in sRead:gmatch("CFS_PDF_STAGE: ([^\r\n]+)") do sProblem = sStage; end
				error("PDF timed out during "..sProblem.."; the previous export was preserved.", 2);
			end
			if (wx.wxFileExists(pStage.."/Print-error.txt")) then sProblem = Documents.read(pStage.."/Print-error.txt"); end
			if (wx.wxFileExists(pStage.."/Manual.pdf")) then
				bRead, sRead = pcall(Documents.read, pStage.."/Manual.pdf");
				if (bRead and sRead:sub(1, 5) == "%PDF-" and sRead:sub(-2048):find("%%%%EOF")) then sDeliveredPDF = sRead; end
			end
			if (sDeliveredPDF or sProblem) then break; end
			fPrintWait();
		end
		fWrite(pStage.."/js/PrintDelivered.tmp", "window.CFSPrintDelivered();");
		assert(wx.wxRenameFile(pStage.."/js/PrintDelivered.tmp", pStage.."/js/PrintDelivered.js", false), "Cannot acknowledge PDF delivery.");
		for _ = 1, 80 do if (not wx.wxProcess.Exists(nPID)) then break; end fPrintWait(); end
		if (sProblem) then error(sProblem, 2); end
	end
	bOK, sFailure = pcall(fPrintJob);
	if (not bOK and nPID and wx.wxProcess.Exists(nPID)) then
		-- A headless browser has no closeable window for SIGTERM on Windows.
		-- Force termination only for the PID owned by this export job.
		wx.wxProcess.Kill(nPID, wx.wxSIGKILL, wx.wxKILL_CHILDREN);
		for _ = 1, 40 do if (not wx.wxProcess.Exists(nPID)) then break; end wx.wxMilliSleep(25); end
	end
	assert(bOK, sFailure);
	return sDeliveredPDF;
end

--[[!
@fqxn CFS.Manual.Exporter.Functions.run
@desc Builds one static Web site or paginated PDF from already sanitized shared-renderer HTML. Validates numeric PDF settings, keeps the previous output until generation succeeds, rolls back a failed replacement, and removes only the replaced type's old folder. Does not change source Markdown, font files, plugins or another export type.
@param table tContext Bound game/manual/export paths.
@param string sKind web or pdf.
@param string sHTML Complete portable HTML produced by the editor renderer.
@param table tSettings Persisted game PDF settings.
@return table tResult Output path and message.
!]]
function Exporter.run(tContext, sKind, sHTML, tSettings)
	local pRoot		= fAbsolute(tContext.exportRoot.."/Manual");
	local sType		= sKind == "web" and "Web" or "PDF";
	local pOutput	= pRoot.."/"..sType;
	local pStage;
	local pPrevious;
	local pUnique;
	local oTemporary;
	local pBrowser;
	local sCommand;
	local bOK;
	local sFailure;
	local bPrevious	= false;
	assert(sKind == "web" or sKind == "pdf", "Unknown manual export type.");
	assert(type(sHTML) == "string" and #sHTML > 0 and #sHTML <= 4000000, "Invalid or oversized rendered manual.");
	if (sKind == "pdf") then
		assert(type(tSettings) == "table" and type(tSettings.pdf) == "table" and tSettings.pdf.units == "in", "Invalid saved PDF settings.");
		for _, sKey in ipairs({"width", "height", "bleed", "marginTop", "marginBottom", "marginInside", "marginOutside", "dpi"}) do
			local nValue = tSettings.pdf[sKey];
			assert(type(nValue) == "number" and nValue == nValue and nValue < math.huge and nValue >= 0, "Invalid saved PDF field: "..sKey);
		end
		assert(tSettings.pdf.width > tSettings.pdf.marginInside + tSettings.pdf.marginOutside and tSettings.pdf.height > tSettings.pdf.marginTop + tSettings.pdf.marginBottom and tSettings.pdf.dpi > 0, "PDF settings leave no content area.");
		pBrowser = fBrowser();
	end
	assert(wx.wxFileName.Mkdir(pRoot, 511, wx.wxPATH_MKDIR_FULL), "Cannot create the manual export root.");
	oTemporary = wx.wxFile();
	pUnique = wx.wxFileName.CreateTempFileName(pRoot.."/."..sType.."-", oTemporary);
	if (oTemporary:IsOpened()) then oTemporary:Close(); end
	oTemporary:delete();
	assert(pUnique ~= "" and wx.wxRemoveFile(pUnique), "Cannot reserve an export staging name.");
	pStage, pPrevious = pUnique.."-stage", pUnique.."-previous";
	assert(wx.wxMkdir(pStage), "Cannot create the export staging folder.");

	--[[!
	@fqxn CFS.Manual.Exporter.Private.Functions.fBuild
	@desc Populates one owned staging directory and, for PDF, waits for the isolated headless print process. wxExecute runs outside browser callbacks through Adapter's guarded dispatcher.
	@vis private
	!]]
	local function fBuild()
		local sPDF;
		local sDocument = sHTML;
		local oPage;
		local sURL;
		local nExit;
		--[[!
		@fqxn CFS.Manual.Exporter.Private.Functions.fInlinePrintStyle
		@desc Supplies local stylesheet text to the paginator without file-origin fetch requests. Rewrites the shared css-folder artwork URLs relative to the staged HTML document; Web output remains unchanged.
		@param string sName Owned staged CSS filename.
		@return string sStyle Inline style element.
		@vis private
		!]]
		local function fInlinePrintStyle(sName)
			local sCSS = Documents.read(pStage.."/css/"..sName):gsub("url%((['\"]?)%.%./", "url(%1"):gsub("<", "\\3C ");
			return "<style>"..sCSS.."</style>";
		end
		assert(wx.wxMkdir(pStage.."/css"), "Cannot create export CSS folder.");
		assert(wx.wxMkdir(pStage.."/js"), "Cannot create export script folder.");
		for _, sName in ipairs({"bootstrap.min.css", "intro-preview.css", "glossary.css", "Reader.css", "Components.css", "Print.css"}) do
			if (sKind == "pdf" and sName == "intro-preview.css") then
				-- The Web file retains its browser-print fallback. PDF uses the
				-- same screen components with a dedicated paginated layout.
				fWrite(pStage.."/css/"..sName, (Documents.read(_Scripts.."/Manual/Web/css/"..sName):gsub("@media%s+print%s*(%b{})", "")));
			else assert(wx.wxCopyFile(_Scripts.."/Manual/Web/css/"..sName, pStage.."/css/"..sName, false), "Cannot copy shared manual CSS."); end
		end
		assert(wx.wxCopyFile(_Scripts.."/Manual/Web/js/glossary.js", pStage.."/js/glossary.js", false), "Cannot copy glossary interactions.");
		assert(wx.wxCopyFile(_Scripts.."/Manual/Web/js/Reader.js", pStage.."/js/Reader.js", false), "Cannot copy manual navigation.");
		assert(wx.wxCopyFile(_Scripts.."/Manual/Web/js/bootstrap.bundle.min.js", pStage.."/js/bootstrap.bundle.min.js", false), "Cannot copy reader controls.");
		fCopy(_Scripts.."/Manual/Web/images/components", pStage.."/images/components");
		fCopy(tContext.manualRoot.."/Images", pStage.."/content-images");
		fWrite(pStage.."/css/font-styles.css", Documents.read(tContext.manualRoot.."/Styles/font-styles.css"));
		fWrite(pStage.."/css/web-font-styles.css", Documents.read(tContext.manualRoot.."/Styles/web-font-styles.css"));
		if (sKind == "pdf") then sDocument = sDocument:gsub('<link rel="stylesheet" href="css/([%w_.-]+)">', fInlinePrintStyle); end
		fWrite(pStage.."/index.html", sDocument);
		fWrite(pStage.."/settings.json", JSON.encode(tSettings, {indent = true}));
		if (sKind == "pdf") then
			fCopy(_Scripts.."/Manual/Web/vendor/pagedjs", pStage.."/vendor/pagedjs");
			assert(wx.wxCopyFile(_Scripts.."/Manual/Web/js/Print.js", pStage.."/js/Print.js", false), "Cannot copy PDF pagination bootstrap.");
			oPage = wx.wxFileName(pStage.."/index.html");
			sURL = wx.wxFileSystem.FileNameToURL(oPage); oPage:delete();
			sPDF = fPrintBrowser(pBrowser, pStage, sURL, tContext);
			assert(sPDF:sub(1, 5) == "%PDF-" and sPDF:sub(-2048):find("%%%%EOF"), "The browser returned an incomplete PDF.");
			assert(not sPDF:find("/Title (PDF export incomplete)", 1, true), "PDF pagination did not finish. The previous export was preserved.");
			-- Browser data is private to this export job and never shipped.
			if (wx.wxDirExists(pStage.."/browser-profile")) then fRemove(pStage, pStage.."/browser-profile"); end
			-- HTML, CSS, images and browser data are print inputs, not PDF output.
			-- Keep the verified PDF in memory while rebuilding only our staging
			-- folder, so the published PDF directory contains the PDF alone.
			fRemove(pRoot, pStage);
			assert(wx.wxMkdir(pStage), "Cannot prepare the final PDF-only folder.");
			fWrite(pStage.."/Manual.pdf", sPDF);
		end
	end
	bOK, sFailure = pcall(fBuild);
	if (not bOK) then pcall(fRemove, pRoot, pStage); error(sFailure, 2); end
	if (wx.wxDirExists(pOutput)) then assert(wx.wxRenameFile(pOutput, pPrevious, false), "Cannot hold the previous export; the staged replacement remains at "..pStage); bPrevious = true; end
	if (not wx.wxRenameFile(pStage, pOutput, false)) then
		if (bPrevious) then assert(wx.wxRenameFile(pPrevious, pOutput, false), "Cannot restore the previous export from "..pPrevious); end
		error("Cannot install the export; the staged output remains at "..pStage, 2);
	end
	if (bPrevious) then fRemove(pRoot, pPrevious); end
	return {ok = true, path = pOutput..(sKind == "pdf" and "/Manual.pdf" or "/index.html"), message = sType.." export saved to "..pOutput};
end

return Exporter;
