# OrbitUI

<img width="2464" height="1267" alt="image" src="https://github.com/user-attachments/assets/e183dc2d-f583-4a5e-9dee-99694981bb64" />

<img width="959" height="543" alt="image" src="https://github.com/user-attachments/assets/93399653-d218-4065-8365-ee2965f5f87d" />
Note: the silly names like "burner" or "pad" have been removed from this build - it has standard ui names like nozzle and bed.


One-stop **Orbit UI distro** for [COSMOS firmware](https://github.com/OpenCentauri) on the Elegoo Centauri Carbon. A single installer that puts the Orbit look on both the printer's **touchscreen** and its **web interface**:

- **CosmosWeb** — the custom web dashboard, served at `/`. This distro ships two themes: **Orbit** (default) and **Default** (the stock COSMOS look). Mainsail stays installed at `/mainsail.html`.
- **Orbit screen UI** — the CosmosUI renderer + Orbit theme (from [CosmosUI-Switcher](https://github.com/shawn-makes-stuff/CosmosUI-Switcher)), replacing the stock screen UI as a supervised init service. For this distro the theme's labels are renamed to plain terms at pack time (no mission-control wordplay), a print starting anywhere auto-switches the screen to print status, and long file names ellipsis-truncate instead of overlapping.

**Just want to install it?** Grab `orbitui.tar.gz` from [Releases](https://github.com/shawn-makes-stuff/OrbitUI/releases) and skip to *Install*.

Everything is non-destructive: the read-only rootfs is untouched, all files live in `/user-resource` plus the `/etc` overlay, and `uninstall.sh` reverts both parts fully.

## Build the package

This repo is a thin distro — `pack.py` pulls from sibling checkouts at pack time (no duplicated sources). It expects these folders next to this one (clone/rename to match, or adjust the paths at the top of `pack.py`):

- web app: `../Mainsail Theme Switcher/app` — the CosmosWeb dashboard (themes filtered to orbit + cosmos)
- screen renderer: `../CosmosUI Switcher/renderer/target/armv7-unknown-linux-musleabihf/release/cosmosui-renderer` (build it first — see [CosmosUI-Switcher](https://github.com/shawn-makes-stuff/CosmosUI-Switcher))
- screen theme: `../CosmosUI Switcher/themes/Orbit.cosmosui.zip`

```
python pack.py
```
→ `orbitui.tar.gz`

## Install

```
scp -O orbitui.tar.gz root@<printer-ip>:/user-resource/
ssh root@<printer-ip>
cd /user-resource && tar xzf orbitui.tar.gz
sh orbitui-install/install.sh
```

No network? FAT32 USB stick (COSMOS auto-mounts at `/tmp/usb/<name>`), then run the same tar/install from the mount.

What it does:
1. **Web**: app → `/user-resource/cosmosweb/`, union webroot at `/etc/webui` (stock symlinks + our app), `/` redirects to CosmosWeb, Mainsail at `/mainsail.html`, sidebar link via `navi.json`.
2. **Screen**: renderer + theme → `/user-resource/cosmosui/`, init script `/etc/init.d/cosmosui` (rc 97), remembers and stops the current `screen_ui`, starts Orbit immediately.

No reboot required; one is recommended to confirm boot-time startup of both parts.

## Uninstall

Two equivalent ways — both remove **everything** (screen + web) and restore stock:

- On the printer screen: the **EJECT ORBITUI** button (the theme's eject fires `/user-resource/cosmosui/uninstall.sh`, where the installer places the combined uninstaller).
- Over SSH: `sh /user-resource/orbitui/uninstall.sh`

Restores the stock webroot symlink, `navi.json`, and the previous screen UI, then removes every file the distro added.

## Notes

- Dashboard settings live printer-side in the moonraker DB (namespace `cosmosweb`) and survive reinstalls. If a previous full CosmosWeb install had a now-stripped theme selected (DMG/Marlin/Plain), the UI falls back to the base dark look — pick Orbit or Default in ⚙ Settings.
- The screen renderer's hardware caveats are tracked in the [CosmosUI-Switcher](https://github.com/shawn-makes-stuff/CosmosUI-Switcher) addon README. First-run-in-foreground via SSH is a sensible precaution on a new machine.
- Works alongside the [cosmoace-integration](https://github.com/shawn-makes-stuff/cosmoace-integration) (Anycubic ACE Pro) — CosmosWeb's ACE panel and OrcaSlicer filament sync light up automatically when it's installed.
