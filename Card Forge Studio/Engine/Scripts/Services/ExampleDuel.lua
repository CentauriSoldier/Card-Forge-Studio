--[[!
@fqxn CardForgeEngine.Services.ExampleDuel
@desc Opens the bundled Example Duel through CFA discovery and supplies
    validated scripts and card art to its page.
!]]
local _wx = require("wx");
local _Reader = require("CFA.Reader");
local _Discovery = require("Scripts.Services.GameDiscovery");
local ExampleDuel = {};

--[[!
@fqxn CardForgeEngine.Services.ExampleDuel.openImage
@desc Checks the validated PNG dimensions before decoding bytes in memory.
@param string sBytes Authenticated PNG bytes.
@param string sPath Virtual archive path for diagnostics.
@ret wxImage Decoded image owned by the caller.
!]]
local function openImage(sBytes, sPath)
    assert(#sBytes >= 33 and sBytes:sub(1, 16) == "\137PNG\r\n\26\n\0\0\0\13IHDR",
        "Invalid card PNG: "..sPath);
    local nWidth, nHeight = string.unpack(">I4I4", sBytes, 17);
    assert(nWidth > 0 and nWidth <= 2048 and nHeight > 0 and nHeight <= 2048,
        "Card PNG exceeds the dimension limit: "..sPath);

    local oStream = _wx.wxMemoryInputStream(sBytes, #sBytes);
    local bOK, vResult = pcall(function()
        return _wx.wxImage(oStream, _wx.wxBITMAP_TYPE_PNG);
    end);
    oStream:delete();
    assert(bOK, vResult);
    return vResult;
end

--[[!
@fqxn CardForgeEngine.Services.ExampleDuel.create
@desc Launches the trusted bundled demo. Archive readers are closed once the
    page has uploaded its textures and loaded the scripts it needs to restart.
@param wxWindow oParent Parent for the page.
@param string pRoot Engine installation directory.
@ret table Playable duel view.
!]]
function ExampleDuel.create(oParent, pRoot)
    local tGames = _Discovery.scan(pRoot.."/Examples/Games");
    local tBundle;
    for _, tGame in ipairs(tGames) do
        if (tGame.Title == "Example Duel") then tBundle = tGame; break; end
    end
    assert(tBundle and tBundle.Decks, "Bundled Example Duel or its Decks.lua is missing.");

    local tStarter;
    for _, tSet in ipairs(tBundle.Sets) do
        if (tSet.UUID == "75c287a3-f3ef-4557-b252-eadbaf5935d8") then
            tStarter = tSet;
            break;
        end
    end
    assert(tStarter, "Bundled Example Duel card set is missing.");

    local GameReader, SetReader;
    local bOK, vResult = xpcall(function()
        GameReader = assert(_Reader.open(tBundle.Archive));
        SetReader = assert(_Reader.open(tStarter.Archive));
        assert(GameReader.getMetadata().Kind == "game" and SetReader.getMetadata().Kind == "set",
            "The bundled duel has unexpected archive kinds.");

        local Content = {};
        local tScripts = {};

        -- Load only the demo's named modules. Reuse the loaded data on restart
        -- so the window never needs to retain an archive file handle.
        function Content.load(sName)
            if (tScripts[sName]) then return tScripts[sName]; end

            local fnChunk;
            if (sName == "Decks.lua") then
                fnChunk = assert(loadfile(tBundle.Decks, "t"));
            else
                local Reader;
                if (sName == "Cards.lua") then
                    Reader = SetReader;
                elseif (sName == "Game.lua" or sName == "Page.lua") then
                    Reader = GameReader;
                end

                assert(Reader, "Unexpected duel module: "..sName);
                local sBytes = assert(Reader.read(sName));
                fnChunk = assert(load(sBytes, "@Example Duel CFA/"..sName, "t"));
            end

            local tModule = fnChunk();
            assert(type(tModule) == "table", "Invalid duel module: "..sName);
            tScripts[sName] = tModule;
            return tModule;
        end

        -- Supply decoded assets from the set archive without writing them to disk.
        function Content.loadImage(sPath)
            return openImage(assert(SetReader.read(sPath)), sPath);
        end

        return Content.load("Page.lua").create(oParent, Content);
    end, debug.traceback);

    if (SetReader) then SetReader.close(); SetReader = nil; end
    if (GameReader) then GameReader.close(); GameReader = nil; end
    assert(bOK, vResult);
    return vResult;
end

return ExampleDuel;
