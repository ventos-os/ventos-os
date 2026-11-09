"""Descoberta de jogos instalados: Steam, Heroic (Epic/GOG), Lutris, Bottles e apps Android (Waydroid)."""
import glob
import json
import os
import re
import shutil
import sqlite3
import subprocess
from pathlib import Path

STEAM_FLATPAK = "com.valvesoftware.Steam"
HEROIC_FLATPAK = "com.heroicgameslauncher.hgl"
LUTRIS_FLATPAK = "net.lutris.Lutris"
BOTTLES_FLATPAK = "com.usebottles.bottles"

STEAM_IGNORE = re.compile(r"^(Proton|Steam Linux Runtime|Steamworks Common|Steam Controller|SteamVR|Steam Deck)", re.I)


def _home() -> Path:
    return Path.home()


def _is_flatpak_path(p) -> bool:
    return "/.var/app/" in str(p)


def _read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def _kv(text: str) -> dict:
    out = {}
    for k, v in re.findall(r'"([^"]+)"\s+"([^"]*)"', text):
        out.setdefault(k, v)
    return out


# ---------------------------------------------------------------- Steam
def steam_roots():
    h = _home()
    cands = [h / ".var/app" / STEAM_FLATPAK / ".local/share/Steam",
             h / ".local/share/Steam", h / ".steam/steam"]
    seen, roots = set(), []
    for c in cands:
        if c.is_dir():
            real = os.path.realpath(c)
            if real not in seen:
                seen.add(real)
                roots.append(c)
    return roots


def _steam_cover(root: Path, appid: str) -> str:
    cache = root / "appcache" / "librarycache"
    for pat in (f"{appid}_library_600x900.jpg", f"{appid}/**/library_600x900.jpg",
                f"{appid}_header.jpg", f"{appid}/**/header.jpg"):
        hits = sorted(glob.glob(str(cache / pat), recursive=True))
        if hits:
            return hits[0]
    return ""


def steam_games():
    games = {}
    for root in steam_roots():
        libs = [root]
        vdf = root / "steamapps" / "libraryfolders.vdf"
        try:
            for p in re.findall(r'"path"\s+"([^"]+)"', vdf.read_text(encoding="utf-8", errors="replace")):
                libs.append(Path(p))
        except OSError:
            pass
        flat = _is_flatpak_path(root)
        for lib in libs:
            for acf in sorted(glob.glob(str(lib / "steamapps" / "appmanifest_*.acf"))):
                try:
                    kv = _kv(Path(acf).read_text(encoding="utf-8", errors="replace"))
                except OSError:
                    continue
                appid, name = kv.get("appid"), kv.get("name")
                if not appid or not name or STEAM_IGNORE.match(name):
                    continue
                try:
                    if not int(kv.get("StateFlags", "4")) & 4:
                        continue            # não está totalmente instalado
                except ValueError:
                    pass
                gid = f"steam:{appid}"
                if gid in games:
                    continue
                games[gid] = {"id": gid, "name": name, "source": "steam",
                              "cover": _steam_cover(root, appid),
                              "install_dir": str(lib / "steamapps" / "common" / kv.get("installdir", "")),
                              "launch": {"type": "steam", "appid": appid, "flatpak": flat}}
    return list(games.values())


# ---------------------------------------------------------------- Heroic
def heroic_roots():
    h = _home()
    return [p for p in (h / ".var/app" / HEROIC_FLATPAK / "config/heroic", h / ".config/heroic") if p.is_dir()]


def heroic_games():
    games = {}
    for root in heroic_roots():
        flat = _is_flatpak_path(root)
        titles, covers = {}, {}

        def learn(items, key="library"):
            for it in (items.get(key, []) if isinstance(items, dict) else items or []):
                if isinstance(it, dict) and it.get("app_name"):
                    titles[it["app_name"]] = it.get("title") or it["app_name"]
                    covers[it["app_name"]] = it.get("art_square") or it.get("art_cover") or ""

        learn(_read_json(root / "store_cache/legendary_library.json") or {}, "library")
        learn(_read_json(root / "store_cache/gog_library.json") or {}, "games")
        side = _read_json(root / "sideload_apps/library.json") or {}
        learn(side, "games")

        found = []   # (app_name, runner, install_path)
        epic = _read_json(root / "legendaryConfig/legendary/installed.json")
        if isinstance(epic, dict):
            for app, info in epic.items():
                if isinstance(info, dict):
                    titles.setdefault(app, info.get("title") or app)
                    found.append((app, "legendary", info.get("install_path", "")))
        gog = _read_json(root / "gog_store/installed.json")
        if isinstance(gog, dict):
            for info in gog.get("installed", []):
                if isinstance(info, dict) and info.get("appName"):
                    found.append((info["appName"], "gog", info.get("install_path", "")))
        for it in (side.get("games", []) if isinstance(side, dict) else []):
            if isinstance(it, dict) and it.get("app_name"):
                found.append((it["app_name"], "sideload", (it.get("install") or {}).get("executable", "")))

        for app, runner, path in found:
            gid = f"heroic:{runner}:{app}"
            games.setdefault(gid, {"id": gid, "name": titles.get(app, app), "source": "heroic",
                                   "cover": covers.get(app, ""), "install_dir": path,
                                   "launch": {"type": "heroic", "app": app, "runner": runner, "flatpak": flat}})
    return list(games.values())


