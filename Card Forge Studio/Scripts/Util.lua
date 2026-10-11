local Dox      = Dox;
local DoxLua   = DoxLua;
local assert   = assert;
local base64   = base64;
local error    = error;
local ipairs   = ipairs;
local io       = io;
local os       = os;
local rawtype  = rawtype;
local string   = string;
local table    = table;
local tostring = tostring;
local utf8     = utf8;
local wx       = require("wx");

-- Release contents. Folder contents are collected recursively, including linked plugins.
local _tReleaseFiles = {
    "Card Forge Studio.exe",
    "icon.ico",
    "LICENSE",
};
local _tReleaseFolders = {
    "Scripts",
    "Images",
    "Fonts",
    "Docs",
    "Bin",
};
local _tReleaseExcludedFolders = {
    "Bin/Launcher Source",
    "Scripts/Tests",
};
local _tReleaseExcludedNames = {
    ".git", ".codex", ".agents", "AGENTS.md", "AGENT_NOTES.txt", "desktop.ini",
};

--[[!
@fqxn CFS.Modules.Util.Private.Functions.PowerShellList
@desc Encodes a configured string list as PowerShell literal strings, preserving apostrophes.
@param table tValues Configured file or folder names.
@return string sList PowerShell array expression.
@vis private
!]]
local function PowerShellList(tValues)
    local tValuesEncoded = {};
    for _, sValue in ipairs(tValues) do
        table.insert(tValuesEncoded, "'"..sValue:gsub("'", "''").."'");
    end
    return "@("..table.concat(tValuesEncoded, ",")..")";
end


--[[!
@fqxn CFS.Modules.Util.Private.Functions.CollectLuaFiles
@desc Collects Studio Lua sources recursively, excluding the linked Plugins tree. Paths are sorted before import for reproducible builds.
@param string pFolder Source folder to inspect.
@param table tFiles Collected source paths.
!]]
local function CollectLuaFiles(pFolder, tFiles)
    local oFolder = wx.wxDir(pFolder);

    if (not oFolder:IsOpened()) then
        oFolder:delete();
        error("Cannot inspect documentation source folder: "..pFolder, 2);
    end

    local bFound, sName = oFolder:GetFirst("", wx.wxDIR_FILES + wx.wxDIR_DIRS);

    while (bFound) do
        local pEntry = pFolder.."/"..sName;

        if (wx.wxDirExists(pEntry)) then
            if (sName:lower() ~= "plugins") then
                CollectLuaFiles(pEntry, tFiles);
            end
        elseif (sName:lower():match("%.lua$")) then
            table.insert(tFiles, pEntry);
        end

        bFound, sName = oFolder:GetNext();
    end

    oFolder:delete();
end


--[[!
@fqxn CFS.Modules.Util.Private.Functions.InstallPulsarPackage
@desc Extracts the generated package into Pulsar's packages directory. The ZIP is retained after installation failure and removed only after successful extraction.
@param string pZIP Generated package archive.
@param string pPackages Pulsar package directory.
!]]
local function InstallPulsarPackage(pZIP, pPackages)
    -- PowerShell literal strings and an encoded command preserve path characters.
    local sArchive     = "'"..pZIP:gsub("'", "''").."'";
    local sDestination = "'"..pPackages:gsub("'", "''").."'";
    local sScript      = "$ProgressPreference = 'SilentlyContinue'; $ErrorActionPreference = 'Stop'; Add-Type -AssemblyName System.IO.Compression.FileSystem; "..
                    "$root = [System.IO.Path]::GetFullPath("..sDestination.."); "..
                    "[System.IO.Directory]::CreateDirectory($root) | Out-Null; "..
                    "$root = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar; "..
                    "$zip = [System.IO.Compression.ZipFile]::OpenRead("..sArchive.."); "..
                    "try { foreach ($entry in $zip.Entries) { "..
                    "$target = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, $entry.FullName)); "..
                    "if (-not $target.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'ZIP path outside package directory'; }; "..
                    "if ($entry.FullName.EndsWith('/')) { [System.IO.Directory]::CreateDirectory($target) | Out-Null; } "..
                    "else { [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target)) | Out-Null; "..
                    "[System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true); }; "..
                    "}; } finally { $zip.Dispose(); };";
    local tEncoded     = {};

    for _, nCodePoint in utf8.codes(sScript) do
        if (nCodePoint <= 0xFFFF) then
            table.insert(tEncoded, string.pack("<I2", nCodePoint));
        else
            nCodePoint = nCodePoint - 0x10000;
            table.insert(tEncoded, string.pack("<I2I2", 0xD800 + (nCodePoint >> 10), 0xDC00 + (nCodePoint & 0x3FF)));
        end
    end

    local sCommand = "powershell.exe -WindowStyle Hidden -NoProfile -NonInteractive -EncodedCommand "..base64.enc(table.concat(tEncoded));
    local bOK      = os.execute(sCommand);

    if (not bOK) then
        error("Pulsar package installation failed; ZIP retained at "..pZIP, 2);
    end

    local bRemoved, sError = os.remove(pZIP);

    if (not bRemoved) then
        error("Pulsar package installed, but its ZIP could not be removed: "..tostring(sError), 2);
    end
