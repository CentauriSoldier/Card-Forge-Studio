--[[!
@fqxn CardForgeEngine.Scripts.Bootstrap
@desc Minimal native wx startup shell with Studio's wxLuma available for controls. Owns the wx event loop.
    No game loading or gameplay API is defined at this stage.
!]]
local Bootstrap = {};

--[[!
@fqxn CardForgeEngine.Scripts.Bootstrap.run
@desc Opens one native application frame, or verifies startup and closes in --smoke mode.
@param string pRoot Launcher-resolved installation root.
@param table tArguments Forwarded arguments, with the executable at index zero.
!]]
function Bootstrap.run(pRoot, tArguments)
    -- Studio supplies the shared plugins. Engine keeps its renderer local.
    local pStudioPlugins = pRoot.."/../Scripts/Plugins";
    package.path = pStudioPlugins.."/?.lua;"..pStudioPlugins.."/?/init.lua;"
        ..pRoot.."/Scripts/Plugins/?.lua;"..pRoot.."/Scripts/Plugins/?/init.lua;"..package.path;
    require("LuaEx.init");
    require("cog.load")();
    local wx = require("wx");
    local wxLuma = require("wxLuma")();

    -- Add Studio scripts after LuaEx has discovered engine classes.
    package.path = package.path..";"..pRoot.."/../Scripts/?.lua";
    local bSmoke = false;
    for _, sArgument in ipairs(tArguments) do
        bSmoke = bSmoke or sArgument == "--smoke";
    end

    wx.wxGetApp():SetAppName("Card Forge Engine");
    local Window = require("Scripts.Windows.Main").create(pRoot, wxLuma);
    local oFrame = Window.Frame;

    local oTimer, sFailure;

    -- The native frame owns its child controls and destroys them on normal close.
    oFrame:Show(true);
    if (bSmoke) then
        oTimer = wx.wxTimer(oFrame);
        oFrame:Connect(oTimer:GetId(), wx.wxEVT_TIMER, function()
            oTimer:Stop();
            local bOK, sError = xpcall(function()
                assert(Window.Welcome.Control:IsShown(), "Welcome page was not shown.");
                assert(not Window.Welcome.Artwork.Disposed, "Welcome artwork was disposed early.");
                assert(oFrame:IsShown(), "Card Forge Engine window was not shown.");
                assert(package.searchpath("wxLuma", package.path) == pStudioPlugins.."/wxLuma/init.lua", "wxLuma did not resolve from Studio.");
                assert(type(tArguments[0]) == "string", "Launcher did not forward argv[0].");
            end, debug.traceback);
            if (not bOK) then sFailure = sError; end
            oFrame:Close();
        end);
        oTimer:Start(350, true);
    end

    wx.wxGetApp():MainLoop();
    collectgarbage("collect");
    assert(not sFailure, sFailure);
    if (bSmoke) then
        local hResult = assert(io.open(pRoot.."/Bin/Windows/launcher-check.txt", "wb"));
        assert(hResult:write("PASS: Card Forge Engine.exe -> root init.lua -> single native frame, welcome page, bundled artwork, arguments and shutdown.\n"));
        assert(hResult:close());
    end
end

return Bootstrap;
