--[[!
@fqxn CFS.Modules.Globals.ImportSystem
@desc
<section aria-label="ImportSystem overview">
<div style="padding:1.6rem;border:1px solid var(--border);border-radius:16px;background:linear-gradient(135deg,var(--surface-raised),var(--surface));margin-bottom:1.5rem"><p style="margin:0;color:var(--accent);font-weight:700;letter-spacing:.08em">CARD FORGE STUDIO · OVERVIEW</p><h2 style="margin:.5rem 0">ImportSystem</h2><p style="font-size:1.15rem;margin:0">Imports let a game divide reusable helpers into separate source files.</p></div>
<h3>How it fits into your work</h3><p>A script supplies a game-relative path. The import system validates that path before executing the file in the user environment.</p>
<h3>Follow the handoffs</h3><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">An address becomes a script</h3><p style="margin:0">The importer starts with a path relative to the active game folder. It validates the path, reads the file, and compiles its Lua text using the current user environment. Only after those steps does it run the script. FS supplies the game location; UserEnv supplies the names available while the script runs.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)">What the checks mean</h3><p style="margin:0">Absolute paths, parent-folder traversal, invalid filename characters, and reserved filename forms are rejected by the path checks. Reading, compiling, and running are distinct failure points. Runtime errors are returned through a protected call. These application checks help catch bad requests; they are not a replacement for operating-system permissions or a guarantee that arbitrary scripts are safe.</p></article>
</div>
<h3>Explore the connected parts</h3><p>These topics explain the nearby pieces of the workflow. Follow a card to see the part it plays.</p><div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,240px),1fr));gap:1rem;margin:1rem 0">
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.UserEnv">User Environment</a></h3><p style="margin:0">UserEnv is the shared workspace where game scripts find configuration, helper values, and the APIs Studio exposes.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Modules.FS">File System</a></h3><p style="margin:0">FS is Studio's map of where project files belong.</p></article>
<article style="padding:1.2rem;border:1px solid var(--border);border-radius:14px;background:var(--surface-raised);min-width:0"><h3 style="margin:0 0 .6rem;color:var(--accent)"><a href="#CFS.Windows.GameEditor">GameEditor</a></h3><p style="margin:0">Game Editor organizes the shared scripts used throughout a game.</p></article>
</div>
<aside style="padding:1rem 1.2rem;border-left:4px solid var(--accent);background:var(--surface);border-radius:0 10px 10px 0;margin:1.5rem 0"><strong>Good to know</strong><p style="margin:.4rem 0 0">Absolute paths and directory traversal are rejected. This service is not an arbitrary computer-file picker.</p></aside>
<p style="color:var(--muted)">Ready for the details? The child entries in the navigation describe individual functions, inputs, and results.</p>
</section>
!]]

local wx           = require("wx");
local sImportError = "Error importing file: ";

-- Sanitizes a relative import path and resolves it to a Windows path.
--[[!
@fqxn CFS.Modules.Globals.ImportSystem.Private.Functions.SanitizePath
@desc Normalizes a relative Windows import path and rejects absolute paths, traversal, invalid characters, and reserved leaf names.
@param any sRelPath Rel path.
@param any vMessage Message.
@vis private
!]]
local function SanitizePath(sRelPath, vMessage)
    local sMessage = rawtype(vMessage) == "string" and vMessage or "";

    if type(sRelPath) ~= "string" or sRelPath == "" then
        error(sImportError.."Import path must be a non-empty string.\r\n"..sMessage, 2);
    end

    -- Normalize user input to forward slashes first;
    local sPath = sRelPath  :gsub("\\", "/")    -- normalize input first;
                            :gsub("/+", "/");   -- collapse ANY number of /;

    -- Disallow absolute paths (/, \\ -> /, and C:\ -> C:/);
    if (sPath:match("^/") or sPath:match("^%a:/")) then
        error(sImportError.."Absolute paths are not allowed.\r\n"..sMessage, 2);
    end

    -- Disallow traversal;
    for sPart in sPath:gmatch("[^/]+") do
        if (sPart == ".." or sPart == ".") then
            error(sImportError.."Dot path segments are not allowed.\r\n"..sMessage, 2);
        end
    end

    if (sPath:match("^%.%./")) then
        error(sImportError.."Path traversal is not allowed.\r\n"..sMessage, 2);
    end

    -- Disallow dot segments (./);
    if (sPath:match("(^|/)%.(/|$)")) then
        error(sImportError.."Dot path segments are not allowed.\r\n"..sMessage, 2);
    end

    -- Disallow empty / directory paths;
    if (sPath == "" or sPath:match("/$")) then
        error(sImportError.."Import path must point to a file.\r\n"..sMessage, 2);
    end

    -- Disallow Windows-invalid filename characters;
    if (sPath:match('[<>:"|%?%*%c]')) then
        error(sImportError.."Import path contains invalid filename characters.\r\n"..sMessage, 2);
    end

    -- Validate leaf filename (Windows rules)
    local sLeaf = sPath:match("([^/]+)$") or ""

    -- Disallow trailing dot or space (Windows quirk)
    if (sLeaf:match("[ %.]+$")) then
        error(sImportError.."Import filename cannot end with a space or dot.\r\n"..sMessage, 2);
    end

    -- Disallow Windows reserved device names (leaf, before extension)
    local sDev = (sLeaf:match("^([^%.]+)") or ""):upper();

    if (
        sDev == "CON" or
        sDev == "PRN" or
        sDev == "AUX" or
        sDev == "NUL" or
        sDev:match("^COM%d+$") or
        sDev:match("^LPT%d+$")
    ) then
        error(sImportError.."Reserved device names are not allowed in import paths.\r\n"..sMessage, 2);
    end

    return sPath;
end

--TODO make this throw an error so the user knows what's happening when a file doesn't exists or fails
--[[!
@fqxn CFS.Modules.Globals.ImportSystem.Private.Functions.Import
@desc Loads a validated game-relative Lua file into the user environment; returns chunk results or nil and its runtime error.
@param any sPathRaw Path raw.
@param any vMessage Message.
@vis private
!]]
local function Import(sPathRaw, vMessage)
    local sMessage = rawtype(vMessage) == "string" and vMessage or "";
    local sPath = SanitizePath(sPathRaw, sMessage);
    local pFile = io.normalizepath(FS.GetResourceRoot().."/"..sPath);

    if not (wx.wxFileExists(pFile)) then
        error(sImportError.."File does not exist at \""..sPath.."\".\r\n"..sMessage, 2);
    end

    local hFile = assert(io.open(pFile, "rb"));
    local sCode, sReadError = hFile:read("a");
    local bClosed, sCloseError = hFile:close();
    assert(sCode, sReadError);
    assert(bClosed, sCloseError);
    local fChunk, sError = load(sCode, sPath, "t", UserEnv.Get());
    assert(fChunk, sError);

    local tRet = { pcall(fChunk) };

    if not (tRet[1]) then
        return nil, tRet[2];
    end

    return table.unpack(tRet, 2);
end

return {Import = Import, SanitizePath = SanitizePath};
