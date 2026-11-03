"""Interfaz de escritorio para el Trainer de Call of Duty: Black Ops 7 Zombies (BO7_Alternativa).

Diseño y arquitectura idénticos al trainer de Gears E-Day:
- Interfaz gráfica oscura nativa en Tkinter.
- Interruptores custom 'OptionToggle' con confirmación de estado del controlador.
- Atajos de teclado numérico (Num 1..Num 9, Ctrl + Num 1..4).
- Trabajador multihilo desacoplado (UI fluida sin bloqueos).
"""
from __future__ import annotations

import ctypes
from ctypes import wintypes
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import queue
import sys
import threading
import time
import tkinter as tk
from tkinter import messagebox, ttk
from typing import Any, Dict

from options import OPTIONS, OPTION_BY_ID, Option
from controller import BO7TrainerController, SUPPORTED

BG = "#202123"
PANEL = "#202123"
ROW = "#202123"
TEXT = "#e1e1e1"
MUTED = "#b8b8b8"
RED = "#e5484d"
ORANGE = "#f38b00"
GREEN = "#30a46c"
YELLOW = "#f0bf65"

k32 = ctypes.windll.kernel32
u32 = ctypes.windll.user32


class OptionToggle(tk.Canvas):
    """Interruptor compacto cuya posición refleja el estado confirmado por el controlador."""

    def __init__(self, parent, command):
        super().__init__(parent, width=40, height=22, bg=BG, bd=0,
                         highlightthickness=0, takefocus=True, cursor="hand2")
        self.command = command
        self.label = "ACTIVAR"
        self.enabled = False
        self.disabled = False
        self.pending = False
        self.error = False
        self.bind("<Button-1>", lambda _: self.invoke())
        self.bind("<space>", lambda _: self.invoke())
        self.bind("<Return>", lambda _: self.invoke())
        self.bind("<FocusIn>", lambda _: self._draw())
        self.bind("<FocusOut>", lambda _: self._draw())
        self._draw()

    def invoke(self):
        if not self.disabled:
            return self.command()

    def cget(self, key):
        if key == "text":
            return self.label
        if key == "state":
            return "disabled" if self.disabled else "normal"
        return super().cget(key)

    def set_state(self, label, *, enabled=False, disabled=False, pending=False, error=False):
        self.label, self.enabled = label, enabled
        self.disabled, self.pending, self.error = disabled, pending, error
        self._draw()

    def _draw(self):
        self.delete("all")
        color = ORANGE if self.enabled else "#101112"
        if self.pending:
            color = "#755827"
        if self.error:
            color = "#702d2d"
        self.create_oval(4, 4, 20, 20, fill=color, outline=color)
        self.create_oval(20, 4, 36, 20, fill=color, outline=color)
        self.create_rectangle(12, 4, 28, 20, fill=color, outline=color)
        x = 28 if self.enabled else 12
        knob = "#dddddd" if not self.disabled or self.enabled else "#999999"
        self.create_oval(x - 8, 4, x + 8, 20, fill=knob, outline=knob)
        if self.focus_get() is self:
            self.create_rectangle(1, 1, 39, 21, outline=MUTED, dash=(2, 2))


class ControllerWorker(threading.Thread):
    """Hilo trabajador que ejecuta las operaciones de backend sin congelar la UI."""

    def __init__(self, requests: queue.Queue, results: queue.Queue):
        super().__init__(daemon=True)
        self.requests = requests
        self.results = results
        self.controller = BO7TrainerController()

    def run(self):
        while True:
            try:
                task = self.requests.get()
                if task is None:
                    break
                kind, data = task
                if kind == "connect":
                    success = self.controller.connect()
                    self.results.put(("connect", success, self.controller.status()))
                elif kind == "disconnect":
                    self.controller.disconnect()
                    self.results.put(("disconnect", True, self.controller.status()))
                elif kind == "prepare":
                    ok = self.controller.prepare_game(data)
                    self.results.put(("prepare", ok, self.controller.status()))
                elif kind == "status":
                    self.results.put(("status", True, self.controller.status()))
                elif kind == "toggle":
                    opt_id, val = data
                    self.controller.set_option(opt_id, val)
                    self.results.put(("toggle", opt_id, self.controller.status()))
                elif kind == "numeric":
                    opt_id, num = data
                    self.controller.set_numeric(opt_id, num)
                    self.results.put(("numeric", opt_id, self.controller.status()))
                elif kind == "weapon_action":
                    action, value, level = data
                    ok = self.controller.weapon_action(action, value, level)
                    self.results.put(("weapon_action", ok, self.controller.status()))
                elif kind == "reset":
                    for opt in OPTIONS:
                        self.controller.set_option(opt.id, False)
                    self.results.put(("reset", True, self.controller.status()))
            except Exception as e:
                self.results.put(("error", str(e), {}))


