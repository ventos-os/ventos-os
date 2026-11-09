"""Biblioteca unificada: jogos descobertos + jogos/ROMs adicionados manualmente + metadados do usuário."""
import os
from pathlib import Path

CONSOLES = {
    "ps3":     {"label": "PlayStation 3",   "exts": (".pkg",),          "names": ("eboot.bin",)},
    "ps4":     {"label": "PlayStation 4",   "exts": (),                 "names": ("eboot.bin",)},
    "x360":    {"label": "Xbox 360",        "exts": (".xex", ".iso"),   "names": ()},
    "switch1": {"label": "Nintendo Switch", "exts": (".xci", ".nsp"),   "names": ()},
    "switch2": {"label": "Nintendo Switch 2", "exts": (".xci", ".nsp"), "names": ()},
}

SOURCE_LABELS = {
    "steam": "Steam", "heroic": "Heroic (Epic/GOG)", "lutris": "Lutris", "bottles": "Bottles",
    "waydroid": "Android", "emulator": "Emulador", "manual": "Manual",
}

KINDS = ["exe", "bat", "sh", "flatpak", "url", "command", "emulator"]

DEFAULT_SOURCE_TAGS = {"waydroid": ["Android"], "emulator": ["Emulador"]}


def scan_folder(console: str, folder: str, max_depth: int = 4):
    """Lista arquivos de jogo de um console dentro de uma pasta."""
    spec = CONSOLES.get(console)
    if not spec or not os.path.isdir(folder):
        return []
    found = []
    base_depth = folder.rstrip("/").count("/")
    for root, dirs, files in os.walk(folder):
        if root.count("/") - base_depth >= max_depth:
            dirs[:] = []
        for f in files:
            low = f.lower()
            if low in spec["names"] or low.endswith(spec["exts"]):
                found.append(os.path.join(root, f))
    return sorted(found)


def manual_to_game(gid: str, m: dict) -> dict:
    kind = m.get("kind", "command")
    emu = kind == "emulator"
    return {
        "id": gid, "name": m.get("name", "Sem nome"),
        "source": "emulator" if emu else "manual",
        "console": m.get("console", "") if emu else "",
        "cover": m.get("cover", ""), "install_dir": m.get("install_dir", ""),
        "saves_dir": m.get("saves_dir", ""), "manual": True,
        "launch": {"type": "emulator" if emu else "manual", "kind": kind, "target": m.get("target", ""),
                   "console": m.get("console", ""), "file": m.get("file", ""),
                   "emulator": m.get("emulator", ""), "args": m.get("args", "")},
    }


def merged_games(discovered, store, include_hidden=False):
    """Retorna a lista unificada (dicts prontos para a interface). O spec de lançamento fica em 'launch'."""
    games = list(discovered)
    games += [manual_to_game(gid, m) for gid, m in store.data["manual"].items()]
    out = []
    for g in games:
        meta = store.meta(g["id"])
        if meta.get("hidden") and not include_hidden:
            continue
        tags = list(dict.fromkeys(list(meta.get("tags", [])) if "tags" in meta
                                  else DEFAULT_SOURCE_TAGS.get(g["source"], [])))
        console = g.get("console", "")
        out.append({
            "id": g["id"],
            "name": meta.get("name") or g["name"],
            "source": g["source"],
            "sourceLabel": SOURCE_LABELS.get(g["source"], g["source"]),
            "console": console,
            "consoleLabel": CONSOLES.get(console, {}).get("label", ""),
            "cover": meta.get("cover") or g.get("cover", ""),
            "favorite": bool(meta.get("favorite")),
            "tags": tags,
            "lastPlayed": float(meta.get("last_played", 0)),
            "playCount": int(meta.get("play_count", 0)),
            "hidden": bool(meta.get("hidden")),
            "manual": bool(g.get("manual")),
            "installDir": g.get("install_dir", ""),
            "savesDir": meta.get("saves_dir") or g.get("saves_dir", ""),
            "priority": meta.get("priority", "inherit"),
            "modsCount": len(store.mods(g["id"])),
            "launch": g["launch"],
        })
    out.sort(key=lambda x: x["name"].lower())
    return out
