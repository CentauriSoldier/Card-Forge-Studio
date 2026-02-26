local sImportError = "Error importing file: ";

-- Sanitizes a relative import path and resolves it to a Windows path.
function SanitizePath(sRelPath, vMessage)
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
    if (sPath:match("(^|/)%.%.(/|$)")) then
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

    return sPath:gsub("/", "\\");   -- convert to Windows;
end

local function Import(sPathRaw, vMessage)
    local sMessage = rawtype(vMessage) == "string" and vMessage or "";
    local sPath = SanitizePath(sPathRaw, sMessage);
    local pFile = (FS.Game.."\\"..sPath):gsub("\\+", "\\");

    if not (File.DoesExist(pFile)) then
        error(sImportError.."File does not exist at \""..sPath.."\".\r\n"..sMessage, 2);
    end

    local sCode = TextFile.ReadToString(pFile);
    local fChunk, sError = load(sCode, sPath, "t", envrepo.User);

    if not (fChunk) then
        return nil, sError;
    end

    return fChunk;
end
