--[[!
@fqxn CFS.Modules.Wiki.Store
@desc Wiki page and image-asset drafts with stable IDs and conflict-aware disk persistence.
!]]

-- Portable page storage. Stable IDs keep links intact across renames.
local wx = require("wx");
local Store = {};
--[[!
@fqxn CFS.Modules.Wiki.Store.Private.read
@desc Reads binary file contents or returns nil when opening fails; checks successful reading and closing.
@vis private
@param any pFile File path.
!]]
local function read(pFile)
    local hFile = io.open(pFile, "rb");
    if (not hFile) then return nil; end
    local sData = assert(hFile:read("a"));
    assert(hFile:close());
    return sData;
end
--[[!
@fqxn CFS.Modules.Wiki.Store.Private.encode
@desc Encodes bytes as hexadecimal for tab-separated wiki storage.
@vis private
@param any sText Text content.
!]]
local function encode(sText)
    return (sText:gsub(".", function(sChar) return string.format("%02X", sChar:byte()); end));
end
--[[!
@fqxn CFS.Modules.Wiki.Store.Private.decode
@desc Validates hexadecimal storage and decodes the original bytes.
@vis private
@param any sText Text content.
!]]
local function decode(sText)
    assert(#sText % 2 == 0 and not sText:find("[^%x]"), "Malformed wiki data.");
    return (sText:gsub("%x%x", function(sPair) return string.char(tonumber(sPair, 16)); end));
end
--[[!
@fqxn CFS.Modules.Wiki.Store.open
@pulsarlua function Store.open
@desc Loads Wiki.dat, validates page IDs and parent chains, and returns a draft store with stable page IDs.
@param any pRoot Root folder.
!]]
function Store.open(pRoot)
    local pFile = pRoot.."/Wiki.dat";
    local sOriginal = read(pFile);
    assert(sOriginal or not wx.wxFileExists(pFile), "Could not read the wiki.");
    local tPages, nNext = {}, 1;
    if (sOriginal) then
        assert(sOriginal:sub(1, 11) == "CFS-WIKI-1\n", "Unsupported wiki format.");
        for sLine in sOriginal:sub(12):gmatch("[^\n]+") do
            local sID, sParent, sTitle, sXML = sLine:match("^(%d+)\t(%d+)\t(%x+)\t(%x*)$");
            assert(sID, "Malformed wiki page.");
            local nID = tonumber(sID);
            assert(nID > 0 and not tPages[nID], "Duplicate wiki page ID.");
            tPages[nID] = {id = nID, parent = tonumber(sParent), title = decode(sTitle), xml = decode(sXML)};
            nNext = math.max(nNext, nID + 1);
        end
    end
    for nID, tPage in pairs(tPages) do
        local tSeen, nParent = {[nID] = true}, tPage.parent;
        while (nParent ~= 0) do
            assert(tPages[nParent] and not tSeen[nParent], "Wiki contains a missing parent or a cycle.");
            tSeen[nParent] = true; nParent = tPages[nParent].parent;
        end
    end
    local tStore = {pages = tPages, root = pRoot, dirty = false, assets = {}};
    --[[!
    @fqxn CFS.Modules.Wiki.Store.Store.list
    @desc Returns pages sorted by title, breaking equal-title ties by stable ID.
    @vis public
    !]]
    function tStore.list()
        local tRet = {};
        for _, tPage in pairs(tPages) do tRet[#tRet + 1] = tPage; end
        table.sort(tRet, function(a, b)
            if (a.title:lower() == b.title:lower()) then return a.id < b.id; end
            return a.title:lower() < b.title:lower();
        end);
        return tRet;
    end
    --[[!
    @fqxn CFS.Modules.Wiki.Store.Store.add
    @desc Creates a page with a unique ID and validated parent and marks the store dirty.
    @vis public
    @param any sTitle Display title.
    @param any nParent Parent.
    @param any sXML Serialized rich-text XML.
    !]]
    function tStore.add(sTitle, nParent, sXML)
        assert(sTitle:find("%S"), "Enter a page title.");
        assert(nParent == 0 or tPages[nParent], "Parent page is unavailable.");
        local tPage = {id = nNext, parent = nParent, title = sTitle, xml = sXML or ""};
        nNext = nNext + 1; tPages[tPage.id] = tPage; tStore.dirty = true;
        return tPage;
    end
    --[[!
    @fqxn CFS.Modules.Wiki.Store.Store.rename
    @desc Changes a page title while preserving its ID and links.
    @vis public
    @param any nID Page or timer identifier.
    @param any sTitle Display title.
    !]]
    function tStore.rename(nID, sTitle)
        assert(sTitle:find("%S"), "Enter a page title.");
        assert(tPages[nID]).title = sTitle; tStore.dirty = true;
    end
    --[[!
    @fqxn CFS.Modules.Wiki.Store.Store.move
    @desc Changes a page parent after rejecting missing parents and moves beneath the page itself.
    @vis public
    @param any nID Page or timer identifier.
    @param any nParent Parent.
    !]]
    function tStore.move(nID, nParent)
        assert(tPages[nID]);
        local nAncestor = nParent;
        while (nAncestor ~= 0) do
            assert(nAncestor ~= nID, "A page cannot be moved beneath itself.");
            nAncestor = assert(tPages[nAncestor], "Parent page is unavailable.").parent;
        end
        tPages[nID].parent = nParent; tStore.dirty = true;
    end
    --[[!
    @fqxn CFS.Modules.Wiki.Store.Store.remove
    @desc Deletes a page only after its child pages have been moved or removed.
    @vis public
    @param any nID Page or timer identifier.
    !]]
    function tStore.remove(nID)
        for _, tPage in pairs(tPages) do assert(tPage.parent ~= nID, "Move or delete the subpages first."); end
        assert(tPages[nID]); tPages[nID] = nil; tStore.dirty = true;
    end
    --[[!
    @fqxn CFS.Modules.Wiki.Store.Store.update
    @desc Replaces a page XML draft and marks the store dirty only when content changes.
    @vis public
    @param any nID Page or timer identifier.
    @param any sXML Serialized rich-text XML.
    !]]
    function tStore.update(nID, sXML)
        local tPage = assert(tPages[nID]);
        if (tPage.xml ~= sXML) then tPage.xml = sXML; tStore.dirty = true; end
    end
    --[[!
    @fqxn CFS.Modules.Wiki.Store.Store.image
    @desc Reads an image into the asset draft and allocates an unused Assets filename.
    @vis public
    @param any pSource Source.
    !]]
    function tStore.image(pSource)
        local sData = assert(read(pSource), "Could not read the image.");
        local sExtension = (pSource:match("%.([%w]+)$") or "img"):lower();
        local nAsset, sName = 1;
        repeat
            sName = "Image-"..nAsset.."."..sExtension; nAsset = nAsset + 1;
        until (not tStore.assets[sName] and not wx.wxFileExists(pRoot.."/Assets/"..sName))
        tStore.assets[sName] = sData; tStore.dirty = true;
        return sName;
    end
    --[[!
    @fqxn CFS.Modules.Wiki.Store.Store.save
    @desc Checks external changes, stages assets and wiki data, backs up existing data, and retains the draft on failure.
    @vis public
    !]]
    function tStore.save()
        assert(read(pFile) == sOriginal, "The wiki changed externally. Your draft has been kept.");
        assert(wx.wxDirExists(pRoot) or wx.wxFileName.Mkdir(pRoot, 511, wx.wxPATH_MKDIR_FULL), "Could not create the Wiki folder.");
        if (next(tStore.assets)) then
            local pAssets = pRoot.."/Assets";
            assert(wx.wxDirExists(pAssets) or wx.wxFileName.Mkdir(pAssets, 511, wx.wxPATH_MKDIR_FULL), "Could not create Assets.");
            for sName, sData in pairs(tStore.assets) do
                local pAsset = pAssets.."/"..sName;
                if (wx.wxFileExists(pAsset)) then assert(read(pAsset) == sData, "An image asset changed externally.");
                else
                    local oAssetFile = wx.wxFile();
                    local pAssetTemp = wx.wxFileName.CreateTempFileName(pAssets.."/Image-save-", oAssetFile);
                    oAssetFile:Close(); oAssetFile:delete();
                    assert(pAssetTemp ~= "", "Could not create an image working file.");
                    local bOK, sError = pcall(function()
                        local hAsset = assert(io.open(pAssetTemp, "wb"));
                        local bWritten, sFailure = hAsset:write(sData); local bClosed = hAsset:close();
                        assert(bWritten and bClosed, sFailure or "Could not copy the image.");
                        assert(not wx.wxFileExists(pAsset), "An image with this name appeared during saving.");
                        assert(wx.wxRenameFile(pAssetTemp, pAsset, false), "Could not copy the image into Assets.");
                    end);
                    if (wx.wxFileExists(pAssetTemp)) then wx.wxRemoveFile(pAssetTemp); end
                    assert(bOK, sError);
                end
            end
        end
        local tLines = {"CFS-WIKI-1"};
        for _, tPage in ipairs(tStore.list()) do
            tLines[#tLines + 1] = tPage.id.."\t"..tPage.parent.."\t"..encode(tPage.title).."\t"..encode(tPage.xml);
        end
        local sData = table.concat(tLines, "\n").."\n";
        local oFile = wx.wxFile();
        local pTemp = wx.wxFileName.CreateTempFileName(pRoot.."/Wiki-save-", oFile);
        oFile:Close(); oFile:delete();
        assert(pTemp ~= "", "Could not create a wiki save file.");
        local bReplacing = false;
        local bOK, sError = pcall(function()
            local hFile = assert(io.open(pTemp, "wb"));
            local bWritten, sFailure = hFile:write(sData); local bClosed = hFile:close();
            assert(bWritten and bClosed, sFailure or "Could not write the wiki.");
            assert(read(pFile) == sOriginal, "The wiki changed during saving.");
            if (sOriginal) then assert(wx.wxCopyFile(pFile, pRoot.."/Wiki.backup", true), "Could not back up the wiki."); end
            assert(read(pFile) == sOriginal, "The wiki changed while backing up.");
            bReplacing = true;
            assert(wx.wxRenameFile(pTemp, pFile, true), "Could not replace the wiki; your draft has been kept.");
        end);
        if (wx.wxFileExists(pTemp)) then wx.wxRemoveFile(pTemp); end
        if (not bOK and bReplacing and sOriginal and read(pFile) ~= sOriginal) then
            local bRecovered = wx.wxCopyFile(pRoot.."/Wiki.backup", pFile, true);
            if (not bRecovered or read(pFile) ~= sOriginal) then
                sError = tostring(sError).." Recovery failed; the original remains in "..pRoot.."/Wiki.backup.";
            end
        end
        assert(bOK, sError);
        sOriginal = sData; tStore.dirty = false; tStore.assets = {};
    end
    return tStore;
end
return Store;
