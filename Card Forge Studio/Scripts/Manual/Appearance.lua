--[[!
@fqxn CFS.Manual.Appearance
@desc Game-owned manual appearance. Lua settings and CSS/artwork remain separate from the game's named text-style framework.
!]]
local wx = require("wx");
local Documents = require("Manual.Documents");
local Serializer = require("LuaEx.lib.serializer");
local Appearance = {};
local _pTemplate = _Scripts.."/../Docs/Templates/Manual";
local _tAssets = {"Panel.svg", "Banner.svg", "Rail.svg", "CornerTL.svg", "CornerTR.svg", "CornerBL.svg", "CornerBR.svg"};
Appearance.targets = {
    {key = "Page", label = "Page", selector = "&"},
    {key = "Layout", label = "Page layout", selector = ".manual-shell"},
    {key = "Sections", label = "All sections — frame and backing", selector = ".manual-section"},
    {key = "Headings", label = "All headings — title bar", selector = ".manual-section > .section-heading", textSelector = ".manual-section > .section-heading > :is(h1,h2,h3,h4,h5,h6)"},
    {key = "BodyText", label = "All sections — body text and backing", selector = ".manual-section > .section-copy"},
    {key = "Accents", label = "All headings — accent", selector = ".heading-anchor"},
    {key = "Container", label = "Chapter container", selector = ".section-level-2"},
    {key = "Banner", label = "Title banner", selector = ".title-assembly"},
    {key = "Title", label = "Title text", selector = ".web-game-title"},
    {key = "Subtitle", label = "Subtitle text", selector = ".web-manual-subtitle"},
    {key = "Navigation", label = "Contents panel", selector = ".navigation-assembly"},
    {key = "NavigationLink", label = "Contents — links", selector = ".toc a"},
    {key = "NavigationHover", label = "Contents — hovered link", selector = ".toc a:hover"},
    {key = "NavigationCurrent", label = "Contents — selected link", selector = ".toc a.is-current"},
    {key = "NavigationToggle", label = "Contents — open / close button", selector = ".navigation-toggle"},
    {key = "NavigationGroupLink", label = "Contents — group title", selector = ".toc-group-header > a"},
    {key = "NavigationGroupCurrent", label = "Contents — selected group", selector = ".toc .has-current > .toc-group-header"},
    {key = "NavigationAccent", label = "Contents — group accent", selector = ".toc-group-header::before"},
    {key = "NavigationOptions", label = "Contents — options", selector = ".toc-accordion-option"},
    {key = "ViewButtonGroup", label = "Contents — view button layout", selector = ".manual-view-buttons"},
    {key = "ViewButtons", label = "Contents — view buttons", selector = ".manual-view-buttons .btn"},
    {key = "ViewButtonActive", label = "Contents — active view button", selector = ".manual-view-buttons .active"},
    {key = "ChapterStrip", label = "Chapter — information strip", selector = ".chapter-strip"},
    {key = "Footer", label = "Chapter — footer", selector = ".chapter-footer"},
    {key = "FooterLink", label = "Chapter — footer links", selector = ".chapter-footer a"},
    {key = "Quicksheet", label = "Quick reference cards", selector = ".quicksheet-card"},
    {key = "Cover", label = "Cover — layered picture", selector = ".manual-cover"},
    {key = "CoverScene", label = "Cover — main picture", selector = ".manual-cover-scene"},
    {key = "CoverTitle", label = "Cover — title picture", selector = ".manual-cover-title"},
    {key = "NavigationItem", label = "Contents items", selector = ".toc-group-header"},
    {key = "Table", label = "Tables", selector = ".table"},
    {key = "TableHead", label = "Table headings", selector = ".table th"},
    {key = "TableHeadStrong", label = "Tables — bold heading text", selector = ".table th strong"},
    {key = "TableCell", label = "Table cells", selector = ".table td"},
    {key = "Quote", label = "Quotations", selector = "blockquote"},
    {key = "Code", label = "Code blocks", selector = "pre"},
    {key = "Paragraph", label = "Text — paragraphs", selector = ".section-copy p"},
    {key = "Strong", label = "Text — bold", selector = "strong"},
    {key = "Emphasis", label = "Text — italic", selector = "em"},
    {key = "Strike", label = "Text — strikethrough", selector = "s"},
    {key = "Superscript", label = "Text — superscript", selector = "sup"},
    {key = "InlineCode", label = "Text — inline code", selector = ":not(pre) > code"},
    {key = "Link", label = "Links — normal", selector = ".section-copy a:not(.manual-anchor)"},
    {key = "LinkHover", label = "Links — hovered", selector = ".section-copy a:not(.manual-anchor):hover"},
    {key = "BulletList", label = "Lists — bulleted", selector = ".section-copy ul"},
    {key = "NumberList", label = "Lists — numbered", selector = ".section-copy ol"},
    {key = "ListItem", label = "Lists — items", selector = ".section-copy li"},
    {key = "ListMarker", label = "Lists — markers", selector = ".section-copy li::marker"},
    {key = "Divider", label = "Dividers", selector = "hr"},
    {key = "Image", label = "Images", selector = ".source-figure"},
    {key = "TableStripe", label = "Tables — alternating rows", selector = ".table tbody tr:nth-child(even) > td"},
    {key = "Glossary", label = "Glossary — layout", selector = ":is(#glossary, .manual-section:has(> .section-heading > #glossary))"},
    {key = "GlossaryIntro", label = "Glossary — introduction", selector = ':is(#glossary, .manual-section:has(> .section-heading > #glossary)) > :is(.section-heading,.section-copy)'},
    {key = "GlossaryParagraph", label = "Glossary — definition paragraphs", selector = '.manual-section:is([id^="glossary-"], :has(> .section-heading > [id^="glossary-"])) > .section-copy :is(p,li)'},
    {key = "GlossaryEntry", label = "Glossary — entries", selector = '.manual-section:is([id^="glossary-"], :has(> .section-heading > [id^="glossary-"]))'},
    {key = "GlossaryHeading", label = "Glossary — entry heading", selector = '.manual-section:is([id^="glossary-"], :has(> .section-heading > [id^="glossary-"])) > .section-heading', textSelector = '.manual-section:is([id^="glossary-"], :has(> .section-heading > [id^="glossary-"])) > .section-heading > :is(h1,h2,h3,h4,h5,h6)'},
    {key = "GlossaryDefinition", label = "Glossary — entry definition", selector = '.manual-section:is([id^="glossary-"], :has(> .section-heading > [id^="glossary-"])) > .section-copy'},
    {key = "GlossaryLink", label = "Glossary — linked terms", selector = ":is(.section-copy a.glossary-link, .glossary-link)"},
    {key = "GlossaryPopup", label = "Glossary — definition popup", selector = ".glossary-popup"},
    {key = "GlossaryPopupTitle", label = "Glossary — popup title", selector = ".glossary-popup > strong"},
    {key = "GlossaryPopupContent", label = "Glossary — popup definition", selector = ".glossary-popup-content"},
};
for nLevel = 1, 6 do
    local sLevel = tostring(nLevel);
    local sSection = '.manual-heading-level-'..sLevel;
    for _, tTarget in ipairs({
        {key = 'Section', label = 'section', selector = sSection},
        {key = 'Heading', label = 'heading bar', selector = sSection..' > .section-heading'},
        {key = 'Content', label = 'content backing', selector = sSection..' > .section-copy'},
        {key = 'Rail', label = 'connecting rail', selector = sSection..'::before'},
        {key = 'Accent', label = 'heading accent', selector = sSection..' > .section-heading > .heading-anchor'},
    }) do
        Appearance.targets[#Appearance.targets + 1] = {key = tTarget.key..sLevel,
            label = string.rep('#', nLevel)..' '..tTarget.label, selector = tTarget.selector,
            textSelector = tTarget.key == 'Heading' and sSection..' > .section-heading > :is(h1,h2,h3,h4,h5,h6)' or nil};
    end
