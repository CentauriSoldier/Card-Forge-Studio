-- Native rich-text documents and stable section anchors.
local wx = require("wx");
local Document = {};
local _oXMLHandler;
local function ensureHandler()
    if (not wx.wxRichTextBuffer.FindHandler(wx.wxRICHTEXT_TYPE_XML)) then
        _oXMLHandler = wx.wxRichTextXMLHandler("XML", "xml", wx.wxRICHTEXT_TYPE_XML);
        wx.wxRichTextBuffer.AddHandler(_oXMLHandler);
    end
end
local function temporary(fCallback)
    local oFile = wx.wxFile();
    local pFile = wx.wxFileName.CreateTempFileName(wx.wxFileName.GetTempDir().."/CFS-Wiki-", oFile);
    oFile:Close(); oFile:delete();
    assert(pFile ~= "", "Could not create a wiki working file.");
    local bOK, vResult = pcall(fCallback, pFile);
    wx.wxRemoveFile(pFile);
    assert(bOK, vResult);
    return vResult;
end
function Document.capture(oEditor)
    ensureHandler();
    return temporary(function(pFile)
        local bModified = oEditor:IsModified();
        local bSaved = oEditor:GetBuffer():SaveFile(pFile, wx.wxRICHTEXT_TYPE_XML);
        oEditor:GetBuffer():Modify(bModified);
        assert(bSaved, "Could not capture the wiki page.");
        local hFile = assert(io.open(pFile, "rb")); local sXML = assert(hFile:read("a")); hFile:close();
        -- Theme defaults belong to the window; explicit span colors stay in the document.
        sXML = sXML:gsub("(<[%w]+)([^>]*)(>)", function(sStart, sAttributes, sEnd)
            if (sStart ~= "<paragraphlayout" and sStart ~= "<table" and sStart ~= "<cell") then return sStart..sAttributes..sEnd; end
            return sStart..sAttributes:gsub(' textcolor="[^"]*"', ""):gsub(' bgcolor="[^"]*"', "")..sEnd;
        end);
        return sXML;
    end);
end
function Document.load(oEditor, sXML)
    ensureHandler();
    oEditor:SetFocusObject(oEditor:GetBuffer());
    oEditor:SetDefaultStyle(wx.wxRichTextAttr());
    if (sXML == "") then oEditor:Clear(); oEditor:DiscardEdits(); return; end
    temporary(function(pFile)
        local hFile = assert(io.open(pFile, "wb")); assert(hFile:write(sXML)); assert(hFile:close());
        assert(oEditor:LoadFile(pFile, wx.wxRICHTEXT_TYPE_XML), "Could not load the wiki page.");
    end);
    oEditor:DiscardEdits();
