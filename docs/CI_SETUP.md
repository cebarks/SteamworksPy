# CI/CD Setup Guide for SteamworksPy

This guide explains how to set up automated builds for SteamworksPy using self-hosted GitHub Actions runners.

## Why Self-Hosted Runners?

**Legal Requirement:** The Steamworks SDK cannot be legally redistributed or committed to public repositories (Valve Corporation Steamworks SDK Access Agreement). This means:

- ❌ **Cannot use GitHub-hosted runners** - No way to legally provide SDK to cloud runners
- ❌ **Cannot commit SDK to repo** - Violates Valve's license
- ✅ **Must use self-hosted runners** - SDK stays on YOUR hardware (legally obtained with partner account)

This is the ONLY legal way to achieve automated CI/CD for Steamworks-dependent projects.

## Architecture Overview

**Containerized Linux Runner with Cross-Compilation:**

- **Single Linux machine** runs Podman container
- **Container** includes: gcc, g++, MinGW (for Windows cross-compilation), GitHub Actions runner
- **Steamworks SDK** mounted read-only from host into container at `/sdk`
- **Builds:** Native Linux `.so` + Cross-compiled Windows `.dll` from same runner
- **Isolation:** Container provides clean, reproducible environment
- **Legal:** SDK never leaves your infrastructure

## Prerequisites

