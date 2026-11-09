"""Controle de gamepad (SDL2 GameController) -> ações de navegação. Sem SDL2, o app segue funcionando por teclado/mouse."""
import ctypes
import os
import time

from PySide6.QtCore import QThread, Signal


class GamepadThread(QThread):
    action = Signal(str)

    def __init__(self):
        super().__init__()
        self._running = True

    def stop(self):
        self._running = False
        self.wait(1500)

    def run(self):
        try:
            import sdl2
        except Exception as exc:
            print("modojogo: SDL2 indisponível, gamepad desativado:", exc, flush=True)
            return
        os.environ.setdefault("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1")
        if sdl2.SDL_Init(sdl2.SDL_INIT_GAMECONTROLLER) != 0:
            print("modojogo: SDL_Init falhou", flush=True)
            return

        buttons = {
            sdl2.SDL_CONTROLLER_BUTTON_A: "accept", sdl2.SDL_CONTROLLER_BUTTON_B: "back",
            sdl2.SDL_CONTROLLER_BUTTON_X: "x", sdl2.SDL_CONTROLLER_BUTTON_Y: "y",
            sdl2.SDL_CONTROLLER_BUTTON_START: "start", sdl2.SDL_CONTROLLER_BUTTON_BACK: "select",
            sdl2.SDL_CONTROLLER_BUTTON_LEFTSHOULDER: "prev", sdl2.SDL_CONTROLLER_BUTTON_RIGHTSHOULDER: "next",
            sdl2.SDL_CONTROLLER_BUTTON_DPAD_UP: "up", sdl2.SDL_CONTROLLER_BUTTON_DPAD_DOWN: "down",
            sdl2.SDL_CONTROLLER_BUTTON_DPAD_LEFT: "left", sdl2.SDL_CONTROLLER_BUTTON_DPAD_RIGHT: "right",
        }
        directions = {"up", "down", "left", "right"}
        pads, held = {}, {}          # held: direção -> próximo instante de repetição
        stick = {"x": None, "y": None}

        def open_pad(index):
            if sdl2.SDL_IsGameController(index):
                pad = sdl2.SDL_GameControllerOpen(index)
                if pad:
                    pads[sdl2.SDL_JoystickInstanceID(sdl2.SDL_GameControllerGetJoystick(pad))] = pad

        def press(name):
            self.action.emit(name)
            if name in directions:
                held[name] = time.monotonic() + 0.40

        def release(name):
            held.pop(name, None)

        def axis(which, value, neg, pos):
            cur = neg if value < -16000 else pos if value > 16000 else None
            if abs(value) < 8000:
                cur = None
            elif cur is None:
                return
            prev = stick[which]
            if cur != prev:
                if prev:
                    release(prev)
                stick[which] = cur
                if cur:
                    press(cur)

        for i in range(sdl2.SDL_NumJoysticks()):
            open_pad(i)

        ev = sdl2.SDL_Event()
        while self._running:
            if sdl2.SDL_WaitEventTimeout(ctypes.byref(ev), 40):
                t = ev.type
                if t == sdl2.SDL_CONTROLLERDEVICEADDED:
                    open_pad(ev.cdevice.which)
                elif t == sdl2.SDL_CONTROLLERDEVICEREMOVED:
                    pad = pads.pop(ev.cdevice.which, None)
                    if pad:
                        sdl2.SDL_GameControllerClose(pad)
                elif t == sdl2.SDL_CONTROLLERBUTTONDOWN:
                    name = buttons.get(ev.cbutton.button)
                    if name:
                        press(name)
                elif t == sdl2.SDL_CONTROLLERBUTTONUP:
                    name = buttons.get(ev.cbutton.button)
                    if name:
                        release(name)
                elif t == sdl2.SDL_CONTROLLERAXISMOTION:
                    if ev.caxis.axis == sdl2.SDL_CONTROLLER_AXIS_LEFTX:
                        axis("x", ev.caxis.value, "left", "right")
                    elif ev.caxis.axis == sdl2.SDL_CONTROLLER_AXIS_LEFTY:
                        axis("y", ev.caxis.value, "up", "down")
            now = time.monotonic()
            for d, due in list(held.items()):      # repetição ao segurar direcional/analógico
                if now >= due:
                    self.action.emit(d)
                    held[d] = now + 0.12
        for pad in pads.values():
            sdl2.SDL_GameControllerClose(pad)
        sdl2.SDL_Quit()
