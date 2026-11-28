--[[!
@fqxn CFS.Manual.Document
@desc Assembles complete Web and print documents from disk snapshots in Lua. Reuses the reader's existing CSS, artwork, navigation and glossary contracts; no editor HTML or browser DOM is required.
!]]

local Markdown	= require("Manual.Markdown");
local JSON		= require("Manual.Lib.dkjson");
local Document	= {};

--[[!
@fqxn CFS.Manual.Document.Functions.sections
@desc Reads stable section markers in document order, preserving unmarked chapter text. Rejects duplicate generated section IDs.
@param table tData Disk snapshot with ordered chapters.
@return table tSections Canonical sections.
!]]
function Document.sections(tData)
	local tSections	= {};
	local tIDs		= {};
	for _, tChapter in ipairs(tData.chapters) do
        if (tData.context.checkpoint) then tData.context.checkpoint(); end
		local sSource	= tChapter.text:gsub("\r\n", "\n"):gsub("\r", "\n");
		local tMatches	= {};
		local nPosition	= 1;
		while (true) do
			local nStart, nEnd, sMarker, sHashes, sTitle = sSource:find("<!%-%- section: ([^\n]-) %-%->\n(#+)[ \t]+([^\n]+)\n?", nPosition);
			if (not nStart) then break; end
			local sID, sSheet = sMarker:match("^([a-z0-9-]+); quicksheet: ([a-z0-9-]+); source: %d+$");
			if (not sID) then sID = sMarker:match("^([a-z0-9-]+); source: %d+$"); end
			if (sID and #sHashes <= 6) then tMatches[#tMatches + 1] = {first = nStart, last = nEnd, id = sID, sheet = sSheet, level = #sHashes, title = sTitle:gsub("\\([\\`*_%[%]<>|])", "%1")}; end
			nPosition = nEnd + 1;
		end
		if (#tMatches == 0) then
			local sStem	= tChapter.name:sub(1, -4);
			local sID	= "document-"..sStem:gsub("([^A-Za-z0-9_.~-])", function(sChar) return string.format("-%02X", sChar:byte()); end);
			assert(not tIDs[sID], "Duplicate manual section ID: "..sID); tIDs[sID] = true;
			tSections[#tSections + 1] = {id = sID, level = 2, title = sStem, markdown = sSource};
		else
			for nIndex, tMatch in ipairs(tMatches) do
				assert(not tIDs[tMatch.id], "Duplicate manual section ID: "..tMatch.id); tIDs[tMatch.id] = true;
				local sBefore = nIndex == 1 and sSource:sub(1, tMatch.first - 1) or "";
				tSections[#tSections + 1] = {id = tMatch.id, sheet = tMatch.sheet, level = tMatch.level, title = tMatch.title, markdown = sBefore..sSource:sub(tMatch.last + 1, tMatches[nIndex + 1] and tMatches[nIndex + 1].first - 1 or #sSource)};
			end
		end
	end
	assert(#tSections > 0, "The manual has no content to export.");
	return tSections;
end

--[[!
@fqxn CFS.Manual.Document.Functions.build
@desc Builds the portable reader or paginated print input. PDF mode emits semantic content for the Lua layout engine; it includes no browser bootstrap.
@param table tData Read-only manual snapshot.
@param string sKind web or pdf.
@param table tSettings Validated export settings.
@return string sHTML Complete document.
!]]
function Document.build(tData, sKind, tSettings)
	local tSections	= Document.sections(tData);
	local tGroups	= {};
    local nChapterLevel = 6;
    for _, tSection in ipairs(tSections) do nChapterLevel = math.min(nChapterLevel, tSection.level); end
	local tSheets	= {};
	local tStyles	= {};
	local tGlossary	= {};
	local tFiles	= {};
	local bPDF		= sKind == "pdf";
	local sTitle	= Markdown.escape(tData.context.gameName);
	local tOptions;
	local fBody;
	local fNested;
	local tHead		= {'<!doctype html><html lang="en" data-bs-theme="dark"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'..sTitle..'</title>'};
	for _, sCSS in ipairs({tData.gameCSS}) do
		for sName, sCanonical in pairs(require("Manual.FontCSS").lookup(sCSS)) do tStyles[sName] = sCanonical; end
	end
	for _, tChapter in ipairs(tData.chapters) do tFiles[tChapter.name] = true; end
	for nIndex, tSection in ipairs(tSections) do
		if (tSection.level == nChapterLevel) then tGroups[#tGroups + 1] = {section = tSection, children = {}};
		elseif (#tGroups > 0) then tGroups[#tGroups].children[#tGroups[#tGroups].children + 1] = tSection; end
		if (tSection.sheet) then
			local tSheet	= {id = tSection.sheet, title = tSection.title, sections = {tSection}};
			local nNext		= nIndex + 1;
			while (tSections[nNext] and tSections[nNext].level > tSection.level) do tSheet.sections[#tSheet.sections + 1] = tSections[nNext]; nNext = nNext + 1; end
			tSheets[#tSheets + 1] = tSheet;
		end
	end
	tOptions = {styles = tStyles, files = tFiles, pdf = bPDF, delay = tData.glossarySettings.hover_delay_ms};
	local nGlossaryFirst;
	local nGlossaryLast;
	local nGlossaryEntryLevel;
	for nIndex, tSection in ipairs(tSections) do
		if (tSection.id == "glossary") then
			nGlossaryFirst = nIndex + 1;
			nGlossaryLast = nIndex;
			for nNext = nGlossaryFirst, #tSections do
				local tChild = tSections[nNext];
				if (tChild.level <= tSection.level) then break; end
				nGlossaryLast = nNext;
				nGlossaryEntryLevel = math.min(nGlossaryEntryLevel or tChild.level, tChild.level);
			end
			break;
		end
	end
	for nIndex, tSection in ipairs(tSections) do
		if (nGlossaryFirst and nIndex >= nGlossaryFirst and nIndex <= nGlossaryLast and tSection.level == nGlossaryEntryLevel) then
            if (not bPDF and tData.context.onProgress) then tData.context.onProgress("building", "Building glossary entry: "..tSection.title); end
            if (tData.context.checkpoint) then tData.context.checkpoint(); end
			local sDefinition	= Markdown.render(tSection.markdown, tOptions);
			local tEntry		= {id = tSection.id, title = tSection.title, html = sDefinition, plain = sDefinition:gsub("<[^>]*>", " "):gsub("%s+", " ")};
			for _, sTerm in ipairs({tSection.title, table.unpack(tData.alternatives[tSection.id] or {})}) do
				local sKey = sTerm:lower();
				assert(not tGlossary[sKey] or tGlossary[sKey].id == tEntry.id, "Glossary match belongs to more than one entry: "..sTerm);
				tGlossary[sKey] = tEntry;
			end
		end
	end
	tOptions.glossary = tGlossary;
	tOptions.autoLinkTerms = not bPDF and tData.glossarySettings.auto_link_terms == true;
	local tRendered = {};

	--[[!
	@fqxn CFS.Manual.Document.Private.Functions.fBody
	@desc Renders a canonical body once and reuses its bytes for quicksheet copies.
	@vis private
	!]]
	fBody = function(tSection)
		if (not tRendered[tSection]) then
            if (not bPDF and tData.context.onProgress) then tData.context.onProgress("building", "Rendering section: "..tSection.title); end
            if (tData.context.checkpoint) then tData.context.checkpoint(); end
            tOptions.glossaryEntry = nil;
            for _, tEntry in pairs(tGlossary) do
                if (tEntry.id == tSection.id) then tOptions.glossaryEntry = tSection.id; break; end
            end
            tRendered[tSection] = Markdown.render(tSection.markdown, tOptions);
        end
		return tRendered[tSection];
	end;

	--[[!
	@fqxn CFS.Manual.Document.Private.Functions.fNested
	@desc Emits the existing nested section/heading structure with unique quicksheet prefixes.
	@vis private
	!]]
	fNested = function(tItems, sPrefix, bQuick)
		local tOpen, tHTML = {}, {};
		sPrefix = sPrefix or "";
		for nIndex, tSection in ipairs(tItems) do
			local nLevel	= bQuick and nIndex == 1 and 2 or tSection.level;
			local nHeading	= not bPDF and nLevel == 2 and 1 or nLevel;
			local sHeading	= bQuick and nIndex == 1 and "Quicksheet: "..tSection.title or tSection.title;
			local sID		= Markdown.escape(sPrefix..tSection.id);
			while (#tOpen > 0 and tOpen[#tOpen] >= nLevel) do tHTML[#tHTML + 1] = "</section>"; tOpen[#tOpen] = nil; end
			local sClasses	= nLevel <= 3 and "manual-section metal-panel section-level-"..(nLevel == 1 and 2 or nLevel) or "manual-section inset-section section-level-"..nLevel;
			local sBody		= fBody(tSection);
			if (sPrefix ~= "") then
				sBody = sBody:gsub('(<a class="manual%-anchor" id=")([^"]+)', "%1"..sPrefix.."%2");
			end
			tHTML[#tHTML + 1] = '<section class="'..sClasses..' manual-heading-level-'..tSection.level..'" id="'..sID..'" data-section="'..sID..'"'..(nLevel == nChapterLevel and ' data-chapter="'..sID..'"' or "")..'><div class="section-heading"><span class="heading-anchor" aria-hidden="true"></span><h'..nHeading..'>'..Markdown.escape(sHeading)..'</h'..nHeading..'></div><div class="section-copy">'..sBody..'</div>';
			tOpen[#tOpen + 1] = nLevel;
		end
		return table.concat(tHTML)..string.rep("</section>", #tOpen);
	end;
	if (not bPDF) then
        for _, sName in ipairs({"bootstrap.min.css", "intro-preview.css", "Reader.css", "Components.css", "appearance.css", "font-styles.css", "glossary.css"}) do tHead[#tHead + 1] = '<link rel="stylesheet" href="css/'..sName..'">'; end
    end
	if (bPDF) then
		local tTOC, tQuick, tBody	= {}, {}, {};
		for _, tSheet in ipairs(tSheets) do
			local sID = "quick-"..tSheet.id.."-"..tSheet.sections[1].id;
			tTOC[#tTOC + 1] = '<li><a href="#'..sID..'">Quicksheet: '..Markdown.escape(tSheet.title)..'</a></li>';
			tQuick[#tQuick + 1] = fNested(tSheet.sections, "quick-"..tSheet.id.."-", true);
		end
		for nIndex = 2, #tSections do
			local tSection = tSections[nIndex]; tBody[#tBody + 1] = tSection;
			tTOC[#tTOC + 1] = '<li data-level="'..tSection.level..'"><a href="#'..tSection.id..'">'..Markdown.escape(tSection.title)..'</a></li>';
		end
		return table.concat(tHead)..'</head><body><div class="title-assembly pdf-page-header">'..sTitle..' / RULEBOOK</div><main class="manual-shell"><div class="pdf-cover section-copy">'..fBody(tSections[1])..'</div><section class="pdf-contents"><div class="section-heading"><h2>Contents</h2></div><ol class="pdf-toc">'..table.concat(tTOC)..'</ol></section>'..table.concat(tQuick)..fNested(tBody)..'</main></body></html>';
	end
	local tTOC, tSheetTOC, tQuick, tCards	= {}, {}, {}, {};
	local tMetadata							= {groups = {}, sheets = {}};
	for _, tGroup in ipairs(tGroups) do
		local tSection	= tGroup.section;
		local sID		= Markdown.escape(tSection.id);
		local sLabel	= Markdown.escape(tSection.title);
		local tChildren	= {};
		local function fLink(tItem) return '<a data-toc-link data-toc-section="'..tItem.id..'" href="#'..tItem.id..'">'..Markdown.escape(tItem.title)..'</a>'; end
		for _, tChild in ipairs(tGroup.children) do tChildren[#tChildren + 1] = '<li class="toc-depth-'..tChild.level..'">'..fLink(tChild)..'</li>'; end
		if (#tChildren > 0) then
			tTOC[#tTOC + 1] = '<li data-toc-group="'..sID..'"><div class="toc-group-header"><a data-group-link href="#'..sID..'">'..sLabel..'</a><button type="button" class="toc-group-toggle" data-group-toggle aria-label="Expand or collapse '..sLabel..'" aria-expanded="false" aria-controls="toc-'..sID..'"><span aria-hidden="true">▸</span></button></div><ul class="list-unstyled" id="toc-'..sID..'" hidden><li>'..fLink(tSection)..'</li>'..table.concat(tChildren)..'</ul></li>';
		else tTOC[#tTOC + 1] = '<li>'..fLink(tSection)..'</li>'; end
		tMetadata.groups[#tMetadata.groups + 1] = {id = tSection.id, title = tSection.title};
	end
	assert(#tGroups > 0, "The manual needs at least one chapter heading.");
	for _, tSheet in ipairs(tSheets) do
		local sID		= Markdown.escape(tSheet.id);
		local sLabel	= Markdown.escape(tSheet.title);
		tSheetTOC[#tSheetTOC + 1] = '<li><a href="#sheet-'..sID..'">'..sLabel..'</a></li>';
		tCards[#tCards + 1] = '<div class="col-md-6"><article class="quicksheet-card"><h2><a href="#sheet-'..sID..'">'..sLabel..'</a></h2></article></div>';
		tQuick[#tQuick + 1] = '<div data-reader-sheet="'..sID..'" hidden>'..fNested(tSheet.sections, "sheet-"..tSheet.id.."-")..'</div>';
		tMetadata.sheets[#tMetadata.sheets + 1] = {id = tSheet.id, title = tSheet.title, target = tSheet.sections[1].id};
	end
	return table.concat(tHead)..'<script src="js/glossary.js" defer></script><script src="js/bootstrap.bundle.min.js" defer></script><script src="js/Reader.js" defer></script></head><body class="manual-appearance"><a class="visually-hidden-focusable skip-link" href="#main">Skip to content</a><div class="container-xxl manual-shell"><header class="command-header"><div class="title-assembly"><a href="#intro" class="brand-link web-game-title">'..sTitle..'</a><p class="series-label web-manual-subtitle">RULEBOOK</p></div></header><div class="row g-4 g-xl-5 align-items-start"><aside class="col-lg-3"><div class="navigation-assembly metal-panel"><nav class="manual-view-buttons" aria-label="Manual views"><a class="btn btn-sm btn-warning active" id="full-rulebook" href="#intro">Full rulebook</a><a class="btn btn-sm btn-outline-light" id="quicksheet-view" href="#view-quicksheets">Quicksheets</a></nav><label class="toc-accordion-option" title="Expanding a section collapses the other sections."><input type="checkbox" id="reader-accordion" checked> Auto-collapse</label><button class="navigation-toggle" type="button" data-bs-toggle="collapse" data-bs-target="#manual-contents" aria-expanded="true" aria-controls="manual-contents"><span class="status-light" aria-hidden="true"></span><span>CONTENTS</span><span class="toggle-symbol" aria-hidden="true">⌄</span></button><nav class="collapse show" id="manual-contents" aria-label="Table of contents"><ul class="toc list-unstyled" id="reader-chapter-toc">'..table.concat(tTOC)..'</ul><ul class="toc list-unstyled" id="reader-sheet-toc" hidden>'..table.concat(tSheetTOC)..'</ul></nav></div></aside><main class="col-lg-9" id="main"><div class="chapter-strip"><span>THE RULEBOOK</span><span id="reader-chapter-title"></span></div><div class="connected-sections">'..fNested(tSections)..'</div><section id="reader-quicksheets" class="manual-section metal-panel section-level-2" hidden><div class="section-heading"><h1>Quicksheets</h1></div><div class="row g-3">'..table.concat(tCards)..'</div></section>'..table.concat(tQuick)..'<footer class="chapter-footer"><span>'..sTitle..'</span><nav aria-label="Chapter navigation"><a id="reader-previous"></a><a id="reader-next"></a></nav></footer></main></div></div><script type="application/json" id="reader-data">'..JSON.encode(tMetadata):gsub("<", "\\u003c")..'</script></body></html>';
end

--[[!
@fqxn CFS.Manual.Document.Functions.preflight
@desc Checks rendered section fragments with the same Markdown parser used by the website. Collects style, anchor, link and image issues before assembling the full reader.
@param table tData Saved manual snapshot.
@param function fAsset Checks a local output-relative asset reference.
@param table tIssues Accumulated blocking issues.
!]]
function Document.preflight(tData, fAsset, tIssues)
    local tStyles, tFiles, tIDs, tLinks = {}, {}, {}, {};
    local function issue(sMessage) tIssues[#tIssues + 1] = sMessage; end
    local function decode(sText)
        return (sText:gsub("&quot;", '"'):gsub("&#39;", "'"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"));
    end
    local function anchor(sID, sSection)
        if (tIDs[sID]) then issue(sSection..": duplicate anchor #"..sID.." (also in "..tIDs[sID]..").");
        else tIDs[sID] = sSection; end
    end
    for _, sCSS in ipairs({tData.gameCSS}) do
        for sName, sCanonical in pairs(require("Manual.FontCSS").lookup(sCSS)) do tStyles[sName] = sCanonical; end
    end
    for _, tChapter in ipairs(tData.chapters) do tFiles[tChapter.name] = true; end
    local bOK, tSections = pcall(Document.sections, tData);
    if (not bOK) then issue(tostring(tSections)); return; end
    for _, sID in ipairs({"main", "view-quicksheets", "reader-quicksheets", "reader-data", "full-rulebook", "quicksheet-view", "manual-contents", "reader-chapter-toc", "reader-sheet-toc", "reader-chapter-title", "reader-previous", "reader-next", "reader-accordion"}) do anchor(sID, "Website controls"); end
    local tSheets = {};
    for _, tSection in ipairs(tSections) do
        anchor(tSection.id, tSection.title);
        if (tSection.sheet) then
            if (tSheets[tSection.sheet]) then issue("Duplicate quicksheet ID: "..tSection.sheet); end
            tSheets[tSection.sheet] = true;
            anchor("sheet-"..tSection.sheet, tSection.title);
            anchor("sheet-"..tSection.sheet.."-"..tSection.id, tSection.title);
        end
    end
    for _, tSection in ipairs(tSections) do
        if (tData.context.onProgress) then tData.context.onProgress("preflight", "Checking section: "..tSection.title); end
        if (tData.context.checkpoint) then tData.context.checkpoint(); end
        local tOptions = {styles = tStyles, files = tFiles, onIssue = function(sMessage) issue(tSection.title..": "..sMessage); end};
        local bRendered, sHTML = pcall(Markdown.render, tSection.markdown, tOptions);
        if (not bRendered) then issue(tSection.title..": "..tostring(sHTML));
        else
            for sID in sHTML:gmatch('<a class="manual%-anchor" id="([^"]+)"') do anchor(decode(sID), tSection.title); end
            for sURL in sHTML:gmatch('<a href="([^"]+)"') do tLinks[#tLinks + 1] = {url = decode(sURL), section = tSection.title}; end
            for sURL in sHTML:gmatch('<img src="([^"]+)"') do fAsset(decode(sURL), tSection.title); end
        end
    end
    for _, tLink in ipairs(tLinks) do
        local sURL = tLink.url;
        local sAnchor = sURL:match("^#(.*)$") or sURL:match("^index%.html#(.*)$");
        if (sAnchor) then
            local sID = sAnchor:gsub("%%(%x%x)", function(sHex) return string.char(tonumber(sHex, 16)); end);
            if (sID ~= "" and not tIDs[sID]) then issue(tLink.section..": missing link target #"..sID); end
        else fAsset(sURL, tLink.section); end
    end
end

return Document;
