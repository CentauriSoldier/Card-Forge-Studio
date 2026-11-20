--[[!
@fqxn CardForgeEngine.Services.GameDiscovery
@desc Finds installed game packages through LuaEx I/O. Discovery reads directory
    entries only: it never decrypts archives or executes game or deck scripts.
!]]
require("LuaEx.init");
local GameDiscovery = {};

--[[!
@fqxn CardForgeEngine.Services.GameDiscovery.getLibraryPath
@desc Resolves the agreed library beneath the current user's home directory.
    Does not create directories or depend on the application's working directory.
@ret string Path to ~/Card Forge Engine.
!]]
function GameDiscovery.getLibraryPath()
    return io.getuserdir():gsub("[/\\]+$", "").."/Card Forge Engine";
end

--[[!
@fqxn CardForgeEngine.Services.GameDiscovery.archiveUUID
@desc Recognizes a canonical 8-4-4-4-12 hexadecimal UUID archive filename.
    UUID version bits are not restricted; accepted IDs are normalized to lowercase.
@param string pFile File path returned by LuaEx.
@ret string|nil Normalized UUID, or nil for other filenames.
@vis internal
!]]
local function archiveUUID(pFile)
    local sLeaf = pFile:match("([^/\\]+)$") or pFile;
    local sUUID = sLeaf:match("^(.*)%.[cC][fF][aA]$");
    if (not sUUID or #sUUID ~= 36) then return nil; end
    if (sUUID:sub(9, 9) ~= "-" or sUUID:sub(14, 14) ~= "-"
        or sUUID:sub(19, 19) ~= "-" or sUUID:sub(24, 24) ~= "-") then
        return nil;
    end
    local sHex = sUUID:gsub("-", "");
    if (#sHex ~= 32 or sHex:find("[^%x]")) then return nil; end
    return sUUID:lower();
end

--[[!
@fqxn CardForgeEngine.Services.GameDiscovery.inspectGame
@desc Inventories one direct child folder. Exactly one UUID.cfa at its root
    identifies a game. CardSets contains UUID.cfa card sets; Decks.lua and the three
    override archives are optional. A folder without a game archive is ignored.
@param string pDirectory Candidate game folder.
@param table tIssues Receives filesystem errors or ambiguous archive diagnostics.
@ret table|nil Game record suitable for GamesList, or nil when not discoverable.
@vis internal
!]]
local function inspectGame(pDirectory, tIssues)
    -- Keep failures local to a game, so one unreadable folder cannot hide others.
    local function fIssue(pPath, sMessage)
        tIssues[#tIssues + 1] = {Path = pPath, Message = sMessage};
    end

    local tFiles, sReason = io.listfiles(pDirectory, false);
    if (not tFiles) then
        fIssue(pDirectory, sReason);
        return nil;
    end

    local tArchives = {};
    local tByName = {};
    for _, pFile in ipairs(tFiles) do
        local sLeaf = pFile:match("([^/\\]+)$");
        tByName[sLeaf] = pFile;
        local sUUID = archiveUUID(pFile);
        if (sUUID) then
            tArchives[#tArchives + 1] = {UUID = sUUID, Path = pFile};
        end
    end
    if (#tArchives == 0) then return nil; end
    if (#tArchives ~= 1) then
        fIssue(pDirectory, "Expected one UUID.cfa game archive; found "..#tArchives..".");
        return nil;
    end

    local Game = {
        UUID = tArchives[1].UUID,
        Title = pDirectory:match("([^/\\]+)[/\\]*$"),
        Directory = pDirectory,
        Archive = tArchives[1].Path,
        Sets = {},
        Decks = tByName["Decks.lua"],
        Overrides = {
            UIO = tByName["UIO.cfa"],
            GEO = tByName["GEO.cfa"],
            AO = tByName["AO.cfa"],
        },
        -- Image stays nil until the game metadata/artwork contract is defined.
        -- ListEx already supports an image path here and supplies a placeholder.
    };

    local pSets = pDirectory.."/CardSets";
    local bSets, sSetsReason, nSetsCode = io.isdir(pSets);
    if (bSets) then
        local tSets, sListReason = io.listfiles(pSets, false, nil, "cfa");
        if (not tSets) then
            fIssue(pSets, sListReason);
        else
            table.sort(tSets);
            local tByUUID = {};

            -- Each direct UUID-named CFA is one card set.
            for _, pArchive in ipairs(tSets) do
                local sUUID = archiveUUID(pArchive);
                if (not sUUID) then
                    fIssue(pArchive, "Card set archive filename must be a UUID.cfa.");
                elseif (tByUUID[sUUID]) then
                    fIssue(pArchive, "Duplicate card set UUID.");
                else
                    tByUUID[sUUID] = true;
                    Game.Sets[#Game.Sets + 1] = {UUID = sUUID, Archive = pArchive};
                end
            end
        end
    elseif (sSetsReason and nSetsCode ~= 2 and nSetsCode ~= 3) then
        fIssue(pSets, sSetsReason);
    elseif (not sSetsReason) then
        fIssue(pSets, "CardSets exists but is not a directory.");
    end
    return Game;
end

--[[!
@fqxn CardForgeEngine.Services.GameDiscovery.scan
@desc Returns a fresh snapshot of direct game folders, sorted by display name.
    Missing libraries return an empty list. Filesystem failures are reported
    separately, never confused with a successful empty scan. No files are created.
@param string|nil pLibrary Library root; omitted uses getLibraryPath().
    An explicit root supports tests and future user-selected library locations.
@ret table tGames Records with UUID, Title, Directory, Archive, Sets, optional
    Decks, and Overrides (UIO/GEO/AO). Image is intentionally unset for now.
@ret table tIssues Array of Path/Message diagnostics.
!]]
function GameDiscovery.scan(pLibrary)
    pLibrary = pLibrary or GameDiscovery.getLibraryPath();
    assert(rawtype(pLibrary) == "string" and pLibrary ~= "", "Library path must be a nonempty string.");
    local tGames, tIssues = {}, {};
    local bDirectory, sReason, nCode = io.isdir(pLibrary);
    if (not bDirectory) then
        if (nCode ~= 2 and nCode ~= 3) then
            tIssues[1] = {Path = pLibrary, Message = sReason or "Library path is not a directory."};
        end
        return tGames, tIssues;
    end

    local tDirectories;
    tDirectories, sReason = io.listdirs(pLibrary, false);
    if (not tDirectories) then
        return tGames, {{Path = pLibrary, Message = sReason}};
    end
    for _, pDirectory in ipairs(tDirectories) do
        local Game = inspectGame(pDirectory, tIssues);
        if (Game) then tGames[#tGames + 1] = Game; end
    end
    table.sort(tGames, function(tLeft, tRight)
        local sLeft, sRight = tLeft.Title:lower(), tRight.Title:lower();
        if (sLeft ~= sRight) then return sLeft < sRight; end
        return tLeft.Directory < tRight.Directory;
    end);
    return tGames, tIssues;
end

return GameDiscovery;