"""Comandos de lançamento, mods e sessão de jogo (prioridade). Sem dependência de Qt (testável)."""
import os
import shlex
import shutil
import subprocess
import threading
import time
from pathlib import Path

from discovery import BOTTLES_FLATPAK, HEROIC_FLATPAK, LUTRIS_FLATPAK, STEAM_FLATPAK


class LaunchError(Exception):
    pass


def _which_any(*names):
    for n in names:
        p = shutil.which(n)
        if p:
            return p
    for d in (Path.home() / ".local/bin", Path("/usr/local/bin")):
        for n in names:
            if (d / n).is_file() and os.access(d / n, os.X_OK):
                return str(d / n)
    return None


def file_kind(path: str) -> str:
    """'pe' (Windows), 'elf' (Linux) ou 'other' pelos primeiros bytes."""
    try:
        with open(path, "rb") as fh:
            head = fh.read(4)
    except OSError:
        return "other"
    if head[:2] == b"MZ":
        return "pe"
    if head == b"\x7fELF":
        return "elf"
    return "other"


def _args(text: str):
    return shlex.split(text) if text and text.strip() else []


# ------------------------------------------------------------ emuladores
def emulator_command(console: str, file: str, settings: dict, custom: str = ""):
    if custom.strip():
        return shlex.split(custom) + [file]
    if console == "ps3":
        if file.lower().endswith(".pkg"):
            return ["ps-pkg-open", file]
        return ["flatpak", "run", "net.rpcs3.RPCS3", "--no-gui", file]
    if console == "ps4":
        if os.path.isdir(file):
            for cand in ("eboot.bin", "EBOOT.BIN"):
                if os.path.isfile(os.path.join(file, cand)):
                    file = os.path.join(file, cand)
                    break
        return ["shadps4-open", file]
    if console == "x360":
        return ["xenia-open", file]
    if console == "switch1":
        return ["switch-open", file]
    if console == "switch2":
        name = settings.get("switch2_emulator", "lichii")
        binary = _which_any(name) or _which_any("lichii", "eglantine")
        if not binary:
            raise LaunchError("Emulador de Switch 2 não instalado. Rode: switch2-fetch")
        return [binary, file]
    raise LaunchError(f"Console desconhecido: {console!r}")


# ------------------------------------------------------------ lançamento
def build_command(game: dict, settings: dict):
    """Retorna (argv, env_extra). Levanta LaunchError se faltar algo."""
    spec = game["launch"]
    t = spec["type"]
    if t == "steam":
        base = ["flatpak", "run", STEAM_FLATPAK] if spec.get("flatpak") else ["steam"]
        return base + [f"steam://rungameid/{spec['appid']}"], {}
    if t == "heroic":
        url = f"heroic://launch?appName={spec['app']}&runner={spec['runner']}"
        base = ["flatpak", "run", HEROIC_FLATPAK] if spec.get("flatpak") else ["heroic"]
        return base + ["--no-gui", url], {}
    if t == "lutris":
        url = f"lutris:rungame/{spec['slug']}"
        base = ["flatpak", "run", LUTRIS_FLATPAK] if spec.get("flatpak") else ["lutris"]
        return base + [url], {}
    if t == "bottles":
        return ["flatpak", "run", "--command=bottles-cli", BOTTLES_FLATPAK, "run",
                "-p", spec["program"], "-b", spec["bottle"]], {}
    if t == "waydroid":
        return ["waydroid", "app", "launch", spec["package"]], {}
    if t == "emulator":
        if not spec.get("file"):
            raise LaunchError("Nenhum arquivo de jogo definido para este emulador.")
        return emulator_command(spec["console"], spec["file"], settings, spec.get("emulator", "")) + _args(spec.get("args", "")), {}
    if t == "manual":
        return _manual_command(spec), {}
    raise LaunchError(f"Tipo de jogo desconhecido: {t!r}")


def _manual_command(spec: dict):
    kind, target, extra = spec.get("kind", "command"), spec.get("target", ""), _args(spec.get("args", ""))
    if not target:
        raise LaunchError("Nenhum executável/comando/URL definido para este jogo.")
    if kind in ("exe", "bat"):
        if kind == "exe" and file_kind(target) == "elf":
            return [target] + extra
        return ["bottles-open", target]          # Windows: roda pela garrafa padrão do Bottles
    if kind == "sh":
        return ["bash", target] + extra
    if kind == "url":
        return ["xdg-open", target]
    if kind in ("flatpak", "command"):
        return shlex.split(target) + extra
    raise LaunchError(f"Tipo de entrada desconhecido: {kind!r}")


# ------------------------------------------------------------ mods
RUNNABLE_MOD_KINDS = ("exe", "bat", "sh", "jar", "script", "command")
MOD_KINDS = ["exe", "bat", "sh", "jar", "script", "command", "zip", "folder"]


