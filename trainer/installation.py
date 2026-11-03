"""Find the running game using query-only Windows process APIs."""
import ctypes
from ctypes import wintypes
import json
import hashlib
import shutil
import time
import os
from pathlib import Path
import sys


def resource_dir():
    return Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))


def config_path():
    return Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "BO7KronosTrainer/config.json"


def process_roots():
    if os.name != "nt":
        return []
    class Entry(ctypes.Structure):
        _fields_ = [("size", wintypes.DWORD), ("usage", wintypes.DWORD),
                    ("pid", wintypes.DWORD), ("heap", ctypes.c_size_t),
                    ("module", wintypes.DWORD), ("threads", wintypes.DWORD),
                    ("parent", wintypes.DWORD), ("priority", wintypes.LONG),
                    ("flags", wintypes.DWORD), ("name", wintypes.WCHAR * 260)]
    k = ctypes.WinDLL("kernel32", use_last_error=True)
    k.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    k.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    k.Process32FirstW.argtypes = k.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(Entry)]
    k.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    k.OpenProcess.restype = wintypes.HANDLE
    k.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)]
    k.CloseHandle.argtypes = [wintypes.HANDLE]
    snapshot = k.CreateToolhelp32Snapshot(2, 0)
    if snapshot == ctypes.c_void_p(-1).value:
        return []
    result = []
    try:
        entry = Entry()
        entry.size = ctypes.sizeof(entry)
        more = k.Process32FirstW(snapshot, ctypes.byref(entry))
        while more:
            if entry.name.lower() == "cod25-cod.exe":
                handle = k.OpenProcess(0x1000, False, entry.pid)
                if handle:
                    try:
                        buf, length = ctypes.create_unicode_buffer(32768), wintypes.DWORD(32768)
                        if k.QueryFullProcessImageNameW(handle, 0, buf, ctypes.byref(length)):
                            result.append((Path(buf.value).parent, entry.pid))
                    finally:
                        k.CloseHandle(handle)
            more = k.Process32NextW(snapshot, ctypes.byref(entry))
    finally:
        k.CloseHandle(snapshot)
    return result


def is_kronos(root):
    root = Path(root)
    return (root / "cod25-cod.exe").is_file() and (root / "kronos/tools/acts.exe").is_file()


def discover_root():
    for root, pid in process_roots():
        if is_kronos(root):
            return root, pid
    try:
        root = Path(json.loads(config_path().read_text(encoding="utf-8"))["game_root"])
        if is_kronos(root):
            return root, None
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return None, None


def save_root(root):
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"game_root": str(root)}), encoding="utf-8")


def install_script(root):
    root = Path(root)
    if not is_kronos(root):
        raise ValueError("Selecciona la carpeta cod25 de una instalación de Kronos.")
    if any(r.resolve() == root.resolve() for r, _ in process_roots()):
        raise ValueError("Cierra Black Ops 7 antes de actualizar el script del trainer.")
    source = resource_dir() / "kronos/codex_solo_trainer.gsc"
    target = root / "kronos/custom_scripts/codex_solo_trainer.gsc"
    override = target.with_suffix(".gscc")
    if override.exists():
        raise ValueError("Hay un script compilado prioritario con el mismo nombre; retíralo antes de actualizar.")
    if target.exists() and target.read_bytes() != source.read_bytes():
        backup = config_path().parent / "backups" / str(time.time_ns())
        backup.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, backup / target.name)
    target.parent.mkdir(parents=True, exist_ok=True)
    staged = target.with_name(target.name + "." + str(time.time_ns()) + ".tmp")
    try:
        shutil.copy2(source, staged)
        if hashlib.sha256(staged.read_bytes()).digest() != hashlib.sha256(source.read_bytes()).digest():
            raise OSError("No se pudo verificar el script antes de instalarlo.")
        os.replace(staged, target)
    finally:
        staged.unlink(missing_ok=True)
    if hashlib.sha256(target.read_bytes()).digest() != hashlib.sha256(source.read_bytes()).digest():
        raise OSError("No se pudo verificar la copia del script.")
    for name in ("codexcmd", "codexack", "codexcatalog"):
        (root / "kronos" / name).mkdir(exist_ok=True)
    save_root(root)
    return target
