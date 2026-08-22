#!/usr/bin/env python3
"""Package OrbitUI: CosmosWeb (Orbit + Default themes only) + the Orbit screen
UI -> orbitui.tar.gz. Pulls from the sibling project folders at pack time.
Usage: python pack.py [out-dir]"""
import io, json, os, sys, tarfile, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WEB_APP = os.path.join(ROOT, "Mainsail Theme Switcher", "app")
RENDERER = os.path.join(ROOT, "CosmosUI Switcher", "renderer", "target",
                        "armv7-unknown-linux-musleabihf", "release", "cosmosui-renderer")
SCREEN_THEME = os.path.join(ROOT, "CosmosUI Switcher", "themes", "Orbit.cosmosui.zip")
DROP_THEMES = {"dmg", "marlin", "stock"}  # this distro ships Orbit + Default only
THEMES_JSON = [{"id": "orbit", "name": "Orbit"}, {"id": "cosmos", "name": "Default"}]
TEXT = {".html", ".css", ".js", ".json", ".md", ".sh"}

# OrbitUI keeps the Orbit look but drops the mission-control wordplay: every
# screen label is renamed to its plain meaning (exact full-string matches on
# the theme's text fields — actions/ids untouched).
LABELS = {
    "ABORT": "E-STOP", "ABORT MISSION": "EMERGENCY STOP",
    "LAUNCH": "PRINT", "LAUNCH PAD": "PRINT FILES", "pick a payload": "select a file",
    "GO FOR LAUNCH?": "START PRINT?",
    "SCRUB": "CANCEL", "SCRUB LAUNCH": "CANCEL PRINT",
    "STAND DOWN": "BACK", "ROGER": "OK",
    "FLIGHT STATUS": "PRINT STATUS", "live telemetry": "current job",
    "PAYLOAD": "FILE", "STAGE": "LAYER", "T-MINUS": "TIME LEFT", "MISSION": "ELAPSED",
    "ALT Z": "Z HEIGHT", "VELOCITY": "SPEED", "HOLD": "PAUSE",
    "BURNER": "NOZZLE", "BURNER PID": "NOZZLE PID",
    "PAD": "BED", "PAD SURVEY (MESH)": "BED MESH", "PAD SURVEY": "BED MESH",
    "Survey at working temperature for a smooth landing.": "Mesh at working temperature for best accuracy.",
    "THRUST": "FANS", "THRUSTERS": "FANS",
    "MAIN THRUSTER (PART)": "PART FAN", "SIDE BOOSTER (AUX)": "AUX FAN", "EXHAUST VENT (CASE)": "CASE FAN",
    "fan control": "part / aux / case",
    "BEACON": "LIGHTS", "BEACONS": "LIGHTS",
    "CABIN BEACON": "CASE LIGHT", "DOCKING LIGHT (TOOLHEAD)": "TOOLHEAD LIGHT",
    "NAV": "MOVE", "NAVIGATION": "MOVE", "jog & docking": "jog & homing",
    "DOCK ALL (G28)": "HOME ALL (G28)", "DOCK XY": "HOME XY", "DOCK Z": "HOME Z",
    "ENGINES OFF": "MOTORS OFF",
    "FUEL": "SPOOL", "FUEL DEPOT": "FILAMENT",  # home tile labels must fit ~6 chars
    "FUEL UP": "LOAD", "DRAIN": "UNLOAD", "COOL OFF": "COOLDOWN",
    "FEED": "EXTRUDE", "SIP BACK": "RETRACT", "FUEL LENGTH (MM)": "LENGTH (MM)",
    "GUIDE": "CALIB", "GUIDANCE": "CALIBRATION",
    "FULL ALIGNMENT": "FULL CALIBRATION", "VIBRATION DAMPERS": "INPUT SHAPER",
    "TRIM": "TUNE", "TRIM CONTROLS": "FINE-TUNE",
    "ALT TRIM Z": "Z OFFSET", "TRIM STEP (MM)": "STEP (MM)",
    "COMMS": "GCODE", "COMMS LOG": "CONSOLE",
    "SHIP": "SYSTEM", "SHIP CONFIG": "SETTINGS", "SHIP SYSTEMS": "SYSTEM",
    "manifest & maintenance": "info & maintenance", "PORTHOLE GLOW": "BRIGHTNESS",
    "UPLINK": "WIFI",
    "REFIT": "UPDATE", "REFIT (UPDATE COSMOS)": "UPDATE COSMOS",
    "REFIT FAILED": "UPDATE FAILED", "REFIT UNDERWAY": "UPDATE STARTED",
    "BLACK BOX": "SUPPORT ZIP", "BLACK BOX READY": "SUPPORT ZIP READY",
    "BLACK BOX FAILED": "SUPPORT ZIP FAILED",
    "POWER CYCLE": "REBOOT",  # home tile "CONFIG" already fits and reads fine
    "Reboot the whole ship?": "Reboot the printer?",
    "Restart the flight computer?": "Restart Klipper?",
    "Ship restarts shortly.": "Printer restarts shortly.",
    "EJECT COSMOSUI": "EJECT ORBITUI",
    "Remove this UI and restore the\nstock COSMOS screen?":
        "Remove OrbitUI (screen + web UI)\nand restore stock COSMOS?",
}

