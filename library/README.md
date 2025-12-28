# Building SteamworksPy

### Prerequisites 
The Steamworks source files are required for building the SteamworksPy libraries and those are only available to
Steamworks account holders.

A Steamworks account is free and can be registered at https://partner.steamgames.com

The source files can be downloaded here (log-in required): https://partner.steamgames.com/downloads/steamworks_sdk_147.zip (v1.47)

Unpack the archive and place the contents of:
- /sdk/public/steam in SteamworksPy/library/sdk/steam
- /sdk/redistributable_bin/%your_os% in SteamworksPy/library/sdk/redist

## Automated Builds (CI/CD)

SteamworksPy supports automated builds using self-hosted GitHub Actions runners:

- **Linux builds:** Native compilation using `build_linux.sh` (wraps Makefile)
- **Windows builds:** Cross-compilation using `build_windows_cross.sh` (MinGW)
- **Containerized:** Runs in Podman container for isolation and reproducibility
- **Legal compliance:** SDK mounted from host (never committed to repo)

For maintainers setting up CI/CD, see [../docs/CI_SETUP.md](../docs/CI_SETUP.md) for complete instructions.

### Building Manually

**Linux:**
```bash
cd library
ln -s /path/to/steamworks-sdk/sdk sdk
chmod +x build_linux.sh
./build_linux.sh
```

**Windows (cross-compile from Linux):**
```bash
cd library
ln -s /path/to/steamworks-sdk/sdk sdk
chmod +x build_windows_cross.sh
./build_windows_cross.sh
```

**Windows (native):**
```cmd
build_win_64.bat 2022
```

Binaries are output to `redist/linux/` and `redist/windows/` respectively.
