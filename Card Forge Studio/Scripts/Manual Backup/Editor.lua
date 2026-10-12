-- Browser editing stays local. Read snapshots outside WebView event callbacks.
local wx = require("wx");
local Document = require("Manual.Document");
local HTML = require("Manual.HTML");
local Options = require("Manual.Options");
local Styles = require("Manual.Styles");
local Editor = {};
local pRoot = assert(debug.getinfo(1, "S").source:match("^@(.+[/\\])"));

local function read(pFile)
    local oFile = assert(io.open(pFile, "rb")); local sText = assert(oFile:read("a")); assert(oFile:close()); return sText;
end

local function styleList(tItems)
    local tList = {};
    for _, tItem in ipairs(tItems) do tList[#tList + 1] = '<span data-name="'..HTML.escape(tItem.name)..'" data-tag="'..tItem.tag..'"></span>'; end
    return '<div id="game-style-data" hidden>'..table.concat(tList)..'</div>';
end

function Editor.create(dParent, tModel, pStyles, pState)
    pState = pState or FS.AppCFG;
    local sTheme = INIFile.GetValue(pState, "ManualEditor", "Theme");
    if (type(sTheme) ~= "string" or sTheme == "") then sTheme = "dark"; end
    local oView = wxwebview.wxWebView.New(dParent, wx.wxID_ANY);
    local sCSS, sStyles, tItems = Styles.load(pStyles);
    local oTemp = wx.wxFile(); local pTemp = wx.wxFileName.CreateTempFileName("cfs-manual-visual-", oTemp); oTemp:Close(); oTemp:delete();
    local pPage = pTemp..".html"; assert(wx.wxRenameFile(pTemp, pPage));
    local oFileName = wx.wxFileName(pPage); local sURL = wx.wxFileSystem.FileNameToURL(oFileName); oFileName:delete();
    local sPage = HTML.shell(tModel.baseURL, sCSS,
        '<style>'..read(pRoot.."Editor.css")..'</style>',
        '<div id="editor-preferences" data-theme="'..HTML.escape(sTheme)..'" hidden></div><div id="game-style-css" hidden></div>'..styleList(tItems)..'<div id="manual-input" data-source="'..Document.hex(tModel.files[1].text)..'" hidden></div>'..Options.html()
        ..'<div id="manual-app"></div><script>'..read(pRoot.."Diagnostics.js")..read(pRoot.."Shapes.js")..read(pRoot.."Tables.js")..read(pRoot.."Layers.js")..read(pRoot.."MasterPages.js")..read(pRoot.."Snapping.js")..read(pRoot.."Themes.js")..read(pRoot.."Contents.js")..read(pRoot.."Spreads.js")..read(pRoot.."Lists.js")..read(pRoot.."StyleManager.js")..read(pRoot.."TextFlow.js")..read(pRoot.."Editor.js")..'</script>');
    local oFile = assert(io.open(pPage, "wb")); assert(oFile:write(sPage)); assert(oFile:close());
    local bLoaded = false;
    local sSaveRequest;
    local nReported = 0;
    local bAccess = false;
    local tCommands = {};
    local tStatus = {};
    local sCachedSource, sCachedSnapshot;
    local nCapturedRevision;
    local sPreview, nPreviewRevision;
    oView:Connect(wxwebview.wxEVT_WEBVIEW_TITLE_CHANGED, function(oEvent)
        local sTitle = oEvent:GetString();
        local sRevision, sZoom, sUndo, sRedo, sGrid, sSnap, sThemeHex, sBackground, sText, sSave, sDiagnostics, sScale, sView, sPage, sDirty, sZoomStep = sTitle:match("^CFS Manual (%d+)|(%d+)|([01])|([01])|([01])|([01])|(%x+)|(%x+)|(%x+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|([01])|(%d+)$");
        if (sRevision) then
            tStatus = {revision = tonumber(sRevision), zoom = sZoom, undo = sUndo == "1", redo = sRedo == "1", grid = sGrid == "1", snap = sSnap == "1", theme = Document.unhex(sThemeHex), background = "#"..sBackground, text = "#"..sText, save = sSave, diagnostics = tonumber(sDiagnostics), scale = tonumber(sScale) / 100, view = tonumber(sView), page = tonumber(sPage), dirty = sDirty == "1", zoomStep = tonumber(sZoomStep)};
        else
            local nDiagnostics = tonumber(sTitle:match("^CFS Manual JavaScript Error (%d+)$"));
            if (nDiagnostics) then tStatus.diagnostics = nDiagnostics; end
        end
        oEvent:Skip();
    end);
    oView:Connect(wxwebview.wxEVT_WEBVIEW_NAVIGATING, function(oEvent) bLoaded = false; sCachedSource = nil; sCachedSnapshot = nil; nCapturedRevision = nil; sPreview = nil; nPreviewRevision = nil; tStatus = {}; nReported = 0; sSaveRequest = nil; tCommands = {}; oEvent:Skip(); end);
    oView:Connect(wxwebview.wxEVT_WEBVIEW_LOADED, function(oEvent) bLoaded = true; oEvent:Skip(); end);
    oView:LoadURL(sURL);
    local bClosed = false;
    local function diagnostics(sSource)
        local nCount = tonumber(Document.attribute(sSource, "js-error-count")) or 0;
        for nIndex = nReported + 1, nCount do
            local sHex = Document.attribute(sSource, "js-error-"..nIndex);
            if (sHex) then require("Errors").report(Document.unhex(sHex)); end
        end
        nReported = math.max(nReported, nCount);
    end
    local function execute(sContext, sCode)
        if (not bLoaded or oView:IsBusy() or bClosed) then return false; end
        if (bAccess) then tCommands[#tCommands + 1] = {context = sContext, code = sCode}; return true; end
        bAccess = true;
        local sScript = "window.CFSManualDiagnostics ? window.CFSManualDiagnostics.run('"..sContext.."', function(){"..sCode.."}) : 'NOT_READY';";
        -- This binding returns no execution status. Browser diagnostics carry JavaScript failures.
        local bOK, sDetail = pcall(function() oView:RunScript(sScript); end);
        bAccess = false;
        if (not bOK) then require("Errors").report("Manual JavaScript command failed ("..sContext.."): "..tostring(sDetail or "Browser returned no diagnostic detail.")); end
        return bOK;
    end
    return {view = oView,
        busy = function() return bAccess; end,
        status = function()
            if (tStatus.theme and tStatus.theme ~= sTheme) then INIFile.SetValue(pState, "ManualEditor", "Theme", tStatus.theme); sTheme = tStatus.theme; end
            return tStatus;
        end,
        flush = function()
            if (bAccess or not bLoaded or oView:IsBusy() or bClosed) then return; end
            local nCount = math.min(20, #tCommands);
            for _ = 1, nCount do local tCommand = table.remove(tCommands, 1); execute(tCommand.context, tCommand.code); end
        end,
        preview = function()
            if (not bLoaded or oView:IsBusy() or bClosed or bAccess) then return sPreview; end
            if (sPreview and nPreviewRevision == tStatus.view and (tStatus.diagnostics or 0) <= nReported) then return sPreview; end
            bAccess = true; local bOK, sSource = pcall(function() return oView:GetPageSource(); end); bAccess = false;
            if (not bOK) then require("Errors").report("Manual page preview failed: "..tostring(sSource)); return sPreview; end
            diagnostics(sSource); local sHex = Document.attribute(sSource, "preview");
            if (sHex) then sPreview = Document.unhex(sHex); nPreviewRevision = tonumber(Document.attribute(sSource, "view")); end
            return sPreview;
        end,
        capture = function(bForce)
            if (not bLoaded or oView:IsBusy() or bClosed or bAccess) then return nil; end
            if (not bForce and sCachedSource and tStatus.revision and tStatus.revision == nCapturedRevision and (tStatus.diagnostics or 0) <= nReported) then return sCachedSnapshot, sCachedSource; end
            bAccess = true;
            local bOK, sSource = pcall(function() oView:RunScript("if(window.CFSManual)window.CFSManual.snapshot();"); local sSource = oView:GetPageSource(); oView:RunScript("delete document.documentElement.dataset.cfsSnapshot;"); return sSource; end);
            bAccess = false;
            if (not bOK) then require("Errors").report("Manual browser snapshot failed: "..tostring(sSource)); return nil; end
            diagnostics(sSource);
            local sNextTheme = Document.attribute(sSource, "editor-theme");
            if (sNextTheme and sNextTheme ~= sTheme) then INIFile.SetValue(pState, "ManualEditor", "Theme", sNextTheme); sTheme = sNextTheme; end
            sCachedSource = sSource; sCachedSnapshot = Document.snapshot(sSource); nCapturedRevision = tonumber(Document.attribute(sSource, "revision")); tStatus.dirty = Document.attribute(sSource, "dirty") == "1";
            return sCachedSnapshot, sCachedSource;
        end,
        saved = function() if (nCapturedRevision) then return execute("saved", "if(window.CFSManual)window.CFSManual.saved("..nCapturedRevision..");"); end end,
        saveRequested = function()
            local sRequest = tStatus.save;
            if (not sRequest or sRequest == "0" or sRequest == sSaveRequest) then return false; end
            sSaveRequest = sRequest; return true;
        end,
        action = function(sAction)
            assert(type(sAction) == "string" and sAction:match("^[%a%-]+$"), "Invalid manual command.");
            return execute(sAction, "if(window.CFSManual) window.CFSManual.action('"..sAction.."');");
        end,
        zoom = function(nZoom)
            assert(type(nZoom) == "number" and nZoom >= 0.1 and nZoom <= 4, "Invalid page zoom.");
            return execute("zoom", "if(window.CFSManual) window.CFSManual.setZoom("..tostring(nZoom)..");");
        end,
        options = function() return execute("options", "if(window.CFSManual) window.CFSManual.openOptions();"); end,
        refreshStyles = function()
            if (not bLoaded or oView:IsBusy() or bClosed) then return false; end
            if (read(pStyles) == sStyles) then return false; end
            local sNextCSS, sNextStyles, tNextItems = Styles.load(pStyles);
            if (sNextStyles == sStyles) then return false; end
            if (not execute("refresh styles", "if(window.CFSManual) window.CFSManual.styles('"..Document.hex(sNextCSS).."','"..Document.hex(styleList(tNextItems)).."');")) then return false; end
            sStyles = sNextStyles; return true;
        end,
        close = function() if (bClosed) then return true; end if (bAccess) then return false; end bClosed = true; tCommands = {}; oView:Stop(); wx.wxRemoveFile(pPage); end};
end

return Editor;
