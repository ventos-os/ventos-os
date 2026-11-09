#!/usr/bin/env python3
"""Modo Jogo: biblioteca unificada em tela cheia, com navegação por controle."""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")


def main() -> int:
    from PySide6.QtCore import QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine

    from backend import Backend
    from gamepad import GamepadThread

    args = sys.argv[1:]
    fullscreen = "--fullscreen" in args and "--windowed" not in args
    app = QGuiApplication([sys.argv[0]])
    app.setApplicationName("ventos-modojogo")
    app.setDesktopFileName("ventos-modojogo")

    backend = Backend(fullscreen=fullscreen)
    app.installEventFilter(backend)

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(HERE / "qml" / "Main.qml")))
    if not engine.rootObjects():
        print("modojogo: falha ao carregar a interface QML", file=sys.stderr)
        return 1
    backend.attach_window(engine.rootObjects()[0])

    pad = GamepadThread()
    pad.action.connect(backend.padAction)
    pad.start()
    app.aboutToQuit.connect(pad.stop)
    app.aboutToQuit.connect(backend.shutdown)

    backend.refresh()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
