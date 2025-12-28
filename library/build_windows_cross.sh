#!/bin/bash
set -e

echo "[*] Building SteamworksPy for Windows (cross-compile with MinGW)"

# Verify SDK present
if [ ! -d "sdk/public/steam" ]; then
    echo "[!] SDK headers not found at library/sdk/public/steam"
    echo "[!] Expected SDK to be symlinked to library/sdk"
    exit 1
fi

if [ ! -f "sdk/redistributable_bin/win64/steam_api64.dll" ]; then
    echo "[!] steam_api64.dll not found at library/sdk/redistributable_bin/win64/"
    exit 1
fi

if [ ! -f "sdk/redistributable_bin/win64/steam_api64.lib" ]; then
    echo "[!] steam_api64.lib not found at library/sdk/redistributable_bin/win64/"
    exit 1
fi

echo "[*] SDK found, proceeding with cross-compilation"

# Copy Windows SDK files to current directory for linking
cp sdk/redistributable_bin/win64/steam_api64.dll .
cp sdk/redistributable_bin/win64/steam_api64.lib .

# Cross-compile Windows DLL using MinGW
echo "[*] Compiling SteamworksPy64.dll with x86_64-w64-mingw32-g++"
x86_64-w64-mingw32-g++ -std=c++11 \
    -shared \
    -o SteamworksPy64.dll \
    -D_USRDLL -D_WINDLL \
    -I./sdk/public \
    SteamworksPy.cpp \
    steam_api64.lib \
    -static-libgcc -static-libstdc++ \
    -Wl,--out-implib,libSteamworksPy.a

# Create output directory if needed
mkdir -p ../redist/windows

# Move output to redist directory
echo "[*] Moving SteamworksPy64.dll to redist/windows/"
mv SteamworksPy64.dll ../redist/windows/

# Copy Steam API DLL to redist (required at runtime)
cp steam_api64.dll ../redist/windows/

echo "[*] Build complete: redist/windows/SteamworksPy64.dll"
echo "[*] Steam API library also copied to: redist/windows/steam_api64.dll"
