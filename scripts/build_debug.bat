@echo off
pushd %~dp0/../

:: This creates a build that is similar to a release build, but it's debuggable.
:: There is no hot reloading and no separate game library.

set OUT_DIR=bin\debug

if not exist %OUT_DIR% mkdir %OUT_DIR%

odin build src -out:%OUT_DIR%\oui.exe -strict-style -vet -debug

echo Debug build created in %OUT_DIR%
popd