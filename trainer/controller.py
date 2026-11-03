"""Local Kronos GSC channel. No process handles, injection or client memory writes."""
from __future__ import annotations
import copy
import json
import os
from pathlib import Path
import threading
import time
import uuid
import math
from options import OPTIONS, OPTION_BY_ID
from installation import discover_root, install_script, save_root
from channel_lock import ChannelLock
from weapons import weapon_id, AMMO_MOD_IDS

PROTOCOL = 5
FLAGS = frozenset(("godmode", "ammo", "no_reload", "equipment", "field_upgrade", "no_recoil", "damage", "damage_multiplier", "rapid_fire", "game_speed", "fov", "move_speed", "jetpack"))
NUMERIC_FLAGS = frozenset(("damage_multiplier", "game_speed", "fov", "move_speed", "jetpack"))
SUPPORTED = FLAGS | {"points"}


class BO7TrainerController:
    def __init__(self, game_root=None):
        self.explicit_root = game_root is not None
        self.channel_lock = None
        self.root, self.pid = (Path(game_root), None) if game_root else discover_root()
        self.command_path = self.root / "kronos/codexcmd/command.json" if self.root else None
        self.status_path = self.root / "kronos/codexack/status.json" if self.root else None
        self.lock = threading.RLock()
        self.stop_event = threading.Event()
        self.monitor_thread = None
        self.running = self.connected = False
        self.session = ""
        self.lease = self.revision = 0
        self.points_nonce = 0
        self.points_sent_amount = 10000
        self.action_nonce = 0
        self.action_payload = dict(action_kind="", action_value="", action_level=0)
        self.action = dict(nonce=0, kind="", value="", level=0, state="idle", detail="")
        self.action_notice = ""
        self.weapon_catalog = []
        self.catalog_signature = None
        self.protocol_mismatch = False
        self.last_state = {}
        self.last_signature = None
        self.last_ack_time = 0.0
        self.message = "Conecta el menú y entra en Zombies Solo local desde Omnipotent."
        self.options = {
            o.id: dict(enabled=False, requested=False, value=o.default or 0.0,
                       state="off" if o.id in SUPPORTED else "unsupported",
                       message="" if o.id in SUPPORTED else "Pendiente de implementar")
            for o in OPTIONS
        }

    def _write_command(self):
        self.lease += 1
        values = dict(protocol=PROTOCOL, session=self.session, lease=self.lease, revision=self.revision,
                      points_nonce=self.points_nonce, points_amount=self.points_sent_amount)
        values.update({k: int(self.options[k]["requested"]) for k in FLAGS})
        values.update({k + "_value": round(self.options[k]["value"] * 100) for k in NUMERIC_FLAGS})
        # A new map resets the script's consumed-nonce state. Do not replay a
        # completed action (especially end_round) into that next match.
        pending = self.action["state"] == "pending"
        values["action_nonce"] = self.action_nonce if pending else 0
        values.update(self.action_payload if pending else dict(action_kind="", action_value="", action_level=0))
        self.command_path.parent.mkdir(parents=True, exist_ok=True)
        temp = self.command_path.with_suffix(".tmp")
        try:
            temp.write_text(json.dumps(dict(version=1, dvars={}, values=values)), encoding="ascii")
            os.replace(temp, self.command_path)
        finally:
            temp.unlink(missing_ok=True)

    def connect(self):
        with self.lock:
            if self.running:
                return True
            detected_root, detected_pid = discover_root()
            if detected_root is not None and not self.explicit_root:
                self.root, self.pid = detected_root, detected_pid
            if self.root is None:
                self.message = "Abre BO7 desde Omnipotent o selecciona su carpeta con Preparar juego."
                return False
            self.command_path = self.root / "kronos/codexcmd/command.json"
            self.status_path = self.root / "kronos/codexack/status.json"
            script = self.root / "kronos/custom_scripts/codex_solo_trainer.gsc"
            if not script.is_file():
                self.message = "Falta instalar el script local codex_solo_trainer.gsc."
                return False
            self.channel_lock = ChannelLock(self.command_path.with_suffix(".lock"))
            if not self.channel_lock.acquire():
                self.message = "Otro trainer ya controla esta partida. Desconéctalo antes de conectar este."
                return False
            self.session = uuid.uuid4().hex
            self.lease = self.revision = 0
            self.points_nonce = 0
            self.points_sent_amount = int(self.options["points"]["value"])
            self.action_nonce = 0
            self.action_payload = dict(action_kind="", action_value="", action_level=0)
            self.action = dict(nonce=0, kind="", value="", level=0, state="idle", detail="")
            self.action_notice = ""
            self.weapon_catalog = []
            self.catalog_signature = None
            self.protocol_mismatch = False
            self.last_ack_time = 0.0
            self.last_signature = None
            self.last_state = {}
            for k in SUPPORTED:
                self.options[k].update(enabled=False, requested=False, state="off")
            try:
                self._write_command()
            except OSError as exc:
                self.channel_lock.release()
                self.message = f"No se pudo escribir el canal local: {exc}"
                return False
            self.running = True
            self.stop_event.clear()
            self.message = "Esperando al script de Omnipotent. Entra en una nueva partida Solo local."
            self.monitor_thread = threading.Thread(target=self._monitor, daemon=True)
            self.monitor_thread.start()
            return True

    def _read_ack(self):
        try:
            if self.status_path.stat().st_size > 16384:
                return
            data = json.loads(self.status_path.read_text(encoding="utf-8"))
            ack = data.get("values", {})
            if not isinstance(ack, dict):
                return
            if ack.get("protocol") != PROTOCOL:
                self.protocol_mismatch = True
                return
            if ack.get("session") != self.session:
                return
            self.protocol_mismatch = False
            lease, revision = ack.get("lease", -1), ack.get("revision", -1)
            if type(lease) is not int or not 1 <= lease <= self.lease:
                return
            if type(revision) is not int or revision != self.revision:
                return
            if any(type(ack.get(k)) is not int or ack[k] not in (0, 1)
                   for k in ("ready", *FLAGS)):
                return
            if type(ack.get("players")) is not int or not 0 <= ack["players"] <= 256:
                return
            sig = (self.status_path.stat().st_mtime_ns, ack.get("tick"), lease)
            if sig != self.last_signature:
                self.last_ack_time = time.monotonic()
                self.last_signature = sig
            self.last_state = ack
            self._read_catalog()
        except (OSError, ValueError, AttributeError, TypeError):
            # Native save is not atomic: ignore partial snapshots.
            return

    def _read_catalog(self):
        """Catalog is a bounded, session-specific snapshot, never executable input."""
        if self.root is None:
            return
        path = self.root / "kronos/codexcatalog/catalog.json"
        try:
            info = path.stat()
            if info.st_size > 131072:
                return
            signature = (info.st_mtime_ns, info.st_size, self.session)
            if signature == self.catalog_signature:
                return
            values = json.loads(path.read_text(encoding="utf-8")).get("values", {})
            if not isinstance(values, dict) or values.get("protocol") != PROTOCOL or values.get("session") != self.session:
                return
            count = values.get("weapon_count")
            if type(count) is not int or not 0 <= count <= 512:
                return
            names = []
            for i in range(count):
                try:
                    names.append(weapon_id(values.get(f"weapon_{i}")))
                except ValueError:
                    # Metadata may contain non-weapon map keys; retain valid IDs.
                    continue
            self.weapon_catalog = sorted(set(names))
            self.catalog_signature = signature
        except (OSError, ValueError, TypeError, AttributeError):
            return

    def _refresh_state(self):
        fresh = self.last_ack_time > 0 and time.monotonic() - self.last_ack_time < 3
        self.connected = bool(self.running and fresh)
        ack = self.last_state
        ready = self.connected and ack.get("ready") == 1 and ack.get("players") == 1
        if (self.connected and ack.get("revision") == self.revision
                and self.action["state"] == "pending"
                and type(ack.get("action_nonce")) is int
                and ack["action_nonce"] == self.action_nonce):
            result = ack.get("action_result")
            if result in ("applied", "unavailable", "rejected", "failed", "busy"):
                detail = ack.get("action_detail", "")
                self.action.update(state=result, detail=detail[:256] if isinstance(detail, str) else "")
        for k in FLAGS:
            requested = self.options[k]["requested"]
            confirmed = (ready and ack.get("revision") == self.revision
                         and ack.get(k) == int(requested))
            availability_key = "god_available" if k == "godmode" else k + "_available"
            unavailable = ready and requested and ack.get(availability_key) == 0
            conflict = ready and requested and ack.get(k + "_conflict") == 1
            self.options[k].update(enabled=bool(confirmed and requested),
                                   state="active" if confirmed and requested else
                                         "error" if conflict else
                                         "unavailable" if unavailable else
                                         "pending" if requested else "off")
        points = self.options["points"]
        if ready and self.points_nonce > 0 and ack.get("points_nonce") == self.points_nonce:
            points.update(requested=False, enabled=False,
                          state="applied" if ack.get("points_result") == "applied" else "error")
        if not self.running:
            return
        if not self.connected:
            self.message = ("Script anterior en memoria: prepara el juego y reinicia BO7 desde Omnipotent."
                            if self.protocol_mismatch else
                            "Esperando respuesta del script (menú, pausa o partida anterior a la instalación).")
        elif not ready:
            self.message = f"Script conectado; esperando un jugador local activo. {ack.get('reason', '')}"
        else:
            self.message = (f"Omnipotent Solo local · Cargador: {ack.get('clip', '-')} · "
                            f"Reserva: {ack.get('stock', '-')} · Esencia: {ack.get('essence', '-')}.")
            if ack.get("game_speed_conflict") == 1:
                self.message = "El juego cambió su velocidad. Apaga Game Speed antes de volver a activarlo."
            elif ack.get("move_speed_conflict") == 1:
                self.message = "El juego cambió el movimiento. Apaga Move Speed antes de volver a activarlo."

    def _monitor(self):
        while not self.stop_event.wait(0.5):
            with self.lock:
                if not self.running:
                    break
                try:
                    self._write_command()
                    self._read_ack()
                    self._refresh_state()
                except OSError as exc:
                    self.connected = False
                    for k in SUPPORTED:
                        self.options[k].update(enabled=False, requested=False, state="error")
                    self.revision += 1
                    self.message = f"Canal local interrumpido: {exc}"

    def set_option(self, opt_id, enabled):
        with self.lock:
            if opt_id not in SUPPORTED:
                if enabled:
                    self.message = "Esa opción todavía no tiene implementación disponible."
                return False
            if enabled and not self.running:
                self.message = "Pulsa Conectar antes de activar una opción."
                return False
            if opt_id == "points":
                if not enabled:
                    return True
                if not self.connected or self.last_state.get("ready") != 1:
                    self.message = "Espera a estar conectado a un jugador activo antes de añadir esencia."
                    return False
                if self.options["points"]["requested"]:
                    self.message = "La solicitud de esencia anterior sigue pendiente."
                    return False
                self.points_nonce += 1
                self.points_sent_amount = int(self.options["points"]["value"])
            self.options[opt_id].update(requested=bool(enabled), enabled=False,
                                        state="pending" if enabled else "off")
            if enabled and opt_id in ("damage", "damage_multiplier"):
                other = "damage_multiplier" if opt_id == "damage" else "damage"
                self.options[other].update(requested=False, enabled=False, state="off")
            self.revision += 1
            if self.running:
                try:
                    self._write_command()
                except OSError as exc:
                    self.message = f"No se pudo enviar la orden: {exc}"
                    self.options[opt_id].update(requested=False, state="error")
                    return False
            return True

    def set_numeric(self, opt_id, value):
        with self.lock:
            if opt_id != "points" and opt_id not in NUMERIC_FLAGS:
                return False
            if not math.isfinite(float(value)):
                self.message = "Introduce un número finito."
                return False
            option = OPTION_BY_ID[opt_id]
            value = max(option.minimum, min(option.maximum, float(value)))
            self.options[opt_id]["value"] = int(value) if opt_id == "points" else round(value, 2)
            if opt_id in NUMERIC_FLAGS:
                self.revision += 1
                if self.running:
                    try:
                        self._write_command()
                    except OSError as exc:
                        self.message = f"No se pudo enviar el valor: {exc}"
                        return False
            return True

    def weapon_action(self, kind, value="", level=0):
        """Submit one action; heartbeat repeats its nonce, never creates another action."""
        with self.lock:
            self._refresh_state()
            if (not self.connected or self.last_state.get("ready") != 1
                    or self.last_state.get("players") != 1
                    or self.last_state.get("revision") != self.revision):
                self.message = "Conecta el trainer y entra en una partida individual antes de usar Armas."
                self.action_notice = self.message
                return False
            if self.action["state"] == "pending":
                self.message = "Espera la respuesta de la acción anterior; no se enviará otra."
                self.action_notice = self.message
                return False
            try:
                if kind == "give_weapon":
                    value, level = weapon_id(value), 0
                elif kind == "pap":
                    if type(level) is not int or level not in (1, 2, 3):
                        raise ValueError("Pack-a-Punch admite los niveles I, II y III.")
                    value = ""
                elif kind == "ammo_mod":
                    if value not in AMMO_MOD_IDS:
                        raise ValueError("Selecciona un modificador de munición disponible.")
                    level = 0
                elif kind == "end_round":
                    value, level = "", 0
                else:
                    raise ValueError("Acción de armas no disponible.")
            except (ValueError, TypeError) as exc:
                self.message = str(exc)
                self.action_notice = self.message
                return False
            previous = (self.action_nonce, self.action_payload, self.action, self.revision)
            self.action_nonce += 1
            self.action_payload = dict(action_kind=kind, action_value=value, action_level=level)
            self.action = dict(nonce=self.action_nonce, kind=kind, value=value, level=level, state="pending", detail="")
            self.action_notice = ""
            self.revision += 1
            try:
                self._write_command()
            except OSError as exc:
                self.action_nonce, self.action_payload, self.action, self.revision = previous
                self.message = f"No se pudo enviar la acción: {exc}"
                self.action_notice = self.message
                return False
            self.message = "Acción enviada. Esperando confirmación del juego."
            return True

    def prepare_game(self, root=None):
        with self.lock:
            if self.running:
                self.message = "Desconecta el trainer antes de preparar el juego."
                return False
            selected = Path(root) if root else (self.root or discover_root()[0])
            if selected is None:
                self.message = "Selecciona la carpeta cod25 del juego."
                return False
            try:
                install_script(selected)
                self.root = selected
                self.explicit_root = True
                self.command_path = selected / "kronos/codexcmd/command.json"
                self.status_path = selected / "kronos/codexack/status.json"
                self.message = "Script preparado. Reinicia BO7 desde Omnipotent para cargarlo."
                return True
            except (OSError, ValueError) as exc:
                self.message = str(exc)
                return False

    def disconnect(self):
        with self.lock:
            if self.running:
                for k in SUPPORTED:
                    self.options[k].update(requested=False, enabled=False, state="off")
                self.revision += 1
                self.action_payload = dict(action_kind="", action_value="", action_level=0)
                if self.action["state"] == "pending":
                    self.action.update(state="cancelled", detail="Trainer desconectado; la acción no se reenvía al reconectar.")
                try:
                    self._write_command()
                    self.message = "Desconectado; se envió la orden de desactivar."
                except OSError:
                    self.message = "Sin canal; el script desactiva al expirar 5 segundos de simulación."
            self.running = self.connected = False
            self.stop_event.set()
        thread = self.monitor_thread
        if thread and thread is not threading.current_thread():
            thread.join(timeout=1)
        if self.channel_lock:
            self.channel_lock.release()

    def status(self):
        with self.lock:
            self._refresh_state()
            return dict(connected=self.connected, running=self.running, pid=self.pid,
                        game_root=str(self.root) if self.root else "",
                        message=self.message, options=copy.deepcopy(self.options),
                        action=copy.deepcopy(self.action), weapon_catalog=list(self.weapon_catalog),
                        action_notice=self.action_notice,
                        actions_ready=bool(self.connected and self.last_state.get("ready") == 1
                                           and self.last_state.get("players") == 1
                                           and self.last_state.get("revision") == self.revision
                                           and self.action["state"] != "pending"),
                        last_state=copy.deepcopy(self.last_state))