def mod_command(mod: dict):
    """Comando para executar o mod, ou None se ele só puder ser aberto no Dolphin (zip/pasta)."""
    kind, path, extra = mod.get("kind", "command"), mod.get("path", ""), _args(mod.get("args", ""))
    if kind not in RUNNABLE_MOD_KINDS:
        return None
    if not path:
        raise LaunchError("Mod sem caminho/comando.")
    if kind == "exe":
        return ([path] + extra) if file_kind(path) == "elf" else ["bottles-open", path]
    if kind == "bat":
        return ["bottles-open", path]
    if kind == "sh":                              # .sh: executa em um terminal visível
        term = _which_any("konsole")
        return ([term, "-e", "bash", path] if term else ["bash", path]) + extra
    if kind == "jar":
        return ["java", "-jar", path] + extra
    if kind == "script":
        return [path] + extra
    return shlex.split(path) + extra               # command


def dolphin_command(path: str):
    if os.path.isfile(path):
        return ["dolphin", "--select", path]
    return ["dolphin", path]


# ------------------------------------------------------------ sessão / prioridade
def steam_game_pids(appid: str, proc_root: str = "/proc"):
    """PIDs de processos 'reaper SteamLaunch AppId=<id>' (como o Steam lança os jogos)."""
    needle = f"AppId={appid}".encode()
    pids = []
    try:
        entries = os.listdir(proc_root)
    except OSError:
        return pids
    for d in entries:
        if not d.isdigit():
            continue
        try:
            with open(f"{proc_root}/{d}/cmdline", "rb") as fh:
                parts = fh.read().split(b"\0")
        except OSError:
            continue
        if b"SteamLaunch" in parts and needle in parts:
            pids.append(int(d))
    return pids


def power_performance_available() -> bool:
    if not shutil.which("powerprofilesctl"):
        return False
    try:
        out = subprocess.run(["powerprofilesctl", "list"], capture_output=True, text=True, timeout=4).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    return "performance" in out


def effective_priority(game: dict, settings: dict) -> bool:
    mode = game.get("priority", "inherit")
    if mode == "on":
        return True
    if mode == "off":
        return False
    return bool(settings.get("priority_enabled", True))


class GameSession:
    """Mantém a 'Prioridade de jogo' enquanto o jogo roda e a desfaz ao terminar.

    Só usa mecanismos reversíveis e sem privilégios:
      - GameMode (gamemoded -r PID): governador de CPU/prioridade conforme /etc/gamemode.ini
      - perfil de energia "performance" mantido por um processo auxiliar (liberado ao encerrar)
      - MangoHud via variável de ambiente (opcional)
    """

    def __init__(self, game, argv, env_extra, settings, on_end=None):
        self.game, self.argv, self.settings, self.on_end = game, argv, settings, on_end
        self.env = dict(os.environ, **env_extra)
        self.proc = None
        self.power_helper = None
        self._registered = set()
        self._stop = threading.Event()
        self.priority = effective_priority(game, settings)

    def start(self):
        s = self.settings
        if self.priority:
            if s.get("pr_mangohud") and shutil.which("mangohud"):
                self.env["MANGOHUD"] = "1"
            if s.get("pr_power") and power_performance_available():
                self.power_helper = subprocess.Popen(
                    ["powerprofilesctl", "launch", "-p", "performance", "-r", "Modo Jogo", "--", "sleep", "infinity"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            self.proc = subprocess.Popen(self.argv, env=self.env, start_new_session=True,
                                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError as exc:
            self._release()
            raise LaunchError(f"Não consegui iniciar: {exc}")
        threading.Thread(target=self._watch, daemon=True).start()

    def _register_gamemode(self, pid):
        if pid in self._registered or not shutil.which("gamemoded"):
            return
        self._registered.add(pid)
        subprocess.run(["gamemoded", "-r", str(pid)], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=5, check=False)

    def _watch(self):
        spec = self.game["launch"]
        steam = spec.get("type") == "steam"
        started, seen, gone_polls = time.time(), False, 0
        while not self._stop.is_set():
            main_alive = self.proc.poll() is None
            pids = steam_game_pids(spec["appid"]) if steam else []
            if main_alive:
                pids = pids + [self.proc.pid]
            if self.priority and self.settings.get("pr_gamemode"):
                for pid in pids:
                    try:
                        self._register_gamemode(pid)
                    except (OSError, subprocess.SubprocessError):
                        pass
            if pids:
                seen, gone_polls = True, 0
            else:
                gone_polls += 1
                # jogo do Steam: espera ele aparecer (até 120 s); demais: encerra logo após o lançador sair
                limit = 3 if (seen or not steam) else 60
                if gone_polls >= limit:
                    break
            time.sleep(2)
        self._release()
        if self.on_end:
            self.on_end(self.game["id"])

    def _release(self):
        if self.power_helper and self.power_helper.poll() is None:
            self.power_helper.terminate()
        self.power_helper = None

    def stop(self):
        """Encerra a sessão de prioridade (não mata o jogo)."""
        self._stop.set()