end
function Document.sections(oEditor)
    local tSections, tSeen = {}, {};
    local oAttribute = wx.wxRichTextAttr();
    for nPosition = 0, oEditor:GetLastPosition() do
        if (oEditor:GetStyle(nPosition, oAttribute)) then
            local sAnchor = oAttribute:GetParagraphStyleName():match("^WikiHeading%d%|(.*)$");
            if (sAnchor and not tSeen[sAnchor]) then
                tSeen[sAnchor] = true;
                local sTitle = oEditor:GetRange(nPosition, math.min(oEditor:GetLastPosition(), nPosition + 300)):match("^[^\r\n]+") or "Section";
                tSections[#tSections + 1] = {anchor = sAnchor, title = sTitle, position = nPosition};
            end
        end
    end
    oAttribute:delete();
    return tSections;
end
function Document.jump(oEditor, sAnchor)
    for _, tSection in ipairs(Document.sections(oEditor)) do
        if (tSection.anchor == sAnchor) then
            oEditor:SetInsertionPoint(tSection.position);
            oEditor:ScrollIntoView(tSection.position, wx.WXK_DOWN);
            return true;
        end
    end
    return false;
end
function Document.heading(oEditor, nLevel)
    local oSelection = oEditor:GetSelectionRange();
    local nPosition = oEditor:HasSelection() and oSelection:GetStart() or oEditor:GetInsertionPoint();
    local nEnd = oEditor:HasSelection() and oSelection:GetEnd() or nPosition;
    local tAnchors = {};
    for _, tSection in ipairs(Document.sections(oEditor)) do tAnchors[tSection.anchor] = tSection.position; end
    repeat
        local oParagraph = oEditor:GetFocusObject():GetParagraphAtPosition(nPosition);
        if (not oParagraph) then break; end
        local oRange = oParagraph:GetRange();
        local oCurrent = wx.wxRichTextAttr(); oEditor:GetStyle(nPosition, oCurrent);
        local sAnchor = oCurrent:GetParagraphStyleName():match("^WikiHeading%d%|(.*)$");
        if (not sAnchor or (tAnchors[sAnchor] and tAnchors[sAnchor] ~= oRange:GetStart())) then
            repeat sAnchor = os.time().."-"..math.random(100000, 999999); until (not tAnchors[sAnchor])
            tAnchors[sAnchor] = oRange:GetStart();
        end
        local a = wx.wxRichTextAttr();
        a:SetLeftIndent(nLevel == 5 and 100 or 0);
        a:SetFontSize(nLevel == 1 and 24 or nLevel == 2 and 19 or nLevel == 3 and 15 or nLevel == 4 and 13 or 11);
        a:SetFontWeight(nLevel > 0 and nLevel < 5 and wx.wxFONTWEIGHT_BOLD or wx.wxFONTWEIGHT_NORMAL);
        a:SetFontStyle(nLevel == 5 and wx.wxFONTSTYLE_ITALIC or wx.wxFONTSTYLE_NORMAL);
        a:SetParagraphStyleName(nLevel > 0 and nLevel < 5 and ("WikiHeading"..nLevel.."|"..sAnchor) or "");
        oEditor:SetStyleEx(wx.wxRichTextRange(oRange:GetStart(), oRange:GetEnd() + 1), a, wx.wxRICHTEXT_SETSTYLE_WITH_UNDO + wx.wxRICHTEXT_SETSTYLE_PARAGRAPHS_ONLY);
        a:delete(); oCurrent:delete(); nPosition = oRange:GetEnd() + 1;
    until (nPosition >= nEnd)
end
local function listParagraph(oEditor, nPosition)
    local oParagraph = oEditor:GetFocusObject():GetParagraphAtPosition(nPosition or oEditor:GetInsertionPoint());
    if (not oParagraph) then return; end
    local oRange = oParagraph:GetRange();
    local a = wx.wxRichTextAttr(); oEditor:GetStyle(oRange:GetStart(), a);
    return oRange, oParagraph:GetTextForRange(oRange), a;
end
local function paragraphStyle(oEditor, oRange, a)
    oEditor:SetStyleEx(wx.wxRichTextRange(oRange:GetStart(), oRange:GetEnd() + 1), a, wx.wxRICHTEXT_SETSTYLE_WITH_UNDO + wx.wxRICHTEXT_SETSTYLE_PARAGRAPHS_ONLY);
end
local function checkboxFont(oEditor, nPosition)
    local a = wx.wxRichTextAttr(); oEditor:GetStyle(nPosition, a);
    if (a:GetFontFaceName() ~= "Segoe UI Symbol") then
        local oDC = wx.wxClientDC(oEditor); local oFont = a:GetFont(); oDC:SetFont(oFont);
        local nTarget = oDC:GetTextExtent("☑");
        oFont:SetFaceName("Segoe UI Symbol"); oFont:SetWeight(wx.wxFONTWEIGHT_NORMAL); oFont:SetStyle(wx.wxFONTSTYLE_NORMAL);
        local nSize = math.max(1, oFont:GetPointSize());
        repeat oFont:SetPointSize(nSize); oDC:SetFont(oFont); if (oDC:GetTextExtent("☐") >= nTarget or nSize >= 72) then break; end nSize = nSize + 1; until false
        local oStyle = wx.wxRichTextAttr(); oStyle:SetFontFaceName("Segoe UI Symbol"); oStyle:SetFontSize(nSize); oStyle:SetFontWeight(wx.wxFONTWEIGHT_NORMAL); oStyle:SetFontStyle(wx.wxFONTSTYLE_NORMAL);
        oEditor:SetStyleEx(wx.wxRichTextRange(nPosition, nPosition + 1), oStyle, wx.wxRICHTEXT_SETSTYLE_CHARACTERS_ONLY);
        oStyle:delete(); oFont:delete(); oDC:delete();
    end
    a:delete();
end
function Document.checkboxes(oEditor)
    local oOriginal = oEditor:GetFocusObject(); local nCaret = oEditor:GetInsertionPoint(); local oSelection = oEditor:GetSelectionRange();
    local oBoxClass = wx.wxClassInfo.FindClass("wxRichTextParagraphLayoutBox"); local oCompositeClass = wx.wxClassInfo.FindClass("wxRichTextCompositeObject");
    local function visit(oObject)
        local oBox = oObject:IsKindOf(oBoxClass) and oObject:DynamicCast("wxRichTextParagraphLayoutBox") or nil;
        if (oBox and not oBox:GetAttributes():GetParagraphStyleName():match("^WikiCode|")) then
            oEditor:SetFocusObject(oBox); local nPosition = 0;
            while true do
                local oParagraph = oBox:GetParagraphAtPosition(nPosition); if (not oParagraph) then break; end
                local oRange = oParagraph:GetRange(); local sText = oParagraph:GetTextForRange(oRange);
                if (sText:sub(1, 3) == "☐" or sText:sub(1, 3) == "☑") then checkboxFont(oEditor, oRange:GetStart()); end
                local nNext = oRange:GetEnd() + 1; if (nNext <= nPosition or nNext > oBox:GetOwnRange():GetEnd()) then break; end nPosition = nNext;
            end
        end
        local oComposite = oObject:IsKindOf(oCompositeClass) and oObject:DynamicCast("wxRichTextCompositeObject") or nil;
        if (oComposite) then local oNode = oComposite:GetChildren():GetFirst(); while (oNode) do visit(oNode:GetData()); oNode = oNode:GetNext(); end end
    end
    visit(oEditor:GetBuffer()); oEditor:SetFocusObject(oOriginal); oEditor:SetInsertionPoint(nCaret);
    if (oSelection:GetEnd() > oSelection:GetStart()) then oEditor:SetSelection(oSelection:GetStart(), oSelection:GetEnd()); end
end
function Document.checkbox(oEditor)
    local oRange, sText, a = listParagraph(oEditor);
    if (sText:sub(1, 3) == "☐" or sText:sub(1, 3) == "☑") then a:delete(); return; end
    oEditor:BeginBatchUndo("Insert checkbox");
    a:SetBulletStyle(wx.wxTEXT_ATTR_BULLET_STYLE_NONE); paragraphStyle(oEditor, oRange, a);
    oEditor:SetInsertionPoint(oRange:GetStart()); oEditor:WriteText("☐ "); checkboxFont(oEditor, oRange:GetStart());
    oEditor:EndBatchUndo(); a:delete(); oEditor:SetFocus();
end
function Document.toggleCheck(oEditor, nPosition, bHitOnly)
    local oRange, sText, a = listParagraph(oEditor, nPosition); if (not oRange) then return false; end a:delete();
    local sMark = sText:sub(1, 3);
    if (sMark ~= "☐" and sMark ~= "☑") then return false; end
    if (bHitOnly and nPosition ~= oRange:GetStart()) then return false; end
    checkboxFont(oEditor, oRange:GetStart());
    local nStart = oRange:GetStart(); local nCaret = oEditor:GetInsertionPoint();
    local oMarkStyle = wx.wxRichTextAttr(); oEditor:GetStyle(nStart, oMarkStyle);
    oEditor:Freeze(); oEditor:BeginBatchUndo("Toggle checkbox");
    oEditor:Replace(nStart, nStart + 1, sMark == "☐" and "☑" or "☐");
    oEditor:SetStyleEx(wx.wxRichTextRange(nStart, nStart + 1), oMarkStyle, wx.wxRICHTEXT_SETSTYLE_WITH_UNDO + wx.wxRICHTEXT_SETSTYLE_CHARACTERS_ONLY);
    oEditor:EndBatchUndo(); oMarkStyle:delete(); oEditor:SetInsertionPoint(nCaret);
    oEditor:GetBuffer():Invalidate(wx.wxRICHTEXT_ALL); oEditor:LayoutContent(); oEditor:Thaw(); oEditor:Refresh(false);
    return true;
end
function Document.listEnter(oEditor)
    local oRange, sText, a = listParagraph(oEditor); if (not oRange) then return false; end
    local bCheck = sText:sub(1, 3) == "☐" or sText:sub(1, 3) == "☑";
    if (not bCheck and a:GetBulletStyle() == wx.wxTEXT_ATTR_BULLET_STYLE_NONE) then a:delete(); return false; end
    oEditor:BeginBatchUndo("New list item");
    if ((bCheck and sText:sub(4):match("^%s*$")) or sText:match("^%s*$")) then
        if (bCheck) then oEditor:Replace(oRange:GetStart(), oRange:GetEnd(), ""); end
        a:SetBulletStyle(wx.wxTEXT_ATTR_BULLET_STYLE_NONE); a:SetBulletName(""); a:SetBulletNumber(0); a:SetLeftIndent(0, 0);
        paragraphStyle(oEditor, oRange, a);
    else
        local nNext = a:GetBulletNumber() + 1;
        oEditor:Newline(); local oNext = oEditor:GetFocusObject():GetParagraphAtPosition(oEditor:GetInsertionPoint()):GetRange();
        if (a:GetBulletStyle() & (wx.wxTEXT_ATTR_BULLET_STYLE_ARABIC + wx.wxTEXT_ATTR_BULLET_STYLE_LETTERS_LOWER + wx.wxTEXT_ATTR_BULLET_STYLE_ROMAN_LOWER)) ~= 0 then a:SetBulletNumber(nNext); end
        paragraphStyle(oEditor, oNext, a);
        if (bCheck) then oEditor:WriteText("☐ "); checkboxFont(oEditor, oNext:GetStart()); end
    end
    oEditor:EndBatchUndo(); a:delete(); return true;
end
function Document.listIndent(oEditor, bOutdent)
    local oRange, sText, a = listParagraph(oEditor); if (not oRange) then return false; end
    local bCheck = sText:sub(1, 3) == "☐" or sText:sub(1, 3) == "☑";
    if (not bCheck and a:GetBulletStyle() == wx.wxTEXT_ATTR_BULLET_STYLE_NONE) then a:delete(); return false; end
    local nIndent = math.max(60, a:GetLeftIndent() + (bOutdent and -80 or 80)); a:SetLeftIndent(nIndent, bCheck and 0 or 40);
    if ((a:GetBulletStyle() & (wx.wxTEXT_ATTR_BULLET_STYLE_ARABIC + wx.wxTEXT_ATTR_BULLET_STYLE_LETTERS_LOWER + wx.wxTEXT_ATTR_BULLET_STYLE_ROMAN_LOWER)) ~= 0) then
        local nLevel = math.floor((nIndent - 60) / 80) % 3;
        a:SetBulletStyle((nLevel == 0 and wx.wxTEXT_ATTR_BULLET_STYLE_ARABIC or nLevel == 1 and wx.wxTEXT_ATTR_BULLET_STYLE_LETTERS_LOWER or wx.wxTEXT_ATTR_BULLET_STYLE_ROMAN_LOWER) + wx.wxTEXT_ATTR_BULLET_STYLE_PERIOD);
        local nNumber = 1; local nPrevious = oRange:GetStart() - 1;
        while (nPrevious >= 0) do
            local oPreviousRange, _, oPrevious = listParagraph(oEditor, nPrevious);
            if (not oPreviousRange) then break; end
            if (oPrevious:GetLeftIndent() == nIndent and oPrevious:GetBulletStyle() == a:GetBulletStyle()) then nNumber = oPrevious:GetBulletNumber() + 1; oPrevious:delete(); break; end
            local bStop = oPrevious:GetBulletStyle() == wx.wxTEXT_ATTR_BULLET_STYLE_NONE or oPrevious:GetLeftIndent() < nIndent;
            oPrevious:delete(); if (bStop) then break; end nPrevious = oPreviousRange:GetStart() - 1;
        end
        a:SetBulletNumber(nNumber);
    end
    paragraphStyle(oEditor, oRange, a); a:delete(); return true;
end
local function codePadding(oStyle)
    local oPadding = oStyle:GetTextBoxAttr():GetPadding();
    oPadding:GetLeft():SetValue(10, wx.wxTEXT_ATTR_UNITS_PIXELS);
    oPadding:GetRight():SetValue(10, wx.wxTEXT_ATTR_UNITS_PIXELS);
    oPadding:GetTop():SetValue(10, wx.wxTEXT_ATTR_UNITS_PIXELS);
    oPadding:GetBottom():SetValue(10, wx.wxTEXT_ATTR_UNITS_PIXELS);
end
function Document.code(oEditor, sLanguage)
    local oFocus = oEditor:GetFocusObject();
    if (oFocus:GetAttributes():GetParagraphStyleName():match("^WikiCode|")) then
        local oStyle = oFocus:GetAttributes(); oStyle:SetParagraphStyleName("WikiCode|"..sLanguage); codePadding(oStyle); oFocus:SetAttributes(oStyle);
        oEditor:MarkDirty(); oEditor:Refresh(); return;
    end
    local sCode = oEditor:HasSelection() and oEditor:GetStringSelection() or "";
    if (oEditor:HasSelection()) then oEditor:DeleteSelection(); end
    local a = wx.wxRichTextAttr();
    a:SetFontFaceName("Consolas"); a:SetFontSize(11);
    a:SetFontWeight(wx.wxFONTWEIGHT_NORMAL); a:SetFontStyle(wx.wxFONTSTYLE_NORMAL);
    a:SetBackgroundColour(wx.wxColour("#303038")); a:SetTextColour(wx.wxColour("#EEEEEE"));
    a:SetParagraphStyleName("WikiCode|"..sLanguage);
    codePadding(a);
    local oBox = oEditor:WriteTextBox(a); oBox:SetBasicStyle(a);
    oEditor:SetFocusObject(oBox); oEditor:SetInsertionPoint(0); oEditor:SetDefaultStyle(a);
    if (sCode ~= "") then oEditor:WriteText(sCode); end
    a:delete(); oEditor:SetFocus();
end
function Document.exitCode(oEditor)
    local oFocus = oEditor:GetFocusObject();
    if (not oFocus:GetAttributes():GetParagraphStyleName():match("^WikiCode|")) then return false; end
    local oParagraph = oFocus:GetParent(); local nPosition = oParagraph:GetRange():GetEnd();
    local oParent = oParagraph:GetParent():DynamicCast("wxRichTextParagraphLayoutBox");
    oEditor:SetFocusObject(oParent); oEditor:SetInsertionPoint(nPosition);
    oEditor:SetDefaultStyle(wx.wxRichTextAttr()); oEditor:Newline(); oEditor:SetFocus();
    return true;
end
function Document.highlight(oEditor, oLexer)
    local stc = wxstc;
    local tLexers = {Lua = "LUA", JavaScript = "CPP", Python = "PYTHON", HTML = "HTML", CSS = "CSS", SQL = "SQL", C = "CPP", ["C++"] = "CPP"};
    local tPrefixes = {Lua = "LUA", JavaScript = "C", Python = "P", HTML = "H", CSS = "CSS", SQL = "SQL", C = "C", ["C++"] = "C"};
    local tKeywords = {Lua = "and break do else elseif end false for function goto if in local nil not or repeat return then true until while", Python = "and as assert async await break class continue def del elif else except False finally for from global if import in is lambda None nonlocal not or pass raise return True try while with yield", JavaScript = "async await break case catch class const continue debugger default delete do else export extends false finally for function if import in instanceof let new null return static super switch this throw true try typeof var void while yield", C = "auto break case char const continue default do double else enum extern float for goto if int long register return short signed sizeof static struct switch typedef union unsigned void volatile while", ["C++"] = "alignas alignof auto bool break case catch char class const constexpr continue default delete do double else enum explicit export extern false float for friend if inline int long namespace new noexcept nullptr operator private protected public return short signed sizeof static struct switch template this throw true try typedef typename union unsigned using virtual void volatile while"};
    tKeywords.SQL = "select from where insert into values update set delete create table drop alter join left right inner outer on as and or not null is group by order having limit distinct union all case when then else end primary key references index view begin commit rollback";
    local oOriginal = oEditor:GetFocusObject(); local oSelection = oEditor:GetSelectionRange(); local nCaret = oEditor:GetInsertionPoint(); local bModified = oEditor:IsModified();
    local oBoxClass = wx.wxClassInfo.FindClass("wxRichTextParagraphLayoutBox");
    local oCompositeClass = wx.wxClassInfo.FindClass("wxRichTextCompositeObject");
    local function visit(oObject)
        local oBox = oObject:IsKindOf(oBoxClass) and oObject:DynamicCast("wxRichTextParagraphLayoutBox") or nil;
        local sLanguage = oBox and oBox:GetAttributes():GetParagraphStyleName():match("^WikiCode|(.*)$");
        if (sLanguage) then
            local oStyle = oBox:GetAttributes(); codePadding(oStyle); oBox:SetAttributes(oStyle);
            oEditor:SetFocusObject(oBox);
            local sText = oBox:GetText(); oLexer:SetLexer(stc["wxSTC_LEX_"..(tLexers[sLanguage] or "NULL")]);
            oLexer:SetKeyWords(0, tKeywords[sLanguage] or ""); oLexer:SetText(sText); oLexer:Colourise(0, -1);
            local tColors = {}; local sPrefix = tPrefixes[sLanguage];
            local function colors(tNames, sColor)
                for _, sName in ipairs(tNames) do local nStyle = sPrefix and stc["wxSTC_"..sPrefix.."_"..sName]; if (nStyle) then tColors[nStyle] = sColor; end end
            end
            colors({"COMMENT", "COMMENTLINE", "COMMENTDOC", "COMMENTBLOCK"}, "#8FAF87");
            colors({"WORD", "WORD2", "WORD3", "TAG", "TAGUNKNOWN", "CLASSNAME", "DEFNAME", "IDENTIFIER2"}, "#C792EA");
            colors({"STRING", "CHARACTER", "LITERALSTRING", "STRINGEOL", "TRIPLE", "TRIPLEDOUBLE", "DOUBLESTRING", "SINGLESTRING"}, "#ECC48D");
            colors({"NUMBER", "VALUE"}, "#F78C6C"); colors({"OPERATOR", "ATTRIBUTE", "PREPROCESSOR"}, "#89DDFF");
            local nPosition, nStart, sLast = 0, 0, nil;
            local function apply(nEnd)
                if (nEnd > nStart) then
                    local a = wx.wxRichTextAttr(); a:SetTextColour(wx.wxColour(sLast));
                    oEditor:SetStyleEx(wx.wxRichTextRange(nStart, nEnd), a, wx.wxRICHTEXT_SETSTYLE_CHARACTERS_ONLY); a:delete();
                end
            end
            for nByte, nCode in utf8.codes(sText) do
                local sColor = tColors[oLexer:GetStyleAt(nByte - 1)] or "#EEEEEE";
                if (sColor ~= sLast) then if (sLast) then apply(nPosition); end nStart = nPosition; sLast = sColor; end
                nPosition = nPosition + wx.wxString(utf8.char(nCode)):Len();
            end
            if (sLast) then apply(nPosition); end
        end
        local oComposite = oObject:IsKindOf(oCompositeClass) and oObject:DynamicCast("wxRichTextCompositeObject") or nil;
        if (oComposite) then local oNode = oComposite:GetChildren():GetFirst(); while (oNode) do visit(oNode:GetData()); oNode = oNode:GetNext(); end end
    end
    visit(oEditor:GetBuffer()); oEditor:SetFocusObject(oOriginal);
    oEditor:SetInsertionPoint(nCaret); if (oSelection:GetEnd() > oSelection:GetStart()) then oEditor:SetSelection(oSelection:GetStart(), oSelection:GetEnd()); end
    Document.checkboxes(oEditor);
    oEditor:GetBuffer():Modify(bModified);
end
function Document.theme(oEditor, sBackground, sForeground)
    local oBackground, oForeground = wx.wxColour(sBackground), wx.wxColour(sForeground);
    local oBoxClass = wx.wxClassInfo.FindClass("wxRichTextParagraphLayoutBox");
    local oCompositeClass = wx.wxClassInfo.FindClass("wxRichTextCompositeObject");
    local function visit(oObject)
        local oBox = oObject:IsKindOf(oBoxClass) and oObject:DynamicCast("wxRichTextParagraphLayoutBox") or nil;
        if (oBox and not oBox:GetAttributes():GetParagraphStyleName():match("^WikiCode|")) then
            local oStyle = oBox:GetBasicStyle();
            oStyle:SetTextColour(oForeground); oStyle:SetBackgroundColour(oBackground);
            oBox:SetBasicStyle(oStyle);
        end
        local oComposite = oObject:IsKindOf(oCompositeClass) and oObject:DynamicCast("wxRichTextCompositeObject") or nil;
        if (oComposite) then
            local oNode = oComposite:GetChildren():GetFirst();
            while (oNode) do visit(oNode:GetData()); oNode = oNode:GetNext(); end
        end
    end
    visit(oEditor:GetBuffer());
    oEditor:SetBackgroundColour(oBackground);
    oEditor:Refresh();
end
return Document;
