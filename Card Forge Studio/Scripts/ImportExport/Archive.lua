local Archive = {};

--[[!
@fqxn CFS.Modules.ImportExport.Archive
@desc Windows ZIP operations with bounded extraction, relative-path validation, and checked staging cleanup. Archive content is never executed.
@vis private
!]]

--[[!
@fqxn CFS.Modules.ImportExport.Archive.Private.Functions.quote
@desc Encodes a literal PowerShell string.
@vis private
!]]
local function quote(sValue)
    assert(type(sValue) == "string" and not sValue:find("[%z\r\n]"), "Invalid filesystem path.");
    return "'"..sValue:gsub("'", "''").."'";
end

--[[!
@fqxn CFS.Modules.ImportExport.Archive.Functions.run
@desc Runs a checked hidden Windows ZIP operation; reports process errors to the caller.
@param string sAction pack, unpack, copy, deliver, install or remove.
@param string pSource Source path.
@param string pTarget Target path.
@vis private
!]]
function Archive.run(sAction, pSource, pTarget)
    local sScript = "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; Add-Type -AssemblyName System.IO.Compression.FileSystem; $src="..quote(pSource).."; $dst="..quote(pTarget or "").."; ";
    local tActions = {
        pack = [[ [System.IO.Compression.ZipFile]::CreateFromDirectory($src,$dst,[System.IO.Compression.CompressionLevel]::Optimal,$false); ]],
        copy = [[
            $root=[IO.Path]::GetFullPath($src).TrimEnd('\')+'\';
            [IO.Directory]::CreateDirectory($dst) | Out-Null;
            foreach($item in Get-ChildItem -LiteralPath $src -Force -Recurse) {
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Linked project files cannot be packaged.'; }
                $rel=$item.FullName.Substring($root.Length);
                if ($rel -match '^(CardSets|Exports|CSV Backup|Docs)(\\|$)' -or $rel -match '(^|\\)(\.git|\.codex|\.agents)(\\|$)') { continue; }
                $target=[IO.Path]::Combine($dst,$rel);
                if($item.PSIsContainer) { [IO.Directory]::CreateDirectory($target) | Out-Null; }
                else { [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null; [IO.File]::Copy($item.FullName,$target,$false); }
            }
        ]],
        unpack = [[
            $zip=[IO.Compression.ZipFile]::OpenRead($src);
            try {
                if($zip.Entries.Count -gt 65534) { throw 'Too many package entries.'; }
                $root=[IO.Path]::GetFullPath($dst).TrimEnd('\')+'\'; $seen=@{}; [long]$total=0;
                foreach($e in $zip.Entries) {
                    $name=$e.FullName.Replace('\','/');
                    if($name -match '^/|:|[\x00-\x1f]' -or $name -match '(^|/)\.\.?(/|$)' -or $name -match '//|[. ](/|$)' -or $name -match '(^|/)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|/|$)' -or $name -match '[<>"|?*]') { throw 'Unsafe package path.'; }
                    if(($e.ExternalAttributes -shr 16 -band 0xF000) -eq 0xA000 -or ($e.ExternalAttributes -band 0x400) -ne 0) { throw 'Linked archive entries are not supported.'; }
                    if($seen.ContainsKey($name.ToLowerInvariant())) { throw 'Duplicate package entry.'; } $seen[$name.ToLowerInvariant()]=$true;
                    $total += $e.Length; if($total -gt 2147483648 -or $e.Length -gt 536870912) { throw 'Package exceeds extraction limits.'; }
                    $target=[IO.Path]::GetFullPath([IO.Path]::Combine($root,$name));
                    if(-not $target.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) { throw 'Package path escapes staging.'; }
                    if($e.Name -eq '') { [IO.Directory]::CreateDirectory($target) | Out-Null; }
                    else { [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null; [IO.Compression.ZipFileExtensions]::ExtractToFile($e,$target,$false); }
                }
            } finally { $zip.Dispose(); }
        ]],
        deliver = [[
            $stream=$null; $input=$null; $owned=$false;
            try {
                $stream=[IO.File]::Open($dst,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None); $owned=$true;
                $input=[IO.File]::OpenRead($src); $input.CopyTo($stream); $stream.Flush();
            } catch {
                if($stream) { $stream.Dispose(); $stream=$null; }
                if($owned) { [IO.File]::Delete($dst); } throw;
            } finally { if($input) { $input.Dispose(); }; if($stream) { $stream.Dispose(); } }
        ]],
        install = [[
            $parent=[IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($dst));
            $incoming=[IO.Path]::Combine($parent,[IO.Path]::GetFileName($dst)+'.import-stage-'+[Guid]::NewGuid().ToString('N'));
            $backup=$dst+'.import-backup-'+[Guid]::NewGuid().ToString('N'); $had=[IO.Directory]::Exists($dst); $moved=$false;
            if([IO.File]::Exists($dst)) { throw 'Destination is a file.'; }
            if($had -and ((Get-Item -LiteralPath $dst).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Linked destination cannot be replaced.'; }
            [IO.Directory]::CreateDirectory($parent) | Out-Null;
            try {
                $root=[IO.Path]::GetFullPath($src).TrimEnd('\')+'\';
                if(-not [IO.Directory]::Exists($src)) { throw 'Validated staging directory is unavailable.'; }
                [IO.Directory]::CreateDirectory($incoming) | Out-Null;
                foreach($item in Get-ChildItem -LiteralPath $src -Force -Recurse) {
                    if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Linked staging files are not supported.'; }
                    $target=[IO.Path]::Combine($incoming,$item.FullName.Substring($root.Length));
                    if($item.PSIsContainer) { [IO.Directory]::CreateDirectory($target) | Out-Null; }
                    else { [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null; [IO.File]::Copy($item.FullName,$target,$false); }
                }
                if($had) { [IO.Directory]::Move($dst,$backup); $moved=$true; }
                try { [IO.Directory]::Move($incoming,$dst); }
                catch { if($moved) { [IO.Directory]::Move($backup,$dst); $moved=$false; }; throw; }
            } finally {
                $checked=[IO.Path]::GetFullPath($incoming);
                if([IO.Path]::GetDirectoryName($checked) -ne $parent -or [IO.Path]::GetFileName($checked) -notlike '*.import-stage-*') { throw 'Unsafe installation cleanup target.'; }
                if([IO.Directory]::Exists($checked)) { [IO.Directory]::Delete($checked,$true); }
            }
            if($had) { [Console]::WriteLine('Previous files retained in backup: '+$backup); }
        ]],
        remove = [[
            $root=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\';
            $target=[IO.Path]::GetFullPath($src);
            if(-not $target.StartsWith($root,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($target) -notlike 'cfs-package-*') { throw 'Cleanup target is outside owned staging.'; }
            if([IO.Directory]::Exists($target)) { [IO.Directory]::Delete($target,$true); }
        ]],
    };
    tActions.copyAssets = tActions.copy:gsub("CardSets|Exports|CSV Backup|Docs", "CardSets|Exports|CSV Backup|Docs|Dependencies"):gsub("%$false", "$true");
    assert(tActions[sAction], "Unknown archive operation.");
    sScript = "try { "..sScript..tActions[sAction].." } catch { [Console]::WriteLine($_.Exception.Message); exit 1; }";
    local tBytes = {};
    for _, nCode in utf8.codes(sScript) do
        if (nCode <= 65535) then tBytes[#tBytes + 1] = string.pack("<I2", nCode);
        else nCode = nCode - 65536; tBytes[#tBytes + 1] = string.pack("<I2I2", 0xd800 + (nCode >> 10), 0xdc00 + (nCode & 1023)); end
    end
    local hProcess = assert(io.popen("powershell.exe -WindowStyle Hidden -NoProfile -NonInteractive -OutputFormat Text -EncodedCommand "..base64.enc(table.concat(tBytes)).." 2>&1", "r"));
    local sOutput = hProcess:read("a"); local bOK = hProcess:close();
    assert(bOK, "Package operation failed: "..tostring(sOutput));
    return sOutput;
end
return Archive;
