--[[!
@fqxn CFS.Modules.Globals.ImportSystem
@desc Validates game-relative source paths and executes imports in the user environment.
!]]

local wx           = require("wx");
local sImportError = "Error importing file: ";

-- Sanitizes a relative import path and resolves it to a Windows path.
--[[!
@fqxn CFS.Modules.Globals.ImportSystem.Private.SanitizePath
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
@fqxn CFS.Modules.Globals.ImportSystem.Private.Import
@desc Loads a validated game-relative Lua file into the user environment; returns chunk results or nil and its runtime error.
@param any sPathRaw Path raw.
@param any vMessage Message.
@vis private
!]]
local function Import(sPathRaw, vMessage)
    local sMessage = rawtype(vMessage) == "string" and vMessage or "";
    local sPath = SanitizePath(sPathRaw, sMessage);
    local pFile = io.normalizepath(FS.Game.Root.."/"..sPath);

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
