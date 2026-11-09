import os
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "system_files/usr/lib/ventos/modojogo"))

import discovery  # noqa: E402
import launcher  # noqa: E402
import library  # noqa: E402
from store import Store  # noqa: E402


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        patcher = mock.patch.dict(os.environ, {"HOME": str(self.home), "XDG_DATA_HOME": str(self.home / "data")})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.addCleanup(self.tmp.cleanup)

    def write(self, rel, text="", binary=None):
        p = self.home / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        if binary is not None:
            p.write_bytes(binary)
        else:
            p.write_text(text, encoding="utf-8")
        return p


class StoreTests(Base):
    def test_tags_and_persistence(self):
        s = Store(self.home / "lib.json")
        self.assertIn("RPG", s.data["tags"])
        self.assertTrue(s.add_tag("Corrida"))
        self.assertFalse(s.add_tag("corrida"))           # duplicada (sem diferenciar maiúsculas)
        gid = s.add_manual({"name": "X", "kind": "command", "target": "echo"})
        s.set_meta(gid, tags=["RPG", "Corrida"])
        self.assertTrue(s.rename_tag("Corrida", "Racing"))
        self.assertEqual(s.meta(gid)["tags"], ["RPG", "Racing"])
        s.delete_tag("RPG")
        self.assertEqual(s.meta(gid)["tags"], ["Racing"])
        s2 = Store(self.home / "lib.json")               # recarrega do disco
        self.assertIn("Racing", s2.data["tags"])
        self.assertEqual(s2.meta(gid)["tags"], ["Racing"])

    def test_mods_crud(self):
        s = Store(self.home / "lib.json")
        mid = s.add_mod("g1", {"name": "Patch", "kind": "bat", "path": "/x.bat"})
        self.assertTrue(s.mods("g1")[0]["enabled"])
        s.update_mod("g1", mid, enabled=False)
        self.assertFalse(s.mods("g1")[0]["enabled"])
        s.remove_mod("g1", mid)
        self.assertEqual(s.mods("g1"), [])


class DiscoveryTests(Base):
    def test_steam(self):
        root = ".var/app/com.valvesoftware.Steam/.local/share/Steam"
        self.write(f"{root}/steamapps/libraryfolders.vdf", f'"libraryfolders" {{ "0" {{ "path" "{self.home}/Biblioteca2" }} }}')
        self.write(f"{root}/steamapps/appmanifest_10.acf", '"AppState"\n{\n"appid" "10"\n"name" "Jogo Um"\n"StateFlags" "4"\n"installdir" "JogoUm"\n}')
        self.write(f"{root}/steamapps/appmanifest_11.acf", '"AppState"\n{\n"appid" "11"\n"name" "Proton Experimental"\n"StateFlags" "4"\n}')
        self.write("Biblioteca2/steamapps/appmanifest_20.acf", '"AppState"\n{\n"appid" "20"\n"name" "Jogo Dois"\n"StateFlags" "6"\n}')
        self.write("Biblioteca2/steamapps/appmanifest_30.acf", '"AppState"\n{\n"appid" "30"\n"name" "Baixando"\n"StateFlags" "1026"\n}')
        self.write(f"{root}/appcache/librarycache/10_library_600x900.jpg", "img")
        games = {g["id"]: g for g in discovery.steam_games()}
        self.assertEqual(set(games), {"steam:10", "steam:20"})     # sem Proton e sem o jogo ainda baixando
        self.assertTrue(games["steam:10"]["cover"].endswith("10_library_600x900.jpg"))
        self.assertTrue(games["steam:10"]["launch"]["flatpak"])

    def test_heroic(self):
        root = ".var/app/com.heroicgameslauncher.hgl/config/heroic"
        self.write(f"{root}/legendaryConfig/legendary/installed.json", '{"Fortnite1": {"title": "Jogo Epic", "install_path": "/g/e"}}')
        self.write(f"{root}/gog_store/installed.json", '{"installed": [{"appName": "123", "install_path": "/g/gog"}]}')
        self.write(f"{root}/store_cache/gog_library.json", '{"games": [{"app_name": "123", "title": "Jogo GOG", "art_square": "http://x/a.jpg"}]}')
        self.write(f"{root}/sideload_apps/library.json", '{"games": [{"app_name": "side1", "title": "Meu App", "runner": "sideload"}]}')
        games = {g["id"]: g for g in discovery.heroic_games()}
        self.assertEqual(games["heroic:legendary:Fortnite1"]["name"], "Jogo Epic")
        self.assertEqual(games["heroic:gog:123"]["name"], "Jogo GOG")
        self.assertEqual(games["heroic:gog:123"]["cover"], "http://x/a.jpg")
        self.assertIn("heroic:sideload:side1", games)

    def test_lutris(self):
        d = self.home / ".local/share/lutris"
        d.mkdir(parents=True)
        con = sqlite3.connect(d / "pga.db")
        con.execute("CREATE TABLE games (id INTEGER, name TEXT, slug TEXT, runner TEXT, installed INTEGER)")
        con.execute("INSERT INTO games VALUES (1,'Lutris Jogo','lutris-jogo','wine',1), (2,'Nao instalado','x','wine',0)")
        con.commit(); con.close()
        games = discovery.lutris_games()
        self.assertEqual([g["name"] for g in games], ["Lutris Jogo"])
        self.assertEqual(games[0]["launch"]["slug"], "lutris-jogo")

    def test_bottles(self):
        try:
            import yaml  # noqa: F401
        except ImportError:
            self.skipTest("PyYAML ausente")
        self.write(".var/app/com.usebottles.bottles/data/bottles/bottles/Padrao/bottle.yml",
                   "Name: Padrao\nExternal_Programs:\n  abc:\n    name: Meu Programa\n    path: C:\\\\x\\\\a.exe\n")
        games = discovery.bottles_games()
        self.assertEqual(games[0]["launch"], {"type": "bottles", "bottle": "Padrao", "program": "Meu Programa"})

    def test_waydroid_parse(self):
        text = "Name: Calculadora\npackageName: com.android.calculator2\ncategories:\n\tandroid.intent.category.LAUNCHER\nName: Jogo\npackageName: org.x.jogo\n"
        apps = discovery.parse_waydroid_apps(text)
        self.assertEqual([a["package"] for a in apps], ["com.android.calculator2", "org.x.jogo"])


