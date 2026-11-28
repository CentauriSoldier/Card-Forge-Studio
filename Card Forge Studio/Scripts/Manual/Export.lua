--[[!
@fqxn CFS.Manual.Export
@desc Native manual export coordinator. Reads ordered sources, styles and configuration directly from disk; prepares, paginates and writes PDFs in Lua without a browser or print worker.
!]]

local Documents	= require("Manual.Documents");
local Document	= require("Manual.Document");
local Exporter	= require("Manual.Exporter");
local JSON		= require("Manual.Lib.dkjson");
local Serializer  = require("LuaEx.lib.serializer");
local wx          = require("wx");
local PDF         = require("Manual.PDF");
local PDFLayout   = require("Manual.PDFLayout");
local INI         = require("Plugins.INI");
local _tFontInfo  = {};
local Export      = {};
local _tFields	= {"width", "height", "bleed", "marginTop", "marginBottom", "marginInside", "marginOutside", "dpi"};

--[[!
@fqxn CFS.Manual.Export.Functions.settings
@desc Reads existing game-owned export settings without changing any files.
@param table tContext Bound game paths.
@return table tSettings Settings.
@return string sOriginal Original bytes for conflict-aware saves.
!]]
function Export.settings(tContext)
	local sOriginal				= Documents.read(tContext.manualRoot.."/Config/export-settings.json");
	local tSettings, _, sError	= JSON.decode(sOriginal);
	assert(tSettings, sError);
	Export.validate(tSettings);
	return tSettings, sOriginal;
end

--[[!
@fqxn CFS.Manual.Export.Functions.validate
@desc Validates finite physical dimensions, nonnegative bleed/margins and whole-number DPI before preparing files.
@param table tSettings Export settings.
!]]
function Export.validate(tSettings)
	assert(type(tSettings) == "table" and type(tSettings.pdf) == "table" and tSettings.pdf.units == "in", "Invalid PDF settings.");
	for _, sField in ipairs(_tFields) do
		local nValue = tSettings.pdf[sField];
		assert(type(nValue) == "number" and nValue == nValue and nValue < math.huge and nValue >= 0, "Enter a finite nonnegative value for "..sField..".");
	end
	local tPDF = tSettings.pdf;
	assert(tPDF.width > tPDF.marginInside + tPDF.marginOutside and tPDF.height > tPDF.marginTop + tPDF.marginBottom, "Margins must leave a positive content area.");
	assert(tPDF.dpi > 0 and tPDF.dpi % 1 == 0, "DPI must be a positive whole number.");
end

--[[!
@fqxn CFS.Manual.Export.Functions.save
@desc Saves native settings through the existing conflict-aware filesystem service.
@param table tContext Bound manual paths.
@param table tSettings Validated settings.
@param string sOriginal Previously read bytes.
@return string sSaved Saved bytes.
!]]
function Export.save(tContext, tSettings, sOriginal)
	Export.validate(tSettings);
	local sSaved = JSON.encode(tSettings, {indent = "\t"}).."\n";
	Documents.save(tContext.manualRoot.."/Config/export-settings.json", sOriginal, sSaved);
	return sSaved;
end

--[[!
@fqxn CFS.Manual.Export.Functions.presets
@desc Reads Studio's shared supplier catalog without copying or modifying it.
@return table tProfiles Supplier profiles.
!]]
function Export.presets()
	return assert(JSON.decode(Documents.read(_Scripts.."/../Docs/Templates/Manual/PDF Export/The Game Crafter/Profiles.json"))).profiles;
end

--[[!
@fqxn CFS.Manual.Export.Private.Functions.checkpoint
@desc Checks for cancellation on both sides of a scheduled work interval.
@vis private
!]]
local function checkpoint(tContext)
    assert(not tContext.cancelled, "Manual export cancelled; the previous export was preserved.");
    if (tContext.pause) then tContext.pause(); end
    assert(not tContext.cancelled, "Manual export cancelled; the previous export was preserved.");
end

