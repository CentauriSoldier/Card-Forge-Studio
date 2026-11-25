--[[!
@fqxn CFS.Manual.Markdown
@desc Renders manual Markdown on the Lua side. Raw HTML remains literal except for restricted explicit anchors, attribute-free superscript and known style tags. Code spans and blocks are never interpreted as styles.
!]]

local Markdown = {};

--[[!
@fqxn CFS.Manual.Markdown.Functions.escape
@desc Escapes plain text for an HTML attribute or text node.
@param string sText Plain text.
@return string sHTML Escaped text.
!]]
function Markdown.escape(sText)
	return (tostring(sText):gsub("[&<>\"']", {["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&#39;"}));
end

--[[!
@fqxn CFS.Manual.Markdown.Functions.render
@desc Converts headings, paragraphs, nested lists, quotes, fenced/indented code, tables, links, images and inline formatting to portable reader HTML. Options carry the known style names, glossary definitions and PDF image-loading mode.
@param string sSource Markdown source.
@param table|nil tOptions Render options.
@return string sHTML Rendered HTML.
!]]
function Markdown.render(sSource, tOptions)
	local tOptions		= tOptions or {};
	local tReferences	= {};
	local fInline;
	local fBlocks;
	local fCells;
	local fList;
	local fSpecial;
	local tStyles	= tOptions.styles or {};
	local tTerms	= {};
	if (tOptions.autoLinkTerms == true and tOptions.glossary) then
		for sTerm, tEntry in pairs(tOptions.glossary) do
			if (sTerm ~= "") then
				local sPattern = "^"..sTerm:gsub("([^%w%s])", "%%%1"):gsub("%s+", "%%s+");
				tTerms[#tTerms + 1] = {text = sTerm, pattern = sPattern, entry = tEntry};
			end
		end
		table.sort(tTerms, function(tLeft, tRight)
			return #tLeft.text > #tRight.text or (#tLeft.text == #tRight.text and tLeft.text < tRight.text);
		end);
	end
	sSource = sSource:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\0", "\239\191\189");

	--[[!
	@fqxn CFS.Manual.Markdown.Private.Functions.fGlossaryLink
	@desc Uses the existing glossary anchor contract for explicit and automatic links.
	@vis private
	!]]
	local function fGlossaryLink(tEntry, sInside)
		return '<a class="glossary-link" href="#'..Markdown.escape(tEntry.id)..'" data-glossary-title="'..Markdown.escape(tEntry.title)..'" data-glossary-definition="'..Markdown.escape(tEntry.plain)..'" data-glossary-html="'..Markdown.escape(tEntry.html)..'" data-glossary-delay="'..tostring(tOptions.delay or 0)..'">'..sInside..'</a>';
	end

	--[[!
	@fqxn CFS.Manual.Markdown.Private.Functions.fWordPart
	@desc Treats letters, digits, underscores and possessive apostrophes as word continuations. Non-ASCII text is kept whole; Unicode punctuation and symbols delimit words.
	@vis private
	!]]
	local function fWordPart(sText, nByte)
		if (nByte < 1 or nByte > #sText) then return false; end
		local nStart = utf8.offset(sText, 0, nByte);
		local nCode = utf8.codepoint(sText, nStart);
		if (nCode < 128) then return sText:sub(nStart, nStart):match("[%w_']") ~= nil; end
		if (nCode == 0x2019) then return true; end
		return not (nCode == 0xA0 or (nCode >= 0x2000 and nCode <= 0x206F) or (nCode >= 0x2190 and nCode <= 0x2BFF) or (nCode >= 0x3000 and nCode <= 0x303F) or nCode >= 0x1F000);
	end

	--[[!
	@fqxn CFS.Manual.Markdown.Private.Functions.fURL
	@desc Accepts ordinary relative links and explicitly supported schemes. Never emits an application bridge URL or executable scheme.
	@vis private
	!]]
	local function fURL(sURL, bImage)
		local sScheme = sURL:match("^([%a][%w+.-]*):");
		if (sURL:find("[%z\1-\32]") or sURL:find("\\", 1, true)) then return nil; end
		if (sScheme and not ({http = true, https = true, mailto = not bImage, ftp = true})[sScheme:lower()]) then return nil; end
		if (sURL:match("^[^/#?]*&")) then return nil; end
		if (bImage and sURL:lower():match("^images/")) then
			local sPath		= sURL:sub(8);
			local sDecoded	= sPath:gsub("%%(%x%x)", function(sHex) return string.char(tonumber(sHex, 16)); end);
			if (sDecoded:find("\\", 1, true) or sDecoded:find("[%z\1-\31]") or sDecoded:match("^/") or ("/"..sDecoded.."/"):find("/../", 1, true)) then return nil; end
			return "content-images/"..sPath;
		end
		return (sURL:gsub("([^/#?]+%.[mM][dD])#([A-Za-z][A-Za-z0-9_-]*)$", function(sFile, sID)
			return tOptions.files and tOptions.files[sFile] and "#"..sID or sFile.."#"..sID;
		end));
	end

	--[[!
	@fqxn CFS.Manual.Markdown.Private.Functions.fInline
	@desc Scans inline tokens in source order so code, escapes and link destinations are not reinterpreted by later formatting passes.
	@vis private
	!]]
	fInline = function(sText, nDepth, bInLink, bNoAuto)
		local tHTML		= {};
		local nIndex	= 1;
		nDepth = nDepth or 0;
		assert(nDepth < 64, "Manual inline formatting is nested too deeply.");
		while (nIndex <= #sText) do
			local sRest	= sText:sub(nIndex);
			local sChar	= sRest:sub(1, 1);
			local sToken;
			local nUsed;
			if (sChar == "\\" and sRest:sub(2, 2):match("%p")) then
				sToken, nUsed = Markdown.escape(sRest:sub(2, 2)), 2;
			elseif (sRest:sub(1, 2) == "\\\n") then sToken, nUsed = "<br>\n", 2;
			elseif (sChar == "`") then
				local sRun		= sRest:match("^`+");
				local nClose	= #sRun + 1;
				while (true) do
					local nStart, nEnd = sRest:find("`+", nClose);
					if (not nStart) then break; end
					if (nEnd - nStart + 1 == #sRun) then
						local sCode = sRest:sub(#sRun + 1, nStart - 1):gsub("\n", " ");
						if (sCode:match("^ .+ $") and sCode:find("[^ ]")) then sCode = sCode:sub(2, -2); end
						sToken, nUsed = "<code>"..Markdown.escape(sCode).."</code>", nEnd;
						break;
					end
					nClose = nEnd + 1;
				end
			elseif (sChar == "<") then
				local sAnchor	= sRest:match('^<a id="([A-Za-z][A-Za-z0-9_-]*)"></a>');
				local sPrefix, sName = sRest:match("^<(:?)([A-Za-z_][A-Za-z0-9_-]*)>");
				if (sAnchor) then
					sToken, nUsed = '<a class="manual-anchor" id="'..sAnchor..'"></a>', #sAnchor + 13;
				elseif (sName and (tStyles[sName:lower()] or (sPrefix == "" and (sName:lower() == "g" or sName:lower() == "sup")))) then
					local nLevel, nScan = 1, #sName + #sPrefix + 3;
					while (nLevel > 0) do
						local nStart, nEnd, sSlash, sOtherPrefix, sOther = sRest:find("<(/?)(:?)([A-Za-z_][A-Za-z0-9_-]*)>", nScan);
						if (not nStart) then break; end
						if (sOtherPrefix == sPrefix and sOther:lower() == sName:lower()) then
							nLevel = nLevel + (sSlash == "/" and -1 or 1);
							if (nLevel == 0) then
								local sTag = sName:lower();
								local bBuiltin = sPrefix == "" and (sTag == "sup" or sTag == "g");
								local sKey = not bBuiltin and type(tStyles[sTag]) == "string" and tStyles[sTag] or sTag;
								local sInside	= fInline(sRest:sub(#sName + #sPrefix + 3, nStart - 1), nDepth + 1, bInLink, bNoAuto or (bBuiltin and sTag == "g") or sKey == "keyword");
								local sStyled	= bBuiltin and sTag == "sup" and "<sup>"..sInside.."</sup>" or bBuiltin and sTag == "g" and sInside or '<span class="font-'..sKey..'" data-font-style="'..sKey..'" data-inline>'..sInside..'</span>';
								local sPlain	= sInside:gsub("<[^>]*>", ""):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&#39;", "'"):gsub("&quot;", '"');
								local tEntry	= not bInLink and tOptions.glossary and ((bBuiltin and sTag == "g") or (not bBuiltin and sKey == "keyword")) and tOptions.glossary[sPlain:lower()];
								if (tEntry and not sInside:find("data-glossary-title", 1, true)) then
									sStyled = fGlossaryLink(tEntry, sStyled);
								end
								sToken, nUsed = sStyled, nEnd;
								break;
							end
						end
						nScan = nEnd + 1;
					end
				else
                    if (sName and tOptions.onIssue) then tOptions.onIssue("Undefined style tag <"..sPrefix..sName..">."); end
					local sLink	= sRest:match("^<([a-zA-Z][a-zA-Z0-9+.-]*:[^<>%s]+)>");
					local sMail	= sRest:match("^<([%w.!#$%%&'*+/=?^_`{|}~-]+@[%w.-]+)>");
					local sURL	= (sLink or sMail) and fURL(sLink or "mailto:"..sMail);
					if (sURL and not bInLink) then sToken, nUsed = '<a href="'..Markdown.escape(sURL)..'">'..Markdown.escape(sLink or sMail)..'</a>', #(sLink or sMail) + 2; end
				end
			elseif ((sChar == "[" and not bInLink) or sRest:sub(1, 2) == "![") then
				local bImage			= sChar == "!";
				local nOpen				= bImage and 2 or 1;
				local nLevel, nClose	= 1, nOpen + 1;
				while (nClose <= #sRest and nLevel > 0) do
					local sAt = sRest:sub(nClose, nClose);
					if (sAt == "\\") then nClose = nClose + 1;
					elseif (sAt == "[") then nLevel = nLevel + 1;
					elseif (sAt == "]") then nLevel = nLevel - 1; end
					if (nLevel > 0) then nClose = nClose + 1; end
				end
				if (nLevel == 0) then
					local sLabel	= sRest:sub(nOpen + 1, nClose - 1);
					local sAfter	= sRest:sub(nClose + 1);
					local sURL, sTitle;
					local nEnd = nClose;
					if (sAfter:sub(1, 1) == "(") then
						local sDestination = sAfter:match("^(%b())");
						if (sDestination) then
							local sValue = sDestination:sub(2, -2):match("^%s*(.-)%s*$");
							sURL, sTitle = sValue:match('^(.-)%s+"(.*)"$');
							if (not sURL) then sURL, sTitle = sValue:match("^(.-)%s+'(.*)'$"); end
							sURL = (sURL or sValue):gsub("^<(.*)>$", "%1"):gsub("\\(%p)", "%1");
							nEnd = nClose + #sDestination;
						end
					else
						local sRef	= sAfter:match("^%[([^%]]*)%]");
						local tRef	= tReferences[(sRef and sRef ~= "" and sRef or sLabel):lower():gsub("%s+", " ")];
						if (tRef) then sURL, sTitle = tRef.url, tRef.title; nEnd = nClose + (sRef and #sRef + 2 or 0); end
					end
					sURL = sURL and fURL(sURL, bImage);
					if (sURL) then
						local sTitleAttribute = sTitle and ' title="'..Markdown.escape(sTitle)..'"' or "";
						if (bImage) then
							local sAlt = fInline(sLabel, nDepth + 1, true):gsub("<[^>]*>", "");
							sToken = '<img src="'..Markdown.escape(sURL)..'" alt="'..sAlt..'" class="img-fluid source-figure" loading="'..(tOptions.pdf and "eager" or "lazy")..'"'..sTitleAttribute..'>';
						else sToken = '<a href="'..Markdown.escape(sURL)..'"'..sTitleAttribute..'>'..fInline(sLabel, nDepth + 1, true)..'</a>'; end
						nUsed = nEnd;
					end
				end
			elseif (sChar == "*" or sChar == "_" or sRest:sub(1, 2) == "~~") then
				local sMark		= sRest:sub(1, 3) == "***" and "***" or sRest:sub(1, 3) == "___" and "___" or sRest:sub(1, 2) == "~~" and "~~" or sRest:sub(1, 2) == sChar:rep(2) and sChar:rep(2) or sChar;
				local nClose	= sRest:find(sMark, #sMark + 1, true);
				local bWord		= sChar == "_" and nIndex > 1 and sText:sub(nIndex - 1, nIndex - 1):match("[%w_]");
				if (nClose and not bWord and not sRest:sub(#sMark + 1, #sMark + 1):match("%s") and not sRest:sub(nClose - 1, nClose - 1):match("%s")) then
					local sTag = sMark == "~~" and "s" or #sMark == 2 and "strong" or "em";
					sToken = "<"..sTag..">"..(#sMark == 3 and "<strong>" or "")..fInline(sRest:sub(#sMark + 1, nClose - 1), nDepth + 1, bInLink, bNoAuto)..(#sMark == 3 and "</strong>" or "").."</"..sTag..">";
					nUsed = nClose + #sMark - 1;
				end
			elseif (sChar == "&") then
				local sEntity = sRest:match("^&#[xX]%x+;") or sRest:match("^&#%d+;") or sRest:match("^&[A-Za-z][A-Za-z0-9]+;");
				if (sEntity) then sToken, nUsed = sEntity, #sEntity; end
			elseif (sRest:match("^  +\n")) then local sBreak = sRest:match("^  +\n"); sToken, nUsed = "<br>\n", #sBreak; end
			if (not sToken and not bInLink and not bNoAuto and #tTerms > 0 and not fWordPart(sText, nIndex - 1)) then
				for _, tTerm in ipairs(tTerms) do
					local sMatched = sRest:lower():match(tTerm.pattern);
					local nLength = sMatched and #sMatched;
					if (nLength and not fWordPart(sText, nIndex + nLength)) then
						-- Consume an excluded longest match without linking a shorter term inside it.
						local sMatch = Markdown.escape(sRest:sub(1, nLength));
						sToken, nUsed = tTerm.entry.id == tOptions.glossaryEntry and sMatch or fGlossaryLink(tTerm.entry, sMatch), nLength;
						break;
					end
				end
			end
			tHTML[#tHTML + 1] = sToken or Markdown.escape(sChar);
			nIndex = nIndex + (nUsed or 1);
		end
		return table.concat(tHTML);
	end;

	--[[!
	@fqxn CFS.Manual.Markdown.Private.Functions.fCells
	@desc Splits a pipe table row while retaining escaped pipes and code spans.
	@vis private
	!]]
	fCells = function(sLine)
		local tCells, tCell		= {}, {};
		local bCode, bEscape	= false, false;
		sLine = sLine:match("^%s*(.-)%s*$"):gsub("^|", ""):gsub("|$", "");
		for nIndex = 1, #sLine do
			local sChar = sLine:sub(nIndex, nIndex);
			if (sChar == "|" and not bCode and not bEscape) then tCells[#tCells + 1] = table.concat(tCell):match("^%s*(.-)%s*$"); tCell = {};
			else tCell[#tCell + 1] = sChar; end
			if (sChar == "`" and not bEscape) then bCode = not bCode; end
			bEscape = sChar == "\\" and not bEscape;
		end
		tCells[#tCells + 1] = table.concat(tCell):match("^%s*(.-)%s*$");
		return tCells;
	end;

	--[[!
	@fqxn CFS.Manual.Markdown.Private.Functions.fList
	@desc Identifies a list marker and its content indentation.
	@vis private
	!]]
	fList = function(sLine)
		local sIndent, sMark, sSpace, sText = sLine:match("^( *)([-+*])([ \t]+)(.*)$");
		if (not sIndent) then sIndent, sMark, sSpace, sText = sLine:match("^( *)(%d+[.)])([ \t]+)(.*)$"); end
		if (sIndent) then return #sIndent, sMark, #sIndent + #sMark + #sSpace, sText; end
	end;

	--[[!
	@fqxn CFS.Manual.Markdown.Private.Functions.fSpecial
	@desc Recognizes block starts that terminate a paragraph.
	@vis private
	!]]
	fSpecial = function(sLine)
		local sTrim = sLine:match("^%s*(.-)%s*$");
		return sTrim == "" or sLine:match("^ ? ? ?#+%s") or sLine:match("^ ? ? ?>") or sLine:match("^ ? ? ?```") or sLine:match("^ ? ? ?~~~") or fList(sLine) ~= nil or sTrim:match("^%-%-%-[- ]*$") or sTrim:match("^%*%*%*[* ]*$") or sTrim:match("^___[_ ]*$");
	end;

	--[[!
	@fqxn CFS.Manual.Markdown.Private.Functions.fBlocks
	@desc Recursively renders block containers, preserving nested list and quote structure.
	@vis private
	!]]
	fBlocks = function(tLines, nDepth)
		local tHTML		= {};
		local nIndex	= 1;
		assert(nDepth < 64, "Manual block formatting is nested too deeply.");
		while (nIndex <= #tLines) do
			local sLine								= tLines[nIndex];
			local sTrim								= sLine:match("^%s*(.-)%s*$");
			local sFence, sLanguage					= sLine:match("^ ? ? ?(```+)(.*)$");
			local nIndent, sMark, nContent, sItem	= fList(sLine);
			local sHeading, sText					= sLine:match("^ ? ? ?(#+)%s+(.*)$");
			if (not sFence) then sFence, sLanguage = sLine:match("^ ? ? ?(~~~+)(.*)$"); end
			if (sTrim == "") then nIndex = nIndex + 1;
			elseif (sFence) then
				local tCode = {};
				nIndex = nIndex + 1;
				while (nIndex <= #tLines) do
					local sClose = tLines[nIndex]:match("^ ? ? ?([`~]+)%s*$");
					if (sClose and sClose:sub(1, 1) == sFence:sub(1, 1) and #sClose >= #sFence) then nIndex = nIndex + 1; break; end
					tCode[#tCode + 1] = tLines[nIndex]; nIndex = nIndex + 1;
				end
				local sClass = sLanguage:match("^%s*(%S+)");
				tHTML[#tHTML + 1] = '<pre><code'..(sClass and ' class="language-'..Markdown.escape(sClass)..'"' or "")..'>'..Markdown.escape(table.concat(tCode, "\n")..(#tCode > 0 and "\n" or ""))..'</code></pre>';
			elseif (sLine:match("^    ")) then
				local tCode = {};
				while (nIndex <= #tLines and (tLines[nIndex]:match("^    ") or tLines[nIndex]:match("^%s*$"))) do tCode[#tCode + 1] = tLines[nIndex]:gsub("^    ", ""); nIndex = nIndex + 1; end
				tHTML[#tHTML + 1] = "<pre><code>"..Markdown.escape(table.concat(tCode, "\n"):gsub("\n+$", "").."\n").."</code></pre>";
			elseif (sHeading and #sHeading <= 6) then
				tHTML[#tHTML + 1] = "<h"..#sHeading..">"..fInline(sText:gsub("%s+#+%s*$", ""), nil, false, true).."</h"..#sHeading..">"; nIndex = nIndex + 1;
			elseif (sTrim:match("^%-%-%-[- ]*$") or sTrim:match("^%*%*%*[* ]*$") or sTrim:match("^___[_ ]*$")) then tHTML[#tHTML + 1] = "<hr>"; nIndex = nIndex + 1;
			elseif (sLine:match("^ ? ? ?>")) then
				local tQuote = {};
				while (nIndex <= #tLines and tLines[nIndex]:match("^ ? ? ?>")) do tQuote[#tQuote + 1] = tLines[nIndex]:gsub("^ ? ? ?> ?", ""); nIndex = nIndex + 1; end
				tHTML[#tHTML + 1] = "<blockquote>\n"..fBlocks(tQuote, nDepth + 1).."</blockquote>";
			elseif (nIndent and nIndent < 4) then
				local bOrdered	= sMark:match("^%d") ~= nil;
				local sTag		= bOrdered and "ol" or "ul";
				local tItems	= {};
				local bLoose	= false;
				local nStart	= tonumber(sMark:match("^(%d+)"));
				while (nIndex <= #tLines) do
					local nThis, sThis, nWidth, sFirst = fList(tLines[nIndex]);
					if (nThis ~= nIndent or (sThis:match("^%d") ~= nil) ~= bOrdered or sThis:sub(-1) ~= sMark:sub(-1)) then break; end
					local tItem = {sFirst};
					nIndex = nIndex + 1;
					while (nIndex <= #tLines) do
						local sNext	= tLines[nIndex];
						local nNext	= fList(sNext);
						if (nNext and nNext <= nIndent) then break; end
						if (sNext:match("^%s*$")) then
							local nAfterBlank = nIndex + 1;
							while (tLines[nAfterBlank] and tLines[nAfterBlank]:match("^%s*$")) do nAfterBlank = nAfterBlank + 1; end
							local sAfter	= tLines[nAfterBlank];
							local nAfter	= sAfter and fList(sAfter);
							if (not sAfter or (not nAfter and #(sAfter:match("^ *")) < nWidth)) then break; end
							bLoose = true; tItem[#tItem + 1] = "";
						elseif (#(sNext:match("^ *")) >= nWidth) then tItem[#tItem + 1] = sNext:sub(nWidth + 1);
						elseif (not fSpecial(sNext)) then tItem[#tItem + 1] = sNext;
						else break; end
						nIndex = nIndex + 1;
					end
					tItems[#tItems + 1] = tItem;
				end
				tHTML[#tHTML + 1] = "<"..sTag..(nStart and nStart ~= 1 and ' start="'..nStart..'"' or "")..">";
				for _, tItem in ipairs(tItems) do
					local sBody = fBlocks(tItem, nDepth + 1);
					if (not bLoose) then sBody = sBody:gsub("^<p>(.-)</p>", "%1"); end
					tHTML[#tHTML + 1] = "<li>"..sBody.."</li>";
				end
				tHTML[#tHTML + 1] = "</"..sTag..">";
			elseif (tLines[nIndex + 1] and sLine:find("|", 1, true) and tLines[nIndex + 1]:match("^%s*|?%s*:?-+")) then
				local tHead		= fCells(sLine);
				local tAlign	= fCells(tLines[nIndex + 1]);
				local bTable	= #tHead == #tAlign;
				for _, sCell in ipairs(tAlign) do if (not sCell:match("^:?-+:?$")) then bTable = false; end end
				if (bTable) then
					tHTML[#tHTML + 1] = '<div class="table-responsive"><table class="table table-striped table-bordered align-middle"><thead><tr>';
					local function fRow(tCells, sCellTag)
						local tRow = {};
						for nCell = 1, #tHead do
							local sAlignment = tAlign[nCell]:match("^:.*:$") and "center" or tAlign[nCell]:match(":$") and "right" or tAlign[nCell]:match("^:") and "left";
							tRow[#tRow + 1] = "<"..sCellTag..(sAlignment and ' style="text-align:'..sAlignment..'"' or "")..">"..fInline(tCells[nCell] or "", nil, false, sCellTag == "th").."</"..sCellTag..">";
						end
						return table.concat(tRow);
					end
					tHTML[#tHTML + 1] = fRow(tHead, "th").."</tr></thead><tbody>";
					nIndex = nIndex + 2;
					while (nIndex <= #tLines and tLines[nIndex]:find("|", 1, true) and tLines[nIndex]:find("%S")) do tHTML[#tHTML + 1] = "<tr>"..fRow(fCells(tLines[nIndex]), "td").."</tr>"; nIndex = nIndex + 1; end
					tHTML[#tHTML + 1] = "</tbody></table></div>";
				else tHTML[#tHTML + 1] = "<p>"..fInline(sLine).."</p>"; nIndex = nIndex + 1; end
			elseif (tLines[nIndex + 1] and (tLines[nIndex + 1]:match("^ ? ? ?===+%s*$") or tLines[nIndex + 1]:match("^ ? ? ?%-%-%-+%s*$"))) then
				local nLevel = tLines[nIndex + 1]:find("=", 1, true) and 1 or 2;
				tHTML[#tHTML + 1] = "<h"..nLevel..">"..fInline(sLine, nil, false, true).."</h"..nLevel..">"; nIndex = nIndex + 2;
			else
				local tParagraph = {sLine};
				nIndex = nIndex + 1;
				while (nIndex <= #tLines and not fSpecial(tLines[nIndex])) do
					if (tLines[nIndex + 1] and tLines[nIndex]:find("|", 1, true) and tLines[nIndex + 1]:match("^%s*|?%s*:?-+")) then break; end
					tParagraph[#tParagraph + 1] = tLines[nIndex]; nIndex = nIndex + 1;
				end
				tHTML[#tHTML + 1] = "<p>"..fInline(table.concat(tParagraph, "\n")).."</p>";
			end
		end
		return table.concat(tHTML, "\n")..(#tHTML > 0 and "\n" or "");
	end;

	local tLines	= {};
	local bFence	= false;
	for sLine in (sSource.."\n"):gmatch("([^\n]*)\n") do
		local sKey, sURL, sTitle = sLine:match('^ ? ? ?%[([^%]]+)%]:%s*<?([^%s>]+)>?%s*"?(.-)"?%s*$');
		if (sLine:match("^ ? ? ?```") or sLine:match("^ ? ? ?~~~")) then bFence = not bFence; end
		if (sKey and not bFence) then tReferences[sKey:lower():gsub("%s+", " ")] = {url = sURL, title = sTitle ~= "" and sTitle or nil}; tLines[#tLines + 1] = "";
		elseif (not bFence and sLine:match("^%s*<!%-%- section:.-%-%->%s*$")) then tLines[#tLines + 1] = "";
		else
			-- Expand block indentation only; tabs inside literal code/text remain data.
			if (not bFence) then
				sLine = sLine:gsub("^[ \t]+", function(sIndent)
					local nColumns = 0;
					for nIndex = 1, #sIndent do nColumns = nColumns + (sIndent:sub(nIndex, nIndex) == "\t" and 4 - nColumns % 4 or 1); end
					return string.rep(" ", nColumns);
				end);
			end
			tLines[#tLines + 1] = sLine;
		end
	end
	return fBlocks(tLines, 0);
end

return Markdown;
