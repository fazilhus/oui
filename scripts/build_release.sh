#!/bin/bash -eu

# This script creates an optimized release build.
pushd ../

OUT_DIR="bin/release"
mkdir -p "$OUT_DIR"
odin build src -out:$OUT_DIR/oui -strict-style -vet -no-bounds-check -o:speed
echo "Release build created in $OUT_DIR"

popd