end

local Util = {};

--[[!
@fqxn CFS.Modules.Util
@desc Developer utilities for Studio. Build API Docs creates the HTML reference and Pulsar autocomplete package on demand, installs the package, and removes its ZIP only after successful installation. It is launched manually from Help in development mode.
!]]

--[[!
@fqxn CFS.Modules.Util.Functions.BuildAPIDocs
@pulsarlua function Util.BuildAPIDocs
@desc Builds CFS HTML and Pulsar documentation from Studio sources, excluding linked plugins. Uses the application Docs folder, installs the generated package in the current profile’s Pulsar packages folder, and retains the ZIP if installation fails.
@vis public
!]]
function Util.BuildAPIDocs()
    Log.Note("Building API docs");

    local pDocs     = APP_PATH.."/Docs";
    local pProfile  = os.getenv("USERPROFILE");
    local tFiles    = {};

    if (not pProfile or pProfile == "") then
        error("Cannot find the Windows profile for Pulsar package installation.", 2);
    end

    if (not wx.wxDirExists(pDocs) and not wx.wxFileName.Mkdir(pDocs, 511, wx.wxPATH_MKDIR_FULL)) then
        error("Cannot create documentation output folder: "..pDocs, 2);
    end

    CollectLuaFiles(_Scripts, tFiles);
    table.sort(tFiles);

    local oDox   = DoxLua("CFS");
    local sIntro = require("Dox.intro");

    oDox.setIntro(sIntro);

    for _, pFile in ipairs(tFiles) do
        oDox.importFile(pFile, true);
    end

    oDox.refresh();
    oDox.setOutputPath(pDocs);
    oDox.export("index");
    oDox.setBuilder(Dox.BUILDER.PULSAR_LUA);

    local pZIP = oDox.export("CFS");

    InstallPulsarPackage(pZIP, pProfile.."/.pulsar/packages");
    Log.Note("API docs build complete");
end


