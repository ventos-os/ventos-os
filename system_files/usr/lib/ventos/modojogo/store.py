"""Armazenamento do Modo Jogo: JSON com gravação atômica (jogos manuais, metadados, mods, tags, configurações)."""
import json
import os
import tempfile
import time
import uuid
from pathlib import Path

DEFAULT_TAGS = [
    "Jogo de luta", "Jogo de luta 2D", "Jogo de luta 3D", "Plataforma", "RPG",
    "FPS", "Emulador", "Android", "Port de PC", "Streaming",
]

DEFAULT_SETTINGS = {
    "priority_enabled": True,   # "Prioridade de jogo" ligada por padrão
    "pr_gamemode": True,        # Feral GameMode (governador de CPU, prioridade do processo)
    "pr_mangohud": False,       # MangoHud (opcional)
    "pr_power": True,           # perfil de energia "Desempenho", quando suportado
    "pr_dnd": True,             # silenciar notificações do KDE durante o jogo
    "fullscreen": False,
    "switch2_emulator": "lichii",
    "show_hidden": False,
}


def data_dir() -> Path:
    base = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
    return Path(base) / "ventos-modojogo"


class Store:
    def __init__(self, path=None):
        self.path = Path(path) if path else data_dir() / "library.json"
        self.data = self._load()

    # ---------- persistência ----------
    def _load(self):
        data = {"version": 1, "manual": {}, "meta": {}, "mods": {},
                "tags": list(DEFAULT_TAGS), "settings": dict(DEFAULT_SETTINGS)}
        try:
            loaded = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return data
        if isinstance(loaded, dict):
            for key in ("manual", "meta", "mods"):
                if isinstance(loaded.get(key), dict):
                    data[key] = loaded[key]
            if isinstance(loaded.get("tags"), list):
                data["tags"] = [str(t) for t in loaded["tags"]]
            if isinstance(loaded.get("settings"), dict):
                data["settings"].update(loaded["settings"])
        return data

    def save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=self.path.parent, prefix=".library-", suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                json.dump(self.data, fh, ensure_ascii=False, indent=2)
            os.replace(tmp, self.path)
        except BaseException:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise

    # ---------- jogos manuais ----------
    def add_manual(self, fields: dict) -> str:
        gid = "manual:" + uuid.uuid4().hex[:8]
        self.data["manual"][gid] = dict(fields)
        self.save()
        return gid

    def update_manual(self, gid: str, fields: dict):
        if gid in self.data["manual"]:
            self.data["manual"][gid].update(fields)
            self.save()

    def remove_manual(self, gid: str):
        for key in ("manual", "meta", "mods"):
            self.data[key].pop(gid, None)
        self.save()

    # ---------- metadados (favorito, tags, capa, prioridade...) ----------
    def meta(self, gid: str) -> dict:
        return self.data["meta"].get(gid, {})

    def set_meta(self, gid: str, **kv):
        self.data["meta"].setdefault(gid, {}).update(kv)
        self.save()

    def touch_played(self, gid: str):
        m = self.data["meta"].setdefault(gid, {})
        m["last_played"] = time.time()
        m["play_count"] = int(m.get("play_count", 0)) + 1
        self.save()

    # ---------- tags ----------
    def add_tag(self, name: str) -> bool:
        name = name.strip()
        if not name or name.lower() in (t.lower() for t in self.data["tags"]):
            return False
        self.data["tags"].append(name)
        self.save()
        return True

    def rename_tag(self, old: str, new: str) -> bool:
        new = new.strip()
        if old not in self.data["tags"] or not new:
            return False
        if new.lower() != old.lower() and new.lower() in (t.lower() for t in self.data["tags"]):
            return False
        self.data["tags"] = [new if t == old else t for t in self.data["tags"]]
        for m in self.data["meta"].values():
            m["tags"] = [new if t == old else t for t in m.get("tags", [])]
        self.save()
        return True

    def delete_tag(self, name: str):
        self.data["tags"] = [t for t in self.data["tags"] if t != name]
        for m in self.data["meta"].values():
            m["tags"] = [t for t in m.get("tags", []) if t != name]
        self.save()

    # ---------- mods ----------
    def mods(self, gid: str) -> list:
        return [dict(m) for m in self.data["mods"].get(gid, [])]

    def add_mod(self, gid: str, mod: dict) -> str:
        mid = uuid.uuid4().hex[:8]
        entry = {"enabled": True, "run_on_start": True, "args": "", **mod, "id": mid}
        self.data["mods"].setdefault(gid, []).append(entry)
        self.save()
        return mid

    def update_mod(self, gid: str, mid: str, **kv):
        for m in self.data["mods"].get(gid, []):
            if m["id"] == mid:
                m.update(kv)
        self.save()

    def remove_mod(self, gid: str, mid: str):
        self.data["mods"][gid] = [m for m in self.data["mods"].get(gid, []) if m["id"] != mid]
        self.save()

    # ---------- configurações ----------
    def setting(self, key, default=None):
        return self.data["settings"].get(key, DEFAULT_SETTINGS.get(key, default))

    def set_setting(self, key, value):
        self.data["settings"][key] = value
        self.save()
