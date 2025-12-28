#!/bin/bash
set -e

echo "[*] Building SteamworksPy for Linux (native)"

# Verify SDK present
if [ ! -d "sdk/public/steam" ]; then
    echo "[!] SDK headers not found at library/sdk/public/steam"
    echo "[!] Expected SDK to be symlinked to library/sdk"
    exit 1
fi

if [ ! -f "sdk/redistributable_bin/linux64/libsteam_api.so" ]; then
    echo "[!] libsteam_api.so not found at library/sdk/redistributable_bin/linux64/"
    exit 1
fi

echo "[*] SDK found, proceeding with build"

# Copy Steam API library to current directory (Makefile expects it at -L.)
cp sdk/redistributable_bin/linux64/libsteam_api.so .

# Build using Makefile
echo "[*] Compiling SteamworksPy.so"
make

# Create output directory if needed
mkdir -p ../redist/linux

# Move output to redist directory
echo "[*] Moving SteamworksPy.so to redist/linux/"
mv SteamworksPy.so ../redist/linux/

# Copy Steam API library to redist (required at runtime)
cp libsteam_api.so ../redist/linux/

echo "[*] Build complete: redist/linux/SteamworksPy.so"
echo "[*] Steam API library also copied to: redist/linux/libsteam_api.so"