end
Appearance.fields = {
    {key = 'textStyle', label = 'Named text style', kind = 'style'},
    {key = 'background', label = 'Background color / gradient', css = 'background'},
    {key = 'image', label = 'Background image', kind = 'image'},
    {key = 'imageSize', label = 'Image sizing', css = 'background-size'},
    {key = 'imagePosition', label = 'Image position', css = 'background-position'},
    {key = 'imageRepeat', label = 'Image repeat', css = 'background-repeat'},
    {key = 'color', label = 'Text color', css = 'color'},
    {key = 'fontFamily', label = 'Font family', css = 'font-family'},
    {key = 'fontSize', label = 'Text size', css = 'font-size'},
    {key = 'fontWeight', label = 'Text weight', css = 'font-weight'},
    {key = 'lineHeight', label = 'Line height', css = 'line-height'},
    {key = 'fontStyle', label = 'Text slant', css = 'font-style'},
    {key = 'letterSpacing', label = 'Letter spacing', css = 'letter-spacing'},
    {key = 'textDecoration', label = 'Text decoration', css = 'text-decoration'},
    {key = 'textShadow', label = 'Text shadow', css = 'text-shadow'},
    {key = 'listStyleType', label = 'List markers', css = 'list-style-type'},
    {key = 'gridTemplateColumns', label = 'Grid columns', css = 'grid-template-columns'},
    {key = 'columnCount', label = 'Column count', css = 'column-count'},
    {key = 'columnWidth', label = 'Preferred column width', css = 'column-width'},
    {key = 'columnGap', label = 'Column spacing', css = 'column-gap'},
    {key = 'breakInside', label = 'Keep an element together', css = 'break-inside'},
    {key = 'textAlign', label = 'Text alignment', css = 'text-align'},
    {key = 'justifyContent', label = 'Horizontal item alignment', css = 'justify-content'},
    {key = 'alignItems', label = 'Vertical item alignment', css = 'align-items'},
    {key = 'backgroundClip', label = 'Background clipping', css = 'background-clip'},
    {key = 'backgroundOrigin', label = 'Background positioning area', css = 'background-origin'},
    {key = 'backgroundBlend', label = 'Background blending', css = 'background-blend-mode'},
    {key = 'padding', label = 'Inner spacing', css = 'padding'},
    {key = 'margin', label = 'Outer spacing', css = 'margin'},
    {key = 'gap', label = 'Item gap', css = 'gap'},
    {key = 'width', label = 'Width', css = 'width'},
    {key = 'maxWidth', label = 'Maximum width', css = 'max-width'},
    {key = 'height', label = 'Height', css = 'height'},
    {key = 'minHeight', label = 'Minimum height', css = 'min-height'},
    {key = 'borderColor', label = 'Border color', css = 'border-color'},
    {key = 'borderWidth', label = 'Border width', css = 'border-width'},
    {key = 'borderStyle', label = 'Border style', css = 'border-style'},
    {key = 'radius', label = 'Corner radius', css = 'border-radius'},
    {key = 'clip', label = 'Corner cut / clip path', css = 'clip-path'},
    {key = 'shadow', label = 'Shadow', css = 'box-shadow'},
    {key = 'filter', label = 'Visual filter', css = 'filter'},
    {key = 'frameImage', label = 'Frame (rails and corners)', kind = 'image'},
    {key = 'frameSlice', label = 'Frame slice', css = 'border-image-slice'},
    {key = 'frameWidth', label = 'Frame width', css = 'border-image-width'},
    {key = 'frameRepeat', label = 'Frame repeat', css = 'border-image-repeat'},
    {key = 'frameOutset', label = 'Frame outset', css = 'border-image-outset'},
    {key = 'top', label = 'Rail vertical position', css = 'top'},
    {key = 'left', label = 'Rail horizontal position', css = 'left'},
    {key = 'display', label = 'Display (none hides)', css = 'display'},
    {key = 'cornerTL', label = 'Top-left corner artwork', kind = 'image'},
    {key = 'cornerTR', label = 'Top-right corner artwork', kind = 'image'},
    {key = 'cornerBL', label = 'Bottom-left corner artwork', kind = 'image'},
    {key = 'cornerBR', label = 'Bottom-right corner artwork', kind = 'image'},
    {key = 'sourceImage', label = 'Content image for this cover layer', kind = 'image'},
    {key = 'position', label = 'Positioning', css = 'position'},
    {key = 'bottom', label = 'Bottom position', css = 'bottom'},
    {key = 'right', label = 'Right position', css = 'right'},
    {key = 'objectFit', label = 'Picture fit', css = 'object-fit'},
    {key = 'maxHeight', label = 'Maximum height', css = 'max-height'},
    {key = 'aspectRatio', label = 'Aspect ratio', css = 'aspect-ratio'},
    {key = 'overflowWrap', label = 'Long words', css = 'overflow-wrap'},
    {key = 'overflowX', label = 'Horizontal overflow', css = 'overflow-x'},
    {key = 'whiteSpace', label = 'Text wrapping', css = 'white-space'},
    {key = 'columnSpan', label = 'Span all columns', css = 'column-span'},
    {key = 'borderTop', label = 'Top border', css = 'border-top'},
    {key = 'borderRight', label = 'Right border', css = 'border-right'},
    {key = 'borderBottom', label = 'Bottom border', css = 'border-bottom'},
    {key = 'borderLeft', label = 'Left border', css = 'border-left'},
    {key = 'marginBottom', label = 'Space below', css = 'margin-bottom'},
    {key = 'marginTop', label = 'Space above', css = 'margin-top'},
    {key = 'textUnderlineOffset', label = 'Underline offset', css = 'text-underline-offset'},
    {key = 'textDecorationThickness', label = 'Underline thickness', css = 'text-decoration-thickness'},
    {key = 'cornerSize', label = 'Corner artwork size', kind = 'size'},
};
local function relative(sPath)
    assert(type(sPath) == 'string' and sPath ~= '' and not sPath:find('[%z\1-\31\\:]') and sPath:sub(1, 1) ~= '/', 'Use a manual-relative path.');
    for sPart in sPath:gmatch('[^/]+') do assert(sPart ~= '..' and sPart ~= '.', 'Appearance paths cannot leave the manual.'); end
    return sPath;
end
function Appearance.ensure(pManual)
    for _, sFolder in ipairs({'Config', 'Styles', 'Images', 'Images/Appearance', 'Images/Appearance/Defaults'}) do
        local pFolder = pManual..'/'..sFolder;
        assert(wx.wxDirExists(pFolder) or wx.wxMkdir(pFolder), 'Cannot create manual appearance folder: '..pFolder);
    end
    local bNew = not wx.wxFileExists(pManual..'/Config/Appearance.lua');
    do
        for _, sName in ipairs(_tAssets) do
            local pTarget = pManual..'/Images/Appearance/Defaults/'..sName;
            if (not wx.wxFileExists(pTarget)) then assert(wx.wxCopyFile(_Images..'/Manual/Defaults/'..sName, pTarget, false), 'Cannot install default appearance artwork.'); end
        end
    end
    if (bNew) then
        for _, sPath in ipairs({'Styles/Appearance Base.css', 'Config/Appearance.lua'}) do
            if (not wx.wxFileExists(pManual..'/'..sPath)) then assert(wx.wxCopyFile(_pTemplate..'/'..sPath, pManual..'/'..sPath, false), 'Cannot install manual appearance defaults.'); end
        end
    end
end
Appearance.contexts = {
    {key = 'Properties', label = 'All sizes', media = nil},
    {key = 'Tablet', label = 'Tablet / narrow window', media = '(max-width: 991.98px)'},
    {key = 'Phone', label = 'Phone / small window', media = '(max-width: 575.98px)'},
    {key = 'Print', label = 'Print', media = 'print'},
};
function Appearance.validate(tSettings)
    assert(type(tSettings) == 'table' and tSettings.Version == 1 and type(tSettings.Properties) == 'table', 'Invalid manual appearance settings.');
    relative(tSettings.BaseCSS);
    local tTargets, tFields = {}, {};
    for _, tTarget in ipairs(Appearance.targets) do tTargets[tTarget.key] = true; end
    for _, tField in ipairs(Appearance.fields) do tFields[tField.key] = tField; end
    local function fValidateProperties(tProperties)
        assert(type(tProperties) == 'table', 'Appearance properties must be a table.');
        for sTarget, tValues in pairs(tProperties) do
            assert(tTargets[sTarget] and type(tValues) == 'table', 'Unknown manual appearance target: '..tostring(sTarget));
            for sKey, sValue in pairs(tValues) do
                local tField = assert(tFields[sKey], 'Unknown appearance property: '..tostring(sKey));
                assert(not (sTarget:match('^Rail') and sKey:match('^corner') and sValue ~= ''), 'Place corner artwork on a section or heading, not a connecting rail.');
                assert(type(sValue) == 'string' and #sValue <= 4096 and not sValue:find('[%z\1-\31{};<>]'), 'Invalid appearance value: '..sTarget..'.'..sKey);
                if (tField.kind == 'image' and sValue ~= '' and sValue ~= 'none') then
                    relative(sValue); assert(sValue:sub(1, 7) == 'Images/', 'Appearance artwork belongs in Manual/Images.');
                elseif (tField.kind == 'style' and sValue ~= '') then assert(sValue:match('^[A-Za-z_][A-Za-z0-9_-]*$'), 'Invalid named text style.'); end
            end
        end
    end
    local function fValidateTheme(tTheme)
        fValidateProperties(tTheme.Properties);
        for _, tContext in ipairs(Appearance.contexts) do
            if (tContext.media and tTheme[tContext.key]) then fValidateProperties(tTheme[tContext.key]); end
        end
    end
    fValidateTheme(tSettings);
    assert(tSettings.Variants == nil or type(tSettings.Variants) == 'table', 'Invalid section themes.');
    for _, tVariant in ipairs(tSettings.Variants or {}) do
        assert(type(tVariant.Name) == 'string' and #tVariant.Name > 0 and #tVariant.Name <= 80, 'A section theme needs a name.');
        assert(type(tVariant.Sections) == 'table', 'Section themes need section IDs.');
        for _, sID in ipairs(tVariant.Sections) do assert(type(sID) == 'string' and sID:match('^[%w_-]+$'), 'Invalid section ID.'); end
        fValidateTheme(tVariant);
    end
end
function Appearance.load(pManual)
    Appearance.ensure(pManual);
    local sSource = Documents.read(pManual..'/Config/Appearance.lua');
    local tSettings = assert(load(sSource, '@'..pManual..'/Config/Appearance.lua', 't', {serializer = Serializer}))();
    Appearance.validate(tSettings);
    return tSettings, sSource;
end
function Appearance.save(pManual, tSettings, sOriginal)
    Appearance.validate(tSettings);
    local sSource = '-- Manual-specific appearance; named game text styles are referenced, never modified.\nreturn '..Serializer.serialize(tSettings)..';\n';
    return Documents.save(pManual..'/Config/Appearance.lua', sOriginal, sSource);
end
local tFontCache;
local function fontCSS(pManual)
    local sINI = Documents.read(pManual..'/../Styles.ini');
    local sCFG = Documents.read(pManual..'/../Scripts/CFG.lua');
    local sPrevious = Documents.read(pManual..'/Styles/font-styles.css');
    if (tFontCache and tFontCache.root == pManual and tFontCache.ini == sINI and tFontCache.cfg == sCFG and tFontCache.previous == sPrevious) then return tFontCache.css; end
    local sCSS = require('Manual.FontCSS').generate(pManual..'/..', sPrevious);
    assert(Documents.read(pManual..'/../Styles.ini') == sINI and Documents.read(pManual..'/../Scripts/CFG.lua') == sCFG, 'Game styles changed while preparing manual appearance.');
    tFontCache = {root = pManual, ini = sINI, cfg = sCFG, previous = sPrevious, css = sCSS};
    return sCSS;
end
function Appearance.styleNames(pManual)
    local tSeen, tNames = {}, {};
    for _, sFile in ipairs({'font-styles.css'}) do
        local sCSS = fontCSS(pManual);
        for sName in sCSS:gmatch('%.font%-([%w_-]+)%s*{') do
            if (not tSeen[sName]) then tSeen[sName] = true; tNames[#tNames + 1] = sName; end
        end
    end
    table.sort(tNames);
    return tNames;
end
-- Scope appearance to the manual surface, never the editor's controls or Style Editor.
local function scopeCSS(sCSS, sScope)
    local tOutput = {};
    sCSS = sCSS:gsub('/%*.-%*/', '');
    for sSelectors, sBlock in sCSS:gmatch('([^{}]+)(%b{})') do
        sSelectors = sSelectors:match('^%s*(.-)%s*$');
        if (sSelectors:sub(1, 1) == '@') then
            if (sSelectors:match('^@media') or sSelectors:match('^@supports')) then tOutput[#tOutput + 1] = sSelectors..'{'..scopeCSS(sBlock:sub(2, -2), sScope)..'}'; end
        else
            local tSelectors = {};
            -- Commas inside :is(), :has() or quoted attributes are not selector separators.
            local tParts, nStart, nDepth, sQuote = {}, 1, 0, nil;
            for nIndex = 1, #sSelectors do
                local sChar = sSelectors:sub(nIndex, nIndex);
                if (sQuote) then
                    if (sChar == sQuote and sSelectors:sub(nIndex - 1, nIndex - 1) ~= '\\') then sQuote = nil; end
                elseif (sChar == '"' or sChar == "'") then sQuote = sChar;
                elseif (sChar == '(' or sChar == '[') then nDepth = nDepth + 1;
                elseif (sChar == ')' or sChar == ']') then nDepth = nDepth - 1;
                elseif (sChar == ',' and nDepth == 0) then tParts[#tParts + 1] = sSelectors:sub(nStart, nIndex - 1); nStart = nIndex + 1; end
            end
            tParts[#tParts + 1] = sSelectors:sub(nStart);
            for _, sSelector in ipairs(tParts) do
                sSelector = sSelector:match('^%s*(.-)%s*$');
                if (sSelector == ':root' or sSelector == 'body' or sSelector == 'html') then sSelector = sScope;
                elseif (sSelector:match('^body[%s%.#:]')) then sSelector = sScope..sSelector:sub(5);
                else sSelector = sScope..' '..sSelector; end
                tSelectors[#tSelectors + 1] = sSelector;
            end
            tOutput[#tOutput + 1] = table.concat(tSelectors, ',')..sBlock;
        end
    end
    return table.concat(tOutput, '\n');
end
function Appearance.css(pManual, sScope, sImages, tSettings, sFontCSS)
    tSettings = tSettings or Appearance.load(pManual);
    Appearance.validate(tSettings);
    local sBase = Documents.read(pManual..'/'..relative(tSettings.BaseCSS));
    sBase = sBase:gsub('{{MANUAL_IMAGES}}', function() return sImages; end);
    local tCSS = {scopeCSS(sBase, sScope)};
    local tStyles = {};
    for _, sFile in ipairs({'font-styles.css'}) do
        local sCSS = sFontCSS or fontCSS(pManual);
        for sName, sBody in sCSS:gmatch('%.font%-([%w_-]+)%s*{([^{}]*)}') do
            tStyles[sName:lower()] = (tStyles[sName:lower()] or '')..sBody;
        end
        for sAlias, sName in pairs(require('Manual.FontCSS').lookup(sCSS)) do
            if (sAlias ~= sName) then tStyles[sAlias] = tStyles[sName]; end
        end
    end
    local tWarnings = {};
    local function image(sPath, sDefault)
        if (sPath == 'none') then return 'none'; end
        if (not wx.wxFileExists(pManual..'/'..relative(sPath))) then
            tWarnings[#tWarnings + 1] = 'Using default artwork; missing '..sPath;
            sPath = 'Images/Appearance/Defaults/'..sDefault;
            assert(wx.wxFileExists(pManual..'/'..sPath), 'Missing default appearance artwork: '..sPath);
        end
        local sURL = sImages..sPath:sub(8):gsub('([^%w%-%._~/])', function(sChar) return string.format('%%%02X', sChar:byte()); end);
        return 'url("'..sURL..'")';
    end
    local function fSelector(tTarget, sSection, sSuffix)
        sSuffix = sSuffix or "";
        local sSelector = tTarget.selector;
        local tScene, tTitle = tSettings.Properties.CoverScene or {}, tSettings.Properties.CoverTitle or {};
        local function fImageSelector(sPath)
            if (not sPath or sPath == '' or sPath == 'none') then return nil; end
            local sSuffix = sPath:sub(8):gsub('([^%w%-%._~/])', function(sChar) return string.format('%%%02X', sChar:byte()); end);
            return 'img[src$="'..sSuffix..'"],img[src$="'..sPath:sub(8):gsub('"', '\\"')..'"]';
        end
        local sScene, sTitle = fImageSelector(tScene.sourceImage), fImageSelector(tTitle.sourceImage);
        if (tTarget.key == 'CoverScene' and sScene) then sSelector = 'p > :is('..sScene..')';
        elseif (tTarget.key == 'CoverTitle' and sTitle) then sSelector = 'p > :is('..sTitle..')';
        elseif (tTarget.key == 'Cover' and sScene and sTitle) then sSelector = 'p:has(> :is('..sScene..')):has(> :is('..sTitle..'))'; end
        if (not sSection) then return (sSelector == '&' and sScope or sScope..' '..sSelector)..sSuffix; end
        if (sSelector == '&') then return sScope..':has(:is('..sSection..'):not([hidden]):not([hidden] *))'..sSuffix; end
        local sElement, sPseudo = sSelector:match('^(.-)(::[%w-]+)$');
        sElement, sPseudo = sElement or sSelector, sPseudo or '';
        return sScope..' :is('..sSection..'):is('..sElement..')'..sPseudo..sSuffix..','..sScope..' :is('..sSection..') '..sSelector..sSuffix;
    end
    local function fRender(tProperties, sSection)
        for _, tTarget in ipairs(Appearance.targets) do
            local tValues = tProperties[tTarget.key] or {};
            local sSelector = fSelector(tTarget, sSection);
            local tRules = {};
            local tTextRules = {};
            -- Keep the legacy shared container defaults below per-heading custom rules.
            local sPriority = tTarget.key == 'Container' and '' or ' !important';
            for _, tField in ipairs(Appearance.fields) do
                local sValue = tValues[tField.key];
                if (sValue and sValue ~= '' and tField.css) then
                    local sRule = tField.css..':'..sValue..sPriority..';';
                    tRules[#tRules + 1] = sRule;
                    if (tField.key == 'color' or tField.key:match('^font') or tField.key == 'lineHeight') then tTextRules[#tTextRules + 1] = sRule; end
                end
            end
            if (tValues.image and tValues.image ~= '') then tRules[#tRules + 1] = 'background-image:'..image(tValues.image, tTarget.key == 'Banner' and 'Banner.svg' or 'Panel.svg')..' !important;'; end
            if (tValues.frameImage and tValues.frameImage ~= '') then
                tRules[#tRules + 1] = 'border-image-source:'..image(tValues.frameImage, 'Panel.svg')..sPriority..';';
            end
            if (#tRules > 0) then
                if (tTarget.key:match('^Rail')) then tRules[#tRules + 1] = 'content:"";position:absolute;pointer-events:none;'; end
                tCSS[#tCSS + 1] = sSelector..'{'..table.concat(tRules)..'}';
            end
            if (tValues.textStyle and tValues.textStyle ~= '') then
                local sBody = assert(tStyles[tValues.textStyle:lower()], 'Unknown manual heading text style: '..tValues.textStyle);
                sBody = sBody:gsub('font%-size%s*:[^;]+;', '');
                sBody = sBody:gsub('%s*!important', ''):gsub(';', ' !important;');
                tCSS[#tCSS + 1] = (tTarget.textSelector and fSelector({selector = tTarget.textSelector}, sSection) or sSelector)..'{'..sBody..'}';
            end
            if (#tTextRules > 0) then tCSS[#tCSS + 1] = (tTarget.textSelector and fSelector({selector = tTarget.textSelector}, sSection) or sSelector)..'{'..table.concat(tTextRules)..'}'; end
            if (tTarget.key == 'Page' and #tTextRules > 0) then
                tCSS[#tCSS + 1] = sSelector..' :where(p,li,h1,h2,h3,h4,h5,h6,blockquote,td,th){'..table.concat(tTextRules)..'}';
            end
            if ((tTarget.key == 'BodyText' or tTarget.key:match('^Content%d$') or tTarget.key == 'GlossaryDefinition') and #tTextRules > 0) then
                local sBodySelector = fSelector({selector = tTarget.selector..' :where(p,li)'}, sSection);
                tCSS[#tCSS + 1] = sBodySelector..'{'..table.concat(tTextRules)..'}';
            end
            local tCorners, tCornerRules = {}, {};
            local sCornerPrefix = '--manual-corner-'..tTarget.key..'-';
            for _, sKey in ipairs({'cornerTL', 'cornerTR', 'cornerBL', 'cornerBR'}) do
                local sVariable = sCornerPrefix..sKey;
                tCorners[#tCorners + 1] = 'var('..sVariable..',none)';
                if (tValues[sKey] and tValues[sKey] ~= '') then
                    tCornerRules[#tCornerRules + 1] = sVariable..':'..image(tValues[sKey], sKey:gsub('^corner', 'Corner')..'.svg')..';';
                end
            end
            local bCornerArtwork = #tCornerRules > 0;
            if (tValues.cornerSize and tValues.cornerSize ~= '') then
                tCornerRules[#tCornerRules + 1] = sCornerPrefix..'size:'..tValues.cornerSize..';';
            end
            if (#tCornerRules > 0) then tCSS[#tCSS + 1] = sSelector..'{'..table.concat(tCornerRules)..'}'; end
            if (bCornerArtwork) then
                tCSS[#tCSS + 1] = sSelector..'{position:relative;}';
                tCSS[#tCSS + 1] = fSelector(tTarget, sSection, '::after')..'{content:"";position:absolute;inset:0;pointer-events:none;background-image:'..table.concat(tCorners, ',')..';background-position:left top,right top,left bottom,right bottom;background-repeat:no-repeat;background-size:var('..sCornerPrefix..'size,24px 24px);}';
            end
        end
    end
    local function fTheme(tTheme, sSection)
        fRender(tTheme.Properties, sSection);
        for _, tContext in ipairs(Appearance.contexts) do
            if (tContext.media and tTheme[tContext.key]) then
                tCSS[#tCSS + 1] = '@media '..tContext.media..'{';
                fRender(tTheme[tContext.key], sSection);
                tCSS[#tCSS + 1] = '}';
            end
        end
    end
    fTheme(tSettings);
    for _, tVariant in ipairs(tSettings.Variants or {}) do
        local tSections = {};
        for _, sID in ipairs(tVariant.Sections) do
            tSections[#tSections + 1] = '.manual-section:is([data-section="'..sID..'"],#'..sID..',:has(> .section-heading > #'..sID..'))';
        end
        if (#tSections > 0) then fTheme(tVariant, table.concat(tSections, ',')); end
    end
    return table.concat(tCSS, '\n'), tWarnings;
end
return Appearance;