--[[!
@fqxn CFS.Modules.Util.Functions.BuildRelease
@pulsarlua function Util.BuildRelease
@desc Creates a portable release ZIP from the launcher, icon, Bin, Scripts, Images, Fonts, and Docs. Launcher Source and development metadata are excluded. Linked plugin files are copied into the package. DEV_MODE is disabled only in the staged Constants file; the working copy stays unchanged. Existing ZIP files are not replaced.
@param string pZIP New ZIP destination chosen by the developer.
@return string pZIP Completed release archive.
!]]
function Util.BuildRelease(pZIP)
    assert(rawtype(pZIP) == "string" and pZIP:lower():match("%.zip$"), "Choose a release ZIP destination.");
    Log.Note("Building release package");

    local sRoot   = "'"..APP_PATH:gsub("'", "''").."'";
    local sZIP    = "'"..pZIP:gsub("'", "''").."'";
    local sScript = [=[
$ErrorActionPreference = 'Stop';
Add-Type -AssemblyName System.IO.Compression.FileSystem;
$sourceRoot = [System.IO.Path]::GetFullPath(SOURCE_ROOT);
$outputZIP = [System.IO.Path]::GetFullPath(OUTPUT_ZIP);
if ([System.IO.File]::Exists($outputZIP)) { throw 'Release ZIP already exists; choose a new filename.'; }
foreach ($folder in RELEASE_FOLDERS) {
    $prefix = [System.IO.Path]::Combine($sourceRoot,$folder) + [System.IO.Path]::DirectorySeparatorChar;
    if ($outputZIP.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)) { throw 'Release ZIP cannot be placed inside a packaged folder.'; }
}
$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath());
$stage = [System.IO.Path]::Combine($tempRoot,'cfs-release-' + [System.Guid]::NewGuid().ToString('N'));
$stage = [System.IO.Path]::GetFullPath($stage);
if (-not $stage.StartsWith($tempRoot,[System.StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid release staging path.'; }
$excluded = EXCLUDED_NAMES;
$excludedFolders = EXCLUDED_FOLDERS;
function CopyReleaseTree($from,$to,$relative) {
    [System.IO.Directory]::CreateDirectory($to) | Out-Null;
    foreach ($entry in Get-ChildItem -LiteralPath $from -Force) {
        if ($excluded -contains $entry.Name) { continue; }
        $child = $relative + '/' + $entry.Name;
        if ($excludedFolders -contains $child) { continue; }
        $target = [System.IO.Path]::Combine($to,$entry.Name);
        if ($entry.PSIsContainer) { CopyReleaseTree $entry.FullName $target $child; }
        else { [System.IO.File]::Copy($entry.FullName,$target,$false); }
    }
}
try {
    $app = [System.IO.Path]::Combine($stage,'Card Forge Studio');
    [System.IO.Directory]::CreateDirectory($app) | Out-Null;
    foreach ($file in RELEASE_FILES) {
        [System.IO.File]::Copy([System.IO.Path]::Combine($sourceRoot,$file),[System.IO.Path]::Combine($app,$file),$false);
    }
    foreach ($folder in RELEASE_FOLDERS) {
        CopyReleaseTree ([System.IO.Path]::Combine($sourceRoot,$folder)) ([System.IO.Path]::Combine($app,$folder)) $folder;
    }
    $constants = [System.IO.Path]::Combine($app,'Scripts/Constants.lua');
    $encoding = New-Object System.Text.UTF8Encoding($false,$true);
    $text = [System.IO.File]::ReadAllText($constants,$encoding);
    $pattern = 'constant\("DEV_MODE",\s*true\);';
    if ([regex]::Matches($text,$pattern).Count -ne 1) { throw 'Expected one enabled DEV_MODE declaration in release source.'; }
    $text = [regex]::Replace($text,$pattern,'constant("DEV_MODE", false);');
    [System.IO.File]::WriteAllText($constants,$text,$encoding);
    $stagedZIP = [System.IO.Path]::Combine($stage,'release.zip');
    [System.IO.Compression.ZipFile]::CreateFromDirectory($app,$stagedZIP,[System.IO.Compression.CompressionLevel]::Optimal,$true);
    [System.IO.File]::Move($stagedZIP,$outputZIP);
} finally {
    if ([System.IO.Directory]::Exists($stage)) { Remove-Item -LiteralPath $stage -Recurse -Force; }
}
]=];
    sScript = sScript:gsub("SOURCE_ROOT", function() return sRoot; end):gsub("OUTPUT_ZIP", function() return sZIP; end);
    sScript = sScript:gsub("RELEASE_FILES", function() return PowerShellList(_tReleaseFiles); end)
        :gsub("RELEASE_FOLDERS", function() return PowerShellList(_tReleaseFolders); end)
        :gsub("EXCLUDED_FOLDERS", function() return PowerShellList(_tReleaseExcludedFolders); end)
        :gsub("EXCLUDED_NAMES", function() return PowerShellList(_tReleaseExcludedNames); end);
    local oScript = wx.wxFile();
    local pScript = wx.wxFileName.CreateTempFileName(wx.wxFileName.GetTempDir().."/cfs-release-", oScript);
    oScript:Close();
    oScript:delete();
    local hScript = assert(io.open(pScript, "wb"));
    assert(hScript:write(sScript));
    assert(hScript:close());
    local sInvoke = "$ProgressPreference = 'SilentlyContinue'; try { Invoke-Expression ([System.IO.File]::ReadAllText('"..pScript:gsub("'", "''").."')) } catch { [Console]::Out.WriteLine($_.Exception.Message); exit 1; }";
    local tEncoded = {};

    for _, nCodePoint in utf8.codes(sInvoke) do
        if (nCodePoint <= 0xFFFF) then
            table.insert(tEncoded, string.pack("<I2", nCodePoint));
        else
            nCodePoint = nCodePoint - 0x10000;
            table.insert(tEncoded, string.pack("<I2I2", 0xD800 + (nCodePoint >> 10), 0xDC00 + (nCodePoint & 0x3FF)));
        end
    end

    local hProcess = assert(io.popen("powershell.exe -WindowStyle Hidden -NoProfile -NonInteractive -OutputFormat Text -EncodedCommand "..base64.enc(table.concat(tEncoded)).." 2>&1", "r"));
    local sOutput = hProcess:read("a");
    local bOK = hProcess:close();
    assert(os.remove(pScript), "Cannot remove release packaging command file.");
    assert(bOK, "Release packaging failed: "..tostring(sOutput));
    Log.Note("Release package build complete: "..pZIP);
    return pZIP;
end


return Util;
