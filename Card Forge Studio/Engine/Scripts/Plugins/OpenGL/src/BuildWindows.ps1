<#
.SYNOPSIS
Builds the reusable Lua 5.4 renderer against a supplied host runtime.
.DESCRIPTION
Uses an existing LLVM-MinGW toolchain and matching official Lua SDK. Does not
change system installations or download tools. Output and caches stay in Stage.
#>
param(
    [Parameter(Mandatory)][string]$CompilerBin,
    [Parameter(Mandatory)][string]$LuaSource,
    [Parameter(Mandatory)][string]$LuaRuntime,
    [Parameter(Mandatory)][string]$Stage
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $Stage -Force | Out-Null
$exports = & (Join-Path $CompilerBin 'llvm-readobj.exe') --coff-exports $LuaRuntime
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect host Lua exports.' }
$symbols = @($exports | ForEach-Object {
    if ($_ -match '^\s*Name: (lua\w*)\s*$') { $Matches[1] }
})
if ($symbols.Count -lt 50) { throw 'Expected the Lua 5.4 host API.' }
$definition = 'LIBRARY lua54.dll' + "`nEXPORTS`n" + ($symbols -join "`n") + "`n"
[IO.File]::WriteAllText((Join-Path $Stage 'lua54.def'), $definition, [Text.UTF8Encoding]::new($false))
& (Join-Path $CompilerBin 'llvm-dlltool.exe') -m i386:x86-64 -d (Join-Path $Stage 'lua54.def') -l (Join-Path $Stage 'liblua54.a')
if ($LASTEXITCODE -ne 0) { throw 'Cannot create the host import library.' }
& (Join-Path $CompilerBin 'clang.exe') -std=c11 -O2 -Wall -Wextra -Werror -shared `
    '-DLUA_BUILD_AS_DLL' "-I$LuaSource" (Join-Path $PSScriptRoot 'opengl.c') `
    (Join-Path $Stage 'liblua54.a') -lopengl32 -lgdi32 -luser32 -o (Join-Path $Stage 'opengl.dll')
if ($LASTEXITCODE -ne 0) { throw 'OpenGL compilation failed.' }
& (Join-Path $CompilerBin 'llvm-readobj.exe') --coff-imports (Join-Path $Stage 'opengl.dll') |
    Select-String '^\s*Name:'
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the resulting plugin.' }
Write-Output (Join-Path $Stage 'opengl.dll')