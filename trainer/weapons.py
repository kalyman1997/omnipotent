"""Display choices and validation for the game's weapon action channel."""
import re

WEAPONS = (
    ("Ray Gun", "sat_ww_raygun_mp"),
    ("Ray Gun Mark II", "sat_ww_raygunmark2_mp"),
    ("Guantelete de necrofluido", "sat_ww_firefly"),
    ("Arma especial · Hornet", "sat_ww_hornet"),
    ("Luz de Jotunn", "sat_ww_locust"),
    ("Blundergat", "sat_ww_mantis"),
    ("LGM-1", "sat_ww_ruby"),
    ("Arma especial · Scarab", "sat_ww_scarab"),
    ("M15 Mod 0", "sat_ar_hawk"),
    ("FG42", "sat_ar_wren"),
)

# Add entries only after their game-side application contract is established.
AMMO_MODS = (
    ("Eléctrica · Dead Wire", "deadwire"),
    ("Hielo · Cryofreeze", "cryofreeze"),
    ("Fuego · Napalm Burst", "napalmburst"),
    ("Explosiva · Shatter Blast", "shatterblast"),
    ("Aliados · Brain Rot", "brainrot"),
    ("Quitar modificador", "none"),
)
AMMO_MOD_IDS = frozenset(value for _, value in AMMO_MODS)


def weapon_id(value):
    if not isinstance(value, str):
        raise ValueError("Selecciona un arma o escribe su identificador interno.")
    value = value.strip().lower()
    if re.fullmatch(r"[a-z0-9_]{1,96}", value) is None:
        raise ValueError("El identificador del arma solo admite letras, números y guiones bajos (hasta 96 caracteres).")
    return value
