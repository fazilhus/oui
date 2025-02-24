:: This script creates an optimized release build.

@echo off
pushd %~dp0/../

set OUT_DIR=bin\release

if not exist %OUT_DIR% mkdir %OUT_DIR%

odin build src -out:%OUT_DIR%\oui.exe -strict-style -vet -no-bounds-check -o:speed -subsystem:windows

echo Release build created in %OUT_DIR%
popd