def rename_labels(obj):
    if isinstance(obj, dict):
        t = obj.get("text")
        if isinstance(t, str):
            if t in LABELS:
                obj["text"] = LABELS[t]
            elif t.startswith("BURN TEMP"):  # holds a mangled degree sign — prefix match
                obj["text"] = "NOZZLE TEMP" + t[len("BURN TEMP"):]
        for v in obj.values():
            rename_labels(v)
    elif isinstance(obj, list):
        for v in obj:
            rename_labels(v)

def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else HERE
    for p, what in ((WEB_APP, "CosmosWeb app"), (RENDERER, "screen renderer"),
                    (SCREEN_THEME, "Orbit screen theme")):
        if not os.path.exists(p):
            sys.exit(f"{what} missing: {p}")
    out = os.path.join(out_dir, "orbitui.tar.gz")
    with tarfile.open(out, "w:gz") as tar:
        def add(name, data, mode=0o644):
            # 'orbitui-install/': must differ from the runtime /user-resource/orbitui
            info = tarfile.TarInfo("orbitui-install/" + name)
            info.size = len(data)
            info.mode = mode
            tar.addfile(info, io.BytesIO(data))
        for script in ("install.sh", "uninstall.sh"):
            with open(os.path.join(HERE, script), "rb") as f:
                add(script, f.read().replace(b"\r\n", b"\n"), 0o755)
        # web app, minus the themes this distro drops
        for root, dirs, files in os.walk(WEB_APP):
            rel_root = os.path.relpath(root, WEB_APP).replace(os.sep, "/")
            if rel_root == "themes":
                dirs[:] = [d for d in dirs if d not in DROP_THEMES]
            for fn in sorted(files):
                rel = (rel_root + "/" if rel_root != "." else "") + fn
                with open(os.path.join(root, fn), "rb") as f:
                    data = f.read()
                if rel == "themes/themes.json":
                    data = (json.dumps(THEMES_JSON, indent=2) + "\n").encode()
                elif os.path.splitext(fn)[1] in TEXT:
                    data = data.replace(b"\r\n", b"\n")
                add("web/app/" + rel, data)
        # screen renderer + Orbit theme bundle, with every label renamed to its
        # plain meaning (see LABELS). The theme's eject button fires the
        # renderer's hardcoded /user-resource/cosmosui/uninstall.sh — the
        # installer puts the combined uninstaller there.
        with open(RENDERER, "rb") as f:
            add("screen/cosmosui-renderer", f.read(), 0o755)
        z = zipfile.ZipFile(SCREEN_THEME)
        for n in z.namelist():
            if n.endswith("/"):
                continue
            data = z.read(n)
            if n == "ui.json":
                ui = json.loads(data.decode("utf-8"))
                rename_labels(ui)
                data = json.dumps(ui, indent=1, ensure_ascii=False).encode("utf-8")
            add("screen/theme/" + n, data)
    print(f"wrote {out}")
    print("On the printer:  tar xzf orbitui.tar.gz && sh orbitui-install/install.sh")

if __name__ == "__main__":
    main()
