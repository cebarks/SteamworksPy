# CI/CD Quickstart Guide

This guide walks you through setting up automated builds from scratch. Follow these steps in order.

**Estimated time:** 3-4 hours (mostly waiting for downloads/builds)

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] Fedora 43 machine (or any Linux with Podman)
- [ ] ~10GB free disk space
- [ ] Steamworks Partner account (free at https://partner.steamgames.com)
- [ ] GitHub repository admin access
- [ ] Internet connection

---

## Step 1: Download Steamworks SDK (30 minutes)

### 1.1 Create Steamworks Partner Account (if needed)

1. Visit: https://partner.steamgames.com
2. Click "Sign in through Steam"
3. Log in with your Steam account
4. Complete registration (free, no payment required)
5. Accept Steamworks SDK agreement

### 1.2 Download SDK

1. Visit: https://partner.steamgames.com/downloads/list
2. Find "Steamworks SDK"
3. Click download (file: `steamworks_sdk_xxx.zip`, ~300MB)
4. Save to `~/Downloads/`

**Note:** SDK version changes over time. Current version is 1.62+

### 1.3 Extract SDK to Host

```bash
# Create SDK directory
mkdir -p ~/steamworks-sdk

# Extract (replace xxx with your version number)
cd ~/Downloads
unzip steamworks_sdk_*.zip -d ~/steamworks-sdk

# Verify extraction
ls ~/steamworks-sdk/sdk/public/steam/
# Should see: steam_api.h, steam_gameserver.h, etc.

ls ~/steamworks-sdk/sdk/redistributable_bin/linux64/
# Should see: libsteam_api.so

ls ~/steamworks-sdk/sdk/redistributable_bin/win64/
# Should see: steam_api64.dll, steam_api64.lib
```

**Checkpoint:** All three `ls` commands above should list files. If any directory is empty, extraction failed.

---

## Step 2: Build Runner Container (15 minutes)

### 2.1 Verify Podman Installed

```bash
podman --version
# Should show: podman version 4.x.x or newer

# If not installed:
sudo dnf install podman -y
```

### 2.2 Build Container Image

```bash
# Navigate to SteamworksPy repository
cd ~/code/SteamworksPy

# Build image (takes 5-10 minutes on first run)
podman build -t steamworkspy-runner -f .github/runner/Dockerfile .

# Expected output:
# STEP 1/8: FROM fedora:43
# ...
# STEP 8/8: CMD ["./run.sh"]
# COMMIT steamworkspy-runner
# Successfully tagged localhost/steamworkspy-runner:latest
```

### 2.3 Verify Image Built

```bash
podman images | grep steamworkspy-runner
# Should show:
# localhost/steamworkspy-runner  latest  <image-id>  X minutes ago  XXX MB
```

**Checkpoint:** Image should appear in the list with a recent timestamp.

---

## Step 3: Register Runner with GitHub (15 minutes)

### 3.1 Get Registration Token

1. **Open GitHub in browser:**
   - Visit: https://github.com/philippj/SteamworksPy/settings/actions/runners/new

2. **Select runner type:**
   - Operating System: **Linux**
   - Architecture: **x64**

3. **Copy registration token:**
   - Look for "Configure" section
   - Find the `--token` value (starts with `A`, ~100 characters)
   - **Copy this token** (you'll paste it in next step)
   - **Don't close this page yet** - you'll need it for reference

**Important:** Token expires after 1 hour. If you take a break, regenerate it.

### 3.2 Configure Runner in Container

```bash
# Run container interactively to register
podman run -it --rm \
  -v ~/steamworks-sdk/sdk:/sdk:ro \
  -v runner-config:/home/runner/.runner:Z \
  --name steamworkspy-runner-setup \
  steamworkspy-runner \
  ./config.sh \
    --url https://github.com/philippj/SteamworksPy \
    --token PASTE_YOUR_TOKEN_HERE \
    --labels linux,x64,build \
    --name steamworkspy-container-runner \
    --work _work
```

**Replace `PASTE_YOUR_TOKEN_HERE` with the actual token from GitHub!**

### 3.3 Expected Output

You should see:

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

**If you see errors:**
- "Invalid token" → Token expired, get a new one from GitHub
- "Connection failed" → Check internet connection
- "Permission denied" → Check Podman is installed correctly

### 3.4 Verify on GitHub

1. Visit: https://github.com/philippj/SteamworksPy/settings/actions/runners
2. You should see **"steamworkspy-container-runner"**
3. Status: **"Offline"** (normal - we haven't started it yet)

**Checkpoint:** Runner appears in GitHub settings, even if offline.

---

## Step 4: Start Runner Persistently (10 minutes)

### 4.1 Create and Start Container

```bash
# Create runner container that runs in background
podman run -d \
  --name steamworkspy-runner \
  -v ~/steamworks-sdk/sdk:/sdk:ro \
  -v runner-config:/home/runner/.runner:Z \
  -v runner-work:/home/runner/_work:Z \
  --restart always \
  steamworkspy-runner
```

**Expected output:** A long container ID (64 hex characters)

### 4.2 Verify Container Running

```bash
# Check container status
podman ps | grep steamworkspy-runner
# Should show: steamworkspy-runner, Up X seconds

# Check runner logs
podman logs -f steamworkspy-runner
# Should show:
# √ Connected to GitHub
#
# 20XX-XX-XX XX:XX:XXZ: Listening for Jobs
```

Press `Ctrl+C` to exit log view.

### 4.3 Verify on GitHub (Again)

1. Visit: https://github.com/philippj/SteamworksPy/settings/actions/runners
2. **"steamworkspy-container-runner"** should now show:
   - Status: **"Idle"** (green circle)

**Checkpoint:** Runner shows "Idle" status in GitHub. This means it's ready to accept jobs!

---

## Step 5: Enable Auto-Start on Boot (5 minutes)

Make the container start automatically when your machine reboots.

### 5.1 Enable Podman User Service

```bash
# Enable Podman restart service
systemctl --user enable podman-restart.service

# Enable user services to run even when not logged in
loginctl enable-linger $USER

# Verify it's enabled
systemctl --user status podman-restart.service
```

**Expected output:**
```
● podman-restart.service - Podman Start All Containers With Restart Policy
     Loaded: loaded (/usr/lib/systemd/user/podman-restart.service; enabled; preset: disabled)
     Active: inactive (dead)
```

"enabled" and "inactive" is correct - it only runs on boot.

### 5.2 Test Auto-Start (Optional)

```bash
# Reboot your machine
sudo reboot

# After reboot, check container status
podman ps | grep steamworkspy-runner
# Should show: steamworkspy-runner, Up X minutes

# Check GitHub
# Visit: https://github.com/philippj/SteamworksPy/settings/actions/runners
# Should still show "Idle"
```

**Checkpoint:** Container auto-starts after reboot.

---

## Step 6: Test CI/CD (30 minutes)

Now let's test that everything works!

### 6.1 Test Build on a Branch

```bash
# Make sure you're in the repo
cd ~/code/SteamworksPy

# Create a test branch
git checkout -b test-ci-setup

# Make a trivial change
echo "# CI Test $(date)" >> docs/QUICKSTART.md

# Commit and push
git add docs/QUICKSTART.md
git commit -m "Test CI/CD setup"
git push origin test-ci-setup
```

### 6.2 Create Pull Request

1. Visit: https://github.com/philippj/SteamworksPy/pulls
2. Click "New pull request"
3. Base: `master`, Compare: `test-ci-setup`
4. Click "Create pull request"
5. Title: "Test CI/CD Setup"
6. Click "Create pull request"

### 6.3 Watch Build Progress

1. On the PR page, you should see:
   - ⏳ "Some checks haven't completed yet"
   - Build Linux (native) - In progress
   - Build Windows (cross-compile) - In progress

2. Click "Details" to see live logs

3. Wait 5-10 minutes for builds to complete

4. Expected result:
   - ✅ Build Linux (native) - Success
   - ✅ Build Windows (cross-compile) - Success
   - ✅ All checks have passed

### 6.4 Check Runner Logs (Optional)

```bash
# On your Fedora machine, view runner logs
podman logs --tail 50 steamworkspy-runner

# You should see:
# Running job: Build Linux (native)
# ...
# Job Build Linux (native) completed with result: Succeeded
# Running job: Build Windows (cross-compile)
# ...
# Job Build Windows (cross-compile) completed with result: Succeeded
```

### 6.5 Download Build Artifacts (Optional)

1. On PR page, click "Details" for either build job
2. Scroll to bottom, find "Artifacts" section
3. Download `linux-x64` and/or `windows-x64`
4. Unzip and verify `.so` and `.dll` files are present

**Checkpoint:** Both builds pass, artifacts are downloadable.

---

## Step 7: Test Automated Release (30 minutes)

Test creating an automated GitHub Release.

### 7.1 Create a Test Release Tag

```bash
# Switch to master branch
cd ~/code/SteamworksPy
git checkout master

# Pull latest changes
git pull origin master

# Create a test tag
git tag v99.99.99-test

# Push tag to GitHub
git push origin v99.99.99-test
```

### 7.2 Watch Release Build

1. Visit: https://github.com/philippj/SteamworksPy/actions
2. You should see a new workflow run: "Build SteamworksPy"
3. Tag: `v99.99.99-test`
4. Jobs:
   - Build Linux (native)
   - Build Windows (cross-compile)
   - Create GitHub Release

5. Wait 5-10 minutes for all jobs to complete

### 7.3 Verify Release Created

1. Visit: https://github.com/philippj/SteamworksPy/releases
2. You should see: **"SteamworksPy v99.99.99-test"**
3. Click on it
4. Verify attached files:
   - `SteamworksPy.so`
   - `libsteam_api.so`
   - `SteamworksPy64.dll`
   - `steam_api64.dll`

### 7.4 Clean Up Test Release

```bash
# Delete test tag locally
git tag -d v99.99.99-test

# Delete test tag from GitHub
git push origin :refs/tags/v99.99.99-test

# Delete test release from GitHub web UI:
# 1. Visit: https://github.com/philippj/SteamworksPy/releases
# 2. Click "v99.99.99-test"
# 3. Click "Delete this release"
# 4. Confirm deletion
```

**Checkpoint:** Release was created automatically with all binaries attached.

---

## Step 8: Configure PR Security (10 minutes)

Protect yourself from malicious pull requests.

### 8.1 Require Approval for First-Time Contributors

1. Visit: https://github.com/philippj/SteamworksPy/settings/actions
2. Scroll to "Fork pull request workflows from outside collaborators"
3. Select: **"Require approval for first-time contributors"**
4. Click "Save"

This prevents untrusted code from running on your runner until you manually approve it.

### 8.2 Test Protection (Optional)

1. Create a fork of the repo (or ask someone else to)
2. Make a change and create a PR from the fork
3. On the PR page, you should see:
   - ⏸️ "Workflow awaiting approval"
   - Button: "Approve and run"
4. Review the code changes
5. If safe, click "Approve and run"

**Checkpoint:** First-time contributor PRs require manual approval.

---

## ✅ Setup Complete!

Congratulations! Your CI/CD system is now fully operational.

## What You've Achieved

✅ **Automated builds** on every PR and commit
✅ **Automated releases** on every version tag
✅ **Linux + Windows binaries** from single runner
✅ **Legal compliance** with Valve SDK licensing
✅ **Security protections** for untrusted PRs
✅ **Containerized** for easy maintenance

## Daily Usage

### Creating a New Release

```bash
# Commit your changes to master
git checkout master
git add .
git commit -m "Release v1.7.0"
git push origin master

# Tag the release
git tag v1.7.0
git push origin v1.7.0

# Wait 5-10 minutes
# → Release automatically created with binaries!
```

### Monitoring the Runner

```bash
# Check if runner is running
podman ps | grep steamworkspy-runner

# View recent logs
podman logs --tail 100 steamworkspy-runner

# Follow logs in real-time
podman logs -f steamworkspy-runner

# Restart runner (if needed)
podman restart steamworkspy-runner
```

### Updating the SDK

When Valve releases a new SDK version:

```bash
# Download new SDK from partner.steamgames.com
cd ~/Downloads
unzip steamworks_sdk_<new_version>.zip -d ~/steamworks-sdk-new

# Replace old SDK
rm -rf ~/steamworks-sdk/sdk
mv ~/steamworks-sdk-new/sdk ~/steamworks-sdk/

# Restart runner to pick up new SDK
podman restart steamworkspy-runner
```

## Troubleshooting

**Runner shows "Offline" on GitHub:**
```bash
# Check container status
podman ps -a | grep steamworkspy-runner

# If not running, start it
podman start steamworkspy-runner

# Check logs for errors
podman logs steamworkspy-runner
```

**Builds fail with "SDK not found":**
```bash
# Verify SDK mounted correctly
podman exec steamworkspy-runner ls /sdk/public/steam

# If empty, check host SDK exists
ls ~/steamworks-sdk/sdk/public/steam

# Restart container
podman restart steamworkspy-runner
```

**Container won't start after reboot:**
```bash
# Check auto-start is enabled
systemctl --user status podman-restart.service

# If not enabled
systemctl --user enable podman-restart.service
loginctl enable-linger $USER
```

For more troubleshooting, see [CI_SETUP.md](CI_SETUP.md).

## Next Steps

- **Close test PR:** Delete the `test-ci-setup` branch
- **Add CI badge:** Add workflow status badge to README
- **Customize workflow:** Edit `.github/workflows/build.yml` if needed
- **Share with contributors:** Point them to this guide

## Maintenance Schedule

- **Weekly:** Check runner logs for errors
- **Monthly:** Update Podman/Fedora packages (`sudo dnf upgrade`)
- **As needed:** Update SDK when Valve releases new version
- **Yearly:** Regenerate GitHub runner registration token

---

**Questions or issues?** See [CI_SETUP.md](CI_SETUP.md) for detailed reference documentation.
