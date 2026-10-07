@echo off
setlocal
pushd "%~dp0"

call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
if errorlevel 1 goto failed

rc /nologo /fo launcher.res launcher.rc
if errorlevel 1 goto failed

cl /nologo /W4 /WX /O2 /MT /I"C:\Users\CS\Sync\Projects\Wx Builder\lua-5.4.9\src" launcher.c launcher.res "C:\Users\CS\Sync\Projects\Wx Builder\build-lua\lua54.lib" /Fe:"Card Forge Studio.exe" /link /SUBSYSTEM:WINDOWS /DELAYLOAD:lua54.dll delayimp.lib user32.lib shell32.lib
if errorlevel 1 goto failed

powershell -NoProfile -Command "$ErrorActionPreference = 'Stop'; $buildFolder = (Get-Location).Path; $applicationFolder = (Resolve-Path -LiteralPath '..\..').Path; $outputFile = Join-Path $buildFolder 'Card Forge Studio.exe'; $installedFile = Join-Path $applicationFolder 'Card Forge Studio.exe'; Copy-Item -LiteralPath $outputFile -Destination $installedFile -Force; $hasher = [Security.Cryptography.SHA256]::Create(); try { $outputHash = [Convert]::ToBase64String($hasher.ComputeHash([IO.File]::ReadAllBytes($outputFile))); $installedHash = [Convert]::ToBase64String($hasher.ComputeHash([IO.File]::ReadAllBytes($installedFile))); if ($outputHash -ne $installedHash) { throw 'Installed launcher verification failed.' } } finally { $hasher.Dispose() }; Remove-Item -LiteralPath $outputFile"
if errorlevel 1 goto failed

echo Built and installed Card Forge Studio.exe in the application root.
popd
exit /b 0

:failed
echo Build or installation failed. Any compiled EXE remains in this folder.
popd
exit /b 1
