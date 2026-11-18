--[[!
@fqxn CFS.Manual.WebFonts
@desc Collects font requests from the generated reader and its font declarations. Resolves inherited family, weight and slant for text-bearing elements; browser-only generic families remain generic. Does not inspect font licenses.
!]]
local Documents = require("Manual.Documents");
local WebFonts = {};

--[[!
@fqxn CFS.Manual.WebFonts.Functions.requests
@desc Applies the reader's font selectors to its generated element tree. Collects only requested faces, including hidden chapters and quicksheets. Does not render pages or scan font files.
@param string sHTML Generated reader markup.
@param table tData Saved stylesheet snapshot.
@return table tRequests Unique family/weight/slant requests.
!]]
function WebFonts.requests(sHTML, tData)
    local tNodes, tStack, tRules, tVariables = {}, {}, {}, {};
    local tVoid = {area = true, base = true, br = true, col = true, embed = true, hr = true, img = true, input = true, link = true, meta = true, param = true, source = true, track = true, wbr = true};
    sHTML = sHTML:gsub('<script[^>]*>.-</script>', ''):gsub('<!%-%-.-%-%->', '');
    local nPosition = 1;
    while (true) do
        if (tData.context.checkpoint) then tData.context.checkpoint(); end
        local nFirst, nLast, sMarkup = sHTML:find('<([^>]+)>', nPosition);
        if (not nFirst) then break; end
        local tParent = tStack[#tStack];
        if (tParent and sHTML:sub(nPosition, nFirst - 1):find('%S')) then tParent.text = true; end
        if (sMarkup:sub(1, 1) == '/') then tStack[#tStack] = nil;
        elseif (sMarkup:sub(1, 1) ~= '!') then
            local sTag = assert(sMarkup:match('^([%w]+)'), 'Invalid reader markup.');
            local tNode = {tag = sTag, attributes = {}, parent = tParent};
            for sName, _, sValue in sMarkup:gmatch('([%w_:-]+)%s*=%s*(["\'])(.-)%2') do tNode.attributes[sName] = sValue; end
            tNodes[#tNodes + 1] = tNode;
            if (not tVoid[sTag] and not sMarkup:match('/%s*$')) then tStack[#tStack + 1] = tNode; end
        end
        nPosition = nLast + 1;
    end
    local function trim(sValue) return sValue:match('^%s*(.-)%s*$'); end
    local function rules(sCSS)
        for sSelectors, sBlock in sCSS:gmatch('([^{}]+)(%b{})') do
            sSelectors = trim(sSelectors);
            if (sSelectors:sub(1, 1) == '@') then
                if (sSelectors:match('^@media') and not sSelectors:match('^@media%s+print')) then rules(sBlock:sub(2, -2));
                elseif (sSelectors:match('^@supports') or sSelectors:match('^@layer')) then rules(sBlock:sub(2, -2)); end
            else
                local tProperties = {};
                for sName, sValue in sBlock:sub(2, -2):gmatch('([%w%-]+)%s*:%s*([^;{}]+)') do
                    sValue = trim(sValue);
                    if (sName:sub(1, 2) == '--' and sSelectors:find(':root', 1, true)) then tVariables[sName] = sValue; end
                    if (sName == 'font-family' or sName == 'font-weight' or sName == 'font-style') then tProperties[sName] = sValue; end
                end
                if (next(tProperties)) then
                    for sSelector in sSelectors:gmatch('[^,]+') do
                        sSelector = trim(sSelector);
                        local _, nIDs = sSelector:gsub('#[%w_-]+', '');
                        local _, nClasses = sSelector:gsub('[%.:%[]', '');
                        local nTags = 0;
                        for sPart in sSelector:gmatch('[^%s>+~]+') do if (sPart:match('^%a')) then nTags = nTags + 1; end end
                        tRules[#tRules + 1] = {selector = sSelector, properties = tProperties, score = nIDs * 10000 + nClasses * 100 + nTags};
                    end
                end
            end
        end
    end
    for _, sName in ipairs({'bootstrap.min.css', 'intro-preview.css', 'Reader.css', 'Components.css'}) do
        rules(Documents.read(_Scripts..'/Manual/Web/css/'..sName):gsub('/%*.-%*/', ''));
    end
    rules((tData.appearanceCSS or ''):gsub('/%*.-%*/', ''));
    rules(tData.gameCSS:gsub('/%*.-%*/', ''));
    rules(Documents.read(_Scripts..'/Manual/Web/css/glossary.css'):gsub('/%*.-%*/', ''));
    local function simple(tNode, sPart)
        if (not tNode or sPart:find('::', 1, true)) then return false; end
        local bExcluded = false;
        sPart = sPart:gsub(':not%(([^()]*)%)', function(sNot)
            if (sNot:sub(1, 1) == '.' and (' '..(tNode.attributes.class or '')..' '):find(' '..sNot:sub(2)..' ', 1, true)) then bExcluded = true; end
            return '';
        end);
        if (bExcluded) then return false; end
        sPart = sPart:gsub(':[%w-]+%b()', ''):gsub(':[%w-]+', '');
        local sTag = sPart:match('^([%w-]+)');
        if (sTag and sTag ~= tNode.tag) then return false; end
        for sID in sPart:gmatch('#([%w_-]+)') do if (tNode.attributes.id ~= sID) then return false; end end
        for sClass in sPart:gmatch('%.([%w_-]+)') do
            if (not (' '..(tNode.attributes.class or '')..' '):find(' '..sClass..' ', 1, true)) then return false; end
        end
        for sName in sPart:gmatch('%[([%w_-]+)[^%]]*%]') do if (tNode.attributes[sName] == nil) then return false; end end
        return true;
    end
    local function matches(tNode, sSelector)
        if (sSelector:find('[+~]')) then return false; end
        local tParts = {};
        for sPart in sSelector:gsub('>', ' > '):gmatch('%S+') do tParts[#tParts + 1] = sPart; end
        local nPart = #tParts;
        if (not simple(tNode, tParts[nPart] or '')) then return false; end
        nPart = nPart - 1;
        while (nPart > 0) do
            tNode = tNode.parent;
            if (tParts[nPart] == '>') then
                nPart = nPart - 1;
                if (not simple(tNode, tParts[nPart])) then return false; end
            else
                while (tNode and not simple(tNode, tParts[nPart])) do tNode = tNode.parent; end
                if (not tNode) then return false; end
            end
            nPart = nPart - 1;
        end
        return true;
    end
    local function value(sValue, nDepth)
        nDepth = nDepth or 0;
        assert(nDepth < 16, 'Cyclic font CSS variable.');
        return (sValue:gsub('var%(([^()]*)%)', function(sArguments)
            local sName, sFallback = sArguments:match('^%s*([%w-]+)%s*,?%s*(.-)%s*$');
            return value(tVariables[sName] or sFallback or '', nDepth + 1);
        end));
    end
    local tRequests, tSeen = {}, {};
    local tGeneric = {serif = true, ['sans-serif'] = true, monospace = true, cursive = true, fantasy = true, ['system-ui'] = true, ['ui-serif'] = true, ['ui-sans-serif'] = true, ['ui-monospace'] = true, emoji = true, math = true, fangsong = true};
    for _, tNode in ipairs(tNodes) do
        if (tData.context.checkpoint) then tData.context.checkpoint(); end
        local tInherited = tNode.parent and tNode.parent.font or {};
        local tFont, tScores = {}, {};
        for sName, sValue in pairs(tInherited) do tFont[sName] = sValue; end
        for _, tRule in ipairs(tRules) do
            if (matches(tNode, tRule.selector)) then
                for sName, sValue in pairs(tRule.properties) do
                    local nScore = tRule.score + (sValue:find('!important', 1, true) and 1000000 or 0);
                    if (not tScores[sName] or nScore >= tScores[sName]) then
                        sValue = trim(value(sValue:gsub('%s*!important', '')));
                        if (sValue == 'inherit' or sValue == 'unset') then tFont[sName] = tInherited[sName];
                        else tFont[sName] = sValue; end
                        tScores[sName] = nScore;
                    end
                end
            end
        end
        if ((tNode.tag == 'strong' or tNode.tag == 'b') and not tScores['font-weight']) then tFont['font-weight'] = '700'; end
        if ((tNode.tag == 'em' or tNode.tag == 'i') and not tScores['font-style']) then tFont['font-style'] = 'italic'; end
        tNode.font = tFont;
        -- Empty UI labels can receive navigation text after the page loads.
        if (tNode.text or (tNode.attributes.id and (tNode.tag == 'a' or tNode.tag == 'span'))) then
            local sFamilies = tFont['font-family'] or '';
            local sFamily = trim(sFamilies:match('^([^,]+)') or ''):gsub('^["\'](.-)["\']$', '%1');
            if (sFamily ~= '' and not tGeneric[sFamily:lower()]) then
                local sWeight = tFont['font-weight'] or '400';
                local nWeight = tonumber(sWeight) or ((sWeight == 'bold' or sWeight == 'bolder') and 700 or 400);
                local bItalic = tFont['font-style'] == 'italic' or tFont['font-style'] == 'oblique';
                local sKey = sFamily:lower()..'/'..nWeight..'/'..tostring(bItalic);
                if (not tSeen[sKey]) then
                    tSeen[sKey] = true;
                    tRequests[#tRequests + 1] = {family = sFamily, bold = nWeight >= 600, italic = bItalic, weight = nWeight};
                end
            end
        end
    end
    return tRequests;
end
return WebFonts;
