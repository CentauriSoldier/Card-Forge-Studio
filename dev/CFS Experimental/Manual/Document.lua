-- Visual manuals remain HTML. The embedded state describes pages and objects.
local Document = {};

function Document.hex(sText)
    return (sText:gsub(".", function(sChar) return string.format("%02x", sChar:byte()); end));
end

function Document.unhex(sText)
    assert(#sText % 2 == 0 and not sText:find("[^0-9a-fA-F]"), "Invalid manual snapshot.");
    return (sText:gsub("..", function(sPair) return string.char(tonumber(sPair, 16)); end));
end

-- The browser publishes a complete, encoded HTML draft on its root element.
function Document.snapshot(sSource)
    local sHex = sSource:match('data%-cfs%-snapshot="([0-9a-f]+)"');
    return sHex and Document.unhex(sHex) or nil;
end

function Document.attribute(sSource, sName)
    return sSource:match('data%-cfs%-'..sName:gsub("([^%w])", "%%%1")..'="([^"]*)"');
end

return Document;