class LibraryTests(Base):
    def test_merge_manual_hidden_tags(self):
        s = Store(self.home / "lib.json")
        gid = s.add_manual({"name": "Zelda Teste", "kind": "emulator", "console": "switch1", "file": "/r/z.nsp"})
        s.set_meta(gid, favorite=True)
        disc = [{"id": "steam:1", "name": "Alpha", "source": "steam", "cover": "", "install_dir": "", "launch": {"type": "steam", "appid": "1"}},
                {"id": "android:a", "name": "Beta", "source": "waydroid", "cover": "", "install_dir": "", "launch": {"type": "waydroid", "package": "a"}}]
        view = {g["id"]: g for g in library.merged_games(disc, s)}
        self.assertEqual(view[gid]["consoleLabel"], "Nintendo Switch")
        self.assertEqual(view[gid]["tags"], ["Emulador"])        # tag padrão por origem
        self.assertEqual(view["android:a"]["tags"], ["Android"])
        self.assertTrue(view[gid]["favorite"])
        s.set_meta("steam:1", hidden=True)
        self.assertNotIn("steam:1", {g["id"] for g in library.merged_games(disc, s)})
        self.assertIn("steam:1", {g["id"] for g in library.merged_games(disc, s, include_hidden=True)})

    def test_scan_folder(self):
        self.write("roms/a.xci", "x"); self.write("roms/sub/b.NSP", "x"); self.write("roms/c.txt", "x")
        found = library.scan_folder("switch1", str(self.home / "roms"))
        self.assertEqual([os.path.basename(f) for f in found], ["a.xci", "b.NSP"])
        self.write("ps4/CUSA1/eboot.bin", "x")
        self.assertEqual(len(library.scan_folder("ps4", str(self.home / "ps4"))), 1)


