"""Opciones y configuraciones para el Trainer de Black Ops 7 Zombies."""
from __future__ import annotations
from dataclasses import dataclass

@dataclass(frozen=True)
class Option:
    id: str
    key: str
    title: str
    detail: str
    default: float | None = None
    minimum: float = 0.01
    maximum: float = 100.0
    increment: float = 0.25

OPTIONS = (
    Option("godmode", "Num 1", "Infinite Health / Godmode", "Inmunidad al daño de zombies"),
    Option("ammo", "Num 2", "Infinite Ammo", "Activa la función nativa en el jugador local"),
    Option("no_reload", "Num 3", "No Reload", "Repone el cargador con su capacidad real"),
    Option("equipment", "Num 4", "Infinite Equipment", "Granadas y equipamiento táctico infinito"),
    Option("damage", "Num 5", "Super Damage / One Hit Kill", "Eliminación instantánea de zombies"),
    Option("rapid_fire", "Num 6", "Rapid Fire", "Cadencia de disparo aumentada"),
    Option("no_recoil", "Num 7", "No Recoil (Camera)", "Anula la sacudida de cámara; conserva la dispersión del arma"),
    Option("points", "Num 8", "Add Essence", "Añade esta cantidad de esencia una vez por pulsación", 10000.0, 1.0, 999999.0, 5000.0),
    Option("field_upgrade", "Num 9", "Instant Field Upgrade", "Mejora de campo cargada continuamente"),
    Option("damage_multiplier", "Ctrl + Num 1", "Damage Multiplier", "Multiplicador de daño de armas", 2.0, 1.0, 50.0, 0.5),
    Option("move_speed", "Ctrl + Num 2", "Set Move Speed", "Multiplicador de velocidad de movimiento", 1.5, 0.5, 5.0, 0.1),
    Option("game_speed", "Ctrl + Num 3", "Set Game Speed", "Velocidad de simulación del juego", 1.0, 0.2, 5.0, 0.1),
    Option("fov", "Ctrl + Num 4", "Set Base FOV", "Campo de visión base; el juego también aplica el ajuste del perfil", 100.0, 60.0, 110.0, 5.0),
    Option("jetpack", "Ctrl + Num 5", "Jetpack · impulso", "Mantén salto y usa movimiento para dirigir el vuelo; suelta salto para caer", 300.0, 150.0, 800.0, 50.0),
)

OPTION_BY_ID = {opt.id: opt for opt in OPTIONS}
