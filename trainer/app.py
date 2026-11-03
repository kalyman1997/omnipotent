"""Compact desktop trainer inspired by the user's visual reference."""
import ctypes
import math
import queue
import tkinter as tk
from tkinter import filedialog, ttk
from options import OPTIONS
from controller import SUPPORTED
from installation import resource_dir
from widgets import ControllerWorker, OptionToggle
from weapons import WEAPONS, AMMO_MODS

BG = "#111214"
TEXT = "#f0f1f3"
MUTED = "#8f939a"
ORANGE = "#cbd3e0"
GREEN = "#55c78a"


class BO7TrainerApp:
    def __init__(self, root):
        self.root = root
        root.title("omnipotent by kaly · trainer")
        root.geometry("900x760")
        root.minsize(900, 760)
        root.configure(bg=BG)
        self.requests, self.results = queue.Queue(), queue.Queue()
        self.latest_status, self.rows = {}, {}
        self.prev_pressed = set()
        self.hotkeys_enabled = True
        self.catalog = []
        self.weapon_choices = {}
        self.action_buttons = []
        self.worker = ControllerWorker(self.requests, self.results)
        self._build()
        self.worker.start()
        root.protocol("WM_DELETE_WINDOW", self._close)
        root.after(100, self._drain)
        root.after(300, self._status)
        root.after(80, self._hotkeys)

    def label(self, parent, text, color=TEXT, size=10, bold=False, **kwargs):
        return tk.Label(parent, text=text, bg=BG, fg=color,
                        font=("Segoe UI", size, "bold" if bold else "normal"), **kwargs)

    def button(self, parent, text, command, bg="#363839", **kwargs):
        return tk.Button(parent, text=text, command=command, bg=bg, fg=TEXT,
                         activebackground="#47494a", activeforeground="white", relief="flat",
                         bd=0, cursor="hand2", font=("Segoe UI", 9, "bold"), **kwargs)

    def _build(self):
        header = tk.Frame(self.root, bg=BG)
        header.pack(fill="x", padx=24, pady=(20, 14))
        titles = tk.Frame(header, bg=BG)
        titles.pack(side="left", expand=True, fill="x")
        self.label(titles, "omnipotent", TEXT, 23, True).pack(side="left")
        self.label(titles, "by kaly", MUTED, 11).pack(side="left", padx=(12, 0), pady=(10, 0))
        self.connect_button = self.button(header, "Conectar", self._connect, bg="#e6e8ec", width=16, pady=9)
        self.connect_button.configure(fg="#141619")
        self.connect_button.pack(side="right")
        controls = tk.Frame(self.root, bg=BG)
        controls.pack(fill="x", padx=24, pady=(0, 16))
        self.connection_label = self.label(controls, "● DESCONECTADO", MUTED, 9)
        self.connection_label.pack(side="left")
        self.process_label = self.label(controls, "", MUTED, 9)
        self.process_label.pack(side="left", padx=(12, 0))
        self.button(controls, "Desactivar todo", lambda: self.requests.put(("reset", None)), padx=12, pady=5).pack(side="right")
        self.button(controls, "Preparar juego", self._prepare, padx=12, pady=5).pack(side="right", padx=8)
        end_round = self.button(controls, "Terminar ronda", lambda: self._weapon_action("end_round"), padx=12, pady=5)
        end_round.pack(side="right")
        self.action_buttons.append(end_round)
        style = ttk.Style(self.root)
        style.theme_use("clam")
        style.configure("Omni.TNotebook", background=BG, borderwidth=0)
        style.configure("Omni.TNotebook.Tab", background="#1b1d20", foreground=MUTED, padding=(22, 10), font=("Segoe UI", 10))
        style.map("Omni.TNotebook.Tab", background=[("selected", BG)], foreground=[("selected", TEXT)])
        style.configure("Omni.TCombobox", fieldbackground="#202226", background="#30343a", foreground=TEXT, arrowcolor=TEXT, padding=8)
        style.map("Omni.TCombobox", fieldbackground=[("readonly", "#202226")], foreground=[("readonly", TEXT)])
        self.notebook = ttk.Notebook(self.root, style="Omni.TNotebook")
        self.notebook.pack(fill="both", expand=True, padx=24)
        panel = tk.Frame(self.notebook, bg=BG, padx=8, pady=14)
        weapons = tk.Frame(self.notebook, bg=BG, padx=8, pady=14)
        self.notebook.add(panel, text="Jugador")
        self.notebook.add(weapons, text="Armas")
        self._build_options(panel)
        self._build_weapons(weapons)

    def _build_options(self, panel):
        heading = tk.Frame(panel, bg=BG, height=27)
        heading.pack(fill="x")
        self.label(heading, "Atajo", MUTED, 10, False, width=12, anchor="w").pack(side="left")
        self.label(heading, "Opciones", MUTED, 10).pack(side="left", padx=(23, 0))
        tk.Frame(panel, bg="#a3a3a3", height=1).pack(fill="x", pady=(1, 3))
        for opt in OPTIONS:
            if opt.id == "damage_multiplier":
                tk.Frame(panel, bg=BG, height=14).pack(fill="x")
            row = tk.Frame(panel, bg=BG, height=27)
            row.pack(fill="x")
            row.pack_propagate(False)
            available = opt.id in SUPPORTED
            self.label(row, opt.key.replace(" + ", "+"), TEXT if available else "#777777",
                       10, True, width=12, anchor="w").pack(side="left")
            if opt.id == "points":
                toggle = self.button(row, "APPLY", lambda: self._toggle("points"),
                                     bg="#c7c7c7", width=5)
                toggle.configure(fg="#202123", font=("Segoe UI", 7, "bold"))
            else:
                toggle = OptionToggle(row, lambda oid=opt.id: self._toggle(oid))
                toggle.configure(bg=BG)
                toggle.set_state("off", disabled=not available)
            toggle.pack(side="left", padx=(0, 5))
            title = opt.title
            if opt.id == "godmode": title = "Infinite Health / God Mode"
            self.label(row, title, TEXT if available else "#818181", 10, True).pack(side="left")
            status = self.label(row, "" if available else "pendiente", "#747474", 8)
            status.pack(side="right", padx=(4, 0))
            var = None
            if opt.default is not None:
                var = tk.StringVar(value=f"{opt.default:g}")
                editor = tk.Frame(row, bg=BG)
                editor.pack(side="right", padx=3)
                for symbol, delta in (("‹", -1), ("›", 1)):
                    if delta > 0:
                        entry = tk.Entry(editor, textvariable=var, width=7, justify="center", relief="flat",
                                         bg=BG, fg=ORANGE, insertbackground=ORANGE,
                                         font=("Segoe UI", 10), disabledforeground="#666666")
                        entry.pack(side="left")
                        entry.bind("<Return>", lambda e, oid=opt.id: self._number(oid))
                        entry.bind("<FocusOut>", lambda e, oid=opt.id: self._number(oid))
                        if not available: entry.configure(state="disabled")
                    b = self.button(editor, symbol, lambda oid=opt.id, d=delta: self._step(oid, d), bg=BG)
                    b.configure(fg=ORANGE if available else "#666666", font=("Segoe UI", 13), padx=1)
                    b.pack(side="left")
                    if not available: b.configure(state="disabled")
            self.rows[opt.id] = dict(toggle=toggle, status=status, var=var, opt=opt)
        tk.Frame(panel, bg="#a3a3a3", height=1).pack(fill="x", pady=(8, 7))
        self.telemetry_label = self.label(panel, "Salud —     Cargador —     Reserva —     Esencia —", MUTED, 9)
        self.telemetry_label.pack(anchor="w")
        self.help_label = self.label(panel, "Jetpack: mantén SALTO + movimiento para dirigir el vuelo; suelta SALTO para caer.", MUTED, 8)
        self.help_label.pack(anchor="w", pady=(6, 0))
        self.label(panel, "Ctrl+Shift+Home: activar/desactivar atajos", MUTED, 8).pack(anchor="w", pady=(3, 0))
        self.message_var = tk.StringVar(value="Prepara el juego y conecta el trainer a tu partida individual.")
        tk.Label(self.root, textvariable=self.message_var, bg=BG, fg=MUTED,
                 font=("Segoe UI", 9), anchor="w", wraplength=840).pack(side="bottom", fill="x", padx=24, pady=(12, 18), before=self.notebook)

    def _build_weapons(self, panel):
        self.label(panel, "Give Weapon", TEXT, 16, True).pack(anchor="w")
        self.catalog_label = self.label(panel, "Elige una referencia o escribe el identificador interno de un arma.", MUTED, 9)
        self.catalog_label.pack(anchor="w", pady=(5, 10))
        row = tk.Frame(panel, bg=BG)
        row.pack(fill="x")
        self.weapon_var = tk.StringVar()
        self.weapon_combo = ttk.Combobox(row, textvariable=self.weapon_var, style="Omni.TCombobox", font=("Segoe UI", 10))
        self.weapon_combo.pack(side="left", fill="x", expand=True)
        self.weapon_combo.bind("<KeyRelease>", self._filter_weapons)
        self.weapon_combo.bind("<Return>", lambda event: self._give_weapon())
        give = self.button(row, "Dar arma", self._give_weapon, padx=18, pady=10)
        give.pack(side="right", padx=(12, 0))
        self.action_buttons.append(give)
        self._weapon_values([])
        self.label(panel, "Incluye armas especiales de otros mapas cuando el juego puede cargar sus recursos.", MUTED, 9).pack(anchor="w", pady=(8, 18))
        self.label(panel, "Si el inventario está lleno, sustituye el arma equipada.", MUTED, 9).pack(anchor="w", pady=(0, 10))
        self.current_weapon_label = self.label(panel, "Arma actual: —", TEXT, 10, wraplength=810, anchor="w", justify="left")
        self.current_weapon_label.pack(fill="x", pady=(0, 16))
        self.label(panel, "Pack-a-Punch", TEXT, 16, True).pack(anchor="w")
        pap = tk.Frame(panel, bg=BG)
        pap.pack(fill="x", pady=(10, 6))
        for level, title in ((1, "Nivel I"), (2, "Nivel II"), (3, "Nivel III")):
            button = self.button(pap, title, lambda value=level: self._weapon_action("pap", "", value), width=17, pady=10)
            button.pack(side="left", padx=(0, 10))
            self.action_buttons.append(button)
        self.pap_label = self.label(panel, "Nivel actual: — · Se aplica al arma equipada.", MUTED, 9)
        self.pap_label.pack(anchor="w", pady=(0, 18))
        self.label(panel, "Munición elemental", TEXT, 16, True).pack(anchor="w")
        elemental = tk.Frame(panel, bg=BG)
        elemental.pack(fill="x", pady=(10, 6))
        self.ammo_var = tk.StringVar(value=AMMO_MODS[0][0])
        self.ammo_combo = ttk.Combobox(elemental, textvariable=self.ammo_var, values=[title for title, _ in AMMO_MODS], state="readonly", style="Omni.TCombobox", font=("Segoe UI", 10))
        self.ammo_combo.pack(side="left", fill="x", expand=True)
        apply = self.button(elemental, "Aplicar", self._ammo_mod, padx=24, pady=10)
        apply.pack(side="right", padx=(12, 0))
        self.action_buttons.append(apply)
        self.ammo_label = self.label(panel, "Modificador actual: —", MUTED, 9)
        self.ammo_label.pack(anchor="w", pady=(0, 6))
        self.label(panel, "Efectos nativos: conservan su probabilidad y tiempo de recarga; no se activan con cada bala.", MUTED, 9).pack(anchor="w", pady=(0, 8))
        self.action_label = self.label(panel, "Conecta el trainer y entra en una partida individual.", MUTED, 10, wraplength=810, justify="left", anchor="w")
        self.action_label.pack(fill="x", pady=(4, 0))
        for button in self.action_buttons:
            button.configure(state="disabled")

    def _weapon_values(self, catalog):
        known = {value: title for title, value in WEAPONS}
        self.weapon_choices = {f"{title} — {value}": value for title, value in WEAPONS}
        self.weapon_choices.update({f"{known[value]} — {value}" if value in known else value: value for value in catalog})
        self.weapon_combo.configure(values=list(self.weapon_choices))
        if not self.weapon_var.get():
            self.weapon_var.set(next(iter(self.weapon_choices)))

    def _filter_weapons(self, event=None):
        if event is not None and event.keysym in ("Up", "Down", "Return", "Escape", "Tab"):
            return
        query = self.weapon_var.get().lower().strip()
        self.weapon_combo.configure(values=[label for label in self.weapon_choices if query in label.lower()])

    def _give_weapon(self):
        text = self.weapon_var.get()
        self._weapon_action("give_weapon", self.weapon_choices.get(text, text), 0)

    def _ammo_mod(self):
        selected = dict(AMMO_MODS).get(self.ammo_var.get())
        if selected:
            self._weapon_action("ammo_mod", selected, 0)

    def _weapon_action(self, kind, value="", level=0):
        if not self.latest_status.get("actions_ready"):
            self.action_label.configure(text="Espera a estar conectado a un jugador activo y sin otra acción pendiente.", fg=MUTED)
            return
        for button in self.action_buttons:
            button.configure(state="disabled")
        self.action_label.configure(text="Enviando acción…", fg=MUTED)
        self.requests.put(("weapon_action", (kind, value, level)))

    def _connect(self):
        self.requests.put(("disconnect" if self.latest_status.get("running") else "connect", None))

    def _prepare(self):
        path = self.latest_status.get("game_root")
        if not path:
            path = filedialog.askdirectory(title="Selecciona cod25: cod25-cod.exe y la carpeta kronos", parent=self.root)
        if path:
            self.requests.put(("prepare", path))

    def _toggle(self, oid):
        if oid not in SUPPORTED: return
        if oid == "points":
            self._number(oid)
            self.requests.put(("toggle", (oid, True)))
            return
        desired = self.latest_status.get("options", {}).get(oid, {}).get("requested", False)
        self.requests.put(("toggle", (oid, not desired)))

    def _number(self, oid):
        row = self.rows[oid]
        if oid not in SUPPORTED or row["var"] is None: return
        try:
            value = float(row["var"].get())
            if not math.isfinite(value):
                raise ValueError("non-finite input")
            value = max(row["opt"].minimum, min(row["opt"].maximum, value))
            row["var"].set(f"{value:g}")
            self.requests.put(("numeric", (oid, value)))
        except ValueError:
            row["var"].set(f"{row['opt'].default:g}")

    def _step(self, oid, delta):
        row = self.rows[oid]
        try: value = float(row["var"].get())
        except ValueError: value = row["opt"].default
        row["var"].set(f"{value + delta * row['opt'].increment:g}")
        self._number(oid)

    def _status(self):
        self.requests.put(("status", None))
        self.root.after(400, self._status)

    def _drain(self):
        try:
            while True:
                kind, ok, state = self.results.get_nowait()
                if state:
                    self.latest_status = state
                    self._show(state)
                elif kind == "error": self.message_var.set(str(ok))
        except queue.Empty: pass
        self.root.after(60, self._drain)

    def _show(self, state):
        connected, running = state.get("connected"), state.get("running")
        self.connection_label.configure(text="● CONECTADO" if connected else "● ESPERANDO PARTIDA" if running else "● DESCONECTADO",
                                        fg=GREEN if connected else MUTED)
        self.connect_button.configure(text="Desconectar" if running else "Conectar")
        self.process_label.configure(text=f"PID {state['pid']}" if state.get('pid') else "")
        self.message_var.set(state.get("message", ""))
        data = state.get("last_state", {})
        self.telemetry_label.configure(text=f"Salud {data.get('health', '—')}    Cargador {data.get('clip', '—')}    Reserva {data.get('stock', '—')}    Esencia {data.get('essence', '—')}")
        self.current_weapon_label.configure(text=f"Arma actual: {data.get('current_weapon') or '—'}")
        pap = data.get("pap_level")
        self.pap_label.configure(text=f"Nivel actual: {pap if type(pap) is int and pap >= 0 else '—'} · Se aplica al arma equipada.")
        ammo = data.get("ammo_mod")
        ammo_title = {value: title for title, value in AMMO_MODS}.get(ammo, ammo or "—")
        self.ammo_label.configure(text=f"Modificador actual: {ammo_title}")
        catalog = state.get("weapon_catalog", [])
        if catalog != self.catalog:
            self.catalog = list(catalog)
            self._weapon_values(catalog)
            self.catalog_label.configure(text=f"{len(catalog)} armas comunicadas por la partida. También puedes escribir un ID." if catalog else "Elige una referencia o escribe el identificador interno de un arma.")
        for button in self.action_buttons:
            button.configure(state="normal" if state.get("actions_ready") else "disabled")
        action = state.get("action", {})
        phase = action.get("state", "idle")
        detail = action.get("detail", "")
        messages = {
            "idle": "Conecta el trainer y entra en una partida individual.",
            "pending": "Esperando confirmación del juego…",
            "applied": "El juego confirmó la acción.",
            "unavailable": "Esta opción no está disponible para el arma o la partida actual.",
            "rejected": "El juego rechazó la acción; comprueba el arma seleccionada.",
            "busy": "El juego está procesando otra acción. Vuelve a intentarlo.",
            "failed": "La acción no pudo completarse. No se confirmó el resultado.",
            "cancelled": "Acción cancelada al desconectar el trainer.",
        }
        reasons = {
            "round_finished": "Ronda terminada. El juego confirmó el avance a la siguiente.",
            "round_not_active": "Espera al comienzo de una ronda activa.",
            "round_protected_enemy": "Hay un enemigo protegido por un evento; termina ese encuentro primero.",
            "round_transition_timeout": "Se solicitó el cierre, pero el juego no confirmó el cambio de ronda.",
            "weapon_equipped": "Arma entregada y equipada.",
            "weapon_replaced": "Arma equipada sustituida: el inventario estaba lleno.",
            "weapon_replace_rolled_back": "No se pudo entregar el arma; se restauró la anterior.",
            "weapon_equip_timeout": "El arma está en el inventario, pero no se confirmó que quedara equipada.",
            "weapon_not_registered": "El motor no reconoce esta arma en la sesión actual; faltan sus recursos o su ID no es válido.",
            "weapon_assets_not_loaded": "El arma existe, pero el juego no pudo cargar sus recursos en este mapa.",
            "weapon_not_in_inventory": "El juego no entregó el arma. Comprueba los espacios de armas disponibles.",
            "unknown_weapon": "El identificador no corresponde a un arma disponible.",
            "assets_unavailable": "Los recursos del arma no están disponibles en este mapa.",
            "assets_timeout": "El juego no terminó de cargar el arma.",
            "already_upgraded": "El arma ya tiene ese nivel o uno superior.",
            "no_weapon": "Equipa un arma antes de aplicar el cambio.",
            "not_ready": "Espera a que el jugador esté activo en la partida.",
        }
        notice = state.get("action_notice")
        if action.get("kind") == "end_round":
            self.message_var.set(notice or reasons.get(detail, messages.get(phase, "Esperando respuesta…")))
        self.action_label.configure(text=notice or reasons.get(detail, messages.get(phase, "Esperando respuesta…")),
                                    fg=GREEN if phase == "applied" and not notice else MUTED)
        for oid, option in state.get("options", {}).items():
            row = self.rows[oid]
            phase = option.get("state")
            row["status"].configure(text={"active":"●", "pending":"…", "applied":"✓", "error":"error", "unsupported":"pendiente", "unavailable":"no disponible"}.get(phase, ""),
                                    fg=GREEN if phase in ("active", "applied") else MUTED)
            if oid != "points":
                row["toggle"].set_state(phase, enabled=option["enabled"], pending=phase=="pending",
                                         error=phase in ("error", "unavailable"), disabled=oid not in SUPPORTED)

    def _hotkeys(self):
        keys = ctypes.windll.user32.GetAsyncKeyState
        ctrl, shift = bool(keys(0x11) & 0x8000), bool(keys(0x10) & 0x8000)
        combo = ctrl and shift and bool(keys(0x24) & 0x8000)
        if combo and "pause" not in self.prev_pressed:
            self.hotkeys_enabled = not self.hotkeys_enabled
            self.prev_pressed.add("pause")
        elif not combo: self.prev_pressed.discard("pause")
        for i, oid in enumerate(("godmode", "ammo", "no_reload", "equipment", "damage", "rapid_fire", "no_recoil", "points", "field_upgrade"), 1):
            down = bool(keys(0x60+i) & 0x8000)
            if down and i not in self.prev_pressed:
                self.prev_pressed.add(i)
                if self.hotkeys_enabled and not shift and not isinstance(self.root.focus_get(), (tk.Entry, ttk.Entry, ttk.Combobox)):
                    if ctrl:
                        if i <= 5:
                            self._toggle(("damage_multiplier", "move_speed", "game_speed", "fov", "jetpack")[i - 1])
                    else:
                        self._toggle(oid)
            elif not down: self.prev_pressed.discard(i)
        self.root.after(80, self._hotkeys)

    def _close(self):
        self.requests.put(("disconnect", None))
        self.requests.put(None)
        self.worker.join(timeout=1.5)
        self.root.destroy()


if __name__ == "__main__":
    root = tk.Tk()
    app = BO7TrainerApp(root)
    root.mainloop()