class LauncherTests(Base):
    settings = {"switch2_emulator": "lichii"}

    def cmd(self, spec):
        return launcher.build_command({"launch": spec}, self.settings)[0]

    def test_store_launchers(self):
        self.assertEqual(self.cmd({"type": "steam", "appid": "10", "flatpak": True}),
                         ["flatpak", "run", "com.valvesoftware.Steam", "steam://rungameid/10"])
        self.assertEqual(self.cmd({"type": "heroic", "app": "A", "runner": "gog", "flatpak": False}),
                         ["heroic", "--no-gui", "heroic://launch?appName=A&runner=gog"])
        self.assertEqual(self.cmd({"type": "lutris", "slug": "s", "flatpak": False}), ["lutris", "lutris:rungame/s"])
        self.assertEqual(self.cmd({"type": "waydroid", "package": "p.q"}), ["waydroid", "app", "launch", "p.q"])

    def test_emulators(self):
        e = lambda c, f, **kw: self.cmd({"type": "emulator", "console": c, "file": f, **kw})   # noqa: E731
        self.assertEqual(e("ps3", "/r/x.pkg"), ["ps-pkg-open", "/r/x.pkg"])
        self.assertEqual(e("ps3", "/r/EBOOT.BIN"), ["flatpak", "run", "net.rpcs3.RPCS3", "--no-gui", "/r/EBOOT.BIN"])
        self.assertEqual(e("x360", "/r/g.xex", args="--fullscreen")[-1], "--fullscreen")
        self.assertEqual(e("switch1", "/r/j.xci"), ["switch-open", "/r/j.xci"])
        self.assertEqual(e("x360", "/r/g.iso", emulator="meu-emu --opt"), ["meu-emu", "--opt", "/r/g.iso"])
        with self.assertRaises(launcher.LaunchError):
            e("switch2", "/r/j.nsp")                      # nenhum emulador instalado
        self.write(".local/bin/lichii", "#!/bin/sh\n")
        os.chmod(self.home / ".local/bin/lichii", 0o755)
        self.assertEqual(e("switch2", "/r/j.nsp"), [str(self.home / ".local/bin/lichii"), "/r/j.nsp"])

    def test_ps4_folder_resolves_eboot(self):
        self.write("g/eboot.bin", "x")
        self.assertEqual(self.cmd({"type": "emulator", "console": "ps4", "file": str(self.home / "g")}),
                         ["shadps4-open", str(self.home / "g/eboot.bin")])

    def test_manual_kinds(self):
        m = lambda **kw: self.cmd({"type": "manual", **kw})                                       # noqa: E731
        self.write("win.exe", binary=b"MZ\x90\x00"); self.write("lin", binary=b"\x7fELFxxxx")
        self.assertEqual(m(kind="exe", target=str(self.home / "win.exe")), ["bottles-open", str(self.home / "win.exe")])
        self.assertEqual(m(kind="exe", target=str(self.home / "lin"), args="-a b"), [str(self.home / "lin"), "-a", "b"])
        self.assertEqual(m(kind="bat", target="/x.bat"), ["bottles-open", "/x.bat"])
        self.assertEqual(m(kind="sh", target="/x.sh"), ["bash", "/x.sh"])
        self.assertEqual(m(kind="url", target="https://x.y"), ["xdg-open", "https://x.y"])
        self.assertEqual(m(kind="flatpak", target="flatpak run org.a.B", args="--x"), ["flatpak", "run", "org.a.B", "--x"])
        with self.assertRaises(launcher.LaunchError):
            m(kind="command", target="")

    def test_mods(self):
        self.assertIsNone(launcher.mod_command({"kind": "zip", "path": "/m.zip"}))              # só abrir no Dolphin
        self.assertIsNone(launcher.mod_command({"kind": "folder", "path": "/m"}))
        self.assertEqual(launcher.mod_command({"kind": "bat", "path": "/m.bat"}), ["bottles-open", "/m.bat"])
        self.assertEqual(launcher.mod_command({"kind": "jar", "path": "/m.jar"}), ["java", "-jar", "/m.jar"])
        with mock.patch.object(launcher, "_which_any", return_value="/usr/bin/konsole"):
            self.assertEqual(launcher.mod_command({"kind": "sh", "path": "/m.sh"}), ["/usr/bin/konsole", "-e", "bash", "/m.sh"])
        self.assertEqual(launcher.dolphin_command("/nao/existe"), ["dolphin", "/nao/existe"])

    def test_steam_pid_scan(self):
        proc = self.home / "proc"
        for pid, args in {"100": [b"reaper", b"SteamLaunch", b"AppId=10", b"--", b"jogo"],
                          "101": [b"reaper", b"SteamLaunch", b"AppId=99"], "abc": [b"x"]}.items():
            p = proc / pid
            p.mkdir(parents=True)
            (p / "cmdline").write_bytes(b"\0".join(args) + b"\0")
        self.assertEqual(launcher.steam_game_pids("10", str(proc)), [100])

    def test_priority_resolution(self):
        on = {"priority_enabled": True}
        self.assertTrue(launcher.effective_priority({"priority": "inherit"}, on))
        self.assertFalse(launcher.effective_priority({"priority": "off"}, on))
        self.assertTrue(launcher.effective_priority({"priority": "on"}, {"priority_enabled": False}))


if __name__ == "__main__":
    unittest.main()
