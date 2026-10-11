--[[!
@fqxn CFS.Modules.init
@desc
<section aria-label="init overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">init</h2><p style="font-size:1.15rem;margin:0">The launcher entry point brings the native application together.</p></div>
<h3>How it fits into your work</h3><p>It initializes services before creating the main interface. Verification and smoke modes support development checks.</p>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.Globals">Globals</a></h3><p style="margin:0">Globals connects the application services during startup.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.Main">Main</a></h3><p style="margin:0">The main Studio window connects your project, preview, and editing tools.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">This is startup infrastructure, not a game script API.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual methods, inputs, and results.</p>
</section>
!]]

-- The launcher creates and protects APP_PATH (and other constants) before loading this script.
local _pRuntime = assert(APP_PATH, "Start Card Forge Studio through its launcher.");

assert(_pRuntime ~= "" and not _pRuntime:find("[\r\n%z]"), "Launcher supplied an invalid application folder.");

_pRuntime = _pRuntime:gsub("\\", "/"):gsub("/+$", "").."/";

local _pScripts = _pRuntime.."Scripts/";
local wx;
local _dMain, _oTestTimer;

package.path = _pScripts.."?.lua;".._pScripts.."?/init.lua;"..package.path;
package.cpath = _pRuntime.."Bin/?.dll;"..package.cpath;

--[[!
@fqxn CFS.Modules.init.Private.Functions.initialize
@desc Loads runtime services and the main window, supports verification and smoke modes, and enters the native event loop.
@vis private
!]]
local function initialize()
    wx = require("wx");
    require("Globals");
    local dMain = require("Windows.Main");

    if (arg[1] == "--verify") then
        assert(type(dMain.create) == "function", "Editor module is unavailable.");

        return;
    end

    _dMain = dMain.create();
    OnStartUp(_dMain.frame);

    if (arg[1] == "--smoke") then
        _oTestTimer = wx.wxTimer(_dMain.frame);
        _dMain.frame:Connect(wx.wxEVT_TIMER, function()
            _dMain.frame:Close(true);
        end);
        _oTestTimer:Start(250, true);
    end

    wx.wxGetApp():MainLoop();
end

local _bOK, _sError = xpcall(initialize, debug.traceback);

if (not _bOK) then
    require("Errors").report(_sError);
end

os.exit(_bOK and 0 or 1);
