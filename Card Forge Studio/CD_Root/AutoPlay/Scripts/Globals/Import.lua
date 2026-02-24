local sImportError = "Error importing file: ";

-- Sanitizes a relative import path and resolves it to a Windows path.
function SanitizePath(sRelPath)
    if type(sRelPath) ~= "string" or sRelPath == "" then
        error(sImportError.."Import path must be a non-empty string.", 2);
    end

    -- Normalize user input to forward slashes first;
    local sPath = sRelPath  :gsub("\\", "/")    -- normalize input first;
                            :gsub("/+", "/");   -- collapse ANY number of /;

    -- Disallow absolute paths (/, \\ -> /, and C:\ -> C:/);
    if (sPath:match("^/") or sPath:match("^%a:/")) then
        error(sImportError.."Absolute paths are not allowed.", 2);
    end

    -- Disallow traversal;
    if (sPath:match("(^|/)%.%.(/|$)")) then
        error(sImportError.."Path traversal is not allowed.", 2);
    end

    -- Disallow dot segments (./);
    if (sPath:match("(^|/)%.(/|$)")) then
        error(sImportError.."Dot path segments are not allowed.", 2);
    end

    -- Disallow control chars;
    if (sPath:match("[%z\r\n]")) then
        error(sImportError.."Invalid characters in path.", 2);
    end

    -- Disallow empty / directory paths;
    if (sPath == "" or sPath:match("/$")) then
        error(sImportError.."Import path must point to a file.", 2);
    end

    -- Disallow unsupported characters (tighten as needed);
    -- Allows: letters/numbers/_ . - / and spaces;
    if (sPath:match("[^%w%._%-%/ ]")) then
        error(sImportError.."Import path contains unsupported characters.", 2);
    end

    -- Disallow Windows reserved device names in the leaf filename;
    local sLeaf = sPath:match("([^/]+)$")   or "";
    local sDev  = sLeaf:match("^([^%.]+)")  or "";
    sDev        = sDev:upper();

    if (sDev:match("^(CON|PRN|AUX|NUL)$") or sDev:match("^COM[1-9]$") or sDev:match("^LPT[1-9]$")) then
        error(sImportError.."Reserved device names are not allowed in import paths.", 2);
    end

    return sPath:gsub("/", "\\");   -- convert to Windows;
end

local function Import(sPathRaw)
    local sPath = SanitizePath(sPathRaw);
    local pFile = (FS.Game.."\\"..sPath):gsub("\\+", "\\");

    if not (File.DoesExist(pFile)) then
        error(sImportError.."File does not exist at \""..sPath..'."', 2);
    end

    local sCode = TextFile.ReadToString(pFile);
    local fChunk, sError = load(sCode, sPath, "t", envrepo.User);

    if not (fChunk) then
        return nil, sError;
    end

    return fChunk;
end
