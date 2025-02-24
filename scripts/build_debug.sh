#!/bin/bash -eu

# This creates a build that is similar to a release build, but it is debuggable.
# There is no hot reloading and no separate game library.

OUT_DIR="bin/debug"
mkdir -p "$OUT_DIR"
odin build ../src -out:$OUT_DIR/oui.bin -strict-style -vet -debug
echo "Debug build created in $OUT_DIR"