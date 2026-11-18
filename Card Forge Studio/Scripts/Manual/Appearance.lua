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
    {key = "Container", label = "Chapter container", selector = ".section-level-2"},
    {key = "Banner", label = "Title banner", selector = ".title-assembly"},
    {key = "Title", label = "Title text", selector = ".web-game-title"},
    {key = "Subtitle", label = "Subtitle text", selector = ".web-manual-subtitle"},
    {key = "Navigation", label = "Contents panel", selector = ".navigation-assembly"},
    {key = "NavigationItem", label = "Contents items", selector = ".toc-group-header"},
    {key = "Table", label = "Tables", selector = ".table"},
    {key = "TableHead", label = "Table headings", selector = ".table th"},
    {key = "TableCell", label = "Table cells", selector = ".table td"},
    {key = "Quote", label = "Quotations", selector = "blockquote"},
    {key = "Code", label = "Code blocks", selector = "pre"},
};
for nLevel = 1, 6 do
    local sLevel = tostring(nLevel);
    local sSection = '.manual-heading-level-'..sLevel;
    for _, tTarget in ipairs({
        {key = 'Section', label = 'section', selector = sSection},
        {key = 'Heading', label = 'heading bar', selector = sSection..' > .section-heading'},
        {key = 'Content', label = 'content backing', selector = sSection..' > .section-copy'},
        {key = 'Rail', label = 'connecting rail', selector = sSection..'::before'},
    }) do
        Appearance.targets[#Appearance.targets + 1] = {key = tTarget.key..sLevel,
            label = string.rep('#', nLevel)..' '..tTarget.label, selector = tTarget.selector,
            textSelector = tTarget.key == 'Heading' and sSection..' > .section-heading > h'..(nLevel == 2 and '1' or sLevel) or nil};
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
    {key = 'textAlign', label = 'Text alignment', css = 'text-align'},
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
    {key = 'frameImage', label = 'Frame (rails and corners)', kind = 'image'},
    {key = 'frameSlice', label = 'Frame slice', css = 'border-image-slice'},
    {key = 'frameWidth', label = 'Frame width', css = 'border-image-width'},
    {key = 'frameRepeat', label = 'Frame repeat', css = 'border-image-repeat'},
    {key = 'top', label = 'Rail vertical position', css = 'top'},
    {key = 'left', label = 'Rail horizontal position', css = 'left'},
    {key = 'display', label = 'Display (none hides)', css = 'display'},
    {key = 'cornerTL', label = 'Top-left corner artwork', kind = 'image'},
    {key = 'cornerTR', label = 'Top-right corner artwork', kind = 'image'},
    {key = 'cornerBL', label = 'Bottom-left corner artwork', kind = 'image'},
    {key = 'cornerBR', label = 'Bottom-right corner artwork', kind = 'image'},
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
function Appearance.validate(tSettings)
    assert(type(tSettings) == 'table' and tSettings.Version == 1 and type(tSettings.Properties) == 'table', 'Invalid manual appearance settings.');
    relative(tSettings.BaseCSS);
    local tTargets, tFields = {}, {};
    for _, tTarget in ipairs(Appearance.targets) do tTargets[tTarget.key] = true; end
    for _, tField in ipairs(Appearance.fields) do tFields[tField.key] = tField; end
    for sTarget, tValues in pairs(tSettings.Properties) do
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
function Appearance.styleNames(pManual)
    local tSeen, tNames = {}, {};
    for _, sFile in ipairs({'font-styles.css'}) do
        local sCSS = require('Manual.FontCSS').generate(pManual..'/..', Documents.read(pManual..'/Styles/'..sFile));
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
            for sSelector in sSelectors:gmatch('[^,]+') do
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
function Appearance.css(pManual, sScope, sImages, tSettings)
    tSettings = tSettings or Appearance.load(pManual);
    Appearance.validate(tSettings);
    local sBase = Documents.read(pManual..'/'..relative(tSettings.BaseCSS));
    sBase = sBase:gsub('{{MANUAL_IMAGES}}', function() return sImages; end);
    local tCSS = {scopeCSS(sBase, sScope)};
    local tStyles = {};
    for _, sFile in ipairs({'font-styles.css'}) do
        local sCSS = require('Manual.FontCSS').generate(pManual..'/..', Documents.read(pManual..'/Styles/'..sFile));
        for sName, sBody in sCSS:gmatch('%.font%-([%w_-]+)%s*{([^{}]*)}') do
            tStyles[sName:lower()] = (tStyles[sName:lower()] or '')..sBody;
        end
    end
    local function image(sPath)
        if (sPath == 'none') then return 'none'; end
        assert(wx.wxFileExists(pManual..'/'..relative(sPath)), 'Missing appearance artwork: '..sPath);
        local sURL = sImages..sPath:sub(8):gsub('([^%w%-%._~/])', function(sChar) return string.format('%%%02X', sChar:byte()); end);
        return 'url("'..sURL..'")';
    end
    for _, tTarget in ipairs(Appearance.targets) do
        local tValues = tSettings.Properties[tTarget.key] or {};
        local sSelector = tTarget.selector == '&' and sScope or sScope..' '..tTarget.selector;
        local tRules = {};
        for _, tField in ipairs(Appearance.fields) do
            local sValue = tValues[tField.key];
            if (sValue and sValue ~= '' and tField.css) then tRules[#tRules + 1] = tField.css..':'..sValue..';'; end
        end
        if (tValues.image and tValues.image ~= '') then tRules[#tRules + 1] = 'background-image:'..image(tValues.image)..';'; end
        if (tValues.frameImage and tValues.frameImage ~= '') then
            tRules[#tRules + 1] = 'border-image-source:'..image(tValues.frameImage)..';';
        end
        if (#tRules > 0) then
            if (tTarget.key:match('^Rail')) then tRules[#tRules + 1] = 'content:"";position:absolute;pointer-events:none;'; end
            tCSS[#tCSS + 1] = sSelector..'{'..table.concat(tRules)..'}';
        end
        if (tValues.textStyle and tValues.textStyle ~= '') then
            local sBody = assert(tStyles[tValues.textStyle:lower()], 'Unknown manual heading text style: '..tValues.textStyle);
            sBody = sBody:gsub('font%-size%s*:[^;]+;', '');
            if (tValues.fontSize and tValues.fontSize ~= '') then sBody = sBody..'font-size:'..tValues.fontSize..';'; end
            tCSS[#tCSS + 1] = (tTarget.textSelector and sScope..' '..tTarget.textSelector or sSelector)..'{'..sBody..'}';
        end
        local tCorners = {};
        for _, sKey in ipairs({'cornerTL', 'cornerTR', 'cornerBL', 'cornerBR'}) do tCorners[#tCorners + 1] = tValues[sKey] and tValues[sKey] ~= '' and image(tValues[sKey]) or 'none'; end
        if (table.concat(tCorners) ~= 'nonenonenonenone') then
            tCSS[#tCSS + 1] = sSelector..'{position:relative;}';
            tCSS[#tCSS + 1] = sSelector..'::after{content:"";position:absolute;inset:0;pointer-events:none;background-image:'..table.concat(tCorners, ',')..';background-position:left top,right top,left bottom,right bottom;background-repeat:no-repeat;background-size:'..(tValues.cornerSize or '24px 24px')..';}';
        end
    end
    return table.concat(tCSS, '\n');
end
return Appearance;