# ---------------------------------------------------------------- Lutris
def lutris_games():
    h = _home()
    out = []
    for data, flat in ((h / ".var/app" / LUTRIS_FLATPAK / "data/lutris", True), (h / ".local/share/lutris", False)):
        db = data / "pga.db"
        if not db.is_file():
            continue
        try:
            con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
            rows = con.execute("SELECT id, name, slug, runner FROM games WHERE installed = 1").fetchall()
            con.close()
        except sqlite3.Error:
            continue
        for gid, name, slug, runner in rows:
            cover = ""
            for sub in ("coverart", "banners"):
                for ext in ("jpg", "png"):
                    p = data / sub / f"{slug}.{ext}"
                    if p.is_file():
                        cover = str(p)
                        break
                if cover:
                    break
            out.append({"id": f"lutris:{gid}", "name": name, "source": "lutris", "cover": cover,
                        "install_dir": "", "launch": {"type": "lutris", "slug": slug, "runner": runner, "flatpak": flat}})
        if out:
            break
    return out


# ---------------------------------------------------------------- Bottles
def bottles_games():
    try:
        import yaml
    except ImportError:
        return []
    h = _home()
    out = []
    for base in (h / ".var/app" / BOTTLES_FLATPAK / "data/bottles/bottles", h / ".local/share/bottles/bottles"):
        for cfg in sorted(glob.glob(str(base / "*" / "bottle.yml"))):
            try:
                conf = yaml.safe_load(Path(cfg).read_text(encoding="utf-8")) or {}
            except (OSError, yaml.YAMLError):
                continue
            bname = conf.get("Name") or Path(cfg).parent.name
            progs = conf.get("External_Programs") or {}
            for pid, prog in (progs.items() if isinstance(progs, dict) else []):
                if isinstance(prog, dict) and prog.get("name"):
                    out.append({"id": f"bottles:{bname}:{prog['name']}", "name": prog["name"], "source": "bottles",
                                "cover": "", "install_dir": str(Path(prog.get("path", "")).parent),
                                "launch": {"type": "bottles", "bottle": bname, "program": prog["name"]}})
    return out


# ---------------------------------------------------------------- Waydroid
def parse_waydroid_apps(text: str):
    apps, cur = [], {}
    for line in text.splitlines():
        if line.startswith("Name:"):
            if cur.get("package"):
                apps.append(cur)
            cur = {"name": line.split(":", 1)[1].strip()}
        elif line.startswith("packageName:"):
            cur["package"] = line.split(":", 1)[1].strip()
    if cur.get("package"):
        apps.append(cur)
    return apps


def waydroid_games():
    if not shutil.which("waydroid") or not Path("/var/lib/waydroid/.extras-done").exists():
        return []
    try:
        res = subprocess.run(["waydroid", "app", "list"], capture_output=True, text=True, timeout=8)
    except (OSError, subprocess.SubprocessError):
        return []
    return [{"id": f"android:{a['package']}", "name": a["name"], "source": "waydroid", "cover": "",
             "install_dir": "", "launch": {"type": "waydroid", "package": a["package"]}}
            for a in parse_waydroid_apps(res.stdout)]


# ---------------------------------------------------------------- tudo
def discover_all():
    games = []
    for fn in (steam_games, heroic_games, lutris_games, bottles_games, waydroid_games):
        try:
            games.extend(fn())
        except Exception as exc:     # uma fonte quebrada não pode derrubar a biblioteca
            print(f"modojogo: falha em {fn.__name__}: {exc}", flush=True)
    return games