--[[!
@fqxn CFS.Manual.Export.Functions.read
@desc Captures saved sources, order, styles and glossary configuration directly from the bound game's manual folder. Verifies source bytes before returning. Generated CSS is built in memory with the existing font parser.
@param table tContext Bound game paths.
@return table tData Export snapshot.
!]]
function Export.read(tContext)
	local tNames, sOrder	= Documents.order(tContext.manualRoot);
	local tOriginals		= {["Content/_ORDER_.txt"] = sOrder};
	local tData				= {context = tContext, chapters = {}};
	local fRead;

	--[[!
	@fqxn CFS.Manual.Export.Private.Functions.fRead
	@desc Records the exact source bytes used by this export.
	@vis private
	!]]
	fRead = function(sName)
		if (tContext.kind == "web" and tContext.onProgress) then tContext.onProgress("preparing", "Reading "..sName); end
		checkpoint(tContext);
		local sText = Documents.read(tContext.manualRoot.."/"..sName);
		tOriginals[sName] = sText;
		return sText;
	end;
	for _, sName in ipairs(tNames) do tData.chapters[#tData.chapters + 1] = {name = sName, text = fRead("Content/"..sName)}; end
	tData.gameCSS = fRead("Styles/font-styles.css");
	tData.alternatives = assert(JSON.decode(fRead("Config/glossary-alternatives.json")));
	tData.glossarySettings = assert(JSON.decode(fRead("Config/glossary-settings.json")));
	if (CFS and CFS.FontStyle) then
        if (tContext.kind == "web" and tContext.onProgress) then tContext.onProgress("preparing", "Generating game font styles from Styles.ini."); end
        checkpoint(tContext);
        tData.stylesSource = Documents.read(tContext.gameRoot.."/Styles.ini");
        tData.gameCSS = require("Manual.FontCSS").generate(tContext.gameRoot, tData.gameCSS);
        assert(Documents.read(tContext.gameRoot.."/Styles.ini") == tData.stylesSource, "Styles.ini changed while preparing export.");
    end
    if (tContext.kind == "web") then
        local Appearance = require("Manual.Appearance");
        local tAppearance = Appearance.load(tContext.manualRoot);
        fRead("Config/Appearance.lua"); fRead(tAppearance.BaseCSS);
        tData.appearanceCSS = Appearance.css(tContext.manualRoot, ".manual-appearance", "../content-images/", tAppearance, tData.gameCSS);
    end
	if (tContext.kind == "web" and tContext.onProgress) then tContext.onProgress("preparing", "Checking that saved sources have not changed."); end
	for sName, sText in pairs(tOriginals) do
		if (tContext.pause) then checkpoint(tContext); end
		assert(Documents.read(tContext.manualRoot.."/"..sName) == sText, "Manual sources changed while preparing export: "..sName);
	end
	local tCurrent = Documents.list(tContext.manualRoot);
	assert(#tCurrent == #tNames, "The manual chapter list changed while preparing export.");
	for _, sName in ipairs(tCurrent) do assert(tOriginals["Content/"..sName], "The manual chapter list changed while preparing export."); end
	return tData;
end

--[[!
@fqxn CFS.Manual.Export.Private.Functions.fontSHA256
@desc Hashes complete font bytes in Lua. Metadata reuse never relies on timestamps.
@param string pFile Font filename.
@return string sSHA SHA-256 digest in lowercase hexadecimal.
@vis private
!]]
local function fontSHA256(pFile, tContext)
    local hFile = assert(io.open(pFile, "rb"));
    local sBytes, sError = hFile:read("a");
    local bClosed, sCloseError = hFile:close();
    local tHash = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
    local tConstants = {
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
    };
    local tWords = {};
    local function rotate(nValue, nBits)
        return ((nValue >> nBits) | (nValue << (32 - nBits))) & 0xffffffff;
    end

    assert(sBytes, sError); assert(bClosed, sCloseError);
    local nLength = #sBytes;
    sBytes = sBytes.."\128"..string.rep("\0", (55 - nLength) % 64)..string.pack(">I8", nLength * 8);
    for nOffset = 1, #sBytes, 64 do
        if ((nOffset - 1) % 8192 == 0) then checkpoint(tContext); end
        for nIndex = 1, 16 do tWords[nIndex] = string.unpack(">I4", sBytes, nOffset + (nIndex - 1) * 4); end
        for nIndex = 17, 64 do
            local nA, nB = tWords[nIndex - 15], tWords[nIndex - 2];
            local nS0 = rotate(nA, 7) ~ rotate(nA, 18) ~ (nA >> 3);
            local nS1 = rotate(nB, 17) ~ rotate(nB, 19) ~ (nB >> 10);

            tWords[nIndex] = (tWords[nIndex - 16] + nS0 + tWords[nIndex - 7] + nS1) & 0xffffffff;
        end
        local a,b,c,d,e,f,g,h = table.unpack(tHash);
        for nIndex = 1, 64 do
            local nS1 = rotate(e, 6) ~ rotate(e, 11) ~ rotate(e, 25);
            local nChoice = (e & f) ~ ((~e) & g);
            local nT1 = (h + nS1 + nChoice + tConstants[nIndex] + tWords[nIndex]) & 0xffffffff;
            local nS0 = rotate(a, 2) ~ rotate(a, 13) ~ rotate(a, 22);
            local nT2 = (nS0 + ((a & b) ~ (a & c) ~ (b & c))) & 0xffffffff;

            h,g,f,e,d,c,b,a = g,f,e,(d + nT1) & 0xffffffff,c,b,a,(nT1 + nT2) & 0xffffffff;
        end
        for nIndex, nValue in ipairs({a,b,c,d,e,f,g,h}) do tHash[nIndex] = (tHash[nIndex] + nValue) & 0xffffffff; end
    end
    for nIndex, nValue in ipairs(tHash) do tHash[nIndex] = string.format("%08x", nValue); end
    return table.concat(tHash);
end

--[[!
@fqxn CFS.Manual.Export.Private.Functions.fontResolver
@desc Resolves requested faces during layout. Catalog entries and filenames are
    lookup hints. Only a selected file is hashed and retained in the disk cache.
@vis private
!]]
local function fontResolver(tContext, tSettings, bWeb)
    local pCache = _AppDataLocal and _AppDataLocal.."/FontInspection.lua";
    local pHome = os.getenv("HOME") or os.getenv("USERPROFILE");
    local pWindows = os.getenv("WINDIR");
    local pLocal = os.getenv("LOCALAPPDATA");
    local tUsed, tResolved, tInspected = {}, {}, {};
    local tNames, tRoots, tSeen = {{}, {}, {}}, {}, {};
    local tLocalRoots = {tContext.gameRoot.."/Fonts", FS.Fonts};
    local tLocalFiles = {{}, {}};
    local tPrevious = _tFontInfo;
    local function key(sName)
        return (sName:lower():gsub("[%s%p]", ""));
    end
    if (pCache and wx.wxFileExists(pCache)) then
        local bOK, tCache = pcall(function() return Serializer.deserialize(Documents.read(pCache)); end);
        if (bOK and type(tCache) == "table" and tCache.version == 1 and type(tCache.files) == "table") then tPrevious = tCache.files; end
    end
    local function catalog(sName, pFile, nTier)
        pFile = pFile:gsub("\\", "/");
        nTier = nTier or 3;
        local function add(sAlias, pCandidate, nSource)
            local sKey = key(sAlias);
            local tCatalog = tNames[nSource];
            tCatalog[sKey] = tCatalog[sKey] or {};
            tCatalog[sKey][#tCatalog[sKey] + 1] = pCandidate;
        end
        add(sName, pFile, nTier);
        -- Installed names also identify same-named local files without reading unrelated fonts.
        if (nTier == 3) then
            local sFilename = pFile:match("([^/]+)$"):lower();
            for nSource, tFiles in ipairs(tLocalFiles) do
                if (tFiles[sFilename]) then add(sName, tFiles[sFilename], nSource); end
            end
        end
        local tEntry = tPrevious[pFile];
        if (type(tEntry) == "table" and type(tEntry.faces) == "table") then
            for _, tFace in ipairs(tEntry.faces) do
                if (type(tFace) == "table" and type(tFace.aliases) == "table") then
                    local sSuffix = (tFace.bold and " Bold" or "")..(tFace.italic and " Italic" or "");
                    for _, sAlias in ipairs(tFace.aliases) do add(sAlias..sSuffix, pFile, nTier); end
                    if (tFace.postscript) then add(tFace.postscript, pFile, nTier); end
                end
            end
        end
    end
    for nTier, pRoot in ipairs(tLocalRoots) do
        pRoot = pRoot:gsub("\\", "/");
        if (wx.wxDirExists(pRoot)) then
            local oDir = wx.wxDir(pRoot);
            if (oDir:IsOpened()) then
                local bFound, sName = oDir:GetFirst("", wx.wxDIR_FILES + wx.wxDIR_HIDDEN);
                while (bFound) do
                    local sStem = sName:lower():match("^(.*)%.[ot]t[fc]$");
                    if (sStem) then
                        local pFile = pRoot.."/"..sName;
                        tLocalFiles[nTier][sName:lower()] = pFile;
                        catalog(sStem, pFile, nTier);
                    end
                    bFound, sName = oDir:GetNext();
                end
            end
            oDir:delete();
        end
    end
    if (pWindows) then
        local sRoot = "Microsoft\\Windows NT\\CurrentVersion\\Fonts";
        local oCatalog = wx.wxConfig("", "", sRoot, sRoot, wx.wxCONFIG_USE_GLOBAL_FILE);
        local bFound, sName, nIndex = oCatalog:GetFirstEntry();
        while (bFound) do
            local bRead, pFile = oCatalog:Read(sName, "");
            if (bRead and pFile ~= "") then
                if (not pFile:find("[/\\]")) then pFile = pWindows.."/Fonts/"..pFile; end
                for sFace in sName:gsub("%s*%([^()]*%)%s*$", ""):gmatch("[^&]+") do catalog(sFace, pFile); end
            end
            bFound, sName, nIndex = oCatalog:GetNextEntry(nIndex);
        end
        oCatalog:delete();
    end
    if (pLocal) then tRoots[#tRoots + 1] = pLocal.."/Microsoft/Windows/Fonts"; end
    if (pHome) then
        tRoots[#tRoots + 1] = pHome.."/.local/share/fonts";
        tRoots[#tRoots + 1] = pHome.."/.fonts";
        tRoots[#tRoots + 1] = pHome.."/Library/Fonts";
    end
    if (pWindows) then tRoots[#tRoots + 1] = pWindows.."/Fonts"; end
    for _, pRoot in ipairs({"/usr/share/fonts", "/usr/local/share/fonts", "/Library/Fonts", "/System/Library/Fonts"}) do tRoots[#tRoots + 1] = pRoot; end
    -- OS font directories can also be located by filename.
    local function listNames(pRoot, nDepth)
        if (tSeen[pRoot] or not wx.wxDirExists(pRoot) or nDepth > 32) then return; end
        tSeen[pRoot] = true;
        local oDir = wx.wxDir(pRoot);
        if (oDir:IsOpened()) then
            local bFound, sName = oDir:GetFirst("", wx.wxDIR_FILES + wx.wxDIR_DIRS + wx.wxDIR_HIDDEN + wx.wxDIR_NO_FOLLOW);
            while (bFound) do
                local pFile = pRoot.."/"..sName;
                local sStem = sName:lower():match("^(.*)%.[ot]t[fc]$");
                if (sStem) then catalog(sStem, pFile);
                elseif (wx.wxDirExists(pFile) and not wx.wxFileName.Exists(pFile, 0x1004)) then listNames(pFile, nDepth + 1); end
                bFound, sName = oDir:GetNext();
            end
        end
        oDir:delete();
    end
    local bListed = false;
    local function resolve(sFamily, bBold, bItalic)
        local sKey = key(sFamily);
        local tSuffixes;
        if (bBold and bItalic) then tSuffixes = {"bolditalic", "boldoblique", "boldital", "bi"};
        elseif (bBold) then tSuffixes = {"bold", "bd", "b", "semibold"};
        elseif (bItalic) then tSuffixes = {"italic", "oblique", "ital", "i"};
        else tSuffixes = {"regular", "", "normal", "roman", "book"}; end
        local sRequest = sFamily:lower().."/"..tSuffixes[1];
        if (tResolved[sRequest] ~= nil) then return tResolved[sRequest]; end
        local tChecked = {};
        local function selectFace(tFaces)
            local tBest;
            for _, tFace in ipairs(tFaces) do
                local bNamed = tFace.postscript:lower() == sFamily:lower();
                local bFamily = bNamed;
                for _, sAlias in ipairs(tFace.aliases) do
                    if (sAlias:lower() == sFamily:lower()) then bFamily = true; break; end
                end
                if (bFamily and (bWeb or (tFace.supported and tFace.embeddable)) and
                    ((tFace.bold == bBold and tFace.italic == bItalic) or (bNamed and not bBold and not bItalic))) then
                    if (not tBest or math.abs(tFace.weight - (bBold and 700 or 400)) < math.abs(tBest.weight - (bBold and 700 or 400))) then tBest = tFace; end
                end
            end
            return tBest;
        end
        local function match(nTier)
            for _, sSuffix in ipairs(tSuffixes) do
                for _, pCandidate in ipairs(tNames[nTier][sKey..sSuffix] or {}) do
                    local sFilename = pCandidate:match("([^/]+)$"):lower();
                    local pFile = tLocalFiles[1][sFilename] or tLocalFiles[2][sFilename] or pCandidate;
                    if (not tChecked[pFile] and wx.wxFileExists(pFile)) then
                        tChecked[pFile] = true;
                        checkpoint(tContext);
                        local tEntry = tInspected[pFile];
                        local sSHA;
                        if (not tEntry) then
                            local tCached = tPrevious[pFile];
                            if (type(tCached) == "table" and type(tCached.faces) == "table" and selectFace(tCached.faces)) then
                                sSHA = fontSHA256(pFile, tContext);
                                if (sSHA == tCached.sha256) then tEntry = tCached; end
                            end
                            if (not tEntry) then
                                local bOK, vInfo = pcall(PDF.fontInfo, pFile);
                                tEntry = {faces = bOK and vInfo or {}, sha256 = sSHA};
                            end
                            tInspected[pFile] = tEntry;
                        end
                        local tBest = selectFace(tEntry.faces);
                        if (tBest) then
                            if (not tUsed[pFile]) then
                                if (tContext.onProgress) then tContext.onProgress("fonts", "Using manual font: "..pFile); end
                                tEntry.sha256 = tEntry.sha256 or fontSHA256(pFile, tContext);
                                tUsed[pFile] = tEntry;
                            end
                            return tBest;
                        end
                    end
                end
            end
        end
        -- Collections can hold several variants under the unqualified family name.
        if (bBold or bItalic) then tSuffixes[#tSuffixes + 1] = ""; end
        local tFace = match(1) or match(2) or match(3);
        if (not tFace and not bListed) then
            for _, pRoot in ipairs(tRoots) do listNames(pRoot, 0); end
            bListed = true;
            tFace = match(1) or match(2) or match(3);
        end
        tResolved[sRequest] = tFace or false;
        return tFace;
    end
    local function resolveStyleFont(tStyle)
        local tFamilies = tStyle.family and {tStyle.family} or tStyle.code and {"Courier New", "Liberation Mono", "DejaVu Sans Mono", "Noto Sans Mono"}
            or tSettings.pdf.fontFamily and {tSettings.pdf.fontFamily} or {"Arial", "Liberation Sans", "DejaVu Sans", "Noto Sans"};
        for _, sFamily in ipairs(tFamilies) do
            local tFace = resolve(sFamily, tStyle.bold == true, tStyle.italic == true);
            if (tFace) then return tFace; end
        end
        error("Cannot embed the requested font face: "..table.concat(tFamilies, ", ")..(tStyle.bold and " Bold" or "")..(tStyle.italic and " Italic" or "")..". No matching embeddable face was found in game Fonts, application AppData Fonts, or OS fonts.");
    end
    local function saveCache()
        _tFontInfo = tUsed;
        if (not pCache) then return; end
        local pStage;
        local bSaved, sError = pcall(function()
            local oTemporary = wx.wxFile();
            pStage = wx.wxFileName.CreateTempFileName(pCache.."-", oTemporary);
            if (oTemporary:IsOpened()) then oTemporary:Close(); end
            oTemporary:delete();
            assert(pStage ~= "", "Cannot reserve font cache staging file.");
            local hFile = assert(io.open(pStage, "wb"));
            local bWritten, sWriteError = hFile:write(Serializer.serialize({version = 1, files = tUsed}));
            local bClosed, sCloseError = hFile:close();

            assert(bWritten, sWriteError); assert(bClosed, sCloseError);
            assert(wx.wxRenameFile(pStage, pCache, true), "Cannot install font inspection cache.");
        end);
        if (not bSaved) then
            if (pStage and pStage ~= "" and wx.wxFileExists(pStage)) then wx.wxRemoveFile(pStage); end
            if (tContext.onProgress) then tContext.onProgress("warning", "Font inspection cache could not be saved: "..tostring(sError)); end
        end
    end
    return resolveStyleFont, saveCache, resolve;
end

--[[!
@fqxn CFS.Manual.Export.Private.Functions.nativeStyles
@desc Reuses FontStyle and the Style Editor drawing adapter. Text and ordinary
    effect passes become PDF vectors; native bevel/wear masks become alpha images.
    All passes share one logical ActualText string for copy/search behavior.
@param table tContext Job cancellation context.
@param table tOptions Layout options to extend with native measurement/drawing.
@param table tParsed Original saved parsed style descriptors, populated lazily.
@vis private
!]]
local function nativeStyles(tContext, tOptions, tParsed)
    local oBitmap = wx.wxBitmap(2, 2, 32);
    local oDC = wx.wxMemoryDC();
    local oGC;
    local tDrawing;
    local tObjects, tMeasures = {}, {};
    local tOverlayCache = setmetatable({}, {__mode = "k"});
    local bDisposed = false;
    local fObject;
    local fMetrics;
    local fColor;
    local fAdapter;

    oDC:SelectObject(oBitmap);
    oGC = assert(wx.wxGraphicsContext.Create(oDC), "Cannot create the native style measurement context.");
    tDrawing = require("Windows.StyleEditor").drawing(oGC, oDC);
    fColor = function(nColor)
        return {((nColor >> 24) & 255) / 255, ((nColor >> 16) & 255) / 255, ((nColor >> 8) & 255) / 255}, (nColor & 255) / 255;
    end;
    fObject = function(tStyle)
        local sKey = tStyle.nativeStyle.."/"..tStyle.size.."/"..tostring(tStyle.bold).."/"..tostring(tStyle.italic)
            .."/"..tostring(tStyle.underline).."/"..tostring(tStyle.strike).."/"..(tStyle.spacing or 0);
        local oStyle = tObjects[sKey];

        if (not oStyle) then
            local tSource = assert(tParsed[tStyle.nativeStyle:lower()], "Native PDF style was not captured: "..tStyle.nativeStyle);
            local tCopy = {};
            local tFlags = {};

            for sKey, vValue in pairs(tSource) do tCopy[sKey] = vValue; end
            for sKey, vValue in pairs(tSource.FontOptions) do tFlags[sKey] = vValue; end
            tFlags.Bold, tFlags.Italic = tStyle.bold == true, tStyle.italic == true;
            tFlags.Underline, tFlags.StrikeOut = tStyle.underline == true, tStyle.strike == true;
            tCopy.FontOptions, tCopy.FontSize = tFlags, tStyle.size;
            tCopy.FontColorPath = "";
            tCopy.LetterSpacing = (tStyle.spacing or 0) / 0.75;
            oStyle = CFS.FontStyle("", tCopy);
            tObjects[sKey] = oStyle;
        end
        return oStyle;
    end;
    fMetrics = function(tStyle, sText)
        local oStyle = fObject(tStyle);
        local nWidth, nHeight, nMinX, nMinY = oStyle.Prep(tDrawing, sText);
        local _, nTextHeight, nDescent = oGC:GetTextExtent(sText ~= "" and sText or "Mg");
        local nAscent = nTextHeight - nDescent;

        return {width = sText == "" and 0 or nWidth * 0.75, ascent = (nAscent - nMinY) * 0.75,
            descent = (nHeight + nMinY - nAscent) * 0.75, minX = nMinX, minY = nMinY, nativeAscent = nAscent};
    end;
    fAdapter = function(oDocument, tPage, tOperation)
        local tStyle = tOperation.piece.style;
        local tFont = tOperation.piece.font;
        local oStyle = fObject(tStyle);
        local tAdapter = require("Windows.StyleEditor").drawing(oGC, oDC);
        local fSetFont = tAdapter.SetDrawingFont;
        local nPointSize = tStyle.size / 0.75;
        local fText;
        local nPasses = 0;

        tAdapter.SetDrawingFont = function(oFont)
            fSetFont(oFont);
            nPointSize = oFont:GetPointSize() / 0.75;
        end;
        fText = function(nX, nY, sText, nColor)
            local tRGB, nOpacity = fColor(nColor);
            local _, nHeight, nDescent = oGC:GetTextExtent(sText ~= "" and sText or "Mg");
            local nAscent = nHeight - nDescent;
            local nEnd = 0;

            nPasses = nPasses + 1;
            if (nPasses % 128 == 0) then checkpoint(tContext); end
            for nPosition, nCode in utf8.codes(sText) do
                local sCharacter = utf8.char(nCode);
                local sPrefix = sText:sub(1, nPosition + #sCharacter - 1);
                local nOffset = tAdapter.GetTextWidth(sPrefix) - tAdapter.GetTextWidth(sCharacter);

                oDocument.text(tPage, tFont, nPointSize, nX + nOffset, nY + nAscent, sCharacter, {color = tRGB, opacity = nOpacity});
                nEnd = tAdapter.GetTextWidth(sPrefix);
            end
            if (tStyle.underline and nEnd > 0) then oDocument.rectangle(tPage, nX, nY + nAscent + 1, nEnd, 1, tRGB, nOpacity); end
            if (tStyle.strike and nEnd > 0) then oDocument.rectangle(tPage, nX, nY + nAscent * 0.65, nEnd, 1, tRGB, nOpacity); end
        end;
        tAdapter.DrawText = fText;
        tAdapter.WithTextTransform = function(nX, nY, nAngle, fDraw)
            local nRadians = math.rad(nAngle);

            oDocument.withTransform(tPage, {math.cos(nRadians), -math.sin(nRadians), math.sin(nRadians), math.cos(nRadians), nX, nY}, fDraw);
        end;
        tAdapter.WithTextClip = function(nX, nY, nWidth, nHeight, fDraw)
            oDocument.withClip(tPage, nX, nY, nWidth, nHeight, fDraw);
        end;
        tAdapter.DrawAngledText = function(nX, nY, sText, nAngle, nColor)
            tAdapter.WithTextTransform(nX, nY, nAngle, function() fText(0, 0, sText, nColor); end);
        end;
        tAdapter.DrawRectangle = function(nX, nY, nWidth, nHeight, nColor)
            local tRGB, nOpacity = fColor(nColor);

            if (nWidth > 0 and nHeight > 0) then oDocument.rectangle(tPage, nX, nY, nWidth, nHeight, tRGB, nOpacity); end
        end;
        tAdapter.DrawTextBackground = function(nX, nY, nWidth, nHeight, nPadding, nColor, nAngle)
            tAdapter.WithTextTransform(nX, nY, nAngle, function()
                tAdapter.DrawRectangle(-nPadding, -nPadding, nWidth + 2 * nPadding, nHeight + 2 * nPadding, nColor);
            end);
        end;
        tAdapter.DrawTextOverlay = function(oOverlay, nX, nY, nWidth, nHeight)
            local tByDocument = tOverlayCache[oOverlay];
            local tImage;

            if (not tByDocument) then tByDocument = setmetatable({}, {__mode = "k"}); tOverlayCache[oOverlay] = tByDocument; end
            tImage = tByDocument[oDocument];
            if (not tImage) then
                local oImage = oOverlay:ConvertToImage();
                local sAlpha = oImage:HasAlpha() and oImage:GetAlpha() or nil;

                tImage = oDocument.addRawImage(oImage:GetWidth(), oImage:GetHeight(), oImage:GetData(), sAlpha);
                oImage:delete();
                tByDocument[oDocument] = tImage;
            end
            oDocument.image(tPage, tImage, nX, nY, nWidth, nHeight);
        end;
        return tAdapter, oStyle;
    end;
    tOptions.measureStyledText = function(tStyle, sText)
        local sKey = tStyle.nativeStyle.."/"..tStyle.size.."/"..tostring(tStyle.bold).."/"..tostring(tStyle.italic)
            .."/"..tostring(tStyle.underline).."/"..tostring(tStyle.strike).."/"..(tStyle.spacing or 0).."/"..sText;

        if (not tMeasures[sKey]) then tMeasures[sKey] = fMetrics(tStyle, sText); end
        return tMeasures[sKey];
    end;
    tOptions.drawStyledText = function(oDocument, tPage, tOperation)
        local tStyle = tOperation.piece.style;
        local tMetrics = tOptions.measureStyledText(tStyle, tOperation.piece.text);
        local tAdapter, oStyle = fAdapter(oDocument, tPage, tOperation);

        checkpoint(tContext);
        oDocument.withActualText(tPage, tOperation.piece.text, function()
            oDocument.withTransform(tPage, {0.75, 0, 0, 0.75, tOperation.x, tOperation.y - tMetrics.ascent}, function()
                oStyle.Draw("PDF export", tAdapter, oDC, -tMetrics.minX, -tMetrics.minY, tOperation.piece.text);
            end);
        end);
        return true;
    end;
    tOptions.nativeStyle = fObject;
    tOptions.dispose = function()
        if (bDisposed) then return; end
        bDisposed = true;
        for _, oStyle in pairs(tObjects) do oStyle.GetFont():delete(); end
        oGC:delete();
        oDC:SelectObject(wx.wxNullBitmap);
        oDC:delete();
        oBitmap:delete();
    end;
end

--[[!
@fqxn CFS.Manual.Export.Functions.pdfOptions
@desc Resolves the actual font files needed by Lua layout. Context pdfOptions may
    provide explicit font files for portable fixtures or user-selected families.
@param table tContext Bound context.
@param table tData Saved manual snapshot.
@param table tSettings Export settings.
@return table tOptions Lua layout options.
!]]
function Export.pdfOptions(tContext, tData, tSettings)
    local tOptions = {};
    local fSaveFonts;
    local tParsed, tNativeStyles = {}, {};
    local oReader;
    local pStyles = tContext.gameRoot.."/Styles.ini";

    for sKey, vValue in pairs(tContext.pdfOptions or {}) do tOptions[sKey] = vValue; end
    tOptions.checkpoint = function() checkpoint(tContext); end;
    tOptions.cancelled = function() return tContext.cancelled == true; end;
    tOptions.onProgress = tContext.onProgress;
    if (not tOptions.resolveFont and not tOptions.fonts) then
        tOptions.resolveFont, fSaveFonts = fontResolver(tContext, tSettings);
    end
    if (not tOptions.resolveFallbackFonts and tOptions.resolveFont) then
        local tFallbacks;
        tOptions.resolveFallbackFonts = function()
            if (not tFallbacks) then
                tFallbacks = {};
                for _, sFamily in ipairs({"Segoe UI Emoji", "Segoe UI Symbol", "Noto Sans Symbols 2"}) do
                    local bFound, tFace = pcall(tOptions.resolveFont, {family = sFamily});
                    if (bFound and tFace) then tFallbacks[#tFallbacks + 1] = tFace; end
                end
            end
            return tFallbacks;
        end;
    end
    if (CFS and CFS.FontStyle and wx.wxFileExists(pStyles)) then
        oReader = INI.CreateReader(pStyles, false);
        tOptions.resolveStyle = function(sName)
            local tStyle;
            local tNative;

            if (tParsed[sName:lower()]) then return tParsed[sName:lower()]; end
            if (tData.stylesSource) then assert(Documents.read(pStyles) == tData.stylesSource, "Styles.ini changed during PDF generation."); end
            tNative = CFS.FontStyle.Parse(sName, oReader);
            assert(tNative, "PDF style is not defined in Styles.ini: "..sName);
            tStyle = {family = tNative.FontFamily, size = tNative.FontSize,
                bold = tNative.FontOptions.Bold == true, italic = tNative.FontOptions.Italic == true,
                underline = tNative.FontOptions.Underline == true, strike = tNative.FontOptions.StrikeOut == true,
                color = {((tNative.FontColor >> 24) & 255) / 255, ((tNative.FontColor >> 16) & 255) / 255, ((tNative.FontColor >> 8) & 255) / 255},
                spacing = (tNative.LetterSpacing or 0) * 0.75};
            tStyle.nativeStyle = sName;
            tNativeStyles[sName:lower()] = tNative;
            tParsed[sName:lower()] = tStyle;
            return tStyle;
        end;
        nativeStyles(tContext, tOptions, tNativeStyles);
    end
    return tOptions, fSaveFonts;
end

--[[!
@fqxn CFS.Manual.Export.Functions.drawPage
@desc Draws a prepared page on a native canvas. Uses the same FontStyle renderer
    for styled runs and the snapshot's embedded image bytes, never a WebView.
@param table tLayout Completed Lua layout.
@param number nPage One-based page number.
@param wxDC oDC Native preview device context.
@param number nWidth Canvas width.
@param number nHeight Canvas height.
!]]
function Export.drawPage(tLayout, nPage, oDC, nWidth, nHeight)
    local tPlan = assert(tLayout.pages[nPage], "PDF preview page is unavailable.");
    local tPage = tPlan.page;
    local oGC = assert(wx.wxGraphicsContext.Create(oDC), "Cannot create PDF preview graphics context.");
    local nScale = math.max(0.01, math.min((nWidth - 24) / tPage.width, (nHeight - 24) / tPage.height));
    local tCache = tLayout.previewCache or {fonts = {}, images = {}};
    local fFont;
    local fText;
    local bOK, sError;

    assert(not tLayout.disposed, "PDF preview has been released.");
    tLayout.previewCache = tCache;
    fFont = function(tFont, nSize)
        local sKey = tFont.name.."/"..nSize;
        local oFont = tCache.fonts[sKey];

        if (not oFont) then
            oFont = wx.wxFont(math.max(1, math.floor(nSize * 0.75 + 0.5)), wx.wxFONTFAMILY_DEFAULT,
                tFont.italic and wx.wxFONTSTYLE_ITALIC or wx.wxFONTSTYLE_NORMAL,
                tFont.bold and wx.wxFONTWEIGHT_BOLD or wx.wxFONTWEIGHT_NORMAL, false, tFont.family);
            if (oFont.SetFractionalPointSize) then oFont:SetFractionalPointSize(nSize * 0.75); end
            tCache.fonts[sKey] = oFont;
        end
        return oFont;
    end;
    fText = function(tFont, nSize, nX, nBaseline, sText, tColor)
        local oColor = wx.wxColour(math.floor(tColor[1] * 255 + 0.5), math.floor(tColor[2] * 255 + 0.5), math.floor(tColor[3] * 255 + 0.5));
        local nTextWidth, nTextHeight, nDescent;

        oGC:SetFont(fFont(tFont, nSize), oColor);
        nTextWidth, nTextHeight, nDescent = oGC:GetTextExtent(sText);
        oGC:DrawText(sText, nX, nBaseline - nTextHeight + nDescent);
        oColor:delete();
    end;
    bOK, sError = pcall(function()
        local tBaseFont = tLayout.baseFont;

        oGC:Translate((nWidth - tPage.width * nScale) / 2, (nHeight - tPage.height * nScale) / 2);
        oGC:Scale(nScale, nScale);
        oGC:SetPen(wx.wxTRANSPARENT_PEN);
        oGC:SetBrush(wx.wxWHITE_BRUSH);
        oGC:DrawRectangle(0, 0, tPage.width, tPage.height);
        for _, tOperation in ipairs(tPlan.operations) do
            if (tOperation.kind == "text") then
                local tStyle = tOperation.piece.style;

                if (tStyle.nativeStyle and tLayout.options.nativeStyle) then
                    local oStyle = tLayout.options.nativeStyle(tStyle);
                    local tMetrics = tLayout.options.measureStyledText(tStyle, tOperation.piece.text);
                    local tDrawing = require("Windows.StyleEditor").drawing(oGC, oDC);

                    oGC:PushState();
                    oGC:Translate(tOperation.x, tOperation.y - tMetrics.ascent);
                    oGC:Scale(0.75, 0.75);
                    oStyle.Draw("PDF preview", tDrawing, oDC, -tMetrics.minX, -tMetrics.minY, tOperation.piece.text);
                    oGC:PopState();
                else
                    fText(tOperation.piece.font, tStyle.size, tOperation.x, tOperation.y, tOperation.piece.text, tStyle.color);
                end
            elseif (tOperation.kind == "rectangle") then
                local tColor = tOperation.color;
                local oColor = wx.wxColour(math.floor(tColor[1] * 255), math.floor(tColor[2] * 255), math.floor(tColor[3] * 255));
                local oBrush = wx.wxBrush(oColor);

                oGC:SetBrush(oBrush);
                oGC:DrawRectangle(tOperation.x, tOperation.y, tOperation.width, tOperation.height);
                oBrush:delete(); oColor:delete();
            elseif (tOperation.kind == "image") then
                local tImage = tOperation.image;
                local oBitmap = tCache.images[tImage];

                if (not oBitmap) then
                    local sBytes = assert(tImage.sourceBytes, "Native preview image snapshot is missing.");
                    local oStream = wx.wxMemoryInputStream(sBytes, #sBytes);
                    local oImage = wx.wxImage(oStream, wx.wxBITMAP_TYPE_ANY);

                    oStream:delete();
                    assert(oImage:IsOk(), "Cannot decode the PDF preview image.");
                    oBitmap = wx.wxBitmap(oImage);
                    oImage:delete();
                    tCache.images[tImage] = oBitmap;
                end
                oGC:DrawBitmap(oBitmap, tOperation.x, tOperation.y, tOperation.width, tOperation.height);
            elseif (tOperation.kind == "contentsNumber") then
                local sNumber = tostring(tLayout.destinations[tOperation.target].page);
                local tStyle = tOperation.style;
                local tFont = tBaseFont;
                local nTextWidth = tLayout.document.measureText(tFont, tStyle.size, sNumber);

                fText(tFont, tStyle.size, tOperation.x + 30 - nTextWidth, tOperation.y + tFont.ascent * tStyle.size / 1000, sNumber, tStyle.color);
            end
        end
        if (tBaseFont and tLayout.options.showHeader ~= false) then
            local nSize = tLayout.options.headerSize or 8;

            fText(tBaseFont, nSize, tPlan.left, tLayout.settings.pdf.bleed * 72 + nSize * 1.5, tLayout.title.." / RULEBOOK", {0.10, 0.12, 0.15});
        end
        if (tBaseFont and tLayout.options.showFooter ~= false) then
            local nSize = tLayout.options.footerSize or 8;
            local sNumber = tostring(nPage);
            local nOutside = (tLayout.settings.pdf.bleed + tLayout.settings.pdf.marginOutside) * 72;
            local nX = nPage % 2 == 1 and tPage.width - nOutside - tLayout.document.measureText(tBaseFont, nSize, sNumber) or nOutside;

            fText(tBaseFont, nSize, nX, tPage.height - tLayout.settings.pdf.bleed * 72 - nSize, sNumber, {0.10, 0.12, 0.15});
        end
    end);
    oGC:delete();
    assert(bOK, sError);
end

--[[!
@fqxn CFS.Manual.Export.Functions.run
@desc Reads the saved manual and produces Web output, PDF print inputs for preview, or a verified PDF. Browser/editor snapshots and chunked HTML are never accepted.
@param table tContext Bound paths and cancellation flag.
@param string sKind web or pdf.
@param table tSettings Native export settings.
@param boolean|nil bPreview Whether to prepare the embedded PDF preview.
@param function|nil fPause Returns control to the window between PDF work intervals.
@return table tResult Output/preview paths and status.
!]]
function Export.run(tContext, sKind, tSettings, bPreview, fPause)
    local tData;
    local tJob;
    local tLayoutOptions;
    local vDocument;
    local bOK, vResult;

    Export.validate(tSettings);
    assert(sKind == "web" or sKind == "pdf", "Unknown manual export type.");
    tContext = setmetatable({kind = sKind, pause = fPause}, {__index = tContext});
    tContext.checkpoint = function() checkpoint(tContext); end;
    checkpoint(tContext);
    if (tContext.onProgress) then tContext.onProgress("preparing", "Reading and checking saved manual sources."); end
    tData = Export.read(tContext);
    checkpoint(tContext);
    tJob = {gameName = tContext.gameName, gameRoot = tContext.gameRoot, manualRoot = tContext.manualRoot,
        exportRoot = tContext.exportRoot, gameCSS = tData.gameCSS, appearanceCSS = tData.appearanceCSS};
    setmetatable(tJob, {__index = tContext});
    if (CFS and CFS.Log and not tContext.logParent) then pcall(CFS.Log.Note, "Manual "..(bPreview and "preview" or "export").." started: "..sKind); end
    bOK, vResult = pcall(function()
        if (sKind == "pdf") then
            local fSaveFonts;
            tLayoutOptions, fSaveFonts = Export.pdfOptions(tContext, tData, tSettings);
            if (tContext.onProgress) then tContext.onProgress("preparing", "Building manual markup for font preflight."); end
            vDocument = PDFLayout.build(tData, tSettings, tLayoutOptions);
            if (fSaveFonts) then fSaveFonts(); end
            do
                local fDispose = vDocument.dispose;

                vDocument.dispose = function()
                    if (vDocument.disposed) then return; end
                    vDocument.disposed = true;
                    if (vDocument.previewCache) then
                        for _, oFont in pairs(vDocument.previewCache.fonts) do oFont:delete(); end
                        for _, oImage in pairs(vDocument.previewCache.images) do oImage:delete(); end
                    end
                    if (fDispose) then fDispose(); end
                end;
            end
        else
            local tIssues = {};
            local function checkIssues()
                if (#tIssues == 0) then return; end
                for _, sIssue in ipairs(tIssues) do
                    if (tContext.onProgress) then tContext.onProgress("warning", "Web preflight: "..sIssue); end
                end
                error("Web preflight failed with "..#tIssues.." issue(s):\n"..table.concat(tIssues, "\n"), 0);
            end
            if (tContext.onProgress) then tContext.onProgress("preflight", "Checking website assets, styles and internal links."); end
            local fAsset = Exporter.preflight(tData, tIssues);
            Document.preflight(tData, fAsset, tIssues);
            checkIssues();
            if (tContext.onProgress) then tContext.onProgress("building", "Building web navigation, glossary and manual sections."); end
            checkpoint(tContext);
            vDocument = Document.build(tData, "web", tSettings);
            if (tContext.onProgress) then tContext.onProgress("fonts", "Resolving fonts used by the web reader."); end
            local _, fSaveFonts, fResolve = fontResolver(tContext, tSettings, true);
            local tRequests = require("Manual.WebFonts").requests(vDocument, tData);
            local tFiles, tFaces, tCSS = {}, {}, {};
            for _, tRequest in ipairs(tRequests) do
                checkpoint(tContext);
                local tFace = fResolve(tRequest.family, tRequest.bold, tRequest.italic);
                if (not tFace) then
                    tIssues[#tIssues + 1] = "Missing web font: "..tRequest.family.." (weight "..tRequest.weight..", "..(tRequest.italic and "italic" or "normal")..").";
                else
                    local sExtension = tFace.path:lower():match("%.([ot]t[fc])$");
                    if (sExtension == "ttc" or sExtension == "otc") then
                        tIssues[#tIssues + 1] = "Web font requires a standalone TTF/OTF file: "..tRequest.family.." ("..tFace.path..").";
                    else
                        local sTarget = tFiles[tFace.path];
                        if (not sTarget) then
                            sTarget = "font-"..(#tFaces + 1).."."..assert(sExtension);
                            tFiles[tFace.path] = sTarget;
                            tFaces[#tFaces + 1] = {source = tFace.path, name = sTarget};
                        end
                        tCSS[#tCSS + 1] = "@font-face { font-family: "..JSON.encode(tRequest.family).."; src: url(\"../fonts/"..sTarget.."\"); font-weight: "..tRequest.weight.."; font-style: "..(tRequest.italic and "italic" or "normal").."; font-display: swap; }";
                    end
                end
            end
            checkIssues();
            tJob.webFonts, tJob.webFontCSS = tFaces, table.concat(tCSS, "\n").."\n";
            vDocument = vDocument:gsub("</head>", '<link rel="stylesheet" href="css/packaged-fonts.css"></head>', 1);
            fSaveFonts();
            if (tContext.onProgress) then
                tContext.onProgress("preflight", "Web preflight passed; "..#tFaces.." font file(s) selected.");
                if (#tFaces > 0) then tContext.onProgress("warning", "This export includes font files. You are responsible for ensuring you have permission to distribute them."); end
                tContext.onProgress("building", "Web HTML assembled ("..#vDocument.." bytes).");
            end
        end
        return Exporter.run(tJob, sKind, vDocument, tSettings, bPreview);
    end);
    if (not bOK) then
        if (tLayoutOptions and tLayoutOptions.dispose) then tLayoutOptions.dispose(); end
        if (CFS and CFS.Log) then pcall(tContext.cancelled and CFS.Log.Warning or CFS.Log.Error, tostring(vResult), tContext.logParent); end
        error(vResult, 2);
    end
    if (CFS and CFS.Log) then pcall(CFS.Log.Note, vResult.message, tContext.logParent); end
    return vResult;
end

--[[!
@fqxn CFS.Manual.Export.Functions.discard
@desc Releases this window's retained preview inputs through the staging service.
@param table tContext Bound export paths.
@param table tPreview Prepared preview.
!]]
function Export.discard(tContext, tPreview)
	Exporter.discard(tContext, tPreview);
end

return Export;
