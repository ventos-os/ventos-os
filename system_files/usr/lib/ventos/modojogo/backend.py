"""Ponte Python <-> QML do Modo Jogo."""
import shutil
import subprocess
import threading
from pathlib import Path

from PySide6.QtCore import Property, QEvent, QObject, Qt, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QKeyEvent

import discovery
import launcher
import library
from store import Store

PAD_KEYS = {
    "up": Qt.Key.Key_Up, "down": Qt.Key.Key_Down, "left": Qt.Key.Key_Left, "right": Qt.Key.Key_Right,
    "accept": Qt.Key.Key_Return,   # A
    "back": Qt.Key.Key_Escape,     # B
    "x": Qt.Key.Key_F3,            # X  -> ação secundária (mods)
    "y": Qt.Key.Key_F4,            # Y  -> favorito
    "start": Qt.Key.Key_F1,        # Start  -> menu
    "select": Qt.Key.Key_F2,       # Select -> opções
    "prev": Qt.Key.Key_PageUp,     # LB
    "next": Qt.Key.Key_PageDown,   # RB
}


def _url(path: str) -> str:
    if not path or path.startswith(("http://", "https://", "file://")):
        return path or ""
    return QUrl.fromLocalFile(path).toString()


class Backend(QObject):
    gamesChanged = Signal()
    tagsChanged = Signal()
    settingsChanged = Signal()
    inputModeChanged = Signal()
    sessionChanged = Signal()
    toast = Signal(str)
    pathPicked = Signal(str, str)
    _discovered = Signal(list)
    _sessionEnded = Signal(str)

    def __init__(self, store=None, fullscreen=False):
        super().__init__()
        self.store = store or Store()
        self._fullscreen_flag = fullscreen
        self._found, self._full, self._games = [], [], []
        self._input_mode, self._synthetic = "kbm", False
        self._session, self._playing = None, ""
        self._dnd_iface, self._dnd_cookie = None, None
        self._window = None
        self._discovered.connect(self._on_discovered)
        self._sessionEnded.connect(self._on_session_end)

    # ------------------------------------------------------------ propriedades
    @Property("QVariantList", notify=gamesChanged)
    def games(self):
        return self._games

    @Property("QVariantList", notify=tagsChanged)
    def tags(self):
        return list(self.store.data["tags"])

    @Property("QVariantMap", notify=settingsChanged)
    def settings(self):
        return dict(self.store.data["settings"])

    @Property(str, notify=inputModeChanged)
    def inputMode(self):
        return self._input_mode

    @Property(str, notify=sessionChanged)
    def playing(self):
        return self._playing

    @Property(bool, notify=settingsChanged)
    def fullscreen(self):
        return bool(self._fullscreen_flag or self.store.setting("fullscreen"))

    @Property("QVariantList", constant=True)
    def consoles(self):
        return [{"id": k, "label": v["label"]} for k, v in library.CONSOLES.items()]

    @Property("QVariantList", constant=True)
    def kinds(self):
        return library.KINDS

    @Property("QVariantList", constant=True)
    def modKinds(self):
        return launcher.MOD_KINDS

    # ------------------------------------------------------------ janela / entrada
    def attach_window(self, window):
        self._window = window

    def eventFilter(self, obj, ev):
        if not self._synthetic and ev.type() in (QEvent.Type.KeyPress, QEvent.Type.MouseButtonPress, QEvent.Type.MouseMove):
            self._set_mode("kbm")
        return False

    def _set_mode(self, mode):
        if mode != self._input_mode:
            self._input_mode = mode
            self.inputModeChanged.emit()

    @Slot(str)
    def padAction(self, action):
        self._set_mode("gamepad")
        key = PAD_KEYS.get(action)
        win = self._window or QGuiApplication.focusWindow()
        if key is None or win is None:
            return
        self._synthetic = True
        try:
            for t in (QEvent.Type.KeyPress, QEvent.Type.KeyRelease):
                QGuiApplication.sendEvent(win, QKeyEvent(t, key, Qt.KeyboardModifier.NoModifier))
        finally:
            self._synthetic = False

    # ------------------------------------------------------------ biblioteca
    @Slot()
    def refresh(self):
        threading.Thread(target=lambda: self._discovered.emit(discovery.discover_all()), daemon=True).start()

    def _on_discovered(self, games):
        self._found = games
        self._rebuild()

    def _rebuild(self):
        self._full = library.merged_games(self._found, self.store, bool(self.store.setting("show_hidden")))
        self._games = []
        for g in self._full:
            d = {k: v for k, v in g.items() if k != "launch"}
            d["cover"] = _url(d["cover"])
            self._games.append(d)
        self.gamesChanged.emit()

    def _find(self, gid):
        return next((g for g in self._full if g["id"] == gid), None)

    @Slot(str)
    def toggleFavorite(self, gid):
        self.store.set_meta(gid, favorite=not self.store.meta(gid).get("favorite"))
        self._rebuild()

    @Slot(str, str)
    def setPriority(self, gid, mode):
        self.store.set_meta(gid, priority=mode if mode in ("inherit", "on", "off") else "inherit")
        self._rebuild()

    @Slot(str)
    def removeGame(self, gid):
        if gid.startswith("manual:"):
            self.store.remove_manual(gid)
        else:
            self.store.set_meta(gid, hidden=True)     # jogos descobertos são apenas ocultados
        self._rebuild()

    @Slot(str, result="QVariantMap")
    def gameForEdit(self, gid):
        if not gid:
            return {"id": "", "manual": True, "name": "", "kind": "command", "target": "", "console": "ps3",
                    "file": "", "emulator": "", "args": "", "installDir": "", "savesDir": "", "cover": "", "tags": []}
        g = self._find(gid) or {}
        if gid.startswith("manual:"):
            m = self.store.data["manual"].get(gid, {})
            return {"id": gid, "manual": True, "name": g.get("name", ""), "kind": m.get("kind", "command"),
                    "target": m.get("target", ""), "console": m.get("console", "ps3"), "file": m.get("file", ""),
                    "emulator": m.get("emulator", ""), "args": m.get("args", ""), "installDir": m.get("install_dir", ""),
                    "savesDir": m.get("saves_dir", ""), "cover": m.get("cover", ""), "tags": g.get("tags", [])}
        meta = self.store.meta(gid)
        return {"id": gid, "manual": False, "name": g.get("name", ""), "cover": meta.get("cover", ""),
                "savesDir": g.get("savesDir", ""), "tags": g.get("tags", [])}

    @Slot("QVariantMap", result=str)
    def saveGame(self, f):
        gid, name = f.get("id", ""), str(f.get("name", "")).strip()
        if not name:
            self.toast.emit("Dê um nome ao jogo.")
            return ""
        tags = [str(t) for t in f.get("tags", [])]
        if gid and not gid.startswith("manual:"):
            self.store.set_meta(gid, name=name, cover=f.get("cover", ""), saves_dir=f.get("savesDir", ""), tags=tags)
        else:
            fields = {"name": name, "kind": f.get("kind", "command"), "target": f.get("target", ""),
                      "console": f.get("console", ""), "file": f.get("file", ""), "emulator": f.get("emulator", ""),
                      "args": f.get("args", ""), "install_dir": f.get("installDir", ""),
                      "saves_dir": f.get("savesDir", ""), "cover": f.get("cover", "")}
            if gid:
                self.store.update_manual(gid, fields)
            else:
                gid = self.store.add_manual(fields)
            self.store.set_meta(gid, tags=tags)
        self._rebuild()
        self.toast.emit("Jogo salvo.")
        return gid

    @Slot(str, "QVariantList")
    def setTags(self, gid, tags):
        self.store.set_meta(gid, tags=[str(t) for t in tags])
        self._rebuild()

    @Slot(str, str, result=int)
    def scanFolder(self, console, folder):
        existing = {m.get("file") for m in self.store.data["manual"].values()}
        n = 0
        for f in library.scan_folder(console, folder):
            if f in existing:
                continue
            p = Path(f)
            name = p.parent.name if p.name.lower() == "eboot.bin" else p.stem
            self.store.add_manual({"name": name, "kind": "emulator", "console": console, "file": f})
            n += 1
        if n:
            self._rebuild()
        self.toast.emit(f"{n} jogo(s) adicionado(s).")
        return n

    # ------------------------------------------------------------ tags
    @Slot(str, result=bool)
    def addTag(self, name):
        ok = self.store.add_tag(name)
        self.tagsChanged.emit()
        return ok

    @Slot(str, str, result=bool)
    def renameTag(self, old, new):
        ok = self.store.rename_tag(old, new)
        self.tagsChanged.emit()
        self._rebuild()
        return ok

    @Slot(str)
    def deleteTag(self, name):
        self.store.delete_tag(name)
        self.tagsChanged.emit()
        self._rebuild()

    # ------------------------------------------------------------ mods
    @Slot(str, result="QVariantList")
    def modsFor(self, gid):
        return self.store.mods(gid)

    @Slot(str, "QVariantMap")
    def addMod(self, gid, mod):
        self.store.add_mod(gid, {"name": mod.get("name", "Mod"), "kind": mod.get("kind", "command"),
                                 "path": mod.get("path", ""), "args": mod.get("args", "")})
        self._rebuild()

    @Slot(str, str)
    def toggleMod(self, gid, mid):
        for m in self.store.mods(gid):
            if m["id"] == mid:
                self.store.update_mod(gid, mid, enabled=not m.get("enabled", True))

    @Slot(str, str)
    def removeMod(self, gid, mid):
        self.store.remove_mod(gid, mid)
        self._rebuild()

    @Slot(str, str)
    def runMod(self, gid, mid):
        mod = next((m for m in self.store.mods(gid) if m["id"] == mid), None)
        if not mod:
            return
        try:
            cmd = launcher.mod_command(mod)
        except launcher.LaunchError as exc:
            self.toast.emit(str(exc))
            return
        if cmd is None:                                  # zip/pasta: só abrir no Dolphin
            self.openInDolphin(mod.get("path", ""))
            return
        self._spawn(cmd, f"Mod iniciado: {mod['name']}")

    @Slot(str)
    def openInDolphin(self, path):
        if not path:
            self.toast.emit("Caminho vazio.")
            return
        self._spawn(launcher.dolphin_command(path), "Abrindo no Dolphin…")

    def _spawn(self, cmd, ok_msg):
        try:
            subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.toast.emit(ok_msg)
        except OSError as exc:
            self.toast.emit(f"Falha: {exc}")

    # ------------------------------------------------------------ configurações
    @Slot(str, "QVariant")
    def setSetting(self, key, value):
        self.store.set_setting(key, value)
        self.settingsChanged.emit()
        if key == "show_hidden":
            self._rebuild()

    @Slot(str)
    def notify(self, message):
        self.toast.emit(message)

    # ------------------------------------------------------------ seletor de arquivo (KDE)
    @Slot(str, str)
    def pickPath(self, field, kind):
        def work():
            home = str(Path.home())
            if shutil.which("kdialog"):
                cmd = ["kdialog", "--getexistingdirectory" if kind == "dir" else "--getopenfilename", home]
            elif shutil.which("zenity"):
                cmd = ["zenity", "--file-selection"] + (["--directory"] if kind == "dir" else [])
            else:
                self.toast.emit("Instale o kdialog para usar o seletor de arquivos.")
                return
            try:
                out = subprocess.run(cmd, capture_output=True, text=True).stdout.strip()
            except OSError:
                out = ""
            if out:
                self.pathPicked.emit(field, out)
        threading.Thread(target=work, daemon=True).start()

    # ------------------------------------------------------------ lançar jogos
    @Slot(str)
    def launch(self, gid):
        game = self._find(gid)
        if not game:
            return
        settings = self.store.data["settings"]
        try:
            for mod in self.store.mods(gid):                      # mods ativos que são executáveis
                if mod.get("enabled", True) and mod.get("run_on_start", True):
                    cmd = launcher.mod_command(mod)
                    if cmd:
                        subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            argv, env = launcher.build_command(game, settings)
            sess = launcher.GameSession(game, argv, env, settings, on_end=self._sessionEnded.emit)
            if self._session:
                self._session.stop()
            sess.start()
        except launcher.LaunchError as exc:
            self.toast.emit(str(exc))
            return
        self._session, self._playing = sess, game["name"]
        if sess.priority and settings.get("pr_dnd"):
            self._dnd_on()
        self.store.touch_played(gid)
        self._rebuild()
        self.sessionChanged.emit()
        self.toast.emit(f"Iniciando {game['name']}…")

    def _on_session_end(self, gid):
        self._dnd_off()
        self._session, self._playing = None, ""
        self.sessionChanged.emit()

    @Slot()
    def endSession(self):
        """Desfaz a prioridade de jogo agora (notificações, energia, GameMode)."""
        if self._session:
            self._session.stop()

    # Notificações do KDE: Inhibit é liberado automaticamente se este processo morrer.
    def _dnd_on(self):
        try:
            from PySide6.QtDBus import QDBusConnection, QDBusInterface
            iface = QDBusInterface("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                                   "org.freedesktop.Notifications", QDBusConnection.sessionBus())
            if not iface.isValid():
                return
            reply = iface.call("Inhibit", "Modo Jogo", "Jogando", {})
            args = reply.arguments()
            if args:
                self._dnd_iface, self._dnd_cookie = iface, int(args[0])
        except Exception as exc:                # sem D-Bus/KDE: simplesmente não silencia
            print("modojogo: não foi possível silenciar notificações:", exc, flush=True)

    def _dnd_off(self):
        if self._dnd_iface is not None and self._dnd_cookie is not None:
            try:
                self._dnd_iface.call("UnInhibit", self._dnd_cookie)
            except Exception:
                pass
        self._dnd_iface = self._dnd_cookie = None

    # ------------------------------------------------------------ sair
    @Slot()
    def shutdown(self):
        if self._session:
            self._session.stop()
        self._dnd_off()

    @Slot()
    def quit(self):
        QGuiApplication.quit()