- **Fedora 43** (or any Linux with Podman/Docker)
- **Steamworks Partner Account** (free at https://partner.steamgames.com)
- **Steamworks SDK** downloaded from Valve
- **GitHub repository admin access** (to configure self-hosted runners)
- **~5GB disk space** for container, SDK, and build artifacts

## Step 1: Install Podman

Podman is the default container engine on Fedora and provides rootless containers.

```bash
# Verify Podman is installed (comes with Fedora 43)
podman --version

# If not installed
sudo dnf install podman
```

## Step 2: Download Steamworks SDK

1. **Log in to Steamworks Partner Portal:**
   - Visit: https://partner.steamgames.com
   - Create account if needed (free for developers)

2. **Download SDK:**
   - Navigate to: https://partner.steamgames.com/downloads/steamworks_sdk.zip
   - Current version: 1.62 or newer
   - Save to `~/Downloads/steamworks_sdk_<version>.zip`

3. **Extract SDK to host:**
   ```bash
   # Create SDK directory on host
   mkdir -p ~/steamworks-sdk

   # Extract SDK
   cd ~/Downloads
   unzip steamworks_sdk_*.zip -d ~/steamworks-sdk

   # Verify structure
   ls ~/steamworks-sdk/sdk/public/steam/         # Should list .h header files
   ls ~/steamworks-sdk/sdk/redistributable_bin/linux64/libsteam_api.so    # Linux library
   ls ~/steamworks-sdk/sdk/redistributable_bin/win64/steam_api64.dll      # Windows library
   ls ~/steamworks-sdk/sdk/redistributable_bin/win64/steam_api64.lib      # Windows import lib
   ```

**Important:** SDK stays on your host machine and is mounted read-only into the container. It is NEVER committed to git.

## Step 3: Build Runner Container Image

The Dockerfile defines the runner environment with all build tools.

```bash
# Navigate to SteamworksPy repository
cd ~/code/SteamworksPy

# Build container image (this takes 5-10 minutes on first run)
podman build -t steamworkspy-runner -f .github/runner/Dockerfile .

# Verify image was created
podman images | grep steamworkspy-runner
```

The container includes:
- Fedora 43 base
- gcc/g++ (native Linux compilation)
- MinGW (Windows cross-compilation)
- Git, curl, tar
- GitHub Actions runner binary

## Step 4: Register Runner with GitHub

Before running the container, you need to register it with GitHub to get a registration token.

1. **Get registration token:**
   - Visit: https://github.com/philippj/SteamworksPy/settings/actions/runners/new
   - Click "New self-hosted runner"
   - Select "Linux" and "x64"
   - **Copy the registration token** (it starts with `A...` and is ~100 characters)
   - **Keep this page open** - you'll need the token in the next step

2. **Configure runner in container:**
   ```bash
   # Run container interactively to configure (one-time setup)
   podman run -it --rm \
     -v ~/steamworks-sdk/sdk:/sdk:ro \
     -v runner-config:/home/runner/.runner:Z \
     --name steamworkspy-runner-setup \
     steamworkspy-runner \
     ./config.sh \
       --url https://github.com/philippj/SteamworksPy \
       --token <PASTE_YOUR_REGISTRATION_TOKEN_HERE> \
       --labels linux,x64,build \
       --name steamworkspy-container-runner \
       --work _work
   ```

   **Expected output:**
   ```
   --------------------------------------------------------------------------------
   |        ____ _ _   _   _       _          _        _   _                      |
   |       / ___(_) |_| | | |_   _| |__      / \   ___| |_(_) ___  _ __  ___      |
   |      | |  _| | __| |_| | | | | '_ \    / _ \ / __| __| |/ _ \| '_ \/ __|     |
   |      | |_| | | |_|  _  | |_| | |_) |  / ___ \ (__| |_| | (_) | | | \__ \     |
   |       \____|_|\__|_| |_|\__,_|_.__/  /_/   \_\___|\__|_|\___/|_| |_|___/     |
   |                                                                              |
   |                       Self-hosted runner registration                        |
   |                                                                              |
   --------------------------------------------------------------------------------

   # Authentication
   √ Connected to GitHub

   # Runner Registration
   √ Runner successfully added
   √ Runner connection is good

   # Runner settings
   √ Settings Saved.
   ```

3. **Verify registration:**
   - Visit: https://github.com/philippj/SteamworksPy/settings/actions/runners
   - You should see **"steamworkspy-container-runner"** with status **"Offline"** (normal, we haven't started it yet)

## Step 5: Run Container Persistently

Now that the runner is configured, run it as a persistent container that auto-starts on boot.

```bash
# Create and start runner container
podman run -d \
  --name steamworkspy-runner \
  -v ~/steamworks-sdk/sdk:/sdk:ro \
  -v runner-config:/home/runner/.runner:Z \
  -v runner-work:/home/runner/_work:Z \
  --restart always \
  steamworkspy-runner

# Verify container is running
podman ps | grep steamworkspy-runner

# Check runner logs
podman logs -f steamworkspy-runner
```

**Expected log output:**
```
√ Connected to GitHub

2024-01-15 12:34:56Z: Listening for Jobs
```

**Enable auto-start on system boot:**

```bash
# Enable Podman restart service for user containers
systemctl --user enable podman-restart.service

# Enable lingering (allows user services to run even when not logged in)
loginctl enable-linger $USER

# Verify it's enabled
systemctl --user status podman-restart.service
```

## Step 6: Verify Setup

Verify the runner is working correctly:

1. **Check container status:**
   ```bash
   podman ps
   # Should show steamworkspy-runner with STATUS "Up ..."
   ```

2. **Verify SDK mounted:**
   ```bash
   podman exec steamworkspy-runner ls /sdk/public/steam
   # Should list header files like steam_api.h, steam_gameserver.h, etc.

   podman exec steamworkspy-runner ls /sdk/redistributable_bin/linux64
   # Should show libsteam_api.so

   podman exec steamworkspy-runner ls /sdk/redistributable_bin/win64
   # Should show steam_api64.dll and steam_api64.lib
   ```

3. **Verify build tools:**
   ```bash
   # Native Linux compiler
   podman exec steamworkspy-runner gcc --version

   # Windows cross-compiler
   podman exec steamworkspy-runner x86_64-w64-mingw32-gcc --version
   ```

4. **Check GitHub runner status:**
   - Visit: https://github.com/philippj/SteamworksPy/settings/actions/runners
   - **steamworkspy-container-runner** should show status **"Idle"** (green)

5. **Test with a workflow:**
   ```bash
   # Make a small change and push to a branch
   cd ~/code/SteamworksPy
   git checkout -b test-ci
   echo "# CI Test" >> docs/CI_SETUP.md
   git add docs/CI_SETUP.md
   git commit -m "Test CI setup"
   git push origin test-ci

   # Create a pull request on GitHub
   # The workflow should automatically trigger and run on your self-hosted runner
   ```

## Managing the Runner

### View Logs

```bash
# Follow logs in real-time
podman logs -f steamworkspy-runner

# View recent logs
podman logs --tail 100 steamworkspy-runner
```

### Stop/Start/Restart

```bash
# Stop runner
podman stop steamworkspy-runner

# Start runner
podman start steamworkspy-runner

# Restart runner
podman restart steamworkspy-runner

# Check status
podman ps -a | grep steamworkspy-runner
```

### Rebuild Container

If you update the Dockerfile or want to refresh the environment:

```bash
# Stop and remove old container
podman stop steamworkspy-runner
podman rm steamworkspy-runner

# Rebuild image
cd ~/code/SteamworksPy
podman build -t steamworkspy-runner -f .github/runner/Dockerfile .

# Create new container (reuses existing config volume)
podman run -d \
  --name steamworkspy-runner \
  -v ~/steamworks-sdk/sdk:/sdk:ro \
  -v runner-config:/home/runner/.runner:Z \
  -v runner-work:/home/runner/_work:Z \
  --restart always \
  steamworkspy-runner
```

### Update SDK

When Valve releases a new SDK version:

```bash
# Download new SDK from https://partner.steamgames.com
cd ~/Downloads
unzip steamworks_sdk_<new_version>.zip -d ~/steamworks-sdk-new

# Replace old SDK
rm -rf ~/steamworks-sdk/sdk
mv ~/steamworks-sdk-new/sdk ~/steamworks-sdk/

# Restart container to pick up new SDK
podman restart steamworkspy-runner
```

### Access Container Shell

For debugging:

```bash
# Open shell in running container
podman exec -it steamworkspy-runner /bin/bash

# Inside container, you can:
ls /sdk                          # Verify SDK mount
gcc --version                    # Check tools
x86_64-w64-mingw32-gcc --version # Check MinGW
cd _work/SteamworksPy/SteamworksPy/library && cat build_linux.sh  # View build scripts
```

## Creating Releases

Once CI is set up, creating a release is simple:

```bash
cd ~/code/SteamworksPy

# Create and push a version tag
git tag v1.7.0
git push origin v1.7.0

# Wait 5-10 minutes for CI to complete
# GitHub Release is automatically created with Linux and Windows binaries attached
```

Visit https://github.com/philippj/SteamworksPy/releases to see the automated release.

## Security Best Practices

### PR Protection

Malicious pull requests could execute arbitrary code on your runner. Protect yourself:

1. **Require approval for first-time contributors:**
   - Visit: https://github.com/philippj/SteamworksPy/settings/actions
   - Under "Fork pull request workflows from outside collaborators"
   - Select **"Require approval for first-time contributors"**

2. **Review PR code before approving CI runs**
   - Look for suspicious commands in changed files
   - Check for attempts to access/exfiltrate `/sdk`
   - Be especially careful with changes to `.github/workflows/` or `library/build_*.sh`

### SDK Security

- **Mounted read-only:** SDK at `/sdk` is mounted with `:ro` flag (cannot be modified by builds)
- **Never committed:** SDK is in `.gitignore` and never pushed to GitHub
- **Local only:** SDK never leaves your machine

### Container Isolation

- **Runs as non-root:** Container runs as `runner` user, not root
- **Separate from host:** Build processes can't affect host system
- **Clean workspace:** Each build gets fresh workspace via mounted volume

### Network Security

Consider adding firewall rules if running on a server:

```bash
# Allow only HTTPS to GitHub (Actions API)
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" destination address="github.com" port port="443" protocol="tcp" accept'
sudo firewall-cmd --reload
```

## Troubleshooting

### Runner shows "Offline" on GitHub

**Check container status:**
```bash
podman ps -a | grep steamworkspy-runner
```

**If not running:**
```bash
podman start steamworkspy-runner
podman logs steamworkspy-runner
```

**Common causes:**
- Container stopped after host reboot (enable auto-start: see Step 5)
- Network issue (check internet connectivity)
- Registration expired (re-register: see Step 4)

### Builds fail with "SDK not found"

**Verify SDK mounted:**
```bash
podman exec steamworkspy-runner ls /sdk
```

**If empty:**
- Check host SDK path exists: `ls ~/steamworks-sdk/sdk`
- Verify container was started with `-v` flag (see Step 5)
- Restart container: `podman restart steamworkspy-runner`

### Windows cross-compilation fails

**Check MinGW installed:**
```bash
podman exec steamworkspy-runner x86_64-w64-mingw32-gcc --version
```

**If not found:**
- Rebuild container: see "Rebuild Container" above
- Dockerfile may have changed; pull latest from repo

### "Permission denied" errors

**SELinux context issues (Fedora-specific):**

Add `:Z` flag to volume mounts:
```bash
-v runner-config:/home/runner/.runner:Z
-v runner-work:/home/runner/_work:Z
```

Already included in Step 5 commands.

### Disk space issues

**Check workspace size:**
```bash
podman volume inspect runner-work | grep Mountpoint
# Then check size at the mountpoint
sudo du -sh <mountpoint>
```

**Clean up old build artifacts:**
```bash
podman exec steamworkspy-runner rm -rf _work/SteamworksPy/SteamworksPy/redist/*
podman restart steamworkspy-runner
```

## Testing Cross-Compiled Windows DLL (Optional)

You can test the cross-compiled Windows DLL on Linux using Wine:

```bash
# Install Wine on Fedora
sudo dnf install wine

# Test Windows DLL loads
cd redist/windows
wine64 SteamworksPy64.dll

# If it loads without errors, cross-compilation was successful
```

**Note:** Full functionality requires Windows. This only tests that the DLL is properly formatted.

## Performance Notes

- **First build:** ~10-15 minutes (downloads runner, builds image, registers)
- **Subsequent builds:** ~2-5 minutes (just compilation)
- **Disk usage:** ~5GB (SDK: 3GB, container: 1GB, build artifacts: 1GB)
- **CPU usage:** Minimal when idle, peaks during builds

## Cost Analysis

**Infrastructure:**
- Reuse existing Fedora machine: **$0/month**
- Dedicated cloud VM (t3.small): **~$15/month**

**Time:**
- Initial setup: **3-4 hours** (one-time)
- Maintenance: **~30 min/month**

**ROI:** Pays for itself after 2nd release if you value your time.

## Alternative: Bare-Metal Runner (Not Recommended)

You can run the GitHub Actions runner directly on your Fedora host without Podman:

**Pros:**
- Simpler initial setup (no Dockerfile/containers)
- Slightly faster builds (no container overhead)

**Cons:**
- Pollutes host system with build dependencies
- Harder to reset if environment corrupted
- Less secure (no container isolation)
- Not documented here (containerized is recommended)

If you need bare-metal instructions, see GitHub's official docs: https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners

## Further Reading

- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Podman Documentation](https://docs.podman.io/)
- [Steamworks SDK Documentation](https://partner.steamgames.com/doc/sdk)
- [MinGW Cross-Compilation](https://www.mingw-w64.org/)

## Support

For issues with this CI setup:
1. Check this troubleshooting guide first
2. Check GitHub Actions logs: https://github.com/philippj/SteamworksPy/actions
3. Check container logs: `podman logs steamworkspy-runner`
4. Open an issue on GitHub with logs attached

---

**Legal Note:** This setup complies with Valve's Steamworks SDK license by keeping the SDK on infrastructure you control (your Fedora machine) and never redistributing it. The SDK is obtained directly from Valve with your partner account credentials.